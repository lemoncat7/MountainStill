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
TAG = 'v1.3.20-test.1'
PACKAGES = {
    'win32': ('MountainStill-v1.3.20-test.1-Windows-x86_64.zip',
              '18fc6381156896ea8eac46317a28d6a1f18e35f4d89cf32819e9324d0a446150',
              'MountainStill/MountainStill.exe', 114432439),
    'darwin': ('MountainStill-v1.3.20-test.1-macOS-Universal.zip',
               '1473f14531b993df673b0fab7cab53775d24200894772c97c100a8aae9215163',
               APP + '.app/Contents/MacOS/' + APP, 141164315),
}
PNG_BUDGET = 1024 * 1024
ARGS = ['--verbose', '--max-fps', '60']


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
                '-TargetPid', str(pid), '-OutputPath', str(output), '-Palette', str(palette)]
    return [str(root / 'capture'), str(pid), str(output), str(palette)]


def close_command(root, pid):
    if sys.platform == 'win32':
        return ['powershell', '-NoProfile', '-NonInteractive', '-File',
                str(Path(__file__).with_name('native_gui_capture.ps1')),
                '-TargetPid', str(pid), '-RequestClose']
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
                str(Path(__file__).with_name('native_gui_capture.ps1')),'-TargetPid',str(pid),'-GeometryOnly']
    return [str(root/'capture'),str(pid),'--geometry-only']


def apply_geometry_fixture(seed, mode, workarea):
    """Only synthetic game-created save settings; no runtime/package injection."""
    data = copy.deepcopy(seed)
    x,y,_,_ = workarea
    changes = {'geometry_version':2,'window_mode':mode,'normal_width':960,'normal_height':540,
               'normal_x':int(x)+12,'normal_y':int(y)+44,'strip_width':1200,
               'window_x':int(x)+12,'window_y':int(y)+44,'ui_scale':1.5,
               'width':960 if mode=='window' else 1200,'height':540 if mode=='window' else 400,
               'always_on_top':False,'transparent':True,'click_through':False}
    data['settings'].update(changes)
    return data, changes


def expected_geometry(mode, workarea, display_scale):
    # This increment deliberately qualifies scale1/96DPI, not a fabricated HiDPI test.
    if abs(display_scale-1) > .001:
        return {'status':'ENVIRONMENT_UNAVAILABLE','reason':'non_1x_display_outside_this_geometry_matrix'}
    requested = [960,540] if mode=='window' else [1200,400]
    minimum = [960,540] if mode=='window' else [960,400]
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


