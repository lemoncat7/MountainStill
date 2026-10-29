#!/usr/bin/env python3
"""Capability evidence only; GUI_OBSERVED requires independent screenshot review."""
import copy
import base64
import hashlib
import json
import os
import platform
from pathlib import Path
import shutil
import subprocess
import sys
import tempfile
import time
import uuid

from native_package_smoke import (APP, claim_userdata, configure_output,
                                  download, extract, userdata_path, read_save)

# Independent immutable pin: later package-smoke upgrades MUST NOT retarget this probe.
TAG = 'v1.3.27-test.1'
PACKAGES = {
    'win32': ('MountainStill-v1.3.27-test.1-Windows-x86_64.zip',
              '3dae6af8dd4c5bacdd91f4e5ff4552065a1518ebf0134e85fd3923b3394f3f58',
              'MountainStill/MountainStill.exe', 114556300),
    'darwin': ('MountainStill-v1.3.27-test.1-macOS-Universal.zip',
               '01bc98334157b0a0758c299deefbab545bc59b0869934a46dc4018f4cdcd1326',
               APP + '.app/Contents/MacOS/' + APP, 141286722),
}
PNG_BUDGET = 6 * 1024 * 1024
ARGS = ['--verbose', '--max-fps', '60']




def remaining_budget(deadline, cap, reserve=10):
    remaining=deadline-time.monotonic()-reserve
    if remaining<=0:raise RuntimeError('Suite deadline exhausted; operation not started')
    return min(cap,remaining)


def prepare_package(archive, destination, size, sha, deadline):
    # The existing downloader has socket/retry bounds, not a wall-clock bound.
    # Run only our package preparation in an owned child so timeout kills/reaps it.
    code=("import sys; from pathlib import Path; import native_package_smoke as p; "
          "p.TAG=sys.argv[1]; p.download(Path(sys.argv[2]),int(sys.argv[3]),sys.argv[4]); "
          "p.extract(Path(sys.argv[2]),Path(sys.argv[5]))")
    completed=subprocess.run([sys.executable,'-c',code,TAG,str(archive),str(size),sha,str(destination)],
        cwd=str(Path(__file__).parent),stdout=subprocess.PIPE,stderr=subprocess.STDOUT,
        text=True,timeout=remaining_budget(deadline,85,25))
    if completed.returncode:
        bounded_log('PACKAGE_PREPARATION_DIAGNOSTIC '+completed.stdout[-4000:])
        raise RuntimeError('Owned package preparation child failed')

def emit_record(kind, case, value):
    # Each independently parseable record is complete; never split JSON lines.
    record = json.dumps({'case':case, **value}, ensure_ascii=True, separators=(',', ':'))
    if len((kind+' '+record).encode()) > 3900:
        raise ValueError('Structured evidence record exceeds 3900-byte bound')
    print(kind+' '+record, flush=True)


def renderer_evidence(output, requested):
    diagnostics=[]
    for line in output.splitlines():
        if not line.startswith('DESKTOP DISPLAY: '):continue
        try: item=json.loads(line[len('DESKTOP DISPLAY: '):])
        except ValueError:continue
        if (isinstance(item,dict) and item.get('schema')==1 and item.get('window_attached') is True
            and item.get('native_window_ready') is True):diagnostics.append(item)
    actual=diagnostics[-1].get('rendering_driver') if diagnostics else None
    expected=('opengl3_angle' if sys.platform=='win32' else 'opengl3') if requested=='project_default' else requested
    return {'requested_driver':requested, 'expected_preference':expected,
            'actual_driver':actual, 'actual_backend_observed':bool(actual),
            'selection':'REQUEST_MATCH' if actual==expected else ('FALLBACK_OBSERVED' if actual else 'UNVERIFIED'),
            'native_opengl_verified':actual=='opengl3',
            'pixel_transparency_verified':False, 'diagnostic':diagnostics[-1] if diagnostics else None}


def offline_save(userdata, token, processes):
    if any(p.poll() is None for p in processes):raise RuntimeError('LIVE_PROCESS_SAVE_READ_FORBIDDEN')
    marker=userdata/'.native-package-ci-owner'
    path=userdata/'cultivation_save.json'
    if userdata.is_symlink() or marker.is_symlink() or path.is_symlink() or marker.read_text(encoding='ascii')!=token:
        raise RuntimeError('OWNERSHIP_LOST')
    return read_save(path)


