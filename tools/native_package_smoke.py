#!/usr/bin/env python3
"""Run pinned, unmodified release executables on disposable official CI VMs only."""
import hashlib
import json
import math
import os
from pathlib import Path, PurePosixPath
import platform
import re
import shutil
import stat
import sys
import tempfile
import time
import urllib.error
import urllib.request
import uuid
import zipfile

from native_platform_smoke import configure_output, run, unexpected_errors

TAG = 'v1.3.29-test.1'
VERSION = '1.3.29-test.1'
APP = '山隐 · Mountain Still'
PACKAGES = {
    'win32': ('MountainStill-v1.3.29-test.1-Windows-x86_64.zip',
              '00e9ed6436d450cd60788f7bc15d11b4b79a81ec3993c2ffac784174e15418b6',
              'MountainStill/MountainStill.exe', 114565395),
    'darwin': ('MountainStill-v1.3.29-test.1-macOS-Universal.zip',
               'faf004c2700812ff8f3081daf77c6d220c2be360662804ea7213952290aed9d8',
               APP + '.app/Contents/MacOS/' + APP, 141296431),
}
ASSETS = (
    'res://assets/cultivation/beasts/creek_bridge_boss_settle.png',
    'res://assets/cultivation/beasts/creek_bridge_boss_retract.png',
)


def safe_members(bundle):
    """Validate all names before extracting any bytes; reject links and aliases."""
    seen = set()
    total = 0
    for member in bundle.infolist():
        name = member.filename
        parts = PurePosixPath(name).parts
        mode = member.external_attr >> 16
        if (not parts or name.startswith('/') or '\\' in name or ':' in name
                or any(p in ('..', '.') for p in name.rstrip('/').split('/'))
                or any(not p or p.endswith((' ', '.')) for p in name.rstrip('/').split('/'))
                or stat.S_ISLNK(mode)
                or stat.S_IFMT(mode) not in (0, stat.S_IFREG, stat.S_IFDIR)
                or any(p.split('.')[0].upper() in {'CON', 'PRN', 'AUX', 'NUL',
                       *('COM' + str(i) for i in range(1, 10)),
                       *('LPT' + str(i) for i in range(1, 10))} for p in parts)):
            raise ValueError('Unsafe archive member: ' + repr(name))
        normalized = name.rstrip('/').casefold()
        if normalized in seen:
            raise ValueError('Duplicate archive path: ' + repr(name))
        seen.add(normalized)
        total += member.file_size
    if total > 400_000_000:
        raise ValueError('Unexpected expanded archive size')
    return bundle.infolist()


def extract(archive, destination):
    with zipfile.ZipFile(archive) as bundle:
        members = safe_members(bundle)
        for member in members:
            target = destination.joinpath(*PurePosixPath(member.filename).parts)
            if member.is_dir():
                target.mkdir(parents=True, exist_ok=True)
            else:
                target.parent.mkdir(parents=True, exist_ok=True)
                with bundle.open(member) as source, target.open('xb') as sink:
                    shutil.copyfileobj(source, sink)
                if os.name != 'nt':
                    target.chmod(0o755 if member.external_attr >> 16 & 0o111 else 0o644)


def download(target, expected_size, digest):
    url = 'https://github.com/lemoncat7/MountainStill/releases/download/' + TAG + '/' + target.name
    for attempt in range(3):
        try:
            with urllib.request.urlopen(url, timeout=45) as response, target.open('wb') as sink:
                size = 0
                while chunk := response.read(1024 * 1024):
                    size += len(chunk)
                    if size > expected_size:
                        raise ValueError('Release archive exceeds pinned size')
                    sink.write(chunk)
            break
        except (urllib.error.URLError, TimeoutError, ConnectionError):
            if attempt == 2:
                raise
            time.sleep(2 ** attempt)
    hasher = hashlib.sha256()
    with target.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            hasher.update(chunk)
    actual = hasher.hexdigest()
    if target.stat().st_size != expected_size or actual != digest:
        raise ValueError('Release archive size/SHA256 mismatch; refusing execution')
    print('Verified public release archive SHA256: ' + actual, flush=True)


def userdata_path():
    if sys.platform == 'win32':
        base = Path(os.environ['APPDATA'])
    elif sys.platform == 'darwin':
        base = Path.home() / 'Library' / 'Application Support'
    else:
        raise RuntimeError('Only native Windows/macOS supported; Linux cannot certify these packages')
    return base / 'Godot' / 'app_userdata' / APP


def claim_userdata(path, token):
    # mkdir(exist_ok=False) is the ownership boundary. Never adopt an existing save.
    if path.exists() or path.is_symlink():
        raise RuntimeError('User-data path already exists; refusing to read, launch or remove it')
    path.mkdir(parents=True, exist_ok=False)
    (path / '.native-package-ci-owner').write_text(token, encoding='ascii')


def cleanup_userdata(path, token):
    marker = path / '.native-package-ci-owner'
    if path.is_symlink() or not marker.is_file() or marker.is_symlink() or marker.read_text(encoding='ascii') != token:
        raise RuntimeError('User-data ownership lost; refusing cleanup')
    shutil.rmtree(path)


def read_save(path):
    if not path.is_file() or path.is_symlink() or path.stat().st_size > 262144:
        raise AssertionError('Expected game-created bounded regular save file')
    data = json.loads(path.read_text(encoding='utf-8'))
    lifetime = data.get('lifetime_seconds')
    if data.get('version') != 4 or type(lifetime) not in (int, float) or not math.isfinite(lifetime) or lifetime < 0:
        raise AssertionError('Expected valid current save schema/lifetime')
    return data