def run_session(binary, root, userdata, token, label, capture, budget, process_registry):
    process=None
    logfile=root/(label+'.log')
    started=time.monotonic()
    metadata={}; before_geometry={}; png=None; close_result={'status':'CLOSE_NOT_SENT','handler_handled':'unknown'}
    timed_out=False
    try:
        with logfile.open('wb') as log:
            process=subprocess.Popen([str(binary),*ARGS],stdout=log,stderr=subprocess.STDOUT)
            process_registry.append(process)
            bounded_log('OWNED_LAUNCH '+json.dumps({'case':label,'pid':process.pid,'args':ARGS}))
            hint=None
            while process.poll() is None:
                elapsed=time.monotonic()-started
                if hint is None and 'Loading resource: res://assets/cultivation/beasts/opportunity_cairn.png' in log_text(logfile):hint=elapsed
                target=min(30,max(18 if not capture else 12,hint+2)) if hint is not None else 30
                if elapsed>=target:break
                time.sleep(.2)
            if process.poll() is None:
                try:
                    remaining=38-(time.monotonic()-started)
                    if remaining>0:
                        before_geometry=native_json(geometry_command(root,process.pid),min(4,remaining))
                        bounded_log('GEOMETRY_SAMPLE '+json.dumps({'case':label,'sample':'pre_capture','metadata':before_geometry}))
                    if capture and time.monotonic()-started<=37.5:
                        time.sleep(.2)
                        candidate=root/(label+'.png')
                        remaining=43-(time.monotonic()-started)
                        if remaining>0:
                            metadata=native_json(capture_command(root,process.pid,candidate,1),min(5,remaining))
                            bounded_log('CAPTURE_METADATA '+json.dumps({'case':label,**metadata}))
                            if metadata.get('status')=='CAPTURE_READY':
                                size=candidate.stat().st_size
                                if not 8<=size<=budget:raise ValueError('PNG exceeds combined2-image1MiB budget; no downsampling')
                                if candidate.read_bytes()[:8]!=b'\x89PNG\r\n\x1a\n':raise ValueError('Invalid PNG')
                                png=candidate
                except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as error:
                    bounded_log('CASE_CAPTURE_DIAGNOSTIC '+json.dumps({'case':label,'reason':str(error)[:500]}))
            before_save=owned_save_snapshot(userdata,token)
            if process.poll() is None:
                remaining=45-(time.monotonic()-started)
                if remaining>0:
                    try:close_result=native_json(close_command(root,process.pid),min(2,remaining))
                    except (ValueError,RuntimeError,OSError,subprocess.TimeoutExpired) as error:
                        close_result={'status':'CLOSE_REQUEST_UNCONFIRMED','reason':str(error)[:300],'handler_handled':'unknown'}
                else:close_result['reason']='close_deadline_missed_no_late_request'
            close_result['observed_request_return_elapsed_seconds']=round(time.monotonic()-started,2)
            bounded_log('NATIVE_CLOSE_REQUEST '+json.dumps({'case':label,**close_result}))
            try:process.wait(timeout=max(.01,55-(time.monotonic()-started)))
            except subprocess.TimeoutExpired:
                timed_out=True;stop_owned(process)
        after_save=owned_save_snapshot(userdata,token)
        output=log_text(logfile)
        status,reason=classify(output,process.returncode,timed_out,[metadata] if metadata else [],png is not None)
        status,reason,identity_observed=check_boot_identity(status,reason,output)
        geometry=geometry_verdict(label,metadata or before_geometry,after_save) if capture else {'status':'SEED_ONLY_NOT_GEOMETRY_TEST'}
        if capture:
            stable=bool(before_geometry and metadata and before_geometry.get('outer_frame')==metadata.get('outer_frame') and before_geometry.get('backing_scale')==metadata.get('backing_scale'))
            geometry['pre_capture_and_capture_geometry_stable']=stable
            if not stable and geometry['status']!='APPLICATION_FAILURE':
                geometry['status']='CAPTURE_INCONCLUSIVE';geometry['reason']='two_stable_native_geometry_samples_missing'
        if logfile.stat().st_size>4*1024*1024 and status!='APPLICATION_FAILURE':
            status,reason='CAPTURE_INCONCLUSIVE','game_log_exceeds_bounded_review_limit'
        if geometry['status']=='APPLICATION_FAILURE':status,reason='APPLICATION_FAILURE',geometry['reason']
        bounded_log('GAME_LOG_HEAD '+label+'\n'+output[:16000])
        bounded_log('GAME_LOG_TAIL '+label+'\n'+output[-24000:])
        result={'case':label,'status':status,'reason':reason,'exit_code':process.returncode,'forced_timeout':timed_out,
                'elapsed_seconds':round(time.monotonic()-started,2),'native_close_request':close_result,'pinned_boot_marker_observed':identity_observed,
                'before_save':before_save,'after_save':after_save,'save_write_causality':'unknown_autosave_may_race',
                'geometry':geometry,'pre_capture_geometry':before_geometry,'capture_metadata':metadata,
                'normal_exit_is_not_physical_ui_click_test':True,'png_emitted':png is not None}
        bounded_log('GUI_CASE_RESULT '+json.dumps(result))
        if png:frame_png(png,budget)
        return result,png.stat().st_size if png else 0
    finally:
        try:stop_owned(process)
        finally:
            if process is not None and process.poll() is not None and process in process_registry:process_registry.remove(process)