def gameplay_projection(saved):
    return {k:v for k,v in saved.items() if k not in ('settings','saved_at')}


def input_command(root, pid, action, window=None, key=None):
    command=['powershell','-NoProfile','-NonInteractive','-File',
             str(Path(__file__).with_name('native_input_helper.ps1')),
             '-NativeAssembly',str(root/'input.dll'),'-Action',action]
    if action!='Prepare':command+=['-TargetPid',str(pid),'-DesktopKeys']
    if window is not None:command+=['-WindowId',str(window)]
    if key is not None:command+=['-Key',key]
    return command


def native_geometry_verdict(mode, metadata):
    if not isinstance(metadata.get('work_area'),list) or len(metadata['work_area'])!=4:
        return {'status':'CAPTURE_INCONCLUSIVE','reason':'missing_native_workarea'}
    expected=expected_geometry(mode, metadata.get('work_area',[]),float(metadata.get('backing_scale',0)))
    if expected['status']!='EXPECTED':return expected
    actual=[metadata.get('client_width'),metadata.get('client_height')]
    return dict(expected,status='NATIVE_GEOMETRY_OBSERVED' if actual==expected['expected_client'] else 'APPLICATION_FAILURE',
                actual_client=actual,reason='native_client_geometry_comparison_not_pixel_acceptance')


def recover_desktop(root,inputroot,process,logfile,label,budget,deadline):
    result={'status':'CAPTURE_INCONCLUSIVE','reason':'not_started'}
    for key,mode,borderless in [('F2','window',False),('F2','strip',True),('F8','restored',False)]:
        if time.monotonic()+9>=deadline:raise RuntimeError('Recovery deadline exhausted; no late input')
        inspected=native_json(input_command(inputroot,process.pid,'Inspect'),3)
        if inspected.get('status')!='INSPECT_READY' or inspected.get('owner_pid')!=process.pid:
            raise RuntimeError('Recovery input ownership inspection unavailable')
        sent=native_json(input_command(inputroot,process.pid,'Key',inspected['window_id'],key),3)
        emit_record('DESKTOP_KEY',label,{'key':key,'expected_mode':mode,'result':sent})
        if sent.get('status')!='INPUT_SENT' or sent.get('owner_pid')!=process.pid or sent.get('window_id')!=inspected['window_id']:
            raise RuntimeError('Recovery key not confirmed; no retry')
        time.sleep(.6)
        metadata=native_json(geometry_command(root,process.pid),3)
        evidence=renderer_evidence(log_text(logfile),'project_default')
        geometry=native_geometry_verdict(mode,metadata)
        diag=evidence.get('diagnostic') or {}
        valid=geometry['status']=='NATIVE_GEOMETRY_OBSERVED' and diag.get('borderless') is borderless
        if key=='F8':valid=valid and all(diag.get(k) is False for k in ('transparency_requested','window_transparent_flag','viewport_transparent_background'))
        emit_record('DESKTOP_RECOVERY_STEP',label,{'key':key,'expected_mode':mode,'geometry':geometry,'diagnostic':diag,'state_observed':valid})
        if not valid:return {'status':'APPLICATION_FAILURE','reason':'delivered_key_state_not_observed','geometry':geometry},None
    if time.monotonic()+5>=deadline:raise RuntimeError('Recovery capture deadline exhausted')
    png=root/(label+'-restored.png')
    capture=native_json(capture_command(root,process.pid,png,2),5)
    emit_record('RECOVERY_CAPTURE',label,capture)
    if capture.get('status')!='CAPTURE_READY':return {'status':'CAPTURE_INCONCLUSIVE','reason':'restore_screenshot_unavailable'},None
    if not 8<=png.stat().st_size<=budget or png.read_bytes()[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Recovery PNG invalid or budget exhausted')
    return {'status':'RESTORE_STATE_OBSERVED_REQUIRES_IMAGE_REVIEW','geometry':geometry},png

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


def cleanup_owned_userdata(path, token):
    marker = path / '.native-package-ci-owner'
    if path.is_symlink() or marker.is_symlink() or not marker.is_file() or marker.read_text(encoding='ascii') != token:
        raise RuntimeError('User-data ownership lost; refusing cleanup')
    # rmtree validates ownership once; retry ONLY its failing unlink/rmdir operation.
    # The marker may already have been removed, so do not re-adopt/recreate it.
    def retry_operation(function, failed_path, exception):
        if not isinstance(exception[1], PermissionError):
            raise exception[1]
        for delay in (.1, .2, .3):
            time.sleep(delay)
            try:
                function(failed_path)
                return
            except PermissionError:
                pass
        raise exception[1]
    shutil.rmtree(path, onerror=retry_operation)


def classify(output, returncode, timed_out, captures, has_png):
    renderer_failure = any(x in output.lower() for x in ('unable to create opengl', 'could not initialize opengl', 'failed to create opengl', 'unable to initialize vulkan', 'could not initialize vulkan'))
    # Permit ONLY exact WASAPI initialization errors with their immediately following
    # WASAPI source attribution AND an explicit engine-reported dummy fallback.
    errors = []
    lines = output.splitlines()
    dummy = 'All audio drivers failed, falling back to the dummy driver.' in output
    for index, line in enumerate(lines):
        if 'ERROR:' not in line:
            continue
        attributed = index + 1 < len(lines) and 'drivers/wasapi/audio_driver_wasapi.cpp:' in lines[index + 1]
        known_audio = line.strip() in ('ERROR: Condition "hr != ((HRESULT)0x00000000)" is true. Returning: ERR_CANT_OPEN', 'ERROR: WASAPI: init_output_device error.')
        if not (dummy and known_audio and attributed):
            errors.append(line)
    if renderer_failure:
        return 'ENVIRONMENT_UNAVAILABLE', 'default_renderer_initialization_failed_requires_triage'
    if errors:
        return 'APPLICATION_FAILURE', 'engine_or_script_error_requires_triage'
    if timed_out:
        return 'CAPTURE_INCONCLUSIVE', '60_second_owned_process_deadline'
    if returncode != 0:
        return 'APPLICATION_FAILURE', 'nonzero_exit_requires_triage'
    if any(c['status'] == 'ENVIRONMENT_UNAVAILABLE' for c in captures):
        return 'ENVIRONMENT_UNAVAILABLE', 'capture_permission_or_desktop_unavailable'
    return 'CAPTURE_INCONCLUSIVE', 'independent_image_review_required' if has_png else 'no_capture'


def stop_owned(process):
    if process is None or process.poll() is not None:
        return
    if sys.platform == 'win32':
        try:
            result = subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           capture_output=True, timeout=2, check=False)
            bounded_log('OWNED_TASKKILL ' + json.dumps({'pid':process.pid, 'returncode':result.returncode}))
        except (subprocess.TimeoutExpired, OSError):
            pass
        if process.poll() is None:
            process.kill()
    else:
        process.kill()
    process.wait(timeout=2)
    bounded_log('OWNED_REAP ' + json.dumps({'pid':process.pid, 'returncode':process.returncode}))


