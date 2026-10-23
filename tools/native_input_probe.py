#!/usr/bin/env python3
"""Pinned v20 native OS input evidence. Never read saves while any game is alive."""
import copy
import hashlib
import json
import os
from pathlib import Path
import platform
import subprocess
import sys
import tempfile
import time
import uuid

import native_gui_probe as gui
from native_package_smoke import claim_userdata, download, extract, read_save, userdata_path
from native_reload_session import filter_audio_environment
from native_platform_smoke import unexpected_errors

HARD_STOP = 55
CLOSE_AT = 43
ROOT = Path(__file__).parent


def native_json(command, timeout):
    """Bounded helper IO/time, including at most2s failed-helper cleanup.

    Do not import the long-session helper's10+10second shutdown allowance:
    our game process has a separate55second hard lifetime budget.
    """
    process=None
    with tempfile.TemporaryFile() as stdout, tempfile.TemporaryFile() as stderr:
        try:
            process=subprocess.Popen(command,stdout=stdout,stderr=stderr)
            deadline=time.monotonic()+timeout
            while process.poll() is None:
                if os.fstat(stdout.fileno()).st_size+os.fstat(stderr.fileno()).st_size>65536:
                    raise RuntimeError('HELPER_OUTPUT_BUDGET')
                if time.monotonic()>=deadline:raise RuntimeError('HELPER_TIMEOUT')
                time.sleep(min(.05,max(0,deadline-time.monotonic())))
            if time.monotonic()>=deadline:raise RuntimeError('HELPER_DEADLINE_EXCEEDED')
            if process.returncode!=0:raise RuntimeError('HELPER_NONZERO')
            if os.fstat(stdout.fileno()).st_size+os.fstat(stderr.fileno()).st_size>65536:raise RuntimeError('HELPER_OUTPUT_BUDGET')
            stdout.seek(0);value=json.loads(stdout.read(65537).decode('utf-8'))
            if not isinstance(value,dict):raise RuntimeError('HELPER_JSON_OBJECT_REQUIRED')
            return value
        finally:
            if process is not None and process.poll() is None:
                if sys.platform=='win32':
                    try:subprocess.run(['taskkill','/PID',str(process.pid),'/T','/F'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL,timeout=1.5,check=False)
                    except (OSError,subprocess.TimeoutExpired):pass
                if process.poll() is None:process.kill()
                process.wait(timeout=.5)


def emit(kind, value):
    gui.bounded_log(kind+' '+json.dumps(value,ensure_ascii=False))


def offline_save(userdata, token, processes):
    if any(p.poll() is None for p in processes):
        raise RuntimeError('LIVE_PROCESS_SAVE_READ_FORBIDDEN')
    marker=userdata/'.native-package-ci-owner'
    if userdata.is_symlink() or marker.is_symlink() or marker.read_text(encoding='ascii')!=token:
        raise RuntimeError('OWNERSHIP_LOST')
    path=userdata/'cultivation_save.json'
    if path.is_symlink():raise RuntimeError('UNSAFE_SAVE_PATH')
    return read_save(path)


def formal_projection(saved):
    # These must not move during paused paper navigation or reward-free trial.
    return {k:copy.deepcopy(v) for k,v in saved.items()
            if k not in ('settings','saved_at','arrival_seen','activity')}


def final_assertions(before, after):
    errors=[]
    if before.get('arrival_seen') is not False or after.get('arrival_seen') is not True:errors.append('arrival_seen_not_false_to_true')
    if before.get('activity')!='meditate' or after.get('activity')!='gather':errors.append('formal_return_G_not_persisted')
    if after.get('settings',{}).get('paused') is not True:errors.append('formal_pause_not_preserved')
    if formal_projection(before)!=formal_projection(after):errors.append('formal_gameplay_changed_while_paused')
    return errors


def input_command(root,pid,action,window=None,**kwargs):
    cmd=['powershell','-NoProfile','-NonInteractive','-File',str(ROOT/'native_input_helper.ps1'),
         '-NativeAssembly',str(root/'input.dll'),'-Action',action,'-TargetPid',str(pid)]
    if window is not None:cmd+=['-WindowId',str(window)]
    for k,v in kwargs.items():cmd+=['-'+k,str(v)]
    return cmd


def session(binary,root,inputroot,label,processes,interactive=False):
    process=None;started=time.monotonic();captures=[];events=[];geometry={};close={};failure=None;forced=False
    logfile=root/(label+'.log')
    def elapsed():return time.monotonic()-started
    def helper(cmd,budget=3):
        if elapsed()+budget>CLOSE_AT:raise RuntimeError('INPUT_BUDGET_EXHAUSTED')
        return native_json(cmd,budget)
    try:
        with logfile.open('wb') as log:
            process=subprocess.Popen([str(binary),*gui.ARGS],stdout=log,stderr=subprocess.STDOUT)
            processes.append(process)
            hint=None
            while process.poll() is None:
                text=gui.log_text(logfile)
                if 'Loading resource: res://assets/cultivation/beasts/opportunity_cairn.png' in text and hint is None:hint=elapsed()
                if hint is not None and elapsed()>=max(12,hint+2):break
                if elapsed()>=20:raise RuntimeError('RENDER_READINESS_HINT_TIMEOUT')
                time.sleep(.15)
            if process.poll() is not None:raise RuntimeError('EARLY_APPLICATION_EXIT')
            geometry=helper(gui.geometry_command(root,process.pid),3)
            if geometry.get('status')!='GEOMETRY_READY':raise RuntimeError('GEOMETRY_UNAVAILABLE')
            if interactive:
                inspect=helper(input_command(inputroot,process.pid,'Inspect'))
                emit('INPUT_INSPECT',inspect)
                if inspect.get('status')!='INSPECT_READY':raise RuntimeError('INPUT_ENVIRONMENT_UNAVAILABLE')
                window=inspect['window_id']
                def event(action,**kw):
                    result=helper(input_command(inputroot,process.pid,action,window,**kw),2)
                    events.append(result);emit('NATIVE_INPUT_EVENT',result)
                    if result.get('status')!='INPUT_SENT':raise RuntimeError('INPUT_ENVIRONMENT_UNAVAILABLE: '+str(result.get('reason','input not confirmed')))
                    time.sleep(1.0)
                def capture(name,roi):
                    path=inputroot/(name+'.png')
                    result=helper(input_command(inputroot,process.pid,'Capture',window,
                        OutputPath=path,RoiX=roi[0],RoiY=roi[1],RoiWidth=roi[2],RoiHeight=roi[3]),5)
                    emit('NATIVE_INPUT_CAPTURE',result)
                    if result.get('status')!='CAPTURE_READY':raise RuntimeError('CAPTURE_UNAVAILABLE')
                    captures.append((path,result))
                # Formal pause is an offline legal setting; do not toggle it here.
                event('Click',ClientX=268,ClientY=514)
                capture('arrival-guide',(202,20,700,140))
                event('Key',Key='I')
                event('Click',ClientX=583,ClientY=47)
                event('Click',ClientX=536,ClientY=94)
                event('Click',ClientX=292,ClientY=263)
                event('Key',Key='Space')  # Session-only pause, requires visual review.
                capture('mirror-controls',(16,10,700,72))
                capture('mirror-combat',(300,300,400,240))
                event('Key',Key='Esc')
                event('Key',Key='G')     # Ignored by practice: final save establishes return.
            else:
                time.sleep(.5)
    except Exception as error:
        failure=type(error).__name__+': '+str(error)
    finally:
        if process is not None and process.poll() is None:
            try:
                remaining=45-elapsed()
                if remaining<=0:raise RuntimeError('CLOSE_REQUEST_DEADLINE_MISSED')
                close=native_json(gui.close_command(root,process.pid),min(2,remaining))
            except Exception as error:close={'status':'CLOSE_UNCONFIRMED','reason':str(error)}
            try:process.wait(timeout=max(.01,HARD_STOP-elapsed()))
            except subprocess.TimeoutExpired:forced=True;gui.stop_owned(process)
        if process is not None and process.poll() is None:gui.stop_owned(process)
    output=gui.log_text(logfile)
    filtered,audio_unavailable=filter_audio_environment(output)
    errors=unexpected_errors(filtered,'native-input')
    if errors:failure='APPLICATION_ERRORS: '+repr(errors)
    if 'UPDATE BOOT: 1.3.20-test.1' not in output:failure=failure or 'PINNED_BOOT_NOT_OBSERVED'
    if process is None or process.returncode!=0:failure=failure or 'NONZERO_OR_MISSING_EXIT'
    if forced:failure=failure or 'OWNED_PROCESS_HARD_TIMEOUT'
    if close.get('status')!='CLOSE_REQUEST_SENT':failure=failure or 'NORMAL_CLOSE_UNCONFIRMED'
    result={'case':label,'exit_code':None if process is None else process.returncode,'forced_timeout':forced,
            'elapsed_seconds':round(elapsed(),3),'failure':failure,'geometry':geometry,'close':close,
            'events':events,'audio_environment_unavailable':audio_unavailable,'capture_count':len(captures)}
    emit('NATIVE_INPUT_CASE',result);gui.bounded_log(output)
    return result,captures


def main():
    gui.configure_output();processes=[];owned=False;userdata=None;token=uuid.uuid4().hex;status='CAPTURE_INCONCLUSIVE';error=None;cases=[];cleanup=[]
    try:
        if os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted' or os.environ.get('GITHUB_REPOSITORY')!='lemoncat7/MountainStill':raise RuntimeError('OFFICIAL_REPOSITORY_RUNNER_REQUIRED')
        if sys.platform=='darwin':
            with tempfile.TemporaryDirectory(prefix='mountainstill-input-',dir=os.environ['RUNNER_TEMP']) as tmp:
                binary=Path(tmp)/'preflight';arch=platform.machine()
                if arch not in ('arm64','x86_64'):raise RuntimeError('UNSUPPORTED_ARCH')
                built=subprocess.run(['swiftc','-parse-as-library',str(ROOT/'native_input_preflight.swift'),'-o',str(binary)],stdout=subprocess.PIPE,stderr=subprocess.PIPE,timeout=60)
                if built.returncode:raise RuntimeError('PREFLIGHT_COMPILE_FAILED')
                result=native_json([str(binary)],3);emit('MAC_INPUT_PREFLIGHT',result)
                status='CAPABILITY_ONLY_NOT_INPUT_TEST' if result.get('status')=='PREFLIGHT_READY' else 'ENVIRONMENT_UNAVAILABLE';return 0
        if sys.platform!='win32':raise RuntimeError('WINDOWS_INPUT_ONLY')
        import native_package_smoke
        native_package_smoke.TAG=gui.TAG
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-',dir=os.environ['RUNNER_TEMP']) as tmp, tempfile.TemporaryDirectory(prefix='mountainstill-input-',dir=os.environ['RUNNER_TEMP']) as itmp:
            root=Path(tmp);inputroot=Path(itmp)
            for cmd in ([ 'powershell','-NoProfile','-NonInteractive','-File',str(ROOT/'native_gui_capture.ps1'),'-PrepareAssembly','-NativeAssembly',str(root/'capture.dll')],input_command(inputroot,0,'Prepare')):
                prepared=native_json(cmd,60);emit('INPUT_HELPER_PREPARE',prepared)
                if prepared.get('status')!='HELPER_PREPARED':raise RuntimeError('HELPER_PREPARE_FAILED')
            name,sha,exe,size=gui.PACKAGES['win32'];archive=root/name;download(archive,size,sha);extract(archive,root/'app');binary=root/'app'/exe
            userdata=userdata_path();claim_userdata(userdata,token);owned=True
            (userdata/'updates').mkdir();(userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
            result,_=session(binary,root,inputroot,'fresh-seed',processes);cases.append(result)
            if result['failure']:raise RuntimeError('SEED_FAILED')
            seed=offline_save(userdata,token,processes)
            fixture,changes=gui.apply_geometry_fixture(seed,'window',result['geometry']['work_area'])
            emit('OFFLINE_GEOMETRY_PREPARATION',changes)
            (userdata/'cultivation_save.json').write_text(json.dumps(fixture,ensure_ascii=False),encoding='utf-8')
            result,_=session(binary,root,inputroot,'geometry-seed',processes);cases.append(result)
            if result['failure']:raise RuntimeError('GEOMETRY_SEED_FAILED')
            before=offline_save(userdata,token,processes)
            before['settings']['paused']=True
            (userdata/'cultivation_save.json').write_text(json.dumps(before,ensure_ascii=False),encoding='utf-8')
            emit('OFFLINE_INPUT_BASELINE',{'only_setting_changed':'paused=true','sha256':hashlib.sha256(json.dumps(before,sort_keys=True).encode()).hexdigest(),'arrival_seen':before.get('arrival_seen'),'activity':before.get('activity')})
            result,captures=session(binary,root,inputroot,'native-input',processes,True);cases.append(result)
            after=offline_save(userdata,token,processes)
            assertions=final_assertions(before,after)
            emit('OFFLINE_INPUT_SAVE_BEFORE',before)
            emit('OFFLINE_INPUT_SAVE_AFTER',after)
            emit('OFFLINE_INPUT_ASSERTIONS',{'errors':assertions,'arrival_seen':after.get('arrival_seen'),'activity':after.get('activity'),'paused':after.get('settings',{}).get('paused'),'save_read_only_after_all_processes_terminal':True})
            budget=gui.PNG_BUDGET
            for path,metadata in captures:budget-=gui.frame_png(path,budget)
            if result['failure']:raise RuntimeError(result['failure'])
            if assertions:raise RuntimeError('SAVE_ASSERTIONS_FAILED: '+repr(assertions))
            if len(captures)!=3:raise RuntimeError('MISSING_REQUIRED_SCREENSHOTS')
            status='INPUT_OBSERVED_REQUIRES_INDEPENDENT_IMAGE_REVIEW'
    except Exception as exception:
        error=type(exception).__name__+': '+str(exception)
        if any((c.get('exit_code') is not None and c['exit_code']!=0 and not c.get('forced_timeout')) or (c.get('failure') and 'APPLICATION_ERRORS' in c['failure']) for c in cases) or 'SAVE_ASSERTIONS_FAILED' in error:
            status='APPLICATION_FAILURE'
        elif 'INPUT_ENVIRONMENT_UNAVAILABLE' in error or 'GEOMETRY_UNAVAILABLE' in error:
            status='ENVIRONMENT_UNAVAILABLE'
    finally:
        for process in processes:
            try:gui.stop_owned(process)
            except Exception as exception:cleanup.append(str(exception))
        if owned and all(p.poll() is not None for p in processes):
            try:gui.cleanup_owned_userdata(userdata,token)
            except Exception as exception:cleanup.append(str(exception))
        elif owned:cleanup.append('live_process_userdata_retained')
        emit('NATIVE_INPUT_RESULT',{'status':status,'error':error,'cleanup_errors':cleanup,'case_count':len(cases),'pin':gui.TAG,'scope':'OS-synthetic input, not physical human input, HiDPI or 60-minute stability'})
    return 1 if error or cleanup else 0

if __name__=='__main__':sys.exit(main())
