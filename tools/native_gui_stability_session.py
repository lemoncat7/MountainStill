#!/usr/bin/env python3
"""Owned macOS ARM GUI lifecycle session; no input injection, AX or TCC requests.

Caller provides the verified actual v28-test.1 binary and precompiled root/capture Swift
helper. No saves are opened here. This is not screenshots, GPU timing or proof
that a particular application Quit handler ran.
"""
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import subprocess
import sys
import tempfile
import time

from native_package_stability import (boot_ready, emit, LOG_BUDGET, SAMPLE_INTERVAL,
    memory_summary, metric_interval, read_log_bounded, require_terminal,
    sample, stop_failed_process)
from native_platform_smoke import unexpected_errors

HELPER_BUDGET = 64 * 1024
SETUP_SECONDS = 60
CLOSE_GRACE_SECONDS = 30


def native_json(command, timeout=5):
    """Bound both helper wall time and stdout/stderr bytes; never unbounded PIPE."""
    process = None
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        try:
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr,
                                       start_new_session=True)
            deadline = time.monotonic() + timeout
            while process.poll() is None:
                if os.fstat(stdout.fileno()).st_size + os.fstat(stderr.fileno()).st_size > HELPER_BUDGET:
                    raise RuntimeError('HELPER_OUTPUT_BUDGET_EXCEEDED')
                if time.monotonic() >= deadline:
                    raise RuntimeError('HELPER_TIMEOUT: request result unconfirmed')
                time.sleep(.05)
            if process.wait(timeout=1) != 0:
                raise RuntimeError('NATIVE_HELPER_FAILURE: nonzero exit')
            if os.fstat(stdout.fileno()).st_size + os.fstat(stderr.fileno()).st_size > HELPER_BUDGET:
                raise RuntimeError('HELPER_OUTPUT_BUDGET_EXCEEDED')
            stdout.seek(0)
            data = stdout.read(HELPER_BUDGET + 1)
            value = json.loads(data.decode('utf-8', errors='strict'))
            if not isinstance(value, dict):
                raise RuntimeError('NATIVE_HELPER_FAILURE: object result required')
            return value
        finally:
            if process is not None and process.poll() is None:
                stop_failed_process(process)
            if process is not None and process.poll() is None:
                raise RuntimeError('NATIVE_HELPER_FAILURE: helper exit unconfirmed')


def visible_geometry(value, pid):
    if value.get('status') != 'GEOMETRY_READY':
        return False
    return (type(value.get('owner_pid')) is int and value['owner_pid'] == pid
            and type(value.get('window_id')) is int and value['window_id'] > 0
            and all(type(value.get(key)) in (int, float)
                    and math.isfinite(value[key]) and value[key] > 20
                    for key in ('window_width_points', 'window_height_points')))


def require_close_request(value, pid):
    if value.get('status') != 'CLOSE_REQUEST_SENT' or type(value.get('owner_pid')) is not int or value['owner_pid'] != pid:
        raise RuntimeError('CLOSE_REQUEST_UNCONFIRMED: not successful normal Quit request for owned PID')


def require_gui_terminal(code, ready_wall, minimum, close_sent, before_geometry, after_geometry, pid):
    require_terminal(code, ready_wall, minimum)
    if not close_sent or not visible_geometry(before_geometry, pid) or not visible_geometry(after_geometry, pid):
        raise RuntimeError('EVIDENCE_INSUFFICIENT: owned visible window and successful close request required')


def _logs_ok(root, paths):
    if sum(p.stat().st_size for p in root.glob('*.log')) > LOG_BUDGET:
        raise RuntimeError('LOG_BUDGET_EXCEEDED: not silently truncated')
    for path in paths:
        if unexpected_errors(read_log_bounded(path), 'actual-gui-stability'):
            raise RuntimeError('APPLICATION_FAILURE: engine error/leak/crash diagnostic')