def capture_command(root, pid, output, palette):
    if sys.platform == 'win32':
        return ['powershell', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('native_gui_capture.ps1')),
                '-NativeAssembly',str(root/'capture.dll'),'-TargetPid', str(pid), '-OutputPath', str(output), '-Palette', str(palette)]
    return [str(root / 'capture'), str(pid), str(output), str(palette)]


def close_command(root, pid):
    if sys.platform == 'win32':
        return ['powershell', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('native_gui_capture.ps1')),
                '-NativeAssembly',str(root/'capture.dll'),'-TargetPid', str(pid), '-RequestClose']
    return [str(root / 'capture'), str(pid), '--request-close']


def owned_save_snapshot(userdata, token):
    # Diagnostic failures must not prevent our normal-close request.
    try:
        marker = userdata / '.native-package-ci-owner'
        if userdata.is_symlink() or marker.is_symlink() or not marker.is_file() or marker.read_text(encoding='ascii') != token:
            return {'status':'ownership_unverified_not_read'}
        path = userdata / 'cultivation_save.json'
        if not path.exists():
            return {'status':'not_created_yet'}
        saved = read_save(path)
        return {'status':'valid', 'schema':saved['version'], 'lifetime_seconds':saved['lifetime_seconds'],
                'mtime_ns':path.stat().st_mtime_ns, 'sha256':hashlib.sha256(path.read_bytes()).hexdigest(),
                'geometry_settings':{key:saved.get('settings',{}).get(key) for key in GEOMETRY_KEYS}}
    except (OSError, ValueError, AssertionError, TypeError, AttributeError) as error:
        return {'status':'unverified', 'reason':str(error)[:200]}


