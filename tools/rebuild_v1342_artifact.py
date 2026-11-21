#!/usr/bin/env python3
"""Build isolated v1.3.42 candidates; no publishing, credentials, or artifact upload.

Uses the exact tag commit's build/packaging scripts unchanged. ZIP timestamps are
not rewritten to disguise differences from the original frozen release files.
"""
import argparse
import hashlib
import json
import os
from pathlib import Path
import platform
import shutil
import subprocess
import sys
import urllib.request
import zipfile
import zlib

SOURCE_SHA = '9398dd6796545de37c30c535e7def809c0b613a3'
SOURCE_EPOCH = 1795246581
REPOSITORY = 'https://github.com/lemoncat7/MountainStill.git'
GODOT_NAME = 'Godot_v4.6.3-stable_linux.x86_64.zip'
GODOT_SHA = 'd0bc2113065e481c9c2c2b2c37daa4e8be3fe9e27f0ab9ab0b6096e9a37907f3'
TEMPLATES_NAME = 'Godot_v4.6.3-stable_export_templates.tpz'
TEMPLATES_SHA = '3fbe2c0e2dec9d537ab9ec97bcf8da91dcf23357fc51f67092dd068d839290a8'
DOWNLOAD_BASE = 'https://github.com/godotengine/godot-builds/releases/download/4.6.3-stable/'
FROZEN_MANIFEST = Path(__file__).with_name('v1342_local_candidate.json')

def digest(path):
    with Path(path).open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()

def checked_archive(cache, name, expected):
    target = cache / name
    if not target.exists():
        part = target.with_suffix(target.suffix + '.part')
        with urllib.request.urlopen(DOWNLOAD_BASE + name, timeout=90) as response, part.open('xb') as output:
            shutil.copyfileobj(response, output)
        if digest(part) != expected:
            raise RuntimeError('Official archive digest mismatch: ' + name)
        part.rename(target)
    if not target.is_file() or digest(target) != expected:
        raise RuntimeError('Cached official archive digest mismatch: ' + name)
    return target

def run(command, cwd, env, log, timeout=900):
    with log.open('w') as output:
        result = subprocess.run(command, cwd=cwd, env=env, stdout=output,
                                stderr=subprocess.STDOUT, timeout=timeout)
    if result.returncode:
        raise RuntimeError(f'Failed step ({result.returncode}); see {log}')
    return log.read_text(errors='replace')

def zip_inventory(path):
    with zipfile.ZipFile(path) as archive:
        if archive.testzip() is not None:
            raise RuntimeError('CRC failure: ' + str(path))
        names = archive.namelist()
        if len(names) != len(set(names)):
            raise RuntimeError('Duplicate ZIP names: ' + str(path))
        return {item.filename: {'sha256': hashlib.sha256(archive.read(item)).hexdigest(),
                               'date_time': item.date_time,
                               'external_attr': item.external_attr,
                               'compress_type': item.compress_type}
                for item in archive.infolist()}

