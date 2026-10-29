#!/usr/bin/env python3
"""Pinned actual-package 20-minute headless lifecycle precheck; not formal release certification."""
import copy
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import signal
import subprocess
import sys
import tempfile
import time
import urllib.request
import uuid

from native_package_smoke import extract, claim_userdata, cleanup_userdata, configure_output
from native_platform_smoke import unexpected_errors
from native_process_metrics import sample, cpu_percent

# Independent pin: ordinary package-smoke updates must not silently retarget this observation.
TAG = 'v1.3.27-test.1'
APP = '山隐 · Mountain Still'
PACKAGES = {
    'win32': ('MountainStill-v1.3.27-test.1-Windows-x86_64.zip',
              '3dae6af8dd4c5bacdd91f4e5ff4552065a1518ebf0134e85fd3923b3394f3f58',
              'MountainStill/MountainStill.exe', 114556300),
    'darwin': ('MountainStill-v1.3.27-test.1-macOS-Universal.zip',
               '01bc98334157b0a0758c299deefbab545bc59b0869934a46dc4018f4cdcd1326',
               APP + '.app/Contents/MacOS/' + APP, 141286722),
}
ASSETS = ('creek_bridge_boss_settle.png', 'creek_bridge_boss_retract.png')
LONG_FRAMES = 78000
MIN_WALL_SECONDS = 1200
WARMUP_SECONDS = 300
LONG_TIMEOUT_SECONDS = 1500
LOG_BUDGET = 12 * 1024 * 1024
SAMPLE_INTERVAL = 10


def emit(kind, value):
    print(kind + ' ' + json.dumps(value, ensure_ascii=False, allow_nan=False), flush=True)


def userdata_path():
    # The immutable v27-test.1 app name must guard exactly the directory v27-test.1 writes,
    # even if a future ordinary package-smoke changes its own APP constant.
    if sys.platform == 'win32':
        base = Path(os.environ['APPDATA'])
    elif sys.platform == 'darwin':
        base = Path.home()/'Library'/'Application Support'
    else:
        raise RuntimeError('Native Windows/macOS only')
    return base/'Godot'/'app_userdata'/APP


def download_pinned(root):
    name, expected, executable, size = PACKAGES[sys.platform]
    archive = root / name
    url = 'https://github.com/lemoncat7/MountainStill/releases/download/' + TAG + '/' + name
    digest = hashlib.sha256()
    with urllib.request.urlopen(url, timeout=45) as response, archive.open('xb') as sink:
        count = 0
        while chunk := response.read(1024 * 1024):
            count += len(chunk)
            if count > size:
                raise RuntimeError('Pinned archive length exceeded')
            sink.write(chunk)
            digest.update(chunk)
    if count != size or digest.hexdigest() != expected:
        raise RuntimeError('Pinned archive size/SHA mismatch')
    emit('PIN_VERIFIED', dict(tag=TAG, archive=name, sha256=expected, size=size))
    target = root / 'installed'
    extract(archive, target)
    binary = target / executable
    if not binary.is_file():
        raise RuntimeError('Pinned actual executable missing')
    return binary


def boot_ready(text):
    return bool(re.search(r'^UPDATE BOOT: 1\.3\.27-test\.1\s*$', text, re.M)) and all(
        any('Loading resource:' in line and 'res://assets/cultivation/beasts/' + asset in line
            for line in text.splitlines()) for asset in ASSETS)


def require_terminal(code, ready_wall, minimum):
    if code != 0:
        raise RuntimeError('APPLICATION_FAILURE: nonzero actual executable exit')
    if ready_wall is None:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: pinned bootstrap/resource readiness not observed')
    if ready_wall < minimum:
        raise RuntimeError('DURATION_INSUFFICIENT: real post-readiness monotonic wall time below requirement')


def metric_interval(previous, current, dt):
    if not math.isfinite(current['rss_bytes']) or current['rss_bytes'] <= 0:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: invalid native resident-memory sample')
    return cpu_percent(previous, current, dt)