def check_boot(output):
    if unexpected_errors(output, 'release-package'):
        raise AssertionError('Packaged executable emitted errors/leaks/crash diagnostics')
    if not re.search(r'^UPDATE BOOT: ' + re.escape(VERSION) + r'\s*$', output, re.M):
        raise AssertionError('Expected installed release bootstrap version missing')
    # Godot --verbose records actual resource-loader calls, not archive listing.
    for asset in ASSETS:
        if not any('Loading resource:' in line and asset in line for line in output.splitlines()):
            raise AssertionError('No native resource-loader evidence for required texture: ' + asset)


def check_saved_progress(current, backup, previous):
    for saved in (current, backup):
        if any(saved.get(k) != previous[k] for k in ('herbs', 'dew', 'combat_tactic')):
            raise AssertionError('Second boot/backup did not retain external fixture choices/resources')
    if current['lifetime_seconds'] < previous['lifetime_seconds'] + 9.99:
        raise AssertionError('Second boot did not advance loaded progress')
    if current['lifetime_seconds'] < backup['lifetime_seconds'] + 9.99:
        raise AssertionError('No second autosave beyond initial load/offline-award save')


def main():
    configure_output()
    results = []
    owned = False
    userdata = None
    token = uuid.uuid4().hex
    try:
        if (os.environ.get('GITHUB_ACTIONS') != 'true'
                or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'
                or os.environ.get('GITHUB_REPOSITORY') != 'lemoncat7/MountainStill'):
            raise RuntimeError('Default user directory allowed only on disposable official repository CI VM')
        name, digest, executable, size = PACKAGES[sys.platform]
        print(f'Native OS={sys.platform}; process architecture={platform.machine()}', flush=True)
        userdata = userdata_path()
        print('Actual default Godot user:// OS path: ' + str(userdata), flush=True)
        claim_userdata(userdata, token)
        owned = True
        (userdata / 'updates').mkdir()
        # Public update-network calls are irrelevant to a fixed installed-package test.
        (userdata / 'updates' / 'preferences.cfg').write_text('[updates]\nauto_check=false\n', encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='mountainstill-package-', dir=os.environ['RUNNER_TEMP']) as scratch:
            root = Path(scratch)
            archive = root / name
            download(archive, size, digest)
            destination = root / 'installed'
            extract(archive, destination)
            binary = destination / executable
            if not binary.is_file():
                raise AssertionError('Pinned executable absent')
            results.append(('fixed public release SHA256 and safe extraction', 'PASS'))
            save_path = userdata / 'cultivation_save.json'
            previous = None
            for boot in (1, 2):
                logfile = root / f'boot-{boot}.log'
                command = [str(binary), '--headless', '--verbose', '--log-file', str(logfile),
                           '--fixed-fps', '60', '--quit-after', '900']
                print(f'=== Actual packaged executable boot {boot}; engine frame-limited normal exit ===', flush=True)
                code, stdout = run(command, 120)
                logged = logfile.read_text(encoding='utf-8', errors='replace') if logfile.is_file() else ''
                if logged != stdout:
                    print('=== Native Godot log-file ===\n' + logged, flush=True)
                if code != 0:
                    raise AssertionError(f'Native executable exit code {code}')
                check_boot(stdout + '\n' + logged)
                current = read_save(save_path)
                if current['lifetime_seconds'] < 10:
                    raise AssertionError('No first automatic gameplay save after ten simulated seconds')
                print('Observed save:', json.dumps({k: current[k] for k in ('version', 'lifetime_seconds', 'herbs', 'dew', 'combat_tactic')}), flush=True)
                if boot == 1:
                    # External save fixture, never an injected/replaced executable script.
                    current.update(herbs=123, dew=7, combat_tactic='guarded', auto_advance=False,
                                   activity='meditate', qi=0)
                    current['settings']['paused'] = False
                    previous = current.copy()
                    save_path.write_text(json.dumps(current, ensure_ascii=False), encoding='utf-8')
                    print('External fixture: herbs=123, dew=7, tactic=guarded, manual meditate; based on real first-boot save')
                else:
                    backup = read_save(save_path.with_suffix('.json.bak'))
                    check_saved_progress(current, backup, previous)
                    if list(userdata.glob('*invalid*')):
                        raise AssertionError('Fixture rejected or corrupt-save recovery occurred')
                results.append((f'actual native package boot {boot}, settle/retract loads, save and engine exit', 'PASS'))
    except Exception as error:
        print(f'Native package smoke FAILED: {type(error).__name__}: {error}', flush=True)
        results.append(('package check', 'FAIL'))
    finally:
        if owned:
            try:
                cleanup_userdata(userdata, token)
                results.append(('only job-owned user data removed', 'PASS'))
            except Exception as error:
                print(f'Cleanup FAILED: {error}', flush=True)
                results.append(('job-owned cleanup', 'FAIL'))
        summary = '## Native installed-package smoke (' + TAG + ')\n\n'
        summary += '\n'.join(f'- {state}: {name}' for name, state in results)
        summary += '\n\nActual EXE/app, no substituted engine or altered packaged scripts. External legitimate-save fixture. Headless resource loading + automatic saves + frame-limited engine exit only. NOT GUI close/save guard, rendered art, DPI, transparency, GPU, performance, signing/Gatekeeper, or updater-chain certification.\n'
        print(summary, flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as sink:
                sink.write(summary)
    return 0 if len(results) == 4 and all(state == 'PASS' for _, state in results) else 1


if __name__ == '__main__':
    sys.exit(main())
