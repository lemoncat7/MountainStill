#!/usr/bin/env python3
"""Two actual processes, shared isolated user data, local fixture only."""
import os, pathlib, socket, subprocess, sys, tempfile, time
root = pathlib.Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory(prefix='mountainstill-rate-restart-') as isolated:
    env = dict(os.environ)
    for key, name in [('HOME','home'), ('XDG_DATA_HOME','data'), ('XDG_CONFIG_HOME','config'), ('XDG_CACHE_HOME','cache')]:
        env[key] = str(pathlib.Path(isolated)/name)
        pathlib.Path(env[key]).mkdir()
    server = subprocess.Popen([sys.executable, str(root/'tests/update_http_fixture.py')], stdout=subprocess.DEVNULL, stderr=subprocess.PIPE)
    try:
        for _ in range(40):
            try:
                with socket.create_connection(('127.0.0.1',18765), timeout=.1): break
            except OSError: time.sleep(.05)
        assert server.poll() is None, 'local fixture failed to start'
        for phase in ['seed', 'verify']:
            result = subprocess.run(['godot','--headless','--path',str(root),'--script','res://tests/update_rate_restart_probe.gd','--',phase], env=env, text=True, capture_output=True, timeout=20)
            print(result.stdout, end='')
            assert result.returncode == 0 and 'SCRIPT ERROR' not in result.stderr, result.stderr
        print('UPDATE_RATE_RESTART: actual two-process local HTTP PASS')
    finally:
        server.terminate(); server.wait(timeout=5)
