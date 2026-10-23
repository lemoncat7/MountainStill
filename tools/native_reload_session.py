#!/usr/bin/env python3
"""Owned Windows/macOS reload GUI session; no input injection, AX or TCC requests.

Caller provides the verified actual v20 binary and precompiled native helper
(root/capture.dll on Windows, root/capture on macOS). No saves are opened here.
This is not screenshots, GPU timing or proof
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
    metric_interval, read_log_bounded, require_terminal,
    sample, stop_failed_process)
from native_platform_smoke import unexpected_errors
from native_gui_probe import geometry_command, close_command

HELPER_BUDGET = 64 * 1024
SETUP_SECONDS = 60
CLOSE_GRACE_SECONDS = 30


def native_json(command, timeout=5):
    """Bound both helper wall time and stdout/stderr bytes; never unbounded PIPE."""
    process = None
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        try:
            process = subprocess.Popen(command, stdout=stdout, stderr=stderr,
                                       start_new_session=(os.name != 'nt'))
            deadline = time.monotonic() + timeout
            while process.poll() is None:
                if os.fstat(stdout.fileno()).st_size + os.fstat(stderr.fileno()).st_size > HELPER_BUDGET:
                    raise RuntimeError('HELPER_OUTPUT_BUDGET_EXCEEDED')
                if time.monotonic() >= deadline:
                    raise RuntimeError('HELPER_TIMEOUT: request result unconfirmed')
                time.sleep(min(.05, max(0, deadline-time.monotonic())))
            if time.monotonic() >= deadline:
                raise RuntimeError('HELPER_TIMEOUT: result observed beyond deadline')
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
    if sys.platform == 'win32':
        fields = ('window_width', 'window_height')
        units = 'physical_pixels'
    elif sys.platform == 'darwin':
        fields = ('window_width_points', 'window_height_points')
        units = 'points'
    else:
        return False
    return (type(value.get('owner_pid')) is int and value['owner_pid'] == pid
            and type(value.get('window_id')) is int and value['window_id'] > 0
            and value.get('coordinate_units') == units
            and all(type(value.get(key)) in (int, float)
                    and math.isfinite(value[key]) and value[key] > 20 for key in fields))


def require_close_request(value, pid):
    if value.get('status') != 'CLOSE_REQUEST_SENT' or type(value.get('owner_pid')) is not int or value['owner_pid'] != pid:
        raise RuntimeError('CLOSE_REQUEST_UNCONFIRMED: not successful normal Quit request for owned PID')


def require_gui_terminal(code, ready_wall, minimum, close_sent, before_geometry, after_geometry, pid):
    require_terminal(code, ready_wall, minimum)
    if not close_sent or not visible_geometry(before_geometry, pid) or not visible_geometry(after_geometry, pid):
        raise RuntimeError('EVIDENCE_INSUFFICIENT: owned visible window and successful close request required')


def filter_audio_environment(text):
    """Only the two observed Windows WASAPI errors with source + dummy fallback.

    Every other diagnostic, including SCRIPT ERROR, stays in the error scanner.
    This labels unavailable host audio; it never certifies audible sound.
    """
    lines = text.splitlines()
    fallback = 'WARNING: All audio drivers failed, falling back to the dummy driver.'
    if sys.platform != 'win32' or fallback not in [line.strip() for line in lines]:
        return text, False
    allowed = {
        'ERROR: Condition "hr != ((HRESULT)0x00000000)" is true. Returning: ERR_CANT_OPEN',
        'ERROR: WASAPI: init_output_device error.',
    }
    filtered = []
    observed = False
    for index, line in enumerate(lines):
        attributed = (index + 1 < len(lines) and re.fullmatch(
            r'\s*at: [A-Za-z_][A-Za-z_0-9]* \(drivers/wasapi/audio_driver_wasapi\.cpp:\d+\)\s*',
            lines[index + 1]) is not None)
        if line.strip() in allowed and attributed:
            observed = True
        else:
            filtered.append(line)
    return '\n'.join(filtered), observed


def _logs_ok(root, paths, scan_errors=True, terminal=False):
    if sum(p.stat().st_size for p in root.glob('*.log')) > LOG_BUDGET:
        raise RuntimeError('LOG_BUDGET_EXCEEDED: not silently truncated')
    audio_fallback = False
    if scan_errors:
        for path in paths:
            text = read_log_bounded(path)
            # Init ERROR/source/fallback can arrive in separate writes. Scan a
            # live stream only after THAT stream contains full boot evidence.
            if not terminal and not boot_ready(text):
                continue
            filtered, observed = filter_audio_environment(text)
            audio_fallback = audio_fallback or observed
            if unexpected_errors(filtered, 'actual-gui-stability'):
                raise RuntimeError('APPLICATION_FAILURE: engine error/leak/crash diagnostic')
    return audio_fallback


def session(binary, root, label, rows_out, registry, global_deadline):
    """One 30-second post-readiness restore observation, 120-second stage cap.

    global_deadline is the caller's monotonic overall deadline. Helpers and game
    are bounded by it too. Return only after observed normal Quit/exit0; all
    failure kills remain NOT_PASS. Caller owns save checks, after registry exit.
    """
    if sys.platform not in ('win32', 'darwin'):
        raise RuntimeError('ENVIRONMENT_UNAVAILABLE: native Windows/macOS only')
    if platform.machine().lower() not in ('arm64', 'aarch64', 'amd64', 'x86_64'):
        raise RuntimeError('ENVIRONMENT_UNAVAILABLE: unexpected process architecture')
    if not re.fullmatch(r'[a-zA-Z0-9_-]+', label):
        raise ValueError('Invalid phase label')
    if type(global_deadline) not in (int, float) or not math.isfinite(global_deadline):
        raise ValueError('Finite global monotonic deadline required')
    minimum, timeout = 30, 120
    root = Path(root)
    helper = root / ('capture.dll' if sys.platform == 'win32' else 'capture')
    if not helper.is_file() or not Path(binary).is_file():
        raise RuntimeError('Verified binary or precompiled helper absent')
    logfile, stdoutfile = (root / (label + suffix) for suffix in ('.engine.log', '.stdout.log'))
    command = [str(binary), '--verbose', '--log-file', str(logfile)]
    started, launch_epoch = time.monotonic(), time.time()
    if started >= global_deadline:
        raise RuntimeError('GLOBAL_DEADLINE: no new process launched')
    stage_deadline = min(started + timeout, global_deadline)

    def helper_timeout(close_started=None):
        deadline = stage_deadline
        if close_started is not None:
            deadline = min(deadline, close_started + CLOSE_GRACE_SECONDS)
        remaining = deadline - time.monotonic()
        if remaining <= 0:
            raise RuntimeError('DEADLINE: no late helper request')
        return min(5, remaining)

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
    audio_reported = False

    def report_audio(observed):
        nonlocal audio_reported
        if observed and not audio_reported:
            emit('AUDIO_ENVIRONMENT_FALLBACK', dict(phase=label,
                 reason='exact WASAPI initialization diagnostics with explicit dummy fallback',
                 audible_audio='NOT_TESTED'))
            audio_reported = True

    try:
        with stdoutfile.open('xb') as sink:
            process = subprocess.Popen(command, stdout=sink, stderr=subprocess.STDOUT,
                                       start_new_session=(os.name != 'nt'))
            registry.append(process)
            emit('OWNED_RELOAD_PROCESS', dict(phase=label, pid=process.pid, args=command[1:]))
            while process.poll() is None:
                now = time.monotonic()
                if now >= global_deadline:
                    raise RuntimeError('GLOBAL_DEADLINE: observation incomplete, not pass')
                if now - started > timeout:
                    raise RuntimeError('TIMEOUT: forced cleanup is not normal GUI exit')
                if close_requested is not None and now - close_requested > CLOSE_GRACE_SECONDS:
                    raise RuntimeError('CLOSE_TIMEOUT: normal Quit did not exit within grace')
                report_audio(_logs_ok(root, (stdoutfile, logfile), scan_errors=ready is not None))
                if ready is None:
                    if now - started > SETUP_SECONDS:
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: bootstrap and visible window readiness timeout')
                    if now >= next_geometry and boot_ready(read_log_bounded(logfile)):
                        geometry = native_json(geometry_command(root, process.pid), helper_timeout())
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
                if now >= next_sample and close_requested is None:
                    if stage_deadline-now <= 5:
                        raise RuntimeError('DEADLINE: insufficient bounded metric-call reserve')
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
                    after_geometry = native_json(geometry_command(root, process.pid), helper_timeout())
                    emit('GUI_GEOMETRY', dict(phase=label, moment='before_quit', metadata=after_geometry))
                    if not visible_geometry(after_geometry, process.pid):
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: visible owned window missing before Quit')
                    if process.poll() is not None:
                        raise RuntimeError('APPLICATION_FAILURE: exited before requested normal Quit')
                    if time.monotonic() >= stage_deadline:
                        raise RuntimeError('TIMEOUT: phase deadline reached before normal Quit')
                    close_requested = time.monotonic()
                    close_ready_wall = close_requested-ready
                    close_result = native_json(close_command(root, process.pid), helper_timeout(close_requested))
                    emit('GUI_QUIT_REQUEST', dict(phase=label, metadata=close_result,
                                                  ready_wall_s=close_ready_wall,
                                                  handler_handled='UNKNOWN; helper return is not handler evidence'))
                    require_close_request(close_result, process.pid)
                    close_sent = True
                time.sleep(min(.25, max(0, stage_deadline-time.monotonic())))
            code = process.wait(timeout=5)
        finished = time.monotonic()
        elapsed = finished-started
        if finished >= global_deadline:
            raise RuntimeError('GLOBAL_DEADLINE: exit observed after total deadline')
        if elapsed > timeout:
            raise RuntimeError('TIMEOUT: phase exit observed beyond maximum wall time')
        if close_requested is not None and finished-close_requested > CLOSE_GRACE_SECONDS:
            raise RuntimeError('CLOSE_TIMEOUT: exit not observed within normal Quit grace')
        # End the credited observation at the last confirmed-live point BEFORE Quit.
        require_gui_terminal(code, close_ready_wall, minimum, close_sent,
                             before_geometry, after_geometry, process.pid)
        if not rows:
            raise RuntimeError('EVIDENCE_INSUFFICIENT: no owned process samples')
        report_audio(_logs_ok(root, (stdoutfile, logfile), terminal=True))
        result = dict(phase=label, pid=process.pid, process_identity=first_identity,
                      exit_code=code, wall_s=elapsed,
                      post_readiness_wall_s=close_ready_wall,
                      launch_epoch=launch_epoch, ready_epoch=ready_epoch,
                      sample_count=len(rows), close_to_exit_observed_seconds=finished-close_requested,
                      before_geometry=before_geometry,
                      after_geometry=after_geometry, close_request=close_result,
                      normal_exit='normal application Quit requested; observed exit0; exact handler UNKNOWN',
                      screenshots='NOT_REQUESTED', physical_red_button='NOT_TESTED',
                      audio_environment_fallback=audio_reported, audible_audio='NOT_TESTED')
        emit('RELOAD_PHASE_RESULT', result)
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
                report_audio(filter_audio_environment(text)[1])
                data = text.encode('utf-8')
                emit('GUI_LOG_METADATA', dict(phase=label, file=path.name, bytes=path.stat().st_size,
                                              decoded_sha256=hashlib.sha256(data).hexdigest()))
                for line in text.splitlines():
                    for offset in range(0, max(1, len(line)), 3000):
                        print('ENGINE_LOG ' + line[offset:offset+3000], flush=True)
