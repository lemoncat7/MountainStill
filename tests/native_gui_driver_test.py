import contextlib
import hashlib
import io
from pathlib import Path
import sys
import tempfile
import unittest
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_gui_probe as probe

class Contracts(unittest.TestCase):
    def test_default_renderer_args(self):
        self.assertEqual(probe.ARGS, ['--verbose','--max-fps','60'])
    def test_pin(self):
        self.assertEqual(probe.TAG, 'v1.3.28-test.1')
        self.assertEqual(len(probe.PACKAGES),2)
        self.assertEqual(probe.PACKAGES['win32'][0], 'MountainStill-v1.3.28-test.1-Windows-x86_64.zip')
        self.assertEqual(probe.PACKAGES['win32'][1], '712770c50a52cc21348fadea0a4bcf8efe6ff3987fff83175ff1be9afd0f227e')
        self.assertEqual(probe.PACKAGES['win32'][3], 114561641)
        self.assertEqual(probe.PACKAGES['darwin'][0], 'MountainStill-v1.3.28-test.1-macOS-Universal.zip')
        self.assertEqual(probe.PACKAGES['darwin'][1], 'd914e746f06f32f2bc3a8803c57ed6a37f75ef08f085f43b972b3e034cd21aec')
        self.assertEqual(probe.PACKAGES['darwin'][3], 141292607)
    def test_png_frame(self):
        import base64
        with tempfile.TemporaryDirectory() as tmp:
            p = Path(tmp)/'capture-1.png'; data=b'\x89PNG\r\n\x1a\n'+b'a'*9000; p.write_bytes(data)
            stdout=io.StringIO()
            with contextlib.redirect_stdout(stdout):
                self.assertEqual(probe.frame_png(p,probe.PNG_BUDGET),len(data))
            lines=stdout.getvalue().splitlines()
            self.assertTrue(all(len(line)<=4096 for line in lines))
            self.assertIn(hashlib.sha256(data).hexdigest(),lines[0])
            self.assertEqual(base64.b64decode(''.join(lines[1:-1])),data)
            with self.assertRaises(ValueError): probe.frame_png(p,len(data)-1)
    def test_all_log_lines_bounded(self):
        out=io.StringIO()
        with contextlib.redirect_stdout(out): probe.bounded_log('字'*15000)
        self.assertTrue(all(len(line.encode())<=4096 for line in out.getvalue().splitlines()))
    def test_refuse_outside_runner(self):
        from unittest.mock import patch
        with patch.dict('os.environ',{},clear=True),contextlib.redirect_stdout(io.StringIO()) as out:
            self.assertEqual(probe.main(),0)
        self.assertIn('Only disposable official',out.getvalue())
    def test_windows_failed_taskkill_falls_back_to_owned_process(self):
        from unittest.mock import Mock, patch
        process=Mock(); process.pid=42; process.returncode=-9; process.poll.return_value=None
        with patch.object(probe.sys,'platform','win32'), patch.object(probe.subprocess,'run',return_value=Mock(returncode=1)):
            probe.stop_owned(process)
        process.kill.assert_called_once(); process.wait.assert_called_once_with(timeout=2)
    def test_audio_fallback_does_not_hide_app_errors(self):
        audio='ERROR: WASAPI: init_output_device error.\n   at: init (drivers/wasapi/audio_driver_wasapi.cpp:600)\nWARNING: All audio drivers failed, falling back to the dummy driver.'
        self.assertEqual(probe.classify(audio,0,False,[],True)[0],'CAPTURE_INCONCLUSIVE')
        self.assertEqual(probe.classify(audio+'\nSCRIPT ERROR: broken',0,True,[],True)[0],'APPLICATION_FAILURE')
        self.assertEqual(probe.classify('ERROR: WASAPI: init_output_device error.',0,False,[],True)[0],'APPLICATION_FAILURE')
    def test_owned_cleanup_and_wrong_marker(self):
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp)/'userdata';path.mkdir()
            (path/'.native-package-ci-owner').write_text('ours')
            (path/'game.log').write_text('synthetic')
            with self.assertRaises(RuntimeError):probe.cleanup_owned_userdata(path,'other')
            self.assertTrue(path.exists())
            probe.cleanup_owned_userdata(path,'ours');self.assertFalse(path.exists())
    def test_capture_full_geometry_not_arbitrary_crop(self):
        tools=Path(probe.__file__).parent
        self.assertNotIn('min(area.width, 720', (tools/'native_gui_capture.swift').read_text())
        self.assertIn('GetClientRect', (tools/'native_gui_capture.ps1').read_text())
    def test_owned_save_evidence(self):
        import json
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp);(path/'.native-package-ci-owner').write_text('ours')
            (path/'cultivation_save.json').write_text(json.dumps({'version':4,'lifetime_seconds':12.5}))
            self.assertEqual(probe.owned_save_snapshot(path,'other')['status'],'ownership_unverified_not_read')
            data=probe.owned_save_snapshot(path,'ours')
            self.assertEqual(data['status'],'valid');self.assertEqual(data['lifetime_seconds'],12.5)
    def test_marker_read_failure_is_diagnostic_only(self):
        from unittest.mock import patch
        with tempfile.TemporaryDirectory() as tmp:
            path=Path(tmp);(path/'.native-package-ci-owner').write_text('ours')
            with patch.object(Path,'read_text',side_effect=PermissionError('busy')):
                self.assertEqual(probe.owned_save_snapshot(path,'ours')['status'],'unverified')
    def test_normal_close_not_force_or_automatic_quit(self):
        self.assertNotIn('--quit-after',probe.ARGS)
        tools=Path(probe.__file__).parent
        self.assertIn('PostMessageW($h,0x0010', (tools/'native_gui_capture.ps1').read_text())
        swift=(tools/'native_gui_capture.swift').read_text()
        self.assertIn('app.terminate()',swift);self.assertNotIn('forceTerminate',swift)
        source=Path(probe.__file__).read_text()
        self.assertIn('time.monotonic()-started<=37.5',source)
        self.assertIn('remaining=min(43-',source)
        self.assertIn('remaining=min(45-',source)
        self.assertIn('min(5,remaining)',source)
    def test_windows_helper_precompiled_in_owned_scratch(self):
        from unittest.mock import patch
        root=Path('/tmp/mountainstill-gui-unit')
        with patch.object(probe.sys,'platform','win32'):
            for command in [probe.capture_command(root,1,root/'x.png',1),probe.geometry_command(root,1),probe.close_command(root,1)]:
                self.assertIn('-NativeAssembly',command);self.assertIn(str(root/'capture.dll'),command)
        ps=Path(probe.__file__).with_name('native_gui_capture.ps1').read_text()
        self.assertIn('-OutputAssembly $NativeAssembly',ps);self.assertIn('Add-Type -Path $NativeAssembly',ps)
        self.assertIn('immediate child of RUNNER_TEMP',ps);self.assertIn('ReparsePoint',ps)
        workflow=(Path(probe.__file__).parents[1]/'.github/workflows/native-gui-probe.yml').read_text()
        self.assertIn('windows_only:',workflow);self.assertIn('type: boolean',workflow)
        self.assertNotIn('inputs.runner',workflow)
    def test_boot_identity_preserves_environment_failure(self):
        result=probe.check_boot_identity('ENVIRONMENT_UNAVAILABLE','renderer_failed','could not initialize opengl')
        self.assertEqual(result,('ENVIRONMENT_UNAVAILABLE','renderer_failed',False))
        self.assertEqual(probe.check_boot_identity('CAPTURE_INCONCLUSIVE','no_capture','')[0],'CAPTURE_INCONCLUSIVE')
        self.assertEqual(probe.check_boot_identity('CAPTURE_INCONCLUSIVE','review','UPDATE BOOT: 0.0.0')[0],'APPLICATION_FAILURE')
        self.assertTrue(probe.check_boot_identity('CAPTURE_INCONCLUSIVE','review','UPDATE BOOT: '+probe.TAG[1:])[2])
    def test_geometry_expectations_exact_vs_low_resolution(self):
        normal=probe.expected_geometry('window',[0,0,1024,728],1)
        strip=probe.expected_geometry('strip',[0,0,1024,728],1)
        wide=probe.expected_geometry('strip',[0,25,1920,1010],1)
        self.assertEqual(normal['expected_client'],[960,540])
        self.assertEqual(strip['requested_client'],[1200,400]);self.assertEqual(strip['expected_client'],[1000,400])
        self.assertFalse(strip['exact_requested_size']);self.assertEqual(strip['geometry_target'],'LOW_RESOLUTION_ADAPTATION')
        self.assertEqual(wide['expected_client'],[1200,400]);self.assertTrue(wide['exact_requested_size'])
        self.assertEqual(wide['expected_content_scale_from_source_not_runtime_measurement'],1.25)
        self.assertEqual(probe.expected_geometry('strip',[0,0,1920,1080],2)['status'],'ENVIRONMENT_UNAVAILABLE')
    def test_fixture_only_changes_explicit_settings(self):
        seed={'version':4,'lifetime_seconds':20,'gear':{'x':[1]},'settings':{'music':.3,'window_mode':'window'}}
        fixture,changes=probe.apply_geometry_fixture(seed,'strip',[0,25,1920,1030])
        self.assertEqual(fixture['gear'],seed['gear']);self.assertEqual(fixture['lifetime_seconds'],20)
        self.assertEqual(seed['settings'],{'music':.3,'window_mode':'window'})
        self.assertEqual(fixture['settings']['window_y'],69);self.assertEqual(changes['ui_scale'],1.5)
        self.assertEqual(changes['strip_width'],1200);self.assertFalse(changes['click_through'])
        self.assertEqual(set(changes),set(probe.GEOMETRY_KEYS))
    def test_os_client_mismatch_is_not_compensated(self):
        meta={'work_area':[0,0,1024,728],'backing_scale':1,'client_geometry_source':'GetClientRect+ClientToScreen','client_width':999,'client_height':400}
        save={'status':'valid','geometry_settings':{'window_mode':'strip','width':1000,'height':400}}
        self.assertEqual(probe.geometry_verdict('strip',meta,save)['status'],'APPLICATION_FAILURE')
        meta['client_width']=1000
        self.assertEqual(probe.geometry_verdict('strip',meta,save)['status'],'GEOMETRY_OBSERVED_REQUIRES_IMAGE_REVIEW')
    def test_mac_outer_never_claimed_direct_client(self):
        meta={'work_area':[0,25,1920,1030],'backing_scale':1,'client_geometry_source':'unavailable_without_AX','outer_frame':[12,69,960,568]}
        save={'status':'valid','geometry_settings':{'window_mode':'window','normal_width':960,'normal_height':540}}
        result=probe.geometry_verdict('window',meta,save)
        self.assertIn('not_direct_OS_client_measurement',result['mac_client_limit'])
        self.assertEqual(result['status'],'GEOMETRY_OBSERVED_REQUIRES_IMAGE_REVIEW')
    def test_mocked_session_defers_png_until_after_close(self):
        import json
        from unittest.mock import patch
        class Process:
            pid=321;returncode=None
            def poll(self):return self.returncode
            def wait(self,timeout):return self.returncode
            def kill(self):self.returncode=-9
        # This is a platform-independent orchestration test, not a PTY test.
        # sys.platform is mocked below even on Windows, where os.openpty is absent.
        class MockPTYLog:
            def __init__(self,path):self.path=path
            def __enter__(self):self.stream=self.path.open('wb');return self.stream
            def started(self, **kwargs):pass
            def check(self):pass
            def __exit__(self,*args):self.stream.close()
        process=Process();clock=[0.0]
        def now():clock[0]+=.5;return clock[0]
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);userdata=root/'userdata';userdata.mkdir()
            (userdata/'.native-package-ci-owner').write_text('ours')
            (userdata/'cultivation_save.json').write_text(json.dumps({'version':4,'lifetime_seconds':20,'settings':{'window_mode':'window','normal_width':960,'normal_height':540}}))
            metadata={'status':'GEOMETRY_READY','work_area':[0,0,1024,728],'backing_scale':1,'client_geometry_source':'GetClientRect+ClientToScreen','client_width':960,'client_height':540,'outer_frame':[12,44,976,579]}
            def launch(*args,**kwargs):
                stream=kwargs['stdout']
                data=('UPDATE BOOT: '+probe.TAG[1:]+'\nLoading resource: res://assets/cultivation/beasts/opportunity_cairn.png\n').encode()
                if isinstance(stream,int):
                    import os
                    os.write(stream,data)
                else:stream.write(data);stream.flush()
                return process
            def helper(command,timeout):
                if '--geometry-only' in command:return dict(metadata)
                if '--request-close' in command:process.returncode=0;return {'status':'CLOSE_REQUEST_SENT','handler_handled':'unknown'}
                Path(command[2]).write_bytes(b'\x89PNG\r\n\x1a\n'+b'a'*100)
                return dict(metadata,status='CAPTURE_READY')
            out=io.StringIO();registry=[]
            with patch.object(probe.time,'monotonic',side_effect=now),patch.object(probe.time,'sleep'),patch.object(probe.subprocess,'Popen',side_effect=launch),patch.object(probe,'native_json',side_effect=helper),patch.object(probe.sys,'platform','darwin'),patch.object(probe,'OwnedPTYLog',MockPTYLog),contextlib.redirect_stdout(out):
                result,size=probe.run_session(root/'fake',root,userdata,'ours','window',True,probe.PNG_BUDGET,registry)
            self.assertEqual(size,108);self.assertEqual(result['exit_code'],0);self.assertFalse(result['forced_timeout'])
            self.assertTrue(result['geometry']['pre_capture_and_capture_geometry_stable'])
            self.assertLess(out.getvalue().index('NATIVE_CLOSE_REQUEST'),out.getvalue().index('BEGIN_GUI_PNG'))
            self.assertEqual(registry,[])
    def test_mocked_session_without_posix_openpty(self):
        from unittest.mock import patch
        with patch.object(probe.os,'openpty',create=True,side_effect=AttributeError('os.openpty unavailable on Windows')) as openpty:
            self.test_mocked_session_defers_png_until_after_close()
        openpty.assert_not_called()

    def test_controlled_backdrop_contract(self):
        tools=Path(probe.__file__).parent
        swift=(tools/'native_gui_capture.swift').read_text(); ps=(tools/'native_gui_capture.ps1').read_text()
        self.assertIn('gameOrder + 1 == boardOrder',swift)
        self.assertIn('ShowWithoutActivation',ps)
        self.assertIn('0x0210',ps)
        self.assertNotIn('makeKey',swift)
        self.assertNotIn('activate(',swift)
        self.assertIn('finally',ps);self.assertIn('defer',swift)
    def test_native_permission_contract(self):
        tools=Path(probe.__file__).parent
        swift=(tools/'native_gui_capture.swift').read_text()
        self.assertIn('CGPreflightScreenCaptureAccess()',swift)
        self.assertNotIn('CGRequestScreenCaptureAccess',swift)
        self.assertIn('excludingWindows:[]',swift)
        ps=(tools/'native_gui_capture.ps1').read_text()
        self.assertIn('0x40CC0020',ps)
        self.assertIn('ReleaseDC',ps)
        self.assertNotIn('$graphics.CopyFromScreen',ps)
        self.assertNotIn('ExecutionPolicy',ps)

