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
    def test_command_own_window(self):
        c=probe.input_command(Path('/tmp/owned'),42,'Key',33,Key='G')
        self.assertIn('-WindowId',c);self.assertIn('33',c);self.assertIn(str(Path('/tmp/owned')/'input.dll'),c)

class IndependentFailurePaths(unittest.TestCase):
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
        for delivered in (True,False):
            with self.subTest(delivered=delivered),tempfile.TemporaryDirectory() as td,ExitStack() as stack:
                now=[0.0];process=Mock();process.pid=77;process.returncode=None
                process.poll.side_effect=lambda:process.returncode
                def launch(*args,**kwargs):return process
                def native(command,timeout):
                    if command[0]=='close':
                        process.returncode=0;return {'status':'CLOSE_REQUEST_SENT'}
                    if command[0]=='geometry':return {'status':'GEOMETRY_READY'}
                    action=command[command.index('-Action')+1]
                    if action=='Inspect':return {'status':'INSPECT_READY','window_id':88}
                    if action=='Capture':return {'status':'CAPTURE_READY'}
                    return {'status':'INPUT_SENT' if delivered else 'INPUT_UNAVAILABLE'}
                stack.enter_context(patch.object(probe.subprocess,'Popen',side_effect=launch))
                stack.enter_context(patch.object(probe.time,'monotonic',side_effect=lambda:now[0]))
                stack.enter_context(patch.object(probe.time,'sleep',side_effect=lambda n:now.__setitem__(0,now[0]+n)))
                stack.enter_context(patch.object(probe,'native_json',side_effect=native))
                stack.enter_context(patch.object(probe.gui,'geometry_command',return_value=['geometry']))
                stack.enter_context(patch.object(probe.gui,'close_command',return_value=['close']))
                stack.enter_context(patch.object(probe.gui,'log_text',return_value='UPDATE BOOT: 1.3.20-test.1\nLoading resource: res://assets/cultivation/beasts/opportunity_cairn.png'))
                stack.enter_context(patch.object(probe,'emit'))
                stack.enter_context(patch.object(probe.gui,'bounded_log'))
                stack.enter_context(patch.object(probe,'read_save'))
                result,captures=probe.session(Path('/synthetic'),Path(td),Path(td),'review',[],True)
                self.assertEqual(result['close']['status'],'CLOSE_REQUEST_SENT')
                self.assertLess(result['elapsed_seconds'],45)
                if delivered:
                    self.assertIsNone(result['failure']);self.assertEqual(len(captures),2)
                else:
                    self.assertIn('INPUT_ENVIRONMENT_UNAVAILABLE',result['failure']);self.assertEqual(captures,[])
                probe.read_save.assert_not_called()

if __name__=='__main__':unittest.main()
