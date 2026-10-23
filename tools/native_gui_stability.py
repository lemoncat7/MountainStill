#!/usr/bin/env python3
"""Independent fixed-v20 ARM GUI wall-clock lifecycle observation, not a headless retry."""
import json
import math
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import uuid

import native_package_stability as gate
from native_gui_stability_session import session


def require_environment():
    if (os.environ.get('GITHUB_ACTIONS') != 'true'
            or os.environ.get('RUNNER_ENVIRONMENT') != 'github-hosted'
            or os.environ.get('GITHUB_REPOSITORY') != 'lemoncat7/MountainStill'
            or sys.platform != 'darwin' or platform.machine() != 'arm64'):
        raise RuntimeError('Only official disposable public repository macOS ARM64 CI supported')


def verify_restart(after, restored, backup, offline_upper):
    if not 0 <= offline_upper < 120:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: unbounded restart offline credit')
    for key in ('lifetime_seconds','herbs','dew','journey_completed','journey_bond'):
        if restored[key] < after[key]:
            raise RuntimeError('SAVE_FAILURE: restart lost '+key)
    if restored.get('counters',{}).get('gathered',0) < after.get('counters',{}).get('gathered',0):
        raise RuntimeError('SAVE_FAILURE: restart lost gathered counter')
    if (restored.get('activity') != 'gather'
            or restored.get('journey',{}).get('repeat') is not True
            or restored.get('journey',{}).get('id') != 'bamboo'
            or restored.get('auto_advance') is not False
            or restored.get('settings',{}).get('paused') is not False
            or restored.get('settings',{}).get('low_power') is not False):
        raise RuntimeError('SAVE_FAILURE: restart lost normal-power workload choices')
    # Normal Quit may itself save, making the last primary/backup interval <10 s.
    # Require observed lifetime progression after reloading, not an autosave interval.
    if restored['lifetime_seconds'] <= after['lifetime_seconds']+offline_upper+10:
        raise RuntimeError('SAVE_FAILURE: restart did not advance loaded state')
    if backup['lifetime_seconds'] <= after['lifetime_seconds']+offline_upper+5:
        raise RuntimeError('SAVE_FAILURE: no prior live save after restart')
    if backup['lifetime_seconds'] > restored['lifetime_seconds']:
        raise RuntimeError('SAVE_FAILURE: backup is newer than primary')


def gui_progress(seed, after, backup, offline_upper):
    if not 0 <= offline_upper < 120:
        raise RuntimeError('EVIDENCE_INSUFFICIENT: unbounded startup offline progress')
    life=after['lifetime_seconds']-seed['lifetime_seconds']
    gathered=after.get('counters',{}).get('gathered',0)-seed.get('counters',{}).get('gathered',0)
    returns=after['journey_completed']-seed['journey_completed']
    if life <= offline_upper+10 or gathered <= math.ceil(offline_upper/8)+1 or returns < 1:
        raise RuntimeError('SAVE_FAILURE: no live work beyond startup offline credit')
    # Normal Quit saves again: the last backup gap may be <10s. Instead require
    # the retained previous save itself to reflect live progress, without fabricating timestamps.
    if not seed['lifetime_seconds']+offline_upper+10 < backup['lifetime_seconds'] <= after['lifetime_seconds']:
        raise RuntimeError('SAVE_FAILURE: no valid prior live save retained')
    if after['herbs'] < seed['herbs']+gathered or after['dew'] < seed['dew'] or after['journey_bond'] < seed['journey_bond']+returns:
        raise RuntimeError('SAVE_FAILURE: work counters without retained resources')
    if (after.get('activity')!='gather' or after.get('auto_advance') is not False
            or after['settings'].get('paused') is not False or after['settings'].get('low_power') is not False
            or after.get('journey',{}).get('id')!='bamboo' or after['journey'].get('repeat') is not True):
        raise RuntimeError('SAVE_FAILURE: workload settings lost')
    return dict(lifetime_gain=life,gathered_counter_gain=gathered,completed_fox_returns=returns,
                startup_offline_upper_seconds=offline_upper,
                prior_save_lifetime_gain=backup['lifetime_seconds']-seed['lifetime_seconds'],
                primary_backup_lifetime_delta=after['lifetime_seconds']-backup['lifetime_seconds'],
                save_causality='Quit may save; prior live save retained, exact periodic cadence unmeasured',
                workload='gather plus fox timers, NOT chapter combat',within_phase_idle_fraction='NOT_OBSERVED')