def memory_summary(rows):
    warm = [r for r in rows if r['ready_wall_s'] is not None and r['ready_wall_s'] >= WARMUP_SECONDS]
    if len(warm) < 2:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: no post-warmup trend window')
    xs = [r['ready_wall_s'] / 60 for r in warm]
    ys = [r['rss_bytes'] / 1048576 for r in warm]
    mx, my = sum(xs)/len(xs), sum(ys)/len(ys)
    denominator = sum((x-mx)**2 for x in xs)
    slope = sum((x-mx)*(y-my) for x,y in zip(xs,ys)) / denominator
    growth = 100 * (ys[-1]/ys[0]-1)
    return dict(post_warmup_samples=len(warm), first_mib=ys[0], last_mib=ys[-1],
                peak_mib=max(ys), growth_percent=growth, slope_mib_per_min=slope,
                proposed_rss_budget_review_required=growth > 10 or slope >= 1,
                budget_status='existing proposed 60-minute budget, observation only; not formal pass',
                internal_static_memory='NOT_OBSERVED', node_object_counts='NOT_OBSERVED')


def stop_failed_process(process):
    # Only this Popen child/process group, and only failure cleanup; never successful exit evidence.
    if process.poll() is not None:
        return
    if os.name == 'nt':
        subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                       stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, timeout=10)
    else:
        os.killpg(process.pid, signal.SIGKILL)
    process.kill()
    process.wait(timeout=10)


def read_log_bounded(path):
    if not path.exists():
        return ''
    if path.stat().st_size > LOG_BUDGET:
        raise RuntimeError('LOG_BUDGET_EXCEEDED before reading')
    with path.open('rb') as stream:
        data = stream.read(LOG_BUDGET+1)
    if len(data) > LOG_BUDGET:
        raise RuntimeError('LOG_BUDGET_EXCEEDED while reading')
    return data.decode('utf-8', errors='replace')


def session(binary, root, label, frames, minimum, timeout, rows_out, registry, diagnostic=False):
    logfile = root / (label + '.engine.log')
    stdoutfile = root / (label + '.stdout.log')
    command = [str(binary), '--headless', '--verbose', '--log-file', str(logfile),
               '--max-fps', '60', '--quit-after', str(frames)]
    if diagnostic:
        command.append('--print-fps')
    process = None
    started = time.monotonic()
    launch_epoch = time.time()
    ready = None
    ready_epoch = None
    rows = []
    previous = None
    next_sample = started
    final = None
    last_confirmed_alive = None
    try:
        # Regular file sinks: no unconsumed PIPE and no reader blocking atomic game saves.
        with stdoutfile.open('wb') as sink:
            process = subprocess.Popen(command, stdout=sink, stderr=subprocess.STDOUT,
                                       start_new_session=(os.name != 'nt'))
            registry.append(process)
            emit('OWNED_PROCESS', dict(phase=label, pid=process.pid, args=command[1:]))
            while True:
                now = time.monotonic()
                if process.poll() is not None:
                    break
                last_confirmed_alive = now
                if now-started > timeout:
                    raise RuntimeError('TIMEOUT: forced cleanup is not normal exit')
                if sum(p.stat().st_size for p in root.glob('*.log')) > LOG_BUDGET:
                    raise RuntimeError('LOG_BUDGET_EXCEEDED: observation stopped, not silently truncated')
                if ready is None:
                    text = read_log_bounded(logfile)
                    if boot_ready(text):
                        ready = now
                        ready_epoch = time.time()
                        emit('READY_OBSERVED', dict(phase=label, launch_to_ready_s=now-started))
                    elif now-started > 60:
                        raise RuntimeError('EVIDENCE_INSUFFICIENT: readiness not observed within setup bound')
                if now >= next_sample:
                    for observed_log in (stdoutfile, logfile):
                        if unexpected_errors(read_log_bounded(observed_log), 'actual-package-stability'):
                            raise RuntimeError('APPLICATION_FAILURE: engine error/leak/crash diagnostic during observation')
                    try:
                        current = sample(process.pid)
                    except Exception:
                        if process.poll() is not None:
                            break  # Legitimate last-sample/normal-exit race; no fabricated zero.
                        raise
                    if process.poll() is not None:
                        break
                    cpu = None if previous is None else metric_interval(previous, current, now-previous['sample_mono'])
                    row = dict(current, phase=label, wall_s=now-started,
                               ready_wall_s=None if ready is None else now-ready,
                               cpu_percent_one_core=cpu)
                    emit('PROCESS_SAMPLE', row)
                    rows.append(row)
                    rows_out.append(row)
                    previous = dict(current, sample_mono=now)
                    next_sample = now + SAMPLE_INTERVAL
                time.sleep(.25)
            code = process.wait(timeout=5)
        elapsed = time.monotonic()-started
        ready_wall = None if ready is None or last_confirmed_alive is None else last_confirmed_alive-ready
        require_terminal(code, ready_wall, minimum)
        if not rows:
            raise RuntimeError('EVIDENCE_INSUFFICIENT: no owned-process samples')
        if sum(p.stat().st_size for p in root.glob('*.log')) > LOG_BUDGET:
            raise RuntimeError('LOG_BUDGET_EXCEEDED at terminal check')
        for path in (stdoutfile, logfile):
            text = read_log_bounded(path)
            if unexpected_errors(text, 'actual-package-stability'):
                raise RuntimeError('APPLICATION_FAILURE: engine error/leak/crash diagnostics')
        final = dict(phase=label, exit_code=code, wall_s=elapsed, post_readiness_wall_s=ready_wall,
                     launch_epoch=launch_epoch, ready_epoch=ready_epoch, sample_count=len(rows),
                     normal_exit='engine quit-after; NOT native window-close/save guard')
        if label == 'gather_fox':
            final['memory'] = memory_summary(rows)
        emit('PHASE_RESULT', final)
        return final
    finally:
        if process is not None and process.poll() is None:
            stop_failed_process(process)
            emit('FAILED_PROCESS_CLEANUP',dict(phase=label,pid=process.pid,forced=True,exit_code=process.poll(),status='NOT_NORMAL_EXIT_NOT_PASS'))
        # Bounded complete engine evidence, including on failure; never save payload contents.
        for path in (stdoutfile, logfile):
            if path.exists():
                size = path.stat().st_size
                if size <= LOG_BUDGET:
                    with path.open('rb') as stream:
                        data = stream.read(LOG_BUDGET+1)
                    if len(data)>LOG_BUDGET:
                        raise RuntimeError('LOG_BUDGET_EXCEEDED during terminal output')
                    emit('LOG_METADATA', dict(phase=label, file=path.name, bytes=len(data), sha256=hashlib.sha256(data).hexdigest()))
                    if diagnostic:
                        emit('FPS_DIAGNOSTIC', dict(phase=label, file=path.name, **fps_summary(data.decode('utf-8', errors='replace'))))
                    for line in data.decode('utf-8', errors='replace').splitlines():
                        for offset in range(0, max(len(line),1), 3000):
                            print('ENGINE_LOG ' + line[offset:offset+3000], flush=True)
                else:
                    emit('LOG_NOT_PRINTED', dict(reason='budget exceeded; failure already recorded'))


