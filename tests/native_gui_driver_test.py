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
        self.assertEqual(probe.TAG, 'v1.3.26')
        self.assertEqual(len(probe.PACKAGES),2)
        self.assertEqual(probe.PACKAGES['win32'][0], 'MountainStill-v1.3.26-Windows-x86_64.zip')
        self.assertEqual(probe.PACKAGES['win32'][1], '020576fdaeb14b8c901a2c5f28df5a6ba0de35e121ddb1be80e50dfa2b137873')
        self.assertEqual(probe.PACKAGES['win32'][3], 114552389)
        self.assertEqual(probe.PACKAGES['darwin'][0], 'MountainStill-v1.3.26-macOS-Universal.zip')
        self.assertEqual(probe.PACKAGES['darwin'][1], '78a28978026349aee4c806fd553bfa989f2a841b3fa7755b22adebf23811457d')
        self.assertEqual(probe.PACKAGES['darwin'][3], 141283216)
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
        self.assertIn('remaining=43-',source)
        self.assertIn('remaining=45-',source)
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
        process=Process();clock=[0.0]
        def now():clock[0]+=.5;return clock[0]
        with tempfile.TemporaryDirectory() as tmp:
            root=Path(tmp);userdata=root/'userdata';userdata.mkdir()
            (userdata/'.native-package-ci-owner').write_text('ours')
            (userdata/'cultivation_save.json').write_text(json.dumps({'version':4,'lifetime_seconds':20,'settings':{'window_mode':'window','normal_width':960,'normal_height':540}}))
            metadata={'status':'GEOMETRY_READY','work_area':[0,0,1024,728],'backing_scale':1,'client_geometry_source':'GetClientRect+ClientToScreen','client_width':960,'client_height':540,'outer_frame':[12,44,976,579]}
            def launch(*args,**kwargs):
                kwargs['stdout'].write(('UPDATE BOOT: '+probe.TAG[1:]+'\nLoading resource: res://assets/cultivation/beasts/opportunity_cairn.png\n').encode());kwargs['stdout'].flush();return process
            def helper(command,timeout):
                if '--geometry-only' in command:return dict(metadata)
                if '--request-close' in command:process.returncode=0;return {'status':'CLOSE_REQUEST_SENT','handler_handled':'unknown'}
                Path(command[2]).write_bytes(b'\x89PNG\r\n\x1a\n'+b'a'*100)
                return dict(metadata,status='CAPTURE_READY')
            out=io.StringIO();registry=[]
            with patch.object(probe.time,'monotonic',side_effect=now),patch.object(probe.time,'sleep'),patch.object(probe.subprocess,'Popen',side_effect=launch),patch.object(probe,'native_json',side_effect=helper),patch.object(probe.sys,'platform','darwin'),contextlib.redirect_stdout(out):
                result,size=probe.run_session(root/'fake',root,userdata,'ours','window',True,probe.PNG_BUDGET,registry)
            self.assertEqual(size,108);self.assertEqual(result['exit_code'],0);self.assertFalse(result['forced_timeout'])
            self.assertTrue(result['geometry']['pre_capture_and_capture_geometry_stable'])
            self.assertLess(out.getvalue().index('NATIVE_CLOSE_REQUEST'),out.getvalue().index('BEGIN_GUI_PNG'))
            self.assertEqual(registry,[])
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

if __name__=='__main__': unittest.main()
