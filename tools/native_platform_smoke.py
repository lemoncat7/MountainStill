#!/usr/bin/env python3
"""Native headless source checks; no release/GUI/update-chain certification."""
import argparse
import os
from pathlib import Path
import re
import platform
import shutil
import signal
import subprocess
import sys
import tempfile
import uuid

TESTS = {
    'test_cultivation.gd': r'Cultivation tests: [1-9]\d* checks, 0 failures',
    'test_scene_art_layout.gd': r'Scene original-art layout: [1-9]\d* checks, 0 failures \(geometry/resource, not native graphics\)',
    'test_stone_recovery_contract.gd': r'Stone recovery contract: [1-9]\d* checks, 0 failures',
    'test_chapter_practice_navigation.gd': r'Chapter practice navigation: [1-9]\d* checks, 0 failures',
    'test_practice_host.gd': r'Practice host: [1-9]\d* checks, 0 failures',
    'test_shutdown_lifecycle.gd': r'Shutdown lifecycle: [1-9]\d* checks, 0 failures',
    'update_policy_test.gd': r'update_policy: [1-9]\d* checks passed',
    'update_store_test.gd': r'UPDATE STORE: [1-9]\d* checks, 0 failures',
}
# Deliberate fault-injection diagnostics must be listed by test and exact line.
EXPECTED_ERRORS = {}
ERROR = re.compile(r'^(?:SCRIPT ERROR:|ERROR:|FAIL:)|\b(?:leaked|orphan|crashed)\b', re.I)


def unexpected_errors(output, test):
    allowed = EXPECTED_ERRORS.get(test, ())
    return [line for line in output.splitlines()
            if ERROR.search(line.strip()) and line.strip() not in allowed]


def run(command, timeout):
    process = subprocess.Popen(command, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                               text=True, encoding='utf-8', errors='replace',
                               start_new_session=(os.name != 'nt'))
    try:
        output, _ = process.communicate(timeout=timeout)
        print(output, end='', flush=True)
        return process.returncode, output
    except subprocess.TimeoutExpired:
        # The Windows console launcher can have a child engine process.
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
        else:
            os.killpg(process.pid, signal.SIGKILL)
        process.kill()
        output, _ = process.communicate(timeout=10)
        print(output, end='', flush=True)
        print(f'TIMEOUT after {timeout}s', flush=True)
        return 124, output


def user_data_base():
    if sys.platform == 'win32':
        return Path(os.environ['APPDATA'])
    if sys.platform == 'darwin':
        return Path.home() / 'Library' / 'Application Support'
    return Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local' / 'share'))


def configure_output():
    # Windows redirected Actions stdout can default to a narrow code page even
    # though Godot output was decoded as UTF-8. Keep full Unicode diagnostics.
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8', errors='backslashreplace')


def main():
    configure_output()
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--godot', required=True)
    parser.add_argument('--project', type=Path, default=Path(__file__).resolve().parents[1])
    args = parser.parse_args()
    godot = str(Path(args.godot).resolve())
    results = []
    print(f'Platform: {sys.platform}; architecture: {platform.machine()}', flush=True)
    name = 'MountainStillNativeSmoke-' + uuid.uuid4().hex
    userdata = user_data_base() / name
    if userdata.exists():
        raise RuntimeError('Isolation directory must not already exist')
    try:
        code, version = run([godot, '--version'], 15)
        if code or not version.strip().startswith('4.6.3.stable.'):
            raise RuntimeError('Expected verified Godot 4.6.3 stable; refusing tests')
        with tempfile.TemporaryDirectory(prefix='mountainstill-native-') as scratch:
            project = Path(scratch) / 'project'
            shutil.copytree(args.project, project, ignore=shutil.ignore_patterns('.git', '.godot', '__pycache__'))
            override = project / 'override.cfg'
            if override.exists():
                raise RuntimeError('Refuse to overwrite existing project override.cfg')
            override.write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n', encoding='utf-8')
            probe = project / 'native_ci_userdata_probe.gd'
            probe.write_text('extends SceneTree\nfunc _initialize():\n print("NATIVE_USERDATA=" + OS.get_user_data_dir())\n quit()\n', encoding='utf-8')
            common = [godot, '--headless', '--path', str(project)]
            code, output = run(common + ['--script', str(probe)], 60)
            matches = re.findall(r'^NATIVE_USERDATA=(.+)$', output, re.M)
            if code or len(matches) != 1 or Path(matches[0]).resolve() != userdata.resolve() or unexpected_errors(output, 'probe'):
                raise RuntimeError('Godot user:// isolation probe failed; no gameplay tests executed')
            results.append(('userdata isolation probe', 'PASS'))
            code, output = run(common + ['--editor', '--import'], 240)
            if code or unexpected_errors(output, 'import'):
                raise RuntimeError('Godot source import failed')
            results.append(('source resource import', 'PASS'))
            for test, marker in TESTS.items():
                print(f'\n=== {test} ===', flush=True)
                code, output = run(common + ['--script', 'res://tests/' + test], 60)
                okay = code == 0 and re.search('^' + marker + '$', output, re.M) and not unexpected_errors(output, test)
                results.append((test, 'PASS' if okay else 'FAIL'))
    except Exception as error:
        print(f'Native smoke aborted: {error}', flush=True)
        results.append(('driver/setup', 'FAIL'))
    finally:
        # A random child name, never the platform's entire Application Support/AppData.
        try:
            if userdata.exists():
                shutil.rmtree(userdata)
        except OSError as error:
            print(f'Isolated user-data cleanup failed: {error}', flush=True)
            results.append(('userdata cleanup', 'FAIL'))
        summary = '## Native headless source smoke\n\n' + '\n'.join(f'- {state}: `{test}`' for test, state in results)
        summary += '\n\nNot GUI, DPI, GPU, transparency, signing, release executable or full native update-chain validation.\n'
        print(summary)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'], 'a', encoding='utf-8') as stream:
                stream.write(summary)
    return 0 if len(results) == len(TESTS) + 2 and all(state == 'PASS' for _, state in results) else 1


if __name__ == '__main__':
    sys.exit(main())