def number(value):
    return type(value) in (int,float) and math.isfinite(value) and value >= 0


def save_snapshot(path):
    # ONLY called after that game process has exited, never during its atomic rename sequence.
    if path.is_symlink() or not path.is_file() or path.stat().st_size > 262144:
        raise RuntimeError('SAVE_FAILURE: missing/unsafe/oversized primary or backup')
    def invalid(value):
        raise ValueError('Nonfinite JSON constant: ' + value)
    data = json.loads(path.read_text(encoding='utf-8'), parse_constant=invalid)
    if data.get('version') != 4:
        raise RuntimeError('SAVE_FAILURE: wrong schema')
    for key in ('saved_at','lifetime_seconds','herbs','dew','qi','journey_completed','journey_bond'):
        if not number(data.get(key)):
            raise RuntimeError('SAVE_FAILURE: invalid numeric field ' + key)
    if not number(data.get('counters',{}).get('gathered',0)):
        raise RuntimeError('SAVE_FAILURE: invalid gathered counter')
    return data


def fixture_from(seed):
    data = copy.deepcopy(seed)
    data.update(activity='gather', auto_advance=False, journey={'id':'bamboo','remaining':300.0,'repeat':True})
    data['settings'].update(paused=False, low_power=False)
    data['saved_at'] = int(time.time())
    return data


