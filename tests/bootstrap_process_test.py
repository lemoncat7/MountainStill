#!/usr/bin/env python3
"""Real PCK mount in fresh Godot processes; no mock of bootstrap/store."""
import json, os, pathlib, subprocess, tempfile, re
ROOT = pathlib.Path(__file__).resolve().parents[1]
BUILTIN_VERSION = re.search(r'const BUILTIN_VERSION = "([^"]+)"', (ROOT/"scripts/update_store.gd").read_text()).group(1)
def run(env, *args, expected=0):
    p = subprocess.run(['godot', '--headless', '--path', str(ROOT), *args], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT, timeout=60)
    print(p.stdout)
    assert p.returncode == expected, (p.returncode, expected)
    if expected == 0: assert 'SCRIPT ERROR' not in p.stdout and '\nERROR:' not in p.stdout
    return p.stdout
with tempfile.TemporaryDirectory(prefix='ms-bootstrap-') as tmp:
    env = dict(os.environ, HOME=tmp, XDG_DATA_HOME=tmp)
    run(env, '--script', 'tests/bootstrap_stage_fixture.gd')
    output = run(env)
    assert 'UPDATE BOOT: 1.3.24-test.2' in output and 'FIXTURE_GAME nested-updated-2' in output
    output = run(env)
    assert 'UPDATE BOOT: 1.3.24-test.2' in output and 'FIXTURE_GAME nested-updated-2' in output
with tempfile.TemporaryDirectory(prefix='ms-bootstrap-broken-') as tmp:
    env = dict(os.environ, HOME=tmp, XDG_DATA_HOME=tmp)
    run(env, '--script', 'tests/bootstrap_stage_fixture.gd', '--', '--broken')
    updates = next(pathlib.Path(tmp).rglob('cultivation_save.json')).parent
    save = updates / 'cultivation_save.json'
    original = save.read_bytes()
    run(env, expected=1)
    output = run(env, '--quit-after', '5')
    assert 'UPDATE BOOT: ' + BUILTIN_VERSION in output and '已回退' in output
    assert next(p for p in (updates / 'updates').glob('recovered-newer-snapshot-*') if not p.name.endswith('.bak')).read_text() == 'newer broken save'
    assert json.loads(save.read_text())['version'] == json.loads(original)['version']
print('BOOTSTRAP PROCESS: healthy mount + nested preload + persistent next launch + failed boot rollback PASS')
# Keep a real first game alive; a second process must fail before updater startup.
import socket, time
with tempfile.TemporaryDirectory(prefix='ms-bootstrap-lock-') as tmp:
    env = dict(os.environ, HOME=tmp, XDG_DATA_HOME=tmp)
    first = subprocess.Popen(['godot', '--headless', '--path', str(ROOT)], env=env, text=True, stdout=subprocess.PIPE, stderr=subprocess.STDOUT)
    try:
        deadline = time.monotonic() + 20
        while True:
            assert first.poll() is None, 'first instance exited before lock'
            try:
                with socket.create_connection(('127.0.0.1', 47893), timeout=.2): pass
                break
            except OSError:
                assert time.monotonic() < deadline, 'first instance did not bind lock'
                time.sleep(.1)
        output = run(env, '--quit-after', '5', expected=2)
        assert 'UPDATE LOCK:' in output and 'UPDATE BOOT:' not in output
    finally:
        first.terminate()
        first_output = first.communicate(timeout=20)[0]
        print(first_output)
        assert 'UPDATE LOCK:' not in first_output, 'first instance failed lock'
print('BOOTSTRAP SINGLETON: concurrent process rejected before updater startup PASS')
