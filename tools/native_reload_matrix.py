#!/usr/bin/env python3
"""Fixed v27-test.1 current-save recovery: one seed plus 50 independent native GUI processes."""
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time
import uuid

import native_package_stability as gate
from native_reload_session import session, native_json

RELOADS = 50
DRIVER_SECONDS = 42 * 60
NEW_PROCESS_RESERVE_SECONDS = 150


def require_environment():
    architecture=platform.machine().lower()
    native=(sys.platform=='win32' and architecture in ('amd64','x86_64')) or (sys.platform=='darwin' and architecture in ('arm64','x86_64'))
    if (os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted'
            or os.environ.get('GITHUB_REPOSITORY')!='lemoncat7/MountainStill' or not native):
        raise RuntimeError('Only official disposable repository Windows x64/macOS ARM64/Intel supported')


def budget(deadline, reserve=0):
    remaining=deadline-time.monotonic()
    if not math.isfinite(remaining) or remaining <= reserve:
        raise RuntimeError('TOTAL_BUDGET_INSUFFICIENT: incomplete matrix is not PASS')
    return remaining


def stopped(registry):
    if not registry or any(p.poll() is None for p in registry):
        raise RuntimeError('PROCESS_EXIT_UNCONFIRMED: refuse save reads')


def state_digest(path):
    if path.is_symlink() or not path.is_file() or path.stat().st_size>262144:
        raise RuntimeError('SAVE_FAILURE: unsafe or oversized save digest input')
    with path.open('rb') as stream:data=stream.read(262145)
    if len(data)>262144:raise RuntimeError('SAVE_FAILURE: save grew over budget')
    return hashlib.sha256(data).hexdigest()


def verify_recovery(before, after, backup, offline_upper):
    if not gate.number(offline_upper) or offline_upper >= 120:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: unbounded offline credit')
    keys=('lifetime_seconds','herbs','dew','qi','journey_completed','journey_bond')
    for key in keys:
        if not before[key] <= backup[key] <= after[key]:
            raise RuntimeError('SAVE_FAILURE: primary/backup rollback '+key)
    if not before.get('counters',{}).get('gathered',0) <= backup.get('counters',{}).get('gathered',0) <= after.get('counters',{}).get('gathered',0):
        raise RuntimeError('SAVE_FAILURE: gathered rollback')
    life=after['lifetime_seconds']-before['lifetime_seconds']
    prior_life=backup['lifetime_seconds']-before['lifetime_seconds']
    if life <= offline_upper+10 or prior_life <= offline_upper+5:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: no proven current-process live progress/prior save')
    if backup['lifetime_seconds']>after['lifetime_seconds']:
        raise RuntimeError('SAVE_FAILURE: backup newer than primary')
    for data in (after,backup):
        if (data.get('realm')!=0 or data.get('activity')!='gather' or data.get('auto_advance') is not False
                or data.get('settings',{}).get('paused') is not False
                or data.get('settings',{}).get('low_power') is not False
                or data.get('journey',{}).get('id')!='bamboo' or data['journey'].get('repeat') is not True):
            raise RuntimeError('SAVE_FAILURE: workload choices not retained')
    gathered=after.get('counters',{}).get('gathered',0)-before.get('counters',{}).get('gathered',0)
    returns=after['journey_completed']-before['journey_completed']
    for data in (backup,after):
        dg=data.get('counters',{}).get('gathered',0)-before.get('counters',{}).get('gathered',0)
        dr=data['journey_completed']-before['journey_completed']
        if data['herbs'] < before['herbs']+dg or data['journey_bond'] < before['journey_bond']+dr:
            raise RuntimeError('SAVE_FAILURE: primary/backup counters advanced without retained resources')
    return dict(lifetime_gain=life,prior_save_lifetime_gain=prior_life,
        gathered_gain=gathered,fox_returns_gain=returns,offline_upper_seconds=offline_upper,
        primary_backup_lifetime_delta=after['lifetime_seconds']-backup['lifetime_seconds'],
        save_causality='normal Quit may save; exact autosave cadence/write attribution NOT_PROVEN')


def run_reloads(cycle,check_budget,progress):
    # Exactly 50 attempts without retries; seed is outside this function.
    for number in range(1,RELOADS+1):
        check_budget(NEW_PROCESS_RESERVE_SECONDS)
        progress['attempted']=number
        cycle(number)
        check_budget(0)
        progress['completed']=number
    if progress['completed']!=RELOADS:raise RuntimeError('INCOMPLETE_CURRENT_SAVE_MATRIX')


def prepare_helper(root,deadline):
    budget(deadline,NEW_PROCESS_RESERVE_SECONDS)
    if sys.platform=='win32':
        result=native_json(['powershell','-NoProfile','-NonInteractive','-File',
            str(Path(__file__).with_name('native_gui_capture.ps1')),'-PrepareAssembly',
            '-NativeAssembly',str(root/'capture.dll')],timeout=120)
        if result.get('status')!='HELPER_PREPARED':raise RuntimeError('Native Windows helper not prepared')
    else:
        logfile=root/'helper.compile.txt'
        with logfile.open('wb') as sink:
            result=subprocess.run(['swiftc','-target',platform.machine()+'-apple-macosx15.0','-parse-as-library',
                str(Path(__file__).with_name('native_gui_capture.swift')),'-o',str(root/'capture')],
                stdout=sink,stderr=subprocess.STDOUT,timeout=120)
        if result.returncode:raise RuntimeError('Native macOS helper compile failed')
    budget(deadline,NEW_PROCESS_RESERVE_SECONDS)


