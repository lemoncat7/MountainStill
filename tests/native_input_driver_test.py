import ast
import copy
import importlib.util
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock,patch
TOOLS=Path(__file__).resolve().parents[1]/'tools'
sys.path.insert(0,str(TOOLS))
import native_input_probe as probe

class InputContract(unittest.TestCase):
    def test_exact_formal_boot_not_prerelease_or_prefix(self):
        self.assertTrue(probe.pinned_boot_observed('UPDATE BOOT: 1.3.28-test.1\n'))
        self.assertTrue(probe.pinned_boot_observed('UPDATE BOOT: 1.3.28-test.1 / installed\n'))
        for text in ('', 'UPDATE BOOT: 1.3.28-test.1-test.1\n', 'UPDATE BOOT: 1.3.28-test.10\n',
                     'UPDATE BOOT: 1.3.28-test.1junk\n',
                     'UPDATE BOOT: 1.3.28-test.1\nUPDATE BOOT: 1.3.28-test.1-test.1\n'):
            self.assertFalse(probe.pinned_boot_observed(text))

    def setUp(self):
        self.before={'version':4,'settings':{'paused':True},'arrival_seen':False,'activity':'meditate','saved_at':1,'qi':10,'lifetime_seconds':30,'gear':{},'adventure':{'stage_clears':{}}}
        self.after=copy.deepcopy(self.before);self.after.update(arrival_seen=True,activity='gather',saved_at=3)
    def test_valid_assertions(self):self.assertEqual(probe.final_assertions(self.before,self.after),[])
    def test_no_return(self):
        self.after['activity']='meditate';self.assertIn('formal_return_G_not_persisted',probe.final_assertions(self.before,self.after))
    def test_no_arrival(self):
        self.after['arrival_seen']=False;self.assertIn('arrival_seen_not_false_to_true',probe.final_assertions(self.before,self.after))
    def test_no_pause(self):
        self.after['settings']['paused']=False;self.assertIn('formal_pause_not_preserved',probe.final_assertions(self.before,self.after))
    def test_resource_delta_rejected(self):
        self.after['qi']=11;self.assertIn('formal_gameplay_changed_while_paused',probe.final_assertions(self.before,self.after))
    def test_reward_delta_rejected(self):
        self.after['adventure']['stage_clears']['bamboo']=1;self.assertTrue(probe.final_assertions(self.before,self.after))
    def test_guide_assertions_only_arrival_can_change_gameplay(self):
        after=copy.deepcopy(self.before);after.update(arrival_seen=True,saved_at=3)
        self.assertEqual(probe.final_assertions(self.before,after,guide_only=True),[])
        for key,value,expected in [('activity','gather','guide_changed_formal_activity'),('settings',{'paused':True,'width':961},'guide_changed_settings'),('qi',11,'formal_gameplay_changed_while_paused')]:
            with self.subTest(key=key):
                bad=copy.deepcopy(after);bad[key]=value
                self.assertIn(expected,probe.final_assertions(self.before,bad,guide_only=True))

    def test_guide_rejects_wrong_platform_arch_or_conflicting_mode_before_launch(self):
        for native_platform,arch,args in [('win32','arm64',['--macos-guide-click']),('darwin','x86_64',['--macos-guide-click']),('darwin','arm64',['--macos-guide-click','--macos-input'])]:
            with self.subTest(platform=native_platform,arch=arch),patch.object(probe.sys,'platform',native_platform),patch.object(probe.platform,'machine',return_value=arch),patch.object(probe.sys,'argv',['probe',*args]),patch.object(probe.gui,'configure_output'),patch.object(probe,'emit') as emit,patch.object(probe.subprocess,'Popen') as launch:
                self.assertEqual(probe.main(),1)
                launch.assert_not_called()
                self.assertIn('GUIDE_DIAGNOSTIC_REQUIRES_MAC_ARM_ONLY',emit.call_args.args[1]['error'])

    def test_projection_not_mutated(self):
        p=probe.formal_projection(self.before);p['gear']['x']=2;self.assertEqual(self.before['gear'],{})
    def test_no_live_read(self):
        process=Mock();process.poll.return_value=None
        with patch.object(probe,'read_save') as reader:
            with self.assertRaisesRegex(RuntimeError,'LIVE_PROCESS'):probe.offline_save(Path('/not/read'),'token',[process])
            reader.assert_not_called()
    def test_owned_offline_read(self):
        with tempfile.TemporaryDirectory() as td:
            d=Path(td);(d/'.native-package-ci-owner').write_text('t');p=Mock();p.poll.return_value=0
            with patch.object(probe,'read_save',return_value=self.before) as read:self.assertEqual(probe.offline_save(d,'t',[p]),self.before)
    def test_session_never_reads_save(self):
        import inspect
        s=inspect.getsource(probe.session)
        for prohibited in ['read_save','offline_save','cultivation_save','owned_save_snapshot']:self.assertNotIn(prohibited,s)
    def test_paired_sequence_and_deadlines(self):
        import inspect
        s=inspect.getsource(probe.session)
        self.assertEqual(s.count("event('Key',Key='Space')"),1)
        self.assertLess(s.index("Key='Esc'"),s.index("Key='G'"))
        self.assertEqual(probe.HARD_STOP,55);self.assertEqual(probe.CLOSE_AT,43)
    def test_only_new_workflow_fixed_runners(self):
        text=(TOOLS.parent/'.github/workflows/native-input-probe.yml').read_text()
        self.assertIn('permissions: {}',text);self.assertIn('timeout-minutes: 5',text)
        for prohibited in ['uses:','secrets.','pull_request_target','sudo','self-hosted']:self.assertNotIn(prohibited,text)
    def test_no_injected_engine_script(self):
        import inspect
        self.assertNotIn('--script',inspect.getsource(probe));self.assertEqual(probe.gui.ARGS,['--verbose','--max-fps','60'])
    def test_explicit_windows_path_argument_not_posix_literal(self):
        from pathlib import PureWindowsPath
        root=PureWindowsPath('C:/job/mountainstill-input-test')
        command=probe.input_command(root,42,'Click',33,ClientX=20,ClientY=30)
        argument=command[command.index('-NativeAssembly')+1]
        self.assertEqual(argument,str(root/'input.dll'))
        self.assertNotEqual(argument,'C:/job/mountainstill-input-test/input.dll')
        self.assertEqual(command[command.index('-TargetPid')+1],'42')
        self.assertEqual(command[command.index('-WindowId')+1],'33')
        self.assertEqual(command[command.index('-ClientX')+1],'20')
    def test_original_pixel_crop_payload_budget(self):
        import inspect
        rois=[(202,20,700,140),(16,10,700,72),(300,300,400,240)]
        raw=sum(w*h*4+h for x,y,w,h in rois)
        self.assertEqual(raw,978052)
        self.assertLess(raw+3*8192,probe.gui.PNG_BUDGET)
        for x,y,w,h in rois:
            self.assertLessEqual(x+w,960);self.assertLessEqual(y+h,540)
            self.assertIn(str((x,y,w,h)).replace(' ',''),inspect.getsource(probe.session))
        self.assertIn("len(captures)!=(1 if guide_only else 3)",inspect.getsource(probe.main))
    def test_command_own_window(self):
        c=probe.input_command(Path('/tmp/owned'),42,'Key',33,Key='G')
        self.assertIn('-WindowId',c);self.assertIn('33',c);self.assertIn(str(Path('/tmp/owned')/'input.dll'),c)