GEOMETRY_KEYS = ('geometry_version','window_mode','normal_width','normal_height','normal_x','normal_y',
                 'strip_width','width','height','window_x','window_y','ui_scale','always_on_top','transparent','click_through')


def geometry_command(root, pid):
    if sys.platform == 'win32':
        return ['powershell','-NoProfile','-NonInteractive','-File',
                str(Path(__file__).with_name('native_gui_capture.ps1')),'-NativeAssembly',str(root/'capture.dll'),'-TargetPid',str(pid),'-GeometryOnly']
    return [str(root/'capture'),str(pid),'--geometry-only']


def apply_geometry_fixture(seed, mode, workarea, transparent=True):
    """Only synthetic game-created save settings; no runtime/package injection."""
    data = copy.deepcopy(seed)
    x,y,_,_ = workarea
    changes = {'geometry_version':2,'window_mode':mode,'normal_width':960,'normal_height':540,
               'normal_x':int(x)+12,'normal_y':int(y)+44,'strip_width':1200,
               'window_x':int(x)+12,'window_y':int(y)+44,'ui_scale':1.5,
               'width':960 if mode=='window' else 1200,'height':540 if mode=='window' else 400,
               'always_on_top':False,'transparent':transparent,'click_through':False}
    data['settings'].update(changes)
    return data, changes


def expected_geometry(mode, workarea, display_scale):
    # This increment deliberately qualifies scale1/96DPI, not a fabricated HiDPI test.
    if abs(display_scale-1) > .001:
        return {'status':'ENVIRONMENT_UNAVAILABLE','reason':'non_1x_display_outside_this_geometry_matrix'}
    requested = [1440,720] if mode=='restored' else ([960,540] if mode=='window' else [1200,400])
    minimum = [960,400] if mode=='strip' else [960,540]
    available = [max(1,int(workarea[2])-24),max(1,int(workarea[3])-56)]
    expected = [min(max(requested[i],min(minimum[i],available[i])),available[i]) for i in (0,1)]
    return {'status':'EXPECTED','requested_client':requested,'expected_client':expected,
            'exact_requested_size':expected==requested,'workarea':workarea,
            'expected_content_scale_from_source_not_runtime_measurement':min(1.5,expected[0]/960,expected[1]/320),
            'geometry_target':'EXACT_SIZE' if expected==requested else 'LOW_RESOLUTION_ADAPTATION'}


def geometry_verdict(mode, metadata, after_save):
    try:
        workarea=metadata['work_area']
        scale=float(metadata['backing_scale'])
        expected=expected_geometry(mode,workarea,scale)
        if expected['status']!='EXPECTED':return expected
        saved=after_save.get('geometry_settings',{})
        actual=[saved.get('normal_width'),saved.get('normal_height')] if mode=='window' else [saved.get('width'),saved.get('height')]
        result=dict(expected,application_reported_client=actual,application_reported_mode=saved.get('window_mode'))
        if after_save.get('status')!='valid' or any(type(v) not in (int,float) for v in actual):
            return dict(result,status='CAPTURE_INCONCLUSIVE',reason='missing_valid_game_saved_geometry')
        if actual!=expected['expected_client'] or saved.get('window_mode')!=mode:
            return dict(result,status='APPLICATION_FAILURE',reason='actual_saved_geometry_differs_from_unmodified_product_fit_rule')
        if metadata.get('client_geometry_source')=='GetClientRect+ClientToScreen':
            if [metadata.get('client_width'),metadata.get('client_height')]!=actual:
                return dict(result,status='APPLICATION_FAILURE',reason='OS_client_disagrees_with_game_saved_client')
        else:
            # macOS public window-list API exposes outer frame only. Never relabel as client.
            result['mac_client_limit']='application_saved_size_plus_OS_outer_frame_not_direct_OS_client_measurement'
            outer=metadata.get('outer_frame',[])
            if len(outer)!=4 or abs(outer[2]-actual[0])>1 or outer[3]<actual[1]:
                return dict(result,status='CAPTURE_INCONCLUSIVE',reason='mac_outer_frame_does_not_corrobate_saved_client')
            if mode=='strip' and abs(outer[3]-actual[1])>1:
                return dict(result,status='APPLICATION_FAILURE',reason='borderless_strip_outer_height_differs_from_saved_client')
        return dict(result,status='GEOMETRY_OBSERVED_REQUIRES_IMAGE_REVIEW',reason='not_visual_readability_or_proportion_acceptance')
    except (KeyError,TypeError,ValueError) as error:
        return {'status':'CAPTURE_INCONCLUSIVE','reason':'geometry_metadata_missing: '+str(error)}