class DesktopCompatibilityContracts(unittest.TestCase):
    def diagnostic(self,driver='opengl3_angle',**values):
        import json
        return 'DESKTOP DISPLAY: '+json.dumps(dict(schema=1,window_attached=True,native_window_ready=True,rendering_driver=driver,**values))

    def test_default_angle_and_explicit_native_fallback_distinguished(self):
        from unittest.mock import patch
        with patch.object(probe.sys,'platform','win32'):
            default=probe.renderer_evidence(self.diagnostic(),'project_default')
            self.assertEqual(default['selection'],'REQUEST_MATCH')
            fallback=probe.renderer_evidence(self.diagnostic(),'opengl3')
            self.assertEqual(fallback['requested_driver'],'opengl3')
            self.assertEqual(fallback['actual_driver'],'opengl3_angle')
            self.assertEqual(fallback['selection'],'FALLBACK_OBSERVED')
            self.assertFalse(fallback['native_opengl_verified'])
            self.assertFalse(fallback['pixel_transparency_verified'])
            native=probe.renderer_evidence(self.diagnostic('opengl3',adapter_name='Intel HD',adapter_vendor='Intel',adapter_api='4.1 INTEL-20.0'),'opengl3')
            self.assertTrue(native['native_opengl_verified'])
            self.assertEqual(probe.renderer_evidence(self.diagnostic('opengl3'),'project_default')['selection'],'FALLBACK_OBSERVED')

    def test_bad_or_unready_diagnostics_are_not_renderer_evidence(self):
        for text in ['','DESKTOP DISPLAY: broken','DESKTOP DISPLAY: []','DESKTOP DISPLAY: {"schema":1}']:
            self.assertEqual(probe.renderer_evidence(text,'opengl3')['selection'],'UNVERIFIED')
        text=self.diagnostic()+'\nDESKTOP DISPLAY: {"schema":1,"native_window_ready":false}'
        self.assertEqual(probe.renderer_evidence(text,'opengl3')['actual_driver'],'opengl3_angle')

    def test_mac_default_is_not_reported_as_fallback(self):
        from unittest.mock import patch
        with patch.object(probe.sys,'platform','darwin'):
            self.assertEqual(probe.renderer_evidence(self.diagnostic('opengl3'),'project_default')['selection'],'REQUEST_MATCH')

    def test_structured_records_never_split_or_silently_truncate(self):
        import json
        out=io.StringIO()
        with contextlib.redirect_stdout(out):probe.emit_record('EVIDENCE','case',{'reason':'字'*50})
        line=out.getvalue().strip();self.assertLess(len(line.encode()),4096)
        self.assertEqual(json.loads(line.split(' ',1)[1])['reason'],'字'*50)
        with self.assertRaises(ValueError):probe.emit_record('EVIDENCE','case',{'reason':'x'*4000})

    def test_offline_only_save_and_exact_gameplay_projection(self):
        from unittest.mock import Mock
        with self.assertRaisesRegex(RuntimeError,'LIVE_PROCESS_SAVE_READ_FORBIDDEN'):
            probe.offline_save(Path('/not-read'),'token',[Mock(poll=lambda:None)])
        before={'version':4,'gear':{'x':1},'settings':{'transparent':True},'saved_at':2}
        after=dict(before,settings={'transparent':False},saved_at=3)
        self.assertEqual(probe.gameplay_projection(before),probe.gameplay_projection(after))
        after['gear']={'x':0};self.assertNotEqual(probe.gameplay_projection(before),probe.gameplay_projection(after))

    def test_opaque_fixture_and_restored_geometry(self):
        seed={'settings':{'paused':True},'gear':{'x':1}}
        fixture,_=probe.apply_geometry_fixture(seed,'strip',[0,0,1024,728],False)
        self.assertFalse(fixture['settings']['transparent']);self.assertTrue(fixture['settings']['paused'])
        self.assertEqual(seed,{'settings':{'paused':True},'gear':{'x':1}})
        geometry=probe.native_geometry_verdict('restored',{'work_area':[0,0,1024,728],'backing_scale':1,'client_width':1000,'client_height':672})
        self.assertEqual(geometry['status'],'NATIVE_GEOMETRY_OBSERVED')
        self.assertEqual(probe.native_geometry_verdict('restored',{})['status'],'CAPTURE_INCONCLUSIVE')

    def test_desktop_input_is_explicit_no_general_click_relaxation(self):
        source=Path(probe.__file__).with_name('native_input_helper.ps1').read_text()
        self.assertIn("[switch]$DesktopKeys",source)
        self.assertIn("$Action -notin @('Inspect','Key')",source)
        self.assertIn("$Key -notin @('F2','F8')",source)
        self.assertIn('case "F2":vk=0x71',source);self.assertIn('case "F8":vk=0x77',source)
        self.assertIn('!DesktopKeys && (r.Right-r.Left!=960 || r.Bottom-r.Top!=540)',source)
        self.assertIn('GetForegroundWindow()!=h || !Owns(GetForegroundWindow(),pid)',source)
        self.assertIn('Requested key already down',source)
        cmd=probe.input_command(Path('/owned'),42,'Key',123,'F8')
        self.assertIn('-DesktopKeys',cmd);self.assertIn('42',cmd);self.assertIn('123',cmd)
        self.assertNotIn('-DesktopKeys',probe.input_command(Path('/owned'),0,'Prepare'))

    def test_image_and_suite_budgets_are_explicit(self):
        self.assertEqual(probe.PNG_BUDGET,6*1024*1024)
        source=Path(probe.__file__).read_text()
        self.assertIn('suite_deadline=time.monotonic()+235',source)
        self.assertIn("'expected_png_count':6 if sys.platform=='win32' else 2",source)
        self.assertNotIn('ExecutionPolicy',source)
        workflow=(Path(probe.__file__).parents[1]/'.github/workflows/native-gui-probe.yml').read_text()
        self.assertIn('permissions: {}',workflow);self.assertIn('timeout-minutes: 5',workflow)

    def test_recovery_uses_owned_keys_and_observed_states(self, capture_failure=None):
        from unittest.mock import Mock, patch
        import json
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);log=root/'game.log';stage=[-1];keys=[]
            sizes=[[960,540],[1000,400],[1000,672]]
            def helper(command,timeout):
                if '-Action' in command:
                    action=command[command.index('-Action')+1]
                    if action=='Inspect':return {'status':'INSPECT_READY','owner_pid':42,'window_id':77}
                    key=command[command.index('-Key')+1];keys.append(key);stage[0]+=1
                    log.write_text(self.diagnostic(borderless=stage[0]==1,transparency_requested=stage[0]!=2,
                        window_transparent_flag=stage[0]!=2,viewport_transparent_background=stage[0]!=2))
                    return {'status':'INPUT_SENT','owner_pid':42,'window_id':77}
                if '-OutputPath' in command:
                    if capture_failure=='refused':return {'status':'CAPTURE_INCONCLUSIVE'}
                    if capture_failure=='timeout':raise probe.subprocess.TimeoutExpired(command,5)
                    if capture_failure=='invalid':
                        Path(command[command.index('-OutputPath')+1]).write_bytes(b'bad')
                        return {'status':'CAPTURE_READY'}
                    Path(command[command.index('-OutputPath')+1]).write_bytes(b'\x89PNG\r\n\x1a\n'+b'x'*20)
                    return {'status':'CAPTURE_READY','palette':2,'directly_behind_target':True}
                width,height=sizes[stage[0]]
                if capture_failure=='state' and stage[0]==2:width=999
                return {'work_area':[0,0,1024,728],'backing_scale':1,'client_width':width,'client_height':height}
            with patch.object(probe.sys,'platform','win32'),patch.object(probe,'native_json',side_effect=helper),patch.object(probe.time,'sleep'),contextlib.redirect_stdout(io.StringIO()):
                result,png=probe.recover_desktop(root,root,Mock(pid=42),log,'owned-strip',1024,probe.time.monotonic()+60)
            self.assertEqual(keys,['F2','F2','F8'])
            if capture_failure=='state':
                self.assertEqual(result['status'],'APPLICATION_FAILURE')
                self.assertIsNot(result.get('state_observed'),True)
                self.assertIsNone(png)
                return
            self.assertTrue(result['state_observed'])
            if capture_failure:
                self.assertEqual(result['status'],'CAPTURE_INCONCLUSIVE')
                self.assertEqual(result['capture_status'],'CAPTURE_INCONCLUSIVE')
                self.assertIsNone(png)
            else:
                self.assertEqual(result['status'],'RESTORE_STATE_OBSERVED_REQUIRES_IMAGE_REVIEW')
                self.assertTrue(png.exists())

    def test_recovery_capture_failure_preserves_observed_state(self):
        for failure in ('refused','timeout','invalid','state'):
            with self.subTest(failure=failure):self.test_recovery_uses_owned_keys_and_observed_states(failure)

    def test_recovery_refused_input_has_no_retry_or_following_keys(self):
        from unittest.mock import Mock, patch
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp)
            replies=[{'status':'INSPECT_READY','owner_pid':42,'window_id':77},{'status':'INPUT_REFUSED'}]
            with patch.object(probe,'native_json',side_effect=replies) as helper,contextlib.redirect_stdout(io.StringIO()):
                with self.assertRaisesRegex(RuntimeError,'no retry'):
                    probe.recover_desktop(root,root,Mock(pid=42),root/'log','owned',1024,probe.time.monotonic()+60)
            self.assertEqual(helper.call_count,2)

    def test_complete_windows_matrix_offline_mock(self, capture_failure=False, bad_save=False, bad_exit=False, input_failure=False):
        from unittest.mock import patch
        import json, os
        calls=[]
        with tempfile.TemporaryDirectory() as tmp:
            userdata=Path(tmp)/'userdata'
            def session(binary,root,path,token,label,capture,budget,registry,**kwargs):
                calls.append((label,kwargs))
                if label=='seed':
                    saved={'version':4,'lifetime_seconds':20,'arrival_seen':True,'settings':{'paused':False},'gear':{'x':1}}
                    (path/'cultivation_save.json').write_text(json.dumps(saved))
                else:saved=json.loads((path/'cultivation_save.json').read_text())
                recovery={'status':'NOT_REQUESTED'}
                if kwargs.get('inputroot'):
                    saved['settings'].update(window_mode='window',transparent=False,click_through=False)
                    (path/'cultivation_save.json').write_text(json.dumps(saved))
                    recovery={'status':'CAPTURE_INCONCLUSIVE' if capture_failure else 'RESTORE_STATE_OBSERVED_REQUIRES_IMAGE_REVIEW','state_observed':not input_failure}
                    if bad_save:
                        saved['settings']['transparent']=True
                        (path/'cultivation_save.json').write_text(json.dumps(saved))
                return {'case':label,'exit_code':1 if bad_exit and kwargs.get('inputroot') else 0,'forced_timeout':False,'after_save':{'status':'valid'},'status':'CAPTURE_INCONCLUSIVE',
                    'pinned_boot_marker_observed':True,'pre_capture_geometry':{'work_area':[0,0,1024,728]},
                    'recovery':recovery,'renderer':{'diagnostic':{'borderless':False,'window_transparent_flag':False,'transparency_requested':False,'viewport_transparent_background':False}},
                    'png_emitted':capture,'recovery_png_emitted':bool(kwargs.get('inputroot')) and not capture_failure},100 if capture else 0
            env={'GITHUB_ACTIONS':'true','RUNNER_ENVIRONMENT':'github-hosted','GITHUB_REPOSITORY':'lemoncat7/MountainStill','RUNNER_TEMP':tmp}
            with patch.dict(os.environ,env),patch.object(probe.sys,'platform','win32'),patch.object(probe,'userdata_path',return_value=userdata),patch.object(probe,'run_session',side_effect=session),patch.object(probe,'native_json',return_value={'status':'HELPER_PREPARED'}),patch.object(probe,'prepare_package'),patch.object(probe,'configure_output'),contextlib.redirect_stdout(io.StringIO()) as output:
                self.assertEqual(probe.main(),1 if bad_save or bad_exit else 0)
            if bad_save or bad_exit or input_failure:
                self.assertNotIn('restored-restart',[c[0] for c in calls])
                return
            self.assertEqual([c[0] for c in calls],['seed','default-window','default-strip','restored-restart','opaque-strip','native-request-strip'])
            self.assertEqual(calls[-1][1]['driver'],'opengl3')
            self.assertFalse(calls[-2][1]['expected_transparent'])
            self.assertIsNone(calls[1][1]['driver'])
            summary=json.loads(next(x.split(' ',1)[1] for x in output.getvalue().splitlines() if x.startswith('GUI_PROBE_RESULT ')))
            self.assertEqual(summary['png_count'],summary['expected_png_count']-int(capture_failure))
            self.assertEqual(summary['case_count'],6)
            self.assertFalse(userdata.exists())

    def test_capture_failure_still_checks_save_and_restarts(self):
        self.test_complete_windows_matrix_offline_mock(capture_failure=True)

    def test_capture_failure_does_not_hide_bad_save_or_exit(self):
        self.test_complete_windows_matrix_offline_mock(capture_failure=True,bad_save=True)
        self.test_complete_windows_matrix_offline_mock(capture_failure=True,bad_exit=True)

    def test_unobserved_input_state_never_restarts(self):
        self.test_complete_windows_matrix_offline_mock(capture_failure=True,input_failure=True)

    def test_windows_backdrop_bounded_owned_revalidation(self):
        ps=Path(probe.__file__).with_name('native_gui_capture.ps1').read_text()
        self.assertIn('$attempt -le 3 -and $wait.ElapsedMilliseconds -lt 350',ps)
        self.assertIn('[Math]::Min(350,$wait.ElapsedMilliseconds+100)',ps)
        self.assertEqual(ps.count('[GuiProbe]::SetWindowPos('),1)
        self.assertIn('SetWindowPos($board.Handle,$h,',ps)
        self.assertIn('$boardPid -ne $PID',ps)
        self.assertIn('$actualPid -ne $TargetPid',ps)
        self.assertIn('Capture geometry changed',ps)
        self.assertEqual(ps.count('  Assert-OwnedCaptureGeometry'),3)
        self.assertIn('Assert-OwnedCaptureGeometry\n if (-not $adjacent -or [GuiProbe]::GetWindow($h,2) -ne $board.Handle)',ps)
        self.assertLess(ps.index('if (-not $adjacent'),ps.index('[GuiProbe]::BitBlt('))
        self.assertIn('reason=$_.Exception.Message;backdrop_placement_attempts=$placementAttempts',ps)
        for key in ('behind_hwnd','behind_pid','behind_class','behind_visible'):
            self.assertIn(key,ps)
        self.assertNotIn('GetWindowText',ps)

    def test_expired_budget_never_launches_seed_or_restart(self):
        from unittest.mock import patch
        for label in ['seed','restored-restart']:
            with patch.object(probe.subprocess,'Popen') as launch:
                with self.assertRaisesRegex(RuntimeError,'no game process launched'):
                    probe.run_session(Path('/exe'),Path('/tmp'),Path('/userdata'),'token',label,False,0,[],suite_deadline=probe.time.monotonic()+1)
                launch.assert_not_called()

    def test_package_preparation_has_owned_child_total_timeout(self):
        from unittest.mock import Mock, patch
        with patch.object(probe.subprocess,'run',return_value=Mock(returncode=0)) as run:
            probe.prepare_package(Path('/owned/package.zip'),Path('/owned/app'),123,'a'*64,probe.time.monotonic()+70)
            args,kwargs=run.call_args
            self.assertEqual(args[0][0],sys.executable)
            self.assertLessEqual(kwargs['timeout'],45)
            self.assertEqual(args[0][-1],str(Path('/owned/app')))
            self.assertIn('p.download',args[0][2]);self.assertIn('p.extract',args[0][2])
        with patch.object(probe.subprocess,'run') as run:
            with self.assertRaisesRegex(RuntimeError,'operation not started'):
                probe.prepare_package(Path('/unused'),Path('/unused'),0,'',probe.time.monotonic()-1)
            run.assert_not_called()

if __name__=='__main__': unittest.main()