def session(binary, root, label, minimum, timeout, rows_out, registry, capture=False):
    """Run seed/restart (30s/120s bound) or long (1200s/1500s bound).

    Return normal exit + real post-readiness wall + memory summary for long phase.
    No game process is cleaned as success after forced termination. Caller must
    confirm every registry process has exited before accessing/cleaning userdata.
    """
    if sys.platform != 'darwin' or platform.machine().lower() not in ('arm64', 'aarch64'):
        raise RuntimeError('ENVIRONMENT_UNAVAILABLE: dedicated macOS ARM GUI session only')
    if capture:
        raise ValueError('Screenshots not implemented by this lifecycle session; use capture=False')
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', label):
        raise ValueError('Invalid phase label')
    if type(minimum) is not int or minimum not in (30, 1200) or timeout != (120 if minimum == 30 else 1500):
        raise ValueError('Only reviewed 30-second or 20-minute lifecycle profiles allowed')
    root = Path(root)
    helper = root / 'capture'
    if not helper.is_file() or not Path(binary).is_file():
        raise RuntimeError('Verified binary or precompiled helper absent')
    logfile, stdoutfile = (root / (label + suffix) for suffix in ('.engine.log', '.stdout.log'))
    command = [str(binary), '--verbose', '--log-file', str(logfile)]
    started, launch_epoch = time.monotonic(), time.time()
    ready = ready_epoch = None
    previous = first_identity = None
    next_sample = started
    next_geometry = started
    process = None
    rows = []
    before_geometry, after_geometry = {}, {}
    close_requested = None
    close_sent = False
    close_result = None
    close_ready_wall = None
    try:
        with stdoutfile.open('xb') as sink:
            process = subprocess.Popen(command, stdout=sink, stderr=subprocess.STDOUT,
                                       start_new_session=True)
            registry.append(process)
            emit('OWNED_GUI_PROCESS', dict(phase=label, pid=process.pid, args=command[1:]))
            while process.poll() is None:
                now = time.monotonic()
                if now - started > timeout:
                    raise RuntimeError('TIMEOUT: forced cleanup is not normal GUI exit')
                if close_requested is not None and now - close_requested > CLOSE_GRACE_SECONDS:
                    raise RuntimeError('CLOSE_TIMEOUT: normal Quit did not exit within grace')
                _logs_ok(root, (stdoutfile, logfile))
                if ready is None:
                    if now - started > SETUP_SECONDS:
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: bootstrap and visible window readiness timeout')
                    if now >= next_geometry and boot_ready(read_log_bounded(logfile)):
                        geometry = native_json([str(helper), str(process.pid), '--geometry-only'])
                        next_geometry = time.monotonic() + 1
                        emit('GUI_GEOMETRY', dict(phase=label, moment='setup', metadata=geometry))
                        if geometry.get('status') == 'ENVIRONMENT_UNAVAILABLE':
                            raise RuntimeError('ENVIRONMENT_UNAVAILABLE: helper reports no desktop')
                        if visible_geometry(geometry, process.pid):
                            if time.monotonic() - started > SETUP_SECONDS:
                                raise RuntimeError('EVIDENCE_INSUFFICIENT: geometry readiness exceeded setup bound')
                            before_geometry = geometry
                            ready, ready_epoch = time.monotonic(), time.time()
                            emit('GUI_READY', dict(phase=label, launch_to_ready_s=ready-started,
                                                   evidence='fixed boot/assets plus visible owned PID window'))
                if process.poll() is not None:
                    break
                now = time.monotonic()
                if now >= next_sample:
                    try:
                        current = sample(process.pid)
                    except Exception:
                        if process.poll() is not None:
                            break
                        raise
                    if process.poll() is not None:
                        break
                    if first_identity is None:
                        first_identity = current['identity']
                    if not first_identity or current['identity'] != first_identity:
                        raise RuntimeError('OWNED_PROCESS_IDENTITY_CHANGED')
                    cpu = None if previous is None else metric_interval(previous, current, now-previous['sample_mono'])
                    if not math.isfinite(current['rss_bytes']) or current['rss_bytes'] <= 0:
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: invalid native RSS')
                    row = dict(current, phase=label, wall_s=now-started,
                               ready_wall_s=None if ready is None else now-ready,
                               cpu_percent_one_core=cpu)
                    rows.append(row)
                    rows_out.append(row)
                    emit('PROCESS_SAMPLE', row)
                    previous = dict(current, sample_mono=now)
                    next_sample = now + SAMPLE_INTERVAL
                if ready is not None and now-ready >= minimum and close_requested is None:
                    after_geometry = native_json([str(helper), str(process.pid), '--geometry-only'])
                    emit('GUI_GEOMETRY', dict(phase=label, moment='before_quit', metadata=after_geometry))
                    if not visible_geometry(after_geometry, process.pid):
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: visible owned window missing before Quit')
                    if process.poll() is not None:
                        raise RuntimeError('APPLICATION_FAILURE: exited before requested normal Quit')
                    if time.monotonic()-started > timeout:
                        raise RuntimeError('TIMEOUT: phase deadline reached before normal Quit')
                    close_requested = time.monotonic()
                    close_ready_wall = close_requested-ready
                    close_result = native_json([str(helper), str(process.pid), '--request-close'])
                    emit('GUI_QUIT_REQUEST', dict(phase=label, metadata=close_result,
                                                  ready_wall_s=close_ready_wall,
                                                  handler_handled='UNKNOWN; helper return is not handler evidence'))
                    require_close_request(close_result, process.pid)
                    close_sent = True
                time.sleep(.25)
            code = process.wait(timeout=5)
        finished = time.monotonic()
        elapsed = finished-started
        if elapsed > timeout:
            raise RuntimeError('TIMEOUT: phase exit observed beyond maximum wall time')
        if close_requested is not None and finished-close_requested > CLOSE_GRACE_SECONDS:
            raise RuntimeError('CLOSE_TIMEOUT: exit not observed within normal Quit grace')
        # End the credited observation at the last confirmed-live point BEFORE Quit.
        require_gui_terminal(code, close_ready_wall, minimum, close_sent,
                             before_geometry, after_geometry, process.pid)
        if not rows:
            raise RuntimeError('EVIDENCE_INSUFFICIENT: no owned process samples')
        _logs_ok(root, (stdoutfile, logfile))
        result = dict(phase=label, exit_code=code, wall_s=elapsed,
                      post_readiness_wall_s=close_ready_wall,
                      launch_epoch=launch_epoch, ready_epoch=ready_epoch,
                      sample_count=len(rows), close_to_exit_observed_seconds=finished-close_requested,
                      before_geometry=before_geometry,
                      after_geometry=after_geometry, close_request=close_result,
                      normal_exit='normal application Quit requested; observed exit0; exact handler UNKNOWN',
                      screenshots='NOT_REQUESTED', physical_red_button='NOT_TESTED')
        if minimum == 1200:
            result['memory'] = memory_summary(rows)
        emit('GUI_PHASE_RESULT', result)
        return result
    finally:
        if process is not None and process.poll() is None:
            stop_failed_process(process)
            emit('FAILED_GUI_PROCESS_CLEANUP', dict(phase=label, pid=process.pid,
                  forced=True, exit_code=process.poll(), status='NOT_NORMAL_EXIT_NOT_PASS'))
        if process is not None and process.poll() is None:
            raise RuntimeError('PROCESS_EXIT_UNCONFIRMED: caller must retain userdata')
        for path in (stdoutfile, logfile):
            if path.exists():
                text = read_log_bounded(path)
                data = text.encode('utf-8')
                emit('GUI_LOG_METADATA', dict(phase=label, file=path.name, bytes=path.stat().st_size,
                                              decoded_sha256=hashlib.sha256(data).hexdigest()))
                for line in text.splitlines():
                    for offset in range(0, max(1, len(line)), 3000):
                        print('ENGINE_LOG ' + line[offset:offset+3000], flush=True)
