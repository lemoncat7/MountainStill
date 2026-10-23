#!/usr/bin/env python3
"""Capability evidence only; GUI_OBSERVED requires independent screenshot review."""
import base64
import hashlib
import json
import os
import platform
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import uuid

from native_package_smoke import (APP, claim_userdata, cleanup_userdata, configure_output,
                                  download, extract, userdata_path)

# Independent immutable pin: later package-smoke upgrades MUST NOT retarget this probe.
TAG = 'v1.3.17-test.1'
PACKAGES = {
    'win32': ('MountainStill-v1.3.17-test.1-Windows-x86_64.zip',
              'cea0c082645140b4b94600cc7d15fa4e642e461ad20738c66223272df49a0bfd',
              'MountainStill/MountainStill.exe', 114376509),
    'darwin': ('MountainStill-v1.3.17-test.1-macOS-Universal.zip',
               '9a9c06b3fbda05ac5e4097015002e8070e15c9c47916e1e9409e51503f4a712f',
               APP + '.app/Contents/MacOS/' + APP, 141109182),
}
PNG_BUDGET = 1024 * 1024
ARGS = ['--verbose', '--max-fps', '60', '--quit-after', '1800']


def frame_png(path, remaining):
    size = path.stat().st_size
    if not 8 <= size <= remaining:
        raise ValueError('PNG exceeds combined 1 MiB budget')
    data = path.read_bytes()
    if not data.startswith(b'\x89PNG\r\n\x1a\n'):
        raise ValueError('Not PNG')
    print(f'BEGIN_GUI_PNG {path.name} {size} {hashlib.sha256(data).hexdigest()}')
    encoded = base64.b64encode(data).decode('ascii')
    for offset in range(0, len(encoded), 4000):
        print(encoded[offset:offset + 4000])
    print('END_GUI_PNG ' + path.name, flush=True)
    return size


def bounded_log(text):
    # Keep every stdout line below 4 KiB even for pathological engine errors.
    for line in text.splitlines():
        raw = line.encode('utf-8', errors='backslashreplace')
        for offset in range(0, len(raw), 3000):
            print(raw[offset:offset + 3000].decode('utf-8', errors='replace'), flush=True)


def stop_owned(process):
    if process is None or process.poll() is not None:
        return
    if sys.platform == 'win32':
        try:
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           capture_output=True, timeout=2, check=False)
        except (subprocess.TimeoutExpired, OSError):
            pass
        if process.poll() is None:
            process.kill()
    else:
        process.kill()
    process.wait(timeout=2)


def capture_command(root, pid, output):
    if sys.platform == 'win32':
        return ['powershell', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('native_gui_capture.ps1')),
                '-TargetPid', str(pid), '-OutputPath', str(output)]
    return [str(root / 'capture'), str(pid), str(output)]