def main():
    gate.configure_output();deadline=time.monotonic()+DRIVER_SECONDS
    registry=[];rows=[];owned=False;userdata=None;token=uuid.uuid4().hex
    progress={'attempted':0,'completed':0};passed=False;previous=None
    try:
        require_environment()
        gate.emit('PROFILE',dict(tag=gate.TAG,current_save_only=True,seed_processes=1,recovery_processes=RELOADS,
            cold_process_not_cold_OS_or_disk_cache=True,driver_seconds=DRIVER_SECONDS,
            old_save_migration='NOT_TESTED',updated_active_pack='NOT_TESTED',screenshots='NOT_REQUESTED'))
        userdata=gate.userdata_path();gate.emit('USERDATA',dict(actual_os_path=str(userdata)))
        gate.claim_userdata(userdata,token);owned=True
        (userdata/'updates').mkdir();(userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
        # Existing Windows helper enforces this exact owned temp prefix and direct parent.
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-',dir=os.environ['RUNNER_TEMP']) as folder:
            root=Path(folder);binary=gate.download_pinned(root);prepare_helper(root,deadline)
            save=userdata/'cultivation_save.json';backup_path=Path(str(save)+'.bak')
            budget(deadline,NEW_PROCESS_RESERVE_SECONDS)
            seed_result=session(binary,root,'seed',rows,registry,deadline)
            stopped(registry);seed=gate.save_snapshot(save);gate.save_snapshot(backup_path)
            if seed.get('realm')!=0:raise RuntimeError('Expected fresh realm0 seed')
            fixture=gate.fixture_from(seed)
            save.write_text(json.dumps(fixture,ensure_ascii=False,allow_nan=False),encoding='utf-8')
            previous=fixture;expected_digest=state_digest(save)
            gate.emit('EXTERNAL_FIXTURE_ONCE',dict(activity='gather',journey='bamboo',repeat=True,
                normal_power=True,source='actual seed save; never reset between recovery cycles'))
            identities={seed_result['process_identity']}
            def cycle(number):
                nonlocal previous,expected_digest
                stopped(registry)
                if state_digest(save)!=expected_digest:raise RuntimeError('SAVE_CHAIN_FAILURE: changed between owned processes')
                gate.emit('RELOAD_START',dict(cycle=number,previous_primary_sha256=expected_digest))
                result=session(binary,root,'reload_%02d'%number,rows,registry,deadline)
                stopped(registry)
                identity=result['process_identity']
                if identity in identities:raise RuntimeError('PROCESS_IDENTITY_REUSED: not a distinct cold process')
                identities.add(identity)
                after=gate.save_snapshot(save);backup=gate.save_snapshot(backup_path)
                evidence=verify_recovery(previous,after,backup,result['ready_epoch']-previous['saved_at']+1)
                if list(userdata.glob('*invalid*')):raise RuntimeError('SAVE_FAILURE: invalid-save recovery occurred')
                current_digest=state_digest(save)
                if current_digest==expected_digest:raise RuntimeError('SAVE_FAILURE: unchanged primary save')
                gate.emit('RELOAD_VERIFIED',dict(cycle=number,pid=result['pid'],identity=identity,
                    primary_sha256=current_digest,backup_sha256=state_digest(backup_path),**evidence))
                previous=after;expected_digest=current_digest
            run_reloads(cycle,lambda reserve:budget(deadline,reserve),progress)
            budget(deadline)
            passed=True
    except Exception as error:
        gate.emit('RELOAD_MATRIX_FAILURE',dict(type=type(error).__name__,message=str(error),**progress))
        if owned and registry and all(p.poll() is not None for p in registry):
            try:
                current=gate.save_snapshot(userdata/'cultivation_save.json')
                gate.emit('FAILED_MATRIX_SAVE_DIAGNOSTIC',dict(status='FAIL_NOT_PASS',
                    schema=current['version'],saved_at=current['saved_at'],
                    lifetime_seconds=current['lifetime_seconds'],
                    gathered=current.get('counters',{}).get('gathered',0),
                    fox_returns=current['journey_completed'],
                    primary_sha256=state_digest(userdata/'cultivation_save.json')))
            except Exception as diagnostic_error:
                gate.emit('FAILED_MATRIX_SAVE_UNAVAILABLE',dict(type=type(diagnostic_error).__name__))
    finally:
        if owned and any(p.poll() is None for p in registry):
            passed=False;gate.emit('CLEANUP_BLOCKED',dict(reason='owned process still alive; userdata preserved'))
        elif owned:
            try:gate.cleanup_userdata(userdata,token)
            except Exception as error:
                passed=False;gate.emit('CLEANUP_FAILURE',dict(type=type(error).__name__))
        if time.monotonic()>=deadline:passed=False
        outcome='PASS current-save 50 independent-process recoveries' if passed else 'FAIL/incomplete current-save recovery matrix'
        summary='## v27-test.1 native current-save recovery matrix\n\n'+outcome+'\n\n'+json.dumps(progress)+'\n\nOne extra seed process, not included in50. No old-save/update-path,60-minute mixedGUI, visual, FPS or formal-release certification. No retry masks a failed cycle.\n'
        print(summary,flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'],'a',encoding='utf-8') as sink:sink.write(summary)
    return 0 if passed else 1


if __name__=='__main__':sys.exit(main())