def progress(seed, after, backup, offline_upper):
    if not 0 <= offline_upper < 120:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: startup/offline bound cannot exclude fixture-only progress')
    life = after['lifetime_seconds'] - seed['lifetime_seconds']
    gathered = after.get('counters',{}).get('gathered',0)-seed.get('counters',{}).get('gathered',0)
    returns = after['journey_completed']-seed['journey_completed']
    # Bamboo repeat is 300 seconds; default new save has no gathering-speed perks.
    if life <= offline_upper+10 or gathered <= math.ceil(offline_upper/8)+1 or returns < 1:
        raise RuntimeError('SAVE_FAILURE: no proven live gathering/fox return beyond possible startup offline credit')
    if after['lifetime_seconds'] < backup['lifetime_seconds'] + 9.9:
        raise RuntimeError('SAVE_FAILURE: no observed autosave advancement over atomic backup')
    if after['herbs'] < seed['herbs'] + gathered or after['dew'] < seed['dew'] or after['journey_bond'] < seed['journey_bond'] + returns:
        raise RuntimeError('SAVE_FAILURE: observed work counters without retained resources/bond')
    if after.get('activity') != 'gather' or after.get('auto_advance') is not False or after['settings'].get('paused') is not False:
        raise RuntimeError('SAVE_FAILURE: workload settings not retained')
    if after.get('journey',{}).get('id') != 'bamboo' or after['journey'].get('repeat') is not True:
        raise RuntimeError('SAVE_FAILURE: fox repeat not retained')
    return dict(lifetime_gain=life, gathered_counter_gain=gathered, completed_fox_returns=returns,
                startup_offline_upper_seconds=offline_upper, activity='gather',
                workload='collection plus fox journey timers; NOT chapter combat',
                within_phase_idle_fraction='NOT_DIRECTLY_OBSERVABLE; no runtime instrumentation',
                autosave_lifetime_delta=after['lifetime_seconds']-backup['lifetime_seconds'])


def fps_summary(text):
    # Godot 4.6.3 main.cpp prints integer process-frame bucket counts. These are
    # NOT rendered FPS, exact total frames, or a GUI performance measurement.
    values = [int(x) for x in re.findall(r'^Project FPS: ([0-9]{1,6}) \([0-9]+(?:\.[0-9]+)? mspf\)\s*$', text, re.M)]
    return dict(bucket_count=len(values), first=values[0] if values else None,
                last=values[-1] if values else None, minimum=min(values) if values else None,
                maximum=max(values) if values else None,
                mean=sum(values)/len(values) if values else None,
                reported_bucket_frames=sum(values),
                exact_total_frames='NOT_OBSERVED; initial buckets suppressed and final bucket may be buffered',
                interpretation='process loop diagnostic only; NOT rendered FPS or stability pass')


def failed_save_diagnostic(save, fixture, registry):
    # Only after session finally has confirmed termination; never read a live
    # Windows atomic-save sequence or emit arbitrary save payload/settings.
    if not registry or any(p.poll() is None for p in registry):
        raise RuntimeError('Diagnostic refused: child exit unconfirmed')
    after = save_snapshot(save)
    backup = save_snapshot(Path(str(save)+'.bak'))
    return dict(status='FAILED_PHASE_ONLY_NOT_PASS', normal_exit_confirmed=False,
                owned_exit_codes=[p.poll() for p in registry],
                # Diagnostic mode is macOS ARM only: Popen uses -9 for SIGKILL.
                # Literal avoids referencing a POSIX-only signal constant in Windows unit tests.
                forced_sigkill_observed=any(p.poll()==-9 for p in registry),
                lifetime_gain=after['lifetime_seconds']-fixture['lifetime_seconds'],
                gathered_gain=after.get('counters',{}).get('gathered',0)-fixture.get('counters',{}).get('gathered',0),
                fox_returns_gain=after['journey_completed']-fixture['journey_completed'],
                herbs_gain=after['herbs']-fixture['herbs'], dew_gain=after['dew']-fixture['dew'],
                autosave_lifetime_delta=after['lifetime_seconds']-backup['lifetime_seconds'],
                saved_at_delta_from_fixture=after['saved_at']-fixture['saved_at'],
                saved_at_age_seconds=time.time()-after['saved_at'],
                gather_retained=after.get('activity')=='gather',
                normal_power_retained=after.get('settings',{}).get('low_power') is False,
                note='may include startup offline progress; forced exit is not a successful lifecycle')