def log_text(path):
    try:
        with path.open('rb') as stream:
            return stream.read(4*1024*1024).decode('utf-8',errors='replace')
    except OSError:
        return ''


def native_json(command, timeout):
    result=subprocess.run(command,capture_output=True,text=True,encoding='utf-8',errors='replace',timeout=timeout)
    if result.returncode:
        raise RuntimeError('Native helper nonzero exit: '+str(result.returncode))
    return json.loads(result.stdout.strip())


def check_boot_identity(status, reason, output):
    expected='UPDATE BOOT: '+TAG.removeprefix('v')
    markers=[line.strip().split(' / ',1)[0] for line in output.splitlines() if line.strip().startswith('UPDATE BOOT:')]
    observed=expected in markers
    if observed or status=='ENVIRONMENT_UNAVAILABLE':return status,reason,observed
    if markers:return 'APPLICATION_FAILURE','contradictory_installed_version_boot_marker',False
    if status=='APPLICATION_FAILURE':return status,reason,False
    return 'CAPTURE_INCONCLUSIVE','pinned_boot_marker_not_observed',False


def run_session(binary, root, userdata, token, label, capture, budget, process_registry, *, mode=None, driver=None, inputroot=None, suite_deadline=None, expected_transparent=None):
    process=None
    logfile=root/(label+'.log')
    started=time.monotonic()
    deadline=min(started+55,suite_deadline or started+55)
    if deadline-time.monotonic()<20:
        raise RuntimeError('Insufficient suite budget; no game process launched')
    args=ARGS+(['--rendering-driver',driver] if driver else [])
    requested=driver or 'project_default'
    mode=mode or label
    recovery={'status':'NOT_REQUESTED'}; recovery_png=None
    initial_evidence={}
    before_save=owned_save_snapshot(userdata,token)
    metadata={}; before_geometry={}; png=None; close_result={'status':'CLOSE_NOT_SENT','handler_handled':'unknown'}
    timed_out=False
    try:
        with logfile.open('wb') as log:
            process=subprocess.Popen([str(binary),*args],stdout=log,stderr=subprocess.STDOUT)
            process_registry.append(process)
            bounded_log('OWNED_LAUNCH '+json.dumps({'case':label,'pid':process.pid,'args':args}))
            hint=None
            while process.poll() is None:
                elapsed=time.monotonic()-started
                if hint is None and 'Loading resource: res://assets/cultivation/beasts/opportunity_cairn.png' in log_text(logfile):hint=elapsed
                target=min(30,max(18 if not capture else 12,hint+2)) if hint is not None else 30
                if elapsed>=target or time.monotonic()+20>=deadline:break
                time.sleep(.2)
            if process.poll() is None:
                try:
                    remaining=min(38-(time.monotonic()-started),deadline-time.monotonic()-12)
                    if remaining>0:
                        before_geometry=native_json(geometry_command(root,process.pid),min(4,remaining))
                        bounded_log('GEOMETRY_SAMPLE '+json.dumps({'case':label,'sample':'pre_capture','metadata':before_geometry}))
                    if capture and time.monotonic()-started<=37.5:
                        time.sleep(.2)
                        candidate=root/(label+'.png')
                        remaining=min(43-(time.monotonic()-started),deadline-time.monotonic()-10)
                        if remaining>0:
                            metadata=native_json(capture_command(root,process.pid,candidate,1),min(5,remaining))
                            bounded_log('CAPTURE_METADATA '+json.dumps({'case':label,**metadata}))
                            if metadata.get('status')=='CAPTURE_READY':
                                size=candidate.stat().st_size
                                if not 8<=size<=budget:raise ValueError('PNG exceeds explicit combined image budget; no downsampling')
                                if candidate.read_bytes()[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Invalid PNG')
                                png=candidate
                except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as error:
                    bounded_log('CASE_CAPTURE_DIAGNOSTIC '+json.dumps({'case':label,'reason':str(error)[:500]}))
            initial_evidence=renderer_evidence(log_text(logfile),requested)
            emit_record('INITIAL_RENDERER_EVIDENCE',label,initial_evidence)
            if inputroot is not None and process.poll() is None:
                try:
                    recovery,recovery_png=recover_desktop(root,inputroot,process,logfile,label,budget-(png.stat().st_size if png else 0),deadline-8)
                except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as error:
                    recovery={'status':'CAPTURE_INCONCLUSIVE','reason':str(error)[:400]}
                emit_record('DESKTOP_RECOVERY',label,recovery)
            if process.poll() is None:
                remaining=min(45-(time.monotonic()-started),deadline-time.monotonic()-8)
                if remaining>0:
                    try:close_result=native_json(close_command(root,process.pid),min(2,remaining))
                    except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as error:
                        close_result={'status':'CLOSE_REQUEST_UNCONFIRMED','reason':str(error)[:300],'handler_handled':'unknown'}
                else:close_result['reason']='close_deadline_missed_no_late_request'
            close_result['observed_request_return_elapsed_seconds']=round(time.monotonic()-started,2)
            bounded_log('NATIVE_CLOSE_REQUEST '+json.dumps({'case':label,**close_result}))
            try:process.wait(timeout=max(.01,deadline-time.monotonic()))
            except subprocess.TimeoutExpired:
                timed_out=True;stop_owned(process)
        after_save=owned_save_snapshot(userdata,token)
        output=log_text(logfile)
        status,reason=classify(output,process.returncode,timed_out,[metadata] if metadata else [],png is not None)
        status,reason,identity_observed=check_boot_identity(status,reason,output)
        geometry=(native_geometry_verdict(mode,metadata or before_geometry) if inputroot is not None or mode=='restored' else geometry_verdict(mode,metadata or before_geometry,after_save)) if capture else {'status':'SEED_ONLY_NOT_GEOMETRY_TEST'}
        if capture:
            stable=bool(before_geometry and metadata and before_geometry.get('outer_frame')==metadata.get('outer_frame') and before_geometry.get('backing_scale')==metadata.get('backing_scale'))
            geometry['pre_capture_and_capture_geometry_stable']=stable
            if not stable and geometry['status']!='APPLICATION_FAILURE':
                geometry['status']='CAPTURE_INCONCLUSIVE';geometry['reason']='two_stable_native_geometry_samples_missing'
        if logfile.stat().st_size>4*1024*1024 and status!='APPLICATION_FAILURE':
            status,reason='CAPTURE_INCONCLUSIVE','game_log_exceeds_bounded_review_limit'
        if recovery.get('status')=='APPLICATION_FAILURE':status,reason='APPLICATION_FAILURE',recovery['reason']
        if expected_transparent is not None:
            diag=initial_evidence.get('diagnostic')
            if diag is None:
                if status!='APPLICATION_FAILURE':status,reason='CAPTURE_INCONCLUSIVE','missing_ready_desktop_diagnostic'
            elif any(diag.get(k) is not expected_transparent for k in ('transparency_requested','window_transparent_flag','viewport_transparent_background')):
                status,reason='APPLICATION_FAILURE','requested_transparency_flags_not_applied'
        evidence=renderer_evidence(output,requested)
        emit_record('RENDERER_EVIDENCE',label,evidence)
        if geometry['status']=='APPLICATION_FAILURE':status,reason='APPLICATION_FAILURE',geometry['reason']
        bounded_log('GAME_LOG_HEAD '+label+'\n'+output[:16000])
        bounded_log('GAME_LOG_TAIL '+label+'\n'+output[-24000:])
        result={'case':label,'status':status,'reason':reason,'exit_code':process.returncode,'forced_timeout':timed_out,
                'elapsed_seconds':round(time.monotonic()-started,2),'native_close_request':close_result,'pinned_boot_marker_observed':identity_observed,
                'before_save':before_save,'after_save':after_save,'save_write_causality':'unknown_autosave_may_race',
                'geometry':geometry,'pre_capture_geometry':before_geometry,'capture_metadata':metadata,'renderer':evidence,'initial_renderer':initial_evidence,'recovery':recovery,'recovery_png_emitted':recovery_png is not None,
                'normal_exit_is_not_physical_ui_click_test':True,'png_emitted':png is not None}
        for field,value in result.items():
            if field!='case':emit_record('GUI_CASE_FIELD',label,{'field':field,'value':value})
        emit_record('GUI_CASE_RESULT',label,{key:result[key] for key in ('status','reason','exit_code','forced_timeout','pinned_boot_marker_observed','png_emitted')})
        if png:frame_png(png,budget)
        used=png.stat().st_size if png else 0
        if recovery_png:frame_png(recovery_png,budget-used);used+=recovery_png.stat().st_size
        return result,used
    finally:
        try:stop_owned(process)
        finally:
            if process is not None and process.poll() is not None and process in process_registry:process_registry.remove(process)


def main():
    configure_output();owned=False;userdata=None;token=uuid.uuid4().hex;results=[];cleanup_errors=[];process_registry=[]
    status='CAPTURE_INCONCLUSIVE';reason='not_started'
    suite_deadline=time.monotonic()+235
    input_tmp=None;inputroot=None
    try:
        if (os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted'
            or os.environ.get('GITHUB_REPOSITORY')!='lemoncat7/MountainStill' or sys.platform not in PACKAGES):
            raise RuntimeError('Only disposable official Windows/macOS repository runners allowed')
        import native_package_smoke
        native_package_smoke.TAG=TAG
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-',dir=os.environ['RUNNER_TEMP']) as tmp:
            root=Path(tmp);name,sha,executable,size=PACKAGES[sys.platform]
            archive=root/name;prepare_package(archive,root/'app',size,sha,suite_deadline);binary=root/'app'/executable
            if sys.platform=='win32':
                prepared=native_json(['powershell','-NoProfile','-NonInteractive','-File',
                    str(Path(__file__).with_name('native_gui_capture.ps1')),'-PrepareAssembly','-NativeAssembly',str(root/'capture.dll')],remaining_budget(suite_deadline,60,25))
                if prepared.get('status')!='HELPER_PREPARED':raise RuntimeError('Windows helper not prepared; app not evaluated')
                bounded_log('NATIVE_HELPER_SETUP '+json.dumps(prepared))
                input_tmp=tempfile.TemporaryDirectory(prefix='mountainstill-input-',dir=os.environ['RUNNER_TEMP'])
                inputroot=Path(input_tmp.name)
                prepared=native_json(input_command(inputroot,0,'Prepare'),remaining_budget(suite_deadline,45,25))
                if prepared.get('status')!='HELPER_PREPARED':raise RuntimeError('Input helper unavailable; no restoration claim')
            if sys.platform=='darwin':
                architecture=platform.machine()
                if architecture not in ('arm64','x86_64'):raise RuntimeError('Unexpected native macOS architecture')
                built=subprocess.run(['swiftc','-target',architecture+'-apple-macosx15.0','-parse-as-library',
                    str(Path(__file__).with_name('native_gui_capture.swift')),'-o',str(root/'capture')],capture_output=True,text=True,timeout=remaining_budget(suite_deadline,120,25))
                if built.returncode:
                    bounded_log(built.stderr[-12000:]);raise RuntimeError('Native helper compile failed; no application evaluated')
            userdata=userdata_path();claim_userdata(userdata,token);owned=True
            (userdata/'updates').mkdir();(userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
            seed_result,_=run_session(binary,root,userdata,token,'seed',False,0,process_registry,suite_deadline=suite_deadline);results.append(seed_result)
            if seed_result['exit_code']!=0 or seed_result['forced_timeout'] or seed_result['after_save'].get('status')!='valid' or seed_result['status'] in ('APPLICATION_FAILURE','ENVIRONMENT_UNAVAILABLE') or not seed_result['pinned_boot_marker_observed']:
                raise RuntimeError('Synthetic seed boot did not produce a valid normally-closed save; no geometry fixture applied')
            seed=offline_save(userdata,token,process_registry)
            # Paused, introduction-dismissed fixture avoids incidental progression during display-only tests.
            seed['settings']['paused']=True
            seed['arrival_seen']=True
            workarea=seed_result['pre_capture_geometry'].get('work_area')
            if not isinstance(workarea,list) or len(workarea)!=4:raise RuntimeError('Missing measured workarea; refusing to guess geometry fixture position')
            budget=PNG_BUDGET
            cases=[('window','window',True,None,False),('strip','strip',True,None,False)]
            if sys.platform=='win32':
                cases=[('default-window','window',True,None,False),
                       ('default-strip','strip',True,None,True),
                       ('opaque-strip','strip',False,None,False),
                       ('native-request-strip','strip',True,'opengl3',False)]
            for label,mode,transparent,driver,restore in cases:
                if time.monotonic()+25>=suite_deadline:raise RuntimeError('Suite deadline; remaining cases explicitly unverified')
                offline_save(userdata,token,process_registry)
                fixture,changes=apply_geometry_fixture(seed,mode,workarea,transparent)
                (userdata/'cultivation_save.json').write_text(json.dumps(fixture,ensure_ascii=False),encoding='utf-8')
                emit_record('SYNTHETIC_SAVE_GEOMETRY_FIXTURE',label,{'settings_changes':changes,'only_job_owned_game_created_save':True})
                result,bytes_used=run_session(binary,root,userdata,token,label,True,budget,process_registry,
                    mode=mode,driver=driver,inputroot=inputroot if restore else None,suite_deadline=suite_deadline,expected_transparent=transparent)
                budget-=bytes_used;results.append(result)
                after=offline_save(userdata,token,process_registry)
                preserved=gameplay_projection(fixture)==gameplay_projection(after)
                emit_record('OFFLINE_SAVE_PRESERVATION',label,{'preserved':preserved,'paused':after.get('settings',{}).get('paused'),'schema':after.get('version')})
                if not preserved or after.get('settings',{}).get('paused') is not True:raise AssertionError('Display fixture gameplay/save preservation failed')
                if list(userdata.glob('*invalid*')):raise AssertionError('Synthetic geometry settings rejected/corrupt-save recovery')
                if restore:
                    observed=result['recovery'].get('status')=='RESTORE_STATE_OBSERVED_REQUIRES_IMAGE_REVIEW'
                    saved=after.get('settings',{})
                    if observed and not (saved.get('window_mode')=='window' and saved.get('transparent') is False and saved.get('click_through') is False):
                        raise AssertionError('Observed F8 restoration did not persist')
                    if observed:
                        restart,used=run_session(binary,root,userdata,token,'restored-restart',True,budget,process_registry,mode='restored',suite_deadline=suite_deadline,expected_transparent=False)
                        budget-=used;results.append(restart)
                        reopened=offline_save(userdata,token,process_registry)
                        diag=restart['renderer'].get('diagnostic') or {}
                        valid=(gameplay_projection(after)==gameplay_projection(reopened)
                            and reopened.get('settings',{}).get('window_mode')=='window'
                            and reopened.get('settings',{}).get('transparent') is False
                            and diag.get('borderless') is False and diag.get('window_transparent_flag') is False)
                        emit_record('RESTORED_RESTART_ASSERTION','restored-restart',{'saved_state_and_runtime_observed':valid})
                        if not valid:raise AssertionError('Restoration restart state/save mismatch')
            status='APPLICATION_FAILURE' if any(r['status']=='APPLICATION_FAILURE' for r in results) else 'CAPTURE_INCONCLUSIVE'
            reason='one_or_more_case_failures' if status=='APPLICATION_FAILURE' else 'independent_full_window_image_review_required'
    except Exception as error:
        reason=type(error).__name__+': '+str(error)
        if isinstance(error,AssertionError) or any(r.get('status')=='APPLICATION_FAILURE' for r in results):status='APPLICATION_FAILURE'
    finally:
        for process in process_registry:
            try:stop_owned(process)
            except Exception as error:cleanup_errors.append('owned_process_cleanup_failed: '+str(error)[:300])
        if owned and all(p.poll() is not None for p in process_registry):
            try:cleanup_owned_userdata(userdata,token)
            except Exception as error:cleanup_errors.append(str(error)[:500])
        elif owned:cleanup_errors.append('live_owned_process_userdata_left_for_runner_disposal')
        if input_tmp is not None:
            try:input_tmp.cleanup()
            except OSError as error:cleanup_errors.append('input_helper_cleanup_failed: '+str(error)[:200])
    bounded_log('GUI_PROBE_RESULT '+json.dumps({'status':status,'reason':reason[:1000],
        'case_count':len(results),'expected_case_count':6 if sys.platform=='win32' else 3,
        'png_count':sum(int(r.get('png_emitted',False))+int(r.get('recovery_png_emitted',False)) for r in results),
        'expected_png_count':6 if sys.platform=='win32' else 2,'release_pin':TAG,'cleanup_errors':cleanup_errors,
        'scope':'Windows four display/backend cases plus owned F2/F8 restore and restart; macOS two display cases; real pixels require image review; noHiDPI/performance certification'}))
    return 1 if status=='APPLICATION_FAILURE' else 0


if __name__=='__main__':sys.exit(main())