def main():
    configure_output()
    process = None
    owned = False
    token = uuid.uuid4().hex
    status = 'CAPTURE_INCONCLUSIVE'
    reason = 'not_started'
    try:
        if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'
            or os.environ.get('GITHUB_REPOSITORY') != 'lemoncat7/MountainStill'
            or sys.platform not in PACKAGES):
            raise RuntimeError('Only disposable official Windows/macOS repository runners allowed')
        # Download helper URL is pin-owned, not whatever a future smoke driver targets.
        import native_package_smoke
        native_package_smoke.TAG = TAG
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-', dir=os.environ['RUNNER_TEMP']) as tmp:
            root = Path(tmp)
            name, sha, executable, size = PACKAGES[sys.platform]
            archive = root / name
            download(archive, size, sha)
            extract(archive, root / 'app')
            if sys.platform == 'darwin':
                architecture = platform.machine()
                if architecture not in ('arm64', 'x86_64'):
                    raise RuntimeError('Unexpected native macOS architecture')
                built = subprocess.run(['swiftc', '-target', architecture + '-apple-macosx15.0', '-parse-as-library', str(Path(__file__).with_name('native_gui_capture.swift')),
                                        '-o', str(root / 'capture')], capture_output=True, text=True, timeout=120)
                if built.returncode:
                    bounded_log(built.stderr[-12000:])
                    raise RuntimeError('Native capture helper compilation failed; app not evaluated')
            userdata = userdata_path()
            claim_userdata(userdata, token)
            owned = True
            (userdata / 'updates').mkdir()
            (userdata / 'updates' / 'preferences.cfg').write_text('[updates]\nauto_check=false\n', encoding='utf-8')
            with (root / 'game.log').open('wb') as log:
                started = time.monotonic()
                process = subprocess.Popen([str(root / 'app' / executable), *ARGS], stdout=log, stderr=subprocess.STDOUT)
                budget = PNG_BUDGET
                captures = []
                for index, target in enumerate((5, 12)):
                    while process.poll() is None and time.monotonic() - started < target:
                        time.sleep(.2)
                    if process.poll() is not None:
                        break
                    png = root / f'capture-{index + 1}.png'
                    remaining = 55 - (time.monotonic() - started)
                    if remaining <= 0:
                        break
                    try:
                        result = subprocess.run(capture_command(root, process.pid, png), capture_output=True,
                                                text=True, encoding='utf-8', errors='replace', timeout=min(15, remaining))
                        metadata = json.loads(result.stdout.strip())
                        bounded_log('CAPTURE_METADATA ' + json.dumps(metadata, ensure_ascii=True))
                        captures.append(metadata)
                        if metadata['status'] == 'ENVIRONMENT_UNAVAILABLE':
                            break
                        if metadata['status'] == 'CAPTURE_READY':
                            budget -= frame_png(png, budget)
                    except (ValueError, OSError, subprocess.TimeoutExpired) as error:
                        bounded_log('CAPTURE_ERROR ' + str(error))
                remaining = max(.01, 55 - (time.monotonic() - started))
                timed_out = False
                try:
                    process.wait(timeout=remaining)
                except subprocess.TimeoutExpired:
                    timed_out = True
                    stop_owned(process)
            output = (root / 'game.log').read_text(encoding='utf-8', errors='replace')
            # Public synthetic first-run data only; bounded renderer/startup diagnostics.
            bounded_log('GAME_LOG_BEGIN\n' + output[:24000] + '\nGAME_LOG_END')
            print(json.dumps({'exit_code': process.returncode, 'elapsed_seconds':round(time.monotonic()-started,2),
                              'forced_timeout':timed_out, 'normal_exit_is_not_ui_close_test':True}))
            renderer_failure = any(x in output.lower() for x in ('unable to create opengl', 'could not initialize opengl', 'failed to create opengl', 'unable to initialize vulkan', 'could not initialize vulkan'))
            if renderer_failure:
                status, reason = 'ENVIRONMENT_UNAVAILABLE', 'default_renderer_initialization_failed_requires_triage'
            elif 'SCRIPT ERROR:' in output or 'ERROR:' in output:
                status, reason = 'APPLICATION_FAILURE', 'engine_error_requires_triage'
            elif timed_out:
                status, reason = 'CAPTURE_INCONCLUSIVE', '60_second_owned_process_deadline'
            elif process.returncode != 0:
                status, reason = 'APPLICATION_FAILURE', 'nonzero_exit_requires_triage'
            elif any(c['status'] == 'ENVIRONMENT_UNAVAILABLE' for c in captures):
                status, reason = 'ENVIRONMENT_UNAVAILABLE', 'capture_permission_or_desktop_unavailable'
            else:
                status, reason = 'CAPTURE_INCONCLUSIVE', 'independent_image_review_required' if budget < PNG_BUDGET else 'no_capture'
    except Exception as error:
        reason = type(error).__name__ + ': ' + str(error)
    finally:
        try:
            stop_owned(process)
        except Exception as error:
            status, reason = 'CAPTURE_INCONCLUSIVE', 'owned_process_cleanup_failed: ' + str(error)
        try:
            if owned and (process is None or process.poll() is not None):
                cleanup_userdata(userdata, token)
            elif owned:
                status, reason = 'CAPTURE_INCONCLUSIVE', 'process_still_alive_userdata_left_for_runner_disposal'
        except Exception as error:
            status, reason = 'CAPTURE_INCONCLUSIVE', 'userdata_cleanup_failed: ' + str(error)
    bounded_log('GUI_PROBE_RESULT ' + json.dumps({'status':status, 'reason':reason[:1500]}))
    return 1 if status == 'APPLICATION_FAILURE' else 0


if __name__ == '__main__':
    sys.exit(main())