def build_once(index, workspace, cache, repository, engine_archive, templates, frozen):
    root = workspace / f'run-{index}'
    root.mkdir()
    source = root / 'source'
    source.mkdir()
    logs = root / 'logs'
    logs.mkdir()
    env = os.environ.copy()
    env.update(TZ='UTC', LC_ALL='C.UTF-8', SOURCE_DATE_EPOCH=str(SOURCE_EPOCH),
               GIT_TERMINAL_PROMPT='0')
    run(['git', 'init', '-q', str(source)], root, env, logs / 'git-init.log')
    run(['git', '-c', 'credential.helper=', 'fetch', '--depth=1', repository, SOURCE_SHA],
        source, env, logs / 'git-fetch.log')
    run(['git', 'checkout', '--detach', 'FETCH_HEAD'], source, env, logs / 'git-checkout.log')
    actual = subprocess.check_output(['git', 'rev-parse', 'HEAD'], cwd=source, text=True).strip()
    if actual != SOURCE_SHA:
        raise RuntimeError('Source commit mismatch')
    tracked = subprocess.check_output(['git', 'ls-files', '-z'], cwd=source).split(b'\0')
    source_hashes = {}
    for raw in tracked:
        if raw:
            name = os.fsdecode(raw)
            file = source / name
            os.utime(file, (SOURCE_EPOCH, SOURCE_EPOCH))
            source_hashes[name] = digest(file)
    for key, value in [('DATA', 'data'), ('CONFIG', 'config'), ('CACHE', 'cache')]:
        directory = root / value
        directory.mkdir()
        env['XDG_' + key + '_HOME'] = str(directory)
    bin_dir = root / 'bin'
    bin_dir.mkdir()
    with zipfile.ZipFile(engine_archive) as archive:
        engine = bin_dir / 'godot'
        engine.write_bytes(archive.read('Godot_v4.6.3-stable_linux.x86_64'))
        engine.chmod(0o755)
    template_dir = root / 'data/godot/export_templates/4.6.3.stable'
    template_dir.mkdir(parents=True)
    with zipfile.ZipFile(templates) as archive:
        for name in ['windows_release_x86_64.exe', 'windows_debug_x86_64.exe', 'macos.zip', 'version.txt']:
            (template_dir / name).write_bytes(archive.read('templates/' + name))
    env['GODOT_BIN'] = str(engine)
    env['PATH'] = str(bin_dir) + os.pathsep + env['PATH']
    version = run([str(engine), '--version'], source, env, logs / 'godot-version.log').strip()
    if version != '4.6.3.stable.official.7d41c59c4':
        raise RuntimeError('Godot version mismatch: ' + version)
    run(['bash', 'tools/build_updater_release.sh'], source, env, logs / 'build.log')
    output = root / 'candidate'
    run([sys.executable, 'tools/package_updater_delivery.py', str(output), '--version', '1.3.42'],
        source, env, logs / 'package.log')
    comparisons = []
    for record in frozen:
        path = output / record['name']
        current = {'name': path.name, 'size': path.stat().st_size, 'sha256': digest(path)}
        current['matches_local_candidate'] = current['size'] == record['size'] and current['sha256'] == record['sha256']
        comparisons.append(current)
        if path.suffix == '.zip':
            (logs / (path.name + '.members.json')).write_text(json.dumps(zip_inventory(path), indent=2))
    changed = [name for name, value in source_hashes.items() if digest(source / name) != value]
    if changed:
        raise RuntimeError('Tracked source modified during build: ' + ', '.join(changed))
    report = {'source_sha': SOURCE_SHA, 'source_date_epoch': SOURCE_EPOCH,
              'godot_version': version, 'godot_archive_sha256': GODOT_SHA,
              'templates_archive_sha256': TEMPLATES_SHA, 'python': sys.version,
              'zlib': zlib.ZLIB_RUNTIME_VERSION, 'platform': platform.platform(),
              'tracked_source_unchanged': True, 'files': comparisons,
              'status': 'REBUILT_CANDIDATE_NOT_RELEASED',
              'scope': 'Linux export/structure/CRC only; not native Windows/macOS execution',
              'requires': 'Every differing SHA is a new candidate requiring renewed acceptance; native driver pins still refer to the frozen original ZIPs.'}
    (output / 'REBUILD-STATUS.json').write_text(json.dumps(report, indent=2) + '\n')
    print(json.dumps({'run': index, 'files': comparisons}), flush=True)
    return report

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--workspace', type=Path, required=True, help='New, nonexisting directory; never frozen output')
    parser.add_argument('--cache', type=Path, required=True, help='Verified official archives only; never uploaded')
    parser.add_argument('--repository', default=REPOSITORY, help='Optional local object source; commit SHA remains fixed')
    parser.add_argument('--repetitions', type=int, choices=[1, 2], default=2)
    args = parser.parse_args()
    if sys.platform != 'linux' or platform.machine() != 'x86_64' or sys.version_info[:2] != (3, 12):
        parser.error('Requires Linux x86_64 and CPython 3.12; exact patch/zlib are recorded, not assumed portable')
    workspace = args.workspace.resolve()
    if workspace.exists():
        parser.error('Workspace must not exist; refusing to overwrite any prior result')
    cache = args.cache.resolve()
    cache.mkdir(parents=True, exist_ok=True)
    frozen = json.loads(FROZEN_MANIFEST.read_text())
    if len(frozen) != 7:
        raise RuntimeError('Expected exactly seven local candidate records')
    engine = checked_archive(cache, GODOT_NAME, GODOT_SHA)
    templates = checked_archive(cache, TEMPLATES_NAME, TEMPLATES_SHA)
    workspace.mkdir(parents=True)
    reports = [build_once(i, workspace, cache, args.repository, engine, templates, frozen)
               for i in range(1, args.repetitions + 1)]
    comparison = {'source_sha': SOURCE_SHA, 'repetitions': args.repetitions,
                  'all_files_match_local_candidate': all(f['matches_local_candidate'] for r in reports for f in r['files']),
                  'repeat_comparison': [], 'native_acceptance': 'NOT_RUN'}
    if len(reports) == 2:
        comparison['repeat_comparison'] = [
            {'name': a['name'], 'same_sha256': a['sha256'] == b['sha256']}
            for a, b in zip(reports[0]['files'], reports[1]['files'])]
    upload = workspace / 'artifact'
    upload.mkdir()
    for record in frozen:
        shutil.copyfile(workspace / 'run-1/candidate' / record['name'], upload / record['name'])
    shutil.copyfile(workspace / 'run-1/candidate/REBUILD-STATUS.json', upload / 'REBUILD-STATUS.json')
    (upload / 'REPRODUCIBILITY.json').write_text(json.dumps(comparison, indent=2) + '\n')
    audit = upload / 'audit'
    audit.mkdir()
    for index in range(1, args.repetitions + 1):
        run_root = workspace / f'run-{index}'
        shutil.copytree(run_root / 'logs', audit / f'run-{index}')
        shutil.copyfile(run_root / 'candidate/REBUILD-STATUS.json',
                        audit / f'run-{index}' / 'REBUILD-STATUS.json')
    # Conservative uncompressed ceiling for a later cost review; not a free-storage guarantee.
    total = sum(p.stat().st_size for p in upload.rglob("*") if p.is_file())
    if total > 700 * 1024 * 1024:
        raise RuntimeError('Candidate exceeds reviewed 700 MiB upper bound')
    print(json.dumps({'artifact_bytes': total, **comparison}), flush=True)

if __name__ == '__main__':
    main()