def main():
    configure_output()
    diagnostic = sys.argv[1:] == ['--arm-diagnostic']
    if sys.argv[1:] and not diagnostic:
        raise RuntimeError('Unsupported arguments')
    results = []
    all_rows = []
    registry = []
    owned = False
    userdata = None
    token = uuid.uuid4().hex
    try:
        if (os.environ.get('GITHUB_ACTIONS') != 'true' or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'
                or os.environ.get('GITHUB_REPOSITORY') != 'lemoncat7/MountainStill' or sys.platform not in PACKAGES):
            raise RuntimeError('Only official disposable repository Windows/macOS CI VMs supported')
        if diagnostic and (sys.platform != 'darwin' or platform.machine().lower() not in ('arm64','aarch64')):
            raise RuntimeError('ARM diagnostic must run only on native macOS ARM64')
        emit('PLATFORM', dict(os=sys.platform, architecture=platform.machine(), cpus=os.cpu_count(), tag=TAG))
        userdata = userdata_path()
        emit('USERDATA', dict(actual_os_path=str(userdata)))
        claim_userdata(userdata, token)
        owned = True
        (userdata/'updates').mkdir()
        (userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='ms-stability-',dir=os.environ['RUNNER_TEMP']) as scratch:
            root = Path(scratch)
            binary = download_pinned(root)
            save = userdata/'cultivation_save.json'
            idle = session(binary,root,'seed_idle',1800,20,90,all_rows,registry,diagnostic)
            seed = save_snapshot(save)
            if seed.get('realm') != 0:
                raise RuntimeError('Fixture assumption failed: new seed no longer realm0')
            fixture = fixture_from(seed)
            save.write_text(json.dumps(fixture,ensure_ascii=False,allow_nan=False),encoding='utf-8')
            emit('EXTERNAL_FIXTURE',dict(activity='gather',journey='bamboo',remaining=300,repeat=True,
                                         source='only this job first boot save',scripts_injected=False))
            try:
                long = session(binary,root,'gather_fox',LONG_FRAMES,MIN_WALL_SECONDS,LONG_TIMEOUT_SECONDS,all_rows,registry,diagnostic)
            except Exception:
                if diagnostic:
                    try:
                        emit('FAILED_SAVE_DIAGNOSTIC',failed_save_diagnostic(save,fixture,registry))
                    except Exception as diagnostic_error:
                        emit('FAILED_SAVE_DIAGNOSTIC_UNAVAILABLE',dict(type=type(diagnostic_error).__name__))
                raise
            after = save_snapshot(save)
            backup = save_snapshot(Path(str(save)+'.bak'))
            evidence = progress(fixture,after,backup,long['ready_epoch']-fixture['saved_at']+1)
            emit('LIVE_PROGRESS', evidence)
            restart = session(binary,root,'restart',1800,20,90,all_rows,registry,diagnostic)
            restored = save_snapshot(save)
            restored_backup = save_snapshot(Path(str(save)+'.bak'))
            for key in ('lifetime_seconds','herbs','dew','journey_completed','journey_bond'):
                if restored[key] < after[key]:
                    raise RuntimeError('SAVE_FAILURE: restart lost ' + key)
            if restored.get('activity')!='gather' or restored.get('journey',{}).get('repeat') is not True:
                raise RuntimeError('SAVE_FAILURE: restart lost workload choices')
            if restored['lifetime_seconds'] < restored_backup['lifetime_seconds']+9.9:
                raise RuntimeError('SAVE_FAILURE: restart did not autosave loaded state')
            if list(userdata.glob('*invalid*')):
                raise RuntimeError('SAVE_FAILURE: invalid-save recovery occurred')
            total = idle['wall_s']+long['wall_s']+restart['wall_s']
            emit('PHASE_ALLOCATION',dict(seed_idle_wall_fraction=idle['wall_s']/total,
                                         scheduled_gather_fox_wall_fraction=long['wall_s']/total,
                                         restart_wall_fraction=restart['wall_s']/total,
                                         not_runtime_idle_or_battle_fraction=True))
            results.append('PASS scoped actual-package lifecycle observation and restart')
            if long['memory']['proposed_rss_budget_review_required']:
                results.append('MEMORY_REVIEW_REQUIRED against existing proposed RSS-only budget')
    except Exception as error:
        emit('STABILITY_FAILURE',dict(type=type(error).__name__,message=str(error)))
        results.append('FAIL observation; not formal stability acceptance')
    finally:
        if owned and any(p.poll() is None for p in registry):
            results.append('FAIL process exit unconfirmed; owned user data preserved, not deleted')
        elif owned:
            try:
                cleanup_userdata(userdata,token)
            except Exception as error:
                emit('CLEANUP_FAILURE',dict(message=str(error)))
                results.append('FAIL owned user-data cleanup')
        summary = '## v27-test.1 actual-package 20-minute headless lifecycle precheck\n\n'+'\n'.join('- '+r for r in results)
        summary += '\n\nNo 60-minute mixed GUI, continuous chapter combat, FPS/GPU, internal static-memory/object count, or formal-release certification. RSS budget is a historical proposal; CPU utilization has no pass threshold.\n'
        print(summary,flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'],'a',encoding='utf-8') as sink:sink.write(summary)
    return 0 if results and all(r.startswith('PASS') for r in results) else 1


if __name__ == '__main__':
    sys.exit(main())