def main():
    configure_output();owned=False;userdata=None;token=uuid.uuid4().hex;results=[];cleanup_errors=[];process_registry=[]
    status='CAPTURE_INCONCLUSIVE';reason='not_started'
    try:
        if (os.environ.get('GITHUB_ACTIONS')!='true' or os.environ.get('RUNNER_ENVIRONMENT')!='github-hosted'
            or os.environ.get('GITHUB_REPOSITORY')!='lemoncat7/MountainStill' or sys.platform not in PACKAGES):
            raise RuntimeError('Only disposable official Windows/macOS repository runners allowed')
        import native_package_smoke
        native_package_smoke.TAG=TAG
        with tempfile.TemporaryDirectory(prefix='mountainstill-gui-',dir=os.environ['RUNNER_TEMP']) as tmp:
            root=Path(tmp);name,sha,executable,size=PACKAGES[sys.platform]
            archive=root/name;download(archive,size,sha);extract(archive,root/'app');binary=root/'app'/executable
            if sys.platform=='darwin':
                architecture=platform.machine()
                if architecture not in ('arm64','x86_64'):raise RuntimeError('Unexpected native macOS architecture')
                built=subprocess.run(['swiftc','-target',architecture+'-apple-macosx15.0','-parse-as-library',
                    str(Path(__file__).with_name('native_gui_capture.swift')),'-o',str(root/'capture')],capture_output=True,text=True,timeout=120)
                if built.returncode:
                    bounded_log(built.stderr[-12000:]);raise RuntimeError('Native helper compile failed; no application evaluated')
            userdata=userdata_path();claim_userdata(userdata,token);owned=True
            (userdata/'updates').mkdir();(userdata/'updates'/'preferences.cfg').write_text('[updates]\nauto_check=false\n',encoding='utf-8')
            seed_result,_=run_session(binary,root,userdata,token,'seed',False,0,process_registry);results.append(seed_result)
            if seed_result['exit_code']!=0 or seed_result['forced_timeout'] or seed_result['after_save'].get('status')!='valid' or seed_result['status'] in ('APPLICATION_FAILURE','ENVIRONMENT_UNAVAILABLE') or not seed_result['pinned_boot_marker_observed']:
                raise RuntimeError('Synthetic seed boot did not produce a valid normally-closed save; no geometry fixture applied')
            seed=read_save(userdata/'cultivation_save.json')
            workarea=seed_result['pre_capture_geometry'].get('work_area')
            if not isinstance(workarea,list) or len(workarea)!=4:raise RuntimeError('Missing measured workarea; refusing to guess geometry fixture position')
            budget=PNG_BUDGET
            for mode in ('window','strip'):
                if owned_save_snapshot(userdata,token)['status']!='valid':raise RuntimeError('Owned save unavailable before fixture')
                fixture,changes=apply_geometry_fixture(seed,mode,workarea)
                (userdata/'cultivation_save.json').write_text(json.dumps(fixture,ensure_ascii=False),encoding='utf-8')
                bounded_log('SYNTHETIC_SAVE_GEOMETRY_FIXTURE '+json.dumps({'case':mode,'settings_changes':changes,'only_job_owned_game_created_save':True}))
                result,bytes_used=run_session(binary,root,userdata,token,mode,True,budget,process_registry)
                budget-=bytes_used;results.append(result)
                if list(userdata.glob('*invalid*')):raise RuntimeError('Synthetic geometry settings rejected/corrupt-save recovery')
            status='APPLICATION_FAILURE' if any(r['status']=='APPLICATION_FAILURE' for r in results) else 'CAPTURE_INCONCLUSIVE'
            reason='one_or_more_case_failures' if status=='APPLICATION_FAILURE' else 'independent_full_window_image_review_required'
    except Exception as error:
        reason=type(error).__name__+': '+str(error)
        if any(r.get('status')=='APPLICATION_FAILURE' for r in results):status='APPLICATION_FAILURE'
    finally:
        for process in process_registry:
            try:stop_owned(process)
            except Exception as error:cleanup_errors.append('owned_process_cleanup_failed: '+str(error)[:300])
        if owned and all(p.poll() is not None for p in process_registry):
            try:cleanup_owned_userdata(userdata,token)
            except Exception as error:cleanup_errors.append(str(error)[:500])
        elif owned:cleanup_errors.append('live_owned_process_userdata_left_for_runner_disposal')
    bounded_log('GUI_PROBE_RESULT '+json.dumps({'status':status,'reason':reason[:1000],
        'case_count':len(results),'release_pin':TAG,'cleanup_errors':cleanup_errors,
        'scope':'normal960x540 and requestedstrip1200x400; clamps explicitly not exact-size PASS; noHiDPI/performance/input certification'}))
    return 1 if status=='APPLICATION_FAILURE' else 0


if __name__=='__main__':sys.exit(main())