class IndependentFailurePaths(unittest.TestCase):
    def test_mac_target_identity_rejects_drift_and_missing_geometry(self):
        reference={'owner_pid':77,'window_id':88,'outer_frame':[12,44,960,568],
                   'client_frame':[12,72,960,540],'client_to_screen':[12,72],
                   'backing_scale':1,'foreground_owned':True}
        self.assertTrue(probe.same_input_target(reference,copy.deepcopy(reference),77))
        mutations={'owner_pid':78,'window_id':89,'outer_frame':[12,44,960,570],
                   'client_frame':[12,74,960,540],'client_to_screen':[12,74],
                   'backing_scale':2,'foreground_owned':False}
        for key,value in mutations.items():
            with self.subTest(key=key):
                changed=copy.deepcopy(reference);changed[key]=value
                self.assertFalse(probe.same_input_target(reference,changed,77))
        for key in ('outer_frame','client_frame','client_to_screen'):
            bad=copy.deepcopy(reference);bad[key][0]=float('inf')
            self.assertFalse(probe.same_input_target(bad,bad,77))
            del bad[key]
            self.assertFalse(probe.same_input_target(bad,bad,77))
        missing_scale=copy.deepcopy(reference);del missing_scale['backing_scale']
        self.assertFalse(probe.same_input_target(missing_scale,missing_scale,77))
        for value in (True,2,float('nan')):
            invalid_scale=copy.deepcopy(reference);invalid_scale['backing_scale']=value
            self.assertFalse(probe.same_input_target(invalid_scale,invalid_scale,77))
        wrong_origin=copy.deepcopy(reference);wrong_origin['client_to_screen']=[12,75]
        self.assertFalse(probe.same_input_target(wrong_origin,wrong_origin,77))

    def test_mac_command_binds_pid_window_saved_geometry_without_windows_fallback(self):
        root=Path('/tmp/mountainstill-input-owned')
        command=probe.input_command(root,42,'Click',33,macos=True,ClientX=268,ClientY=514)
        self.assertEqual(command[0],str(root/'input'))
        for key,value in [('-TargetPid','42'),('-WindowId','33'),('-ClientWidth','960'),('-ClientHeight','540'),('-ClientX','268'),('-ClientY','514')]:
            self.assertEqual(command[command.index(key)+1],value)
        self.assertNotIn('powershell',command);self.assertNotIn('-NativeAssembly',command)

    def test_mac_event_workflow_is_explicit_and_has_no_windows_runner(self):
        import inspect
        workflow=(TOOLS.parent/'.github/workflows/native-macos-input-probe.yml').read_text()
        self.assertIn('runner: [macos-15]',workflow)
        self.assertIn('native_input_probe.py --macos-guide-click',workflow)
        self.assertNotIn('macos-15-intel',workflow)
        self.assertNotIn('windows-2025',workflow)
        self.assertIn('permissions: {}',workflow)
        self.assertIn("sys.platform=='darwin' and '--macos-input' not in sys.argv",inspect.getsource(probe.main))

    def test_swift_session_route_source_contract_guards_each_post(self):
        # Source-only contract: Linux cannot execute AppKit hit-testing or compile this helper.
        swift=(TOOLS/'native_input_helper.swift').read_text()
        guard=swift.split('static func sessionHitGuard(',1)[1].split('static func guideClickSession(',1)[0]
        for condition in ['try validate(target)','NSScreen.screens.count == 1','screen.backingScaleFactor == 1','target.client.contains(point)','belowWindowWithWindowNumber:0','hit == Int(target.id)','matches.count == 1','== target.pid']:
            self.assertIn(condition,guard)
        self.assertLess(guard.index('try validate(target)'),guard.index('NSWindow.windowNumber'))
        self.assertLess(guard.index('try appKitHitPoint('),guard.index('NSWindow.windowNumber'))
        self.assertIn('target.display.frame == CGRect(origin:.zero,size:screen.frame.size)',guard)
        mapping=swift.split('static func appKitHitPoint(',1)[1].split('static func coordinateSelfTests()',1)[0]
        for condition in ['cgBounds.origin == .zero','appKitBounds.origin == .zero','cgBounds.size == appKitBounds.size','$0.isFinite','cgPoint.x < cgBounds.width','cgPoint.y < cgBounds.height']:
            self.assertIn(condition,mapping)
        self.assertIn('try coordinateSelfTests()',swift)
        self.assertIn('"coordinate_selftests_negative":9',swift)

        route=swift.split('static func guideClickSession(',1)[1].split('static func main()',1)[0]
        self.assertIn('number(args,"ClientX") == 268',route)
        self.assertIn('number(args,"ClientY") == 514',route)
        self.assertIn('for event in [move,down,up]',route)
        self.assertLess(route.index('try sessionHitGuard('),route.index('event.post(tap:.cgSessionEventTap)'))
        self.assertEqual(route.count('.post('),1)
        self.assertNotIn('postToPid',route)
        self.assertNotIn('keyboardEventSource',route)
        self.assertNotIn('try?',route)
        self.assertIn('(action == "GuideClickSession" && sessionPosted == 2)',swift)
        for forbidden in ['CGRequestPostEventAccess','CGRequestScreenCaptureAccess','AXIsProcessTrustedWithOptions','mouseEventWindowUnderMousePointer']:
            self.assertNotIn(forbidden,swift)

    def test_local_helper_success_returns_object(self):
        process=Mock();process.poll.return_value=0;process.returncode=0
        def launch(command,stdout,stderr):
            stdout.write(b'{"status":"INPUT_SENT"}');stdout.flush();return process
        with patch.object(probe.subprocess,'Popen',side_effect=launch),patch.object(probe.time,'monotonic',return_value=0):
            self.assertEqual(probe.native_json(['synthetic'],2),{'status':'INPUT_SENT'})
        process.kill.assert_not_called()

    def test_helper_timeout_has_short_owned_cleanup(self):
        process=Mock();process.pid=77;process.poll.return_value=None
        with patch.object(probe.subprocess,'Popen',return_value=process),patch.object(probe.sys,'platform','win32'),patch.object(probe.time,'monotonic',side_effect=[0,2]),patch.object(probe.subprocess,'run',side_effect=probe.subprocess.TimeoutExpired('taskkill',1.5)) as kill:
            with self.assertRaisesRegex(RuntimeError,'HELPER_TIMEOUT'):probe.native_json(['synthetic'],1)
        self.assertEqual(kill.call_args.kwargs['timeout'],1.5)
        self.assertEqual(kill.call_args.args[0],['taskkill','/PID','77','/T','/F'])
        process.kill.assert_called_once();process.wait.assert_called_once_with(timeout=.5)

    def test_session_success_and_unconfirmed_event_both_close(self):
        from contextlib import ExitStack
        for native_platform,delivered,guide_only in [('win32',True,False),('win32',False,False),('darwin',True,False),('darwin',False,False),('darwin',True,True),('darwin',False,True),('darwin','badroute',True),('darwin','badhit',True)]:
            with self.subTest(platform=native_platform,delivered=delivered,guide_only=guide_only),tempfile.TemporaryDirectory() as td,ExitStack() as stack:
                transport=Mock();transport.__enter__=Mock(return_value=12345);transport.slave_fd=12345
                stack.enter_context(patch.object(probe,'OwnedPTYLog',return_value=transport))
                stack.enter_context(patch.object(probe.sys,'platform',native_platform))
                now=[0.0];process=Mock();process.pid=77;process.returncode=None
                process.poll.side_effect=lambda:process.returncode
                def launch(*args,**kwargs):
                    if native_platform=='darwin':
                        self.assertEqual(kwargs['stdout'],12345)
                        self.assertEqual(kwargs['stderr'],probe.subprocess.STDOUT)
                        self.assertEqual(kwargs['stdin'],probe.subprocess.DEVNULL)
                    return process
                metadata={'owner_pid':77,'window_id':88,'outer_frame':[12,44,960,568],
                          'client_frame':[12,72,960,540],'client_to_screen':[12,72],
                          'backing_scale':1,'foreground_owned':True}
                actions=[]
                def native(command,timeout):
                    if command[0]=='close':
                        process.returncode=0;return {'status':'CLOSE_REQUEST_SENT'}
                    if command[0]=='geometry':return {'status':'GEOMETRY_READY'}
                    action=command[command.index('-Action')+1]
                    actions.append(action)
                    if guide_only and action=='GuideClickSession':
                        self.assertEqual(command[command.index('-ClientX')+1],'268')
                        self.assertEqual(command[command.index('-ClientY')+1],'514')
                    if action=='Inspect':return dict(metadata,status='INSPECT_READY')
                    if action=='Capture':return dict(metadata,status='CAPTURE_READY')
                    result=dict(metadata,status='INPUT_SENT' if delivered else 'INPUT_UNAVAILABLE')
                    if action=='GuideClickSession':
                        result.update(action=action,route='cgSessionEventTap',posted_events=3,hit_window_id=88,hit_owner_pid=77)
                        if delivered=='badroute':del result['route']
                        if delivered=='badhit':del result['hit_owner_pid']
                    return result
                stack.enter_context(patch.object(probe.subprocess,'Popen',side_effect=launch))
                stack.enter_context(patch.object(probe.time,'monotonic',side_effect=lambda:now[0]))
                stack.enter_context(patch.object(probe.time,'sleep',side_effect=lambda n:now.__setitem__(0,now[0]+n)))
                stack.enter_context(patch.object(probe,'native_json',side_effect=native))
                stack.enter_context(patch.object(probe.gui,'geometry_command',return_value=['geometry']))
                stack.enter_context(patch.object(probe.gui,'close_command',return_value=['close']))
                stack.enter_context(patch.object(probe.gui,'log_text',return_value='UPDATE BOOT: 1.3.28-test.1\nLoading resource: res://assets/cultivation/beasts/opportunity_cairn.png'))
                stack.enter_context(patch.object(probe,'emit'))
                stack.enter_context(patch.object(probe.gui,'bounded_log'))
                stack.enter_context(patch.object(probe,'read_save'))
                result,captures=probe.session(Path('/synthetic'),Path(td),Path(td),'review',[],True,guide_only=guide_only)
                self.assertEqual(result['close']['status'],'CLOSE_REQUEST_SENT')
                self.assertLess(result['elapsed_seconds'],45)
                if delivered is True:
                    self.assertIsNone(result['failure']);self.assertEqual(len(captures),1 if guide_only else 3)
                else:
                    self.assertIn('INPUT_ENVIRONMENT_UNAVAILABLE',result['failure']);self.assertEqual(captures,[])
                if guide_only:
                    self.assertEqual(actions,['Inspect','GuideClickSession','Capture'] if delivered is True else ['Inspect','GuideClickSession'])
                probe.read_save.assert_not_called()
                if native_platform=='darwin':
                    transport.__enter__.assert_called_once()
                    transport.started.assert_called_once()
                    transport.close.assert_called_once()
                    self.assertGreater(transport.check.call_count,0)
                else:
                    probe.OwnedPTYLog.assert_not_called()


    def test_mac_popen_failure_closes_transport_without_starting_worker(self):
        transport=Mock();transport.__enter__=Mock(return_value=12345);transport.slave_fd=12345
        with tempfile.TemporaryDirectory() as td,patch.object(probe.sys,'platform','darwin'),patch.object(probe,'OwnedPTYLog',return_value=transport),patch.object(probe.subprocess,'Popen',side_effect=OSError('synthetic launch failure')),patch.object(probe.gui,'log_text',return_value=''),patch.object(probe,'emit'),patch.object(probe.gui,'bounded_log'):
            result,captures=probe.session(Path('/synthetic'),Path(td),Path(td),'failure',[])
        self.assertIn('synthetic launch failure',result['failure'])
        transport.started.assert_not_called()
        transport.close.assert_called_once()
        transport.check.assert_called_once()
        self.assertEqual(captures,[])

    def test_mac_shutdown_exception_still_closes_transport(self):
        transport=Mock();transport.__enter__=Mock(return_value=12345);transport.slave_fd=12345
        transport.started.side_effect=RuntimeError('synthetic worker failure')
        process=Mock();process.pid=77;process.poll.return_value=None
        process.wait.side_effect=probe.subprocess.TimeoutExpired('owned child',55)
        with tempfile.TemporaryDirectory() as td,patch.object(probe.sys,'platform','darwin'),patch.object(probe,'OwnedPTYLog',return_value=transport),patch.object(probe.subprocess,'Popen',return_value=process),patch.object(probe,'native_json',return_value={'status':'CLOSE_REQUEST_SENT'}),patch.object(probe.gui,'close_command',return_value=['close']),patch.object(probe.gui,'stop_owned',side_effect=OSError('synthetic stop failure')):
            with self.assertRaisesRegex(OSError,'synthetic stop failure'):
                probe.session(Path('/synthetic'),Path(td),Path(td),'failure',[])
        transport.close.assert_called_once()
        transport.check.assert_called_once()

if __name__=='__main__':unittest.main()