def main():
    gate.configure_output()
    registry=[];rows=[];owned=False;userdata=None;token=uuid.uuid4().hex;results=[]
    try:
        require_environment()
        gate.emit('PROFILE',dict(name='v20_ARM_GUI_wall_clock',tag=gate.TAG,
            independent_of_failed_headless_runs=True,headless=False,script_injection=False,
            minimum_long_seconds=1200,warmup_seconds=300,stage_watchdog_seconds=1500,
            close_grace_seconds=30,not_formal_stability_acceptance=True))
        userdata=gate.userdata_path()
        gate.emit('USERDATA',dict(actual_os_path=str(userdata)))
        gate.claim_userdata(userdata,token);owned=True
        (userdata/'updates').mkdir()
        (userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
        with tempfile.TemporaryDirectory(prefix='ms-gui-lifecycle-',dir=os.environ['RUNNER_TEMP']) as folder:
            root=Path(folder)
            binary=gate.download_pinned(root)
            compile_log=root/'helper.compile.txt'
            with compile_log.open('wb') as sink:
                compiled=subprocess.run(['swiftc','-target','arm64-apple-macosx15.0','-parse-as-library',
                    str(Path(__file__).with_name('native_gui_capture.swift')),'-o',str(root/'capture')],
                    stdout=sink,stderr=subprocess.STDOUT,timeout=120)
            if compiled.returncode:
                raise RuntimeError('Native helper compile failed before app observation')
            save=userdata/'cultivation_save.json'
            session(binary,root,'seed_idle',30,120,rows,registry)
            seed=gate.save_snapshot(save)
            if seed.get('realm') != 0:raise RuntimeError('Expected fresh realm0 actual save')
            fixture=gate.fixture_from(seed)
            save.write_text(json.dumps(fixture,ensure_ascii=False,allow_nan=False),encoding='utf-8')
            gate.emit('EXTERNAL_FIXTURE',dict(activity='gather',journey='bamboo',remaining=300,repeat=True,
                normal_power=True,source='job first normal GUI boot save',scripts_injected=False))
            try:
                long=session(binary,root,'gather_fox',1200,1500,rows,registry,capture=False)
            except Exception:
                try:gate.emit('FAILED_SAVE_DIAGNOSTIC',gate.failed_save_diagnostic(save,fixture,registry))
                except Exception as error:gate.emit('FAILED_SAVE_DIAGNOSTIC_UNAVAILABLE',dict(type=type(error).__name__))
                raise
            after=gate.save_snapshot(save);backup=gate.save_snapshot(Path(str(save)+'.bak'))
            evidence=gui_progress(fixture,after,backup,long['ready_epoch']-fixture['saved_at']+1)
            gate.emit('GUI_PROGRESS',evidence)
            restart=session(binary,root,'restart',30,120,rows,registry)
            restored=gate.save_snapshot(save);restored_backup=gate.save_snapshot(Path(str(save)+'.bak'))
            verify_restart(after,restored,restored_backup,restart['ready_epoch']-after['saved_at']+1)
            if list(userdata.glob('*invalid*')):raise RuntimeError('Invalid-save recovery occurred')
            results.append('PASS scoped ARM GUI wall-clock lifecycle, actual normal exit and restart')
            if long['memory']['proposed_rss_budget_review_required']:
                results.append('MEMORY_REVIEW_REQUIRED against existing proposed RSS-only budget')
    except Exception as error:
        gate.emit('GUI_STABILITY_FAILURE',dict(type=type(error).__name__,message=str(error)))
        results.append('FAIL GUI observation; no formal stability acceptance')
    finally:
        if owned and any(p.poll() is None for p in registry):
            results.append('FAIL owned child still running; user data preserved')
        elif owned:
            try:gate.cleanup_userdata(userdata,token)
            except Exception as error:
                gate.emit('CLEANUP_FAILURE',dict(type=type(error).__name__))
                results.append('FAIL owned data cleanup')
        summary='## Independent v20 ARM GUI lifecycle\n\n'+'\n'.join('- '+r for r in results)
        summary+='\n\nDoes not erase headless failures. No 60-minute mixed GUI, sustained combat, rendered FPS, physical close-button click, formal memory or release certification. GUI/headless CPU and RSS are not directly comparable.\n'
        print(summary,flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            with open(os.environ['GITHUB_STEP_SUMMARY'],'a',encoding='utf-8') as sink:sink.write(summary)
    return 0 if results and all(r.startswith('PASS') for r in results) else 1


if __name__=='__main__':sys.exit(main())
