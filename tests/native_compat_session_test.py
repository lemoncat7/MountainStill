#!/usr/bin/env python3
"""Offline contract tests only; no desktop, helper or game is launched."""
from contextlib import ExitStack
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_compat_session as gui


AUDIO_TRACE = ('ERROR: Condition "hr != ((HRESULT)0x00000000)" is true. Returning: ERR_CANT_OPEN\n'
               '   at: audio_device_init (drivers/wasapi/audio_driver_wasapi.cpp:275)\n'
               'ERROR: WASAPI: init_output_device error.\n'
               '   at: init (drivers/wasapi/audio_driver_wasapi.cpp:600)\n'
               'WARNING: All audio drivers failed, falling back to the dummy driver.\n')


def geometry(pid=123):
    return dict(status='GEOMETRY_READY', owner_pid=pid, window_id=5,
                coordinate_units='physical_pixels' if gui.sys.platform=='win32' else 'points',
                window_width_points=1440, window_height_points=720, window_width=1440, window_height=720)


class FakeClock:
    now = 0.0
    def monotonic(self): return self.now
    def sleep(self, value): self.now += value
    def time(self): return 1800000000 + self.now


class Process:
    pid = 123
    def __init__(self, clock, early=None):
        self.clock, self.early, self.code = clock, early, None
    def poll(self):
        return 0 if self.early is not None and self.clock.now >= self.early else self.code
    def wait(self, timeout):
        if self.poll() is None: raise AssertionError('unexpected live wait')
        return self.poll()


class CompatSessionTests(unittest.TestCase):
    def test_visible_owned_geometry_required(self):
        with patch.object(gui.sys,'platform','darwin'):
            self.assertTrue(gui.visible_geometry(geometry(), 123))
        for changes in ({'owner_pid':124}, {'owner_pid':True}, {'window_id':0},
                        {'window_width_points':float('nan')}, {'window_height_points':0},
                        {'status':'CAPTURE_INCONCLUSIVE'}):
            with patch.object(gui.sys,'platform','darwin'):
                self.assertFalse(gui.visible_geometry(dict(geometry(), **changes),123))

    def test_request_sent_does_not_alone_pass(self):
        sent=dict(status='CLOSE_REQUEST_SENT',owner_pid=123,handler_handled='unknown')
        gui.require_close_request(sent,123)
        for changes in ({'status':'CLOSE_REQUEST_REFUSED'},{'owner_pid':124}):
            with self.assertRaises(RuntimeError):gui.require_close_request(dict(sent,**changes),123)
        for code,wall,close in ((0,29,True),(0,None,True),(1,31,True),(0,31,False)):
            with self.assertRaises(RuntimeError):
                gui.require_gui_terminal(code,wall,30,close,geometry(),geometry(),123)
        with patch.object(gui.sys,'platform','darwin'):
            gui.require_gui_terminal(0,30,30,True,geometry(),geometry(),123)

    def run_mock_session(self, mode='normal', system='darwin', global_deadline=720, expected_version='1.3.26-test.1', machine=None):
        clock=FakeClock()
        process=Process(clock,early=10 if mode=='early' else None)
        calls=[]; rows=[]; registry=[]; forced=[]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); binary=root/'actual-app';binary.touch();(root/'capture').touch();(root/'capture.dll').touch()
            (root/'seed.engine.log').write_text(AUDIO_TRACE if mode=='audio' else 'ready')
            def helper(command, timeout):
                action={'-GeometryOnly':'--geometry-only','-RequestClose':'--request-close'}.get(command[-1],command[-1])
                calls.append((clock.now,action))
                if action=='--geometry-only':
                    return dict(status='CAPTURE_INCONCLUSIVE') if mode=='no-window' else geometry()
                if mode=='refused':return dict(status='CLOSE_REQUEST_REFUSED',owner_pid=123)
                if mode=='late-close':clock.now+=31
                if mode=='late-stage':clock.now+=121
                if mode!='hang':process.code=0
                return dict(status='CLOSE_REQUEST_SENT',owner_pid=123,handler_handled='unknown')
            def stop(child):
                forced.append(child.pid);child.code=-9
            with ExitStack() as stack:
                for target,value in ((gui.sys,system),):
                    stack.enter_context(patch.object(target,'platform',value))
                stack.enter_context(patch.object(gui.platform,'machine',return_value=machine or ('AMD64' if system=='win32' else 'arm64')))
                stack.enter_context(patch.object(gui.time,'monotonic',clock.monotonic))
                stack.enter_context(patch.object(gui.time,'sleep',clock.sleep))
                stack.enter_context(patch.object(gui.time,'time',clock.time))
                popen=stack.enter_context(patch.object(gui.subprocess,'Popen',return_value=process))
                stack.enter_context(patch.object(gui,'native_json',side_effect=helper))
                stack.enter_context(patch.object(gui,'boot_ready',return_value=mode!='no-boot'))
                def metric(pid):
                    return dict(pid=123,identity='changed' if mode=='identity' and clock.now>5 else 'fixed',rss_bytes=1000,
                        cpu_seconds=1,nativefieldtype='test')
                stack.enter_context(patch.object(gui,'sample',side_effect=metric))
                emitted=stack.enter_context(patch.object(gui,'emit'))
                stack.enter_context(patch.object(gui,'stop_failed_process',side_effect=stop))
                stack.enter_context(patch('builtins.print'))
                result=None;error=None
                try:result=gui.session(binary,root,'seed',expected_version,rows,registry,global_deadline)
                except RuntimeError as exc:error=str(exc)
                command=popen.call_args.args[0] if popen.called else []
                self.last_audio_emits=[c for c in emitted.call_args_list if c.args[0]=='AUDIO_ENVIRONMENT_FALLBACK']
        return result,error,calls,forced,rows,registry,command

    def test_full_mock_normal_quit_once_after_duration(self):
        result,error,calls,forced,rows,registry,command=self.run_mock_session()
        self.assertIsNone(error)
        self.assertEqual(result['exit_code'],0)
        self.assertGreaterEqual(result['post_readiness_wall_s'],30)
        close=[when for when,kind in calls if kind=='--request-close']
        self.assertEqual(len(close),1);self.assertGreaterEqual(close[0],30)
        self.assertEqual(forced,[]);self.assertTrue(rows);self.assertEqual(len(registry),1)
        for forbidden in ('--headless','--fixed-fps','--quit-after','--script','--max-fps'):
            self.assertNotIn(forbidden,command)
        self.assertIn('handler UNKNOWN',result['normal_exit'])

    def test_early_exit_cannot_pass_or_request_close(self):
        result,error,calls,forced,*_=self.run_mock_session('early')
        self.assertIsNone(result);self.assertIsNotNone(error)
        self.assertFalse(any(kind=='--request-close' for _,kind in calls));self.assertEqual(forced,[])

    def test_close_refused_is_failure_and_forced_cleanup(self):
        result,error,calls,forced,*_=self.run_mock_session('refused')
        self.assertIsNone(result);self.assertIn('CLOSE_REQUEST_UNCONFIRMED',error)
        self.assertEqual(forced,[123]);self.assertEqual(sum(k=='--request-close' for _,k in calls),1)

    def test_sent_but_hung_is_not_handled_or_pass(self):
        result,error,calls,forced,*_=self.run_mock_session('hang')
        self.assertIsNone(result);self.assertIn('CLOSE_TIMEOUT',error);self.assertEqual(forced,[123])
        self.assertEqual(sum(k=='--request-close' for _,k in calls),1)

    def test_terminal_deadlines_apply_even_if_already_exited(self):
        for mode, reason in (('late-close','CLOSE_TIMEOUT'),('late-stage','TIMEOUT')):
            result,error,calls,forced,*_=self.run_mock_session(mode)
            self.assertIsNone(result);self.assertIn(reason,error)
            self.assertEqual(forced,[])  # Already exited, but missed bound is NOT pass.
            self.assertEqual(sum(k=='--request-close' for _,k in calls),1)

    def test_missing_window_or_boot_blocks_close(self):
        for mode in ('no-window','no-boot'):
            result,error,calls,forced,*_=self.run_mock_session(mode)
            self.assertIsNone(result);self.assertIn('readiness timeout',error);self.assertEqual(forced,[123])
            self.assertFalse(any(kind=='--request-close' for _,kind in calls))

    def test_identity_change_fails_before_close(self):
        result,error,calls,forced,*_=self.run_mock_session('identity')
        self.assertIsNone(result);self.assertIn('IDENTITY_CHANGED',error);self.assertEqual(forced,[123])
        self.assertFalse(any(k=='--request-close' for _,k in calls))

    def test_total_deadline_cannot_start_or_pass(self):
        result,error,calls,forced,rows,registry,command=self.run_mock_session(global_deadline=0)
        self.assertIsNone(result);self.assertIn('GLOBAL_DEADLINE',error);self.assertEqual(registry,[])
        result,error,calls,forced,*_=self.run_mock_session(global_deadline=12)
        self.assertIsNone(result);self.assertIn('DEADLINE',error);self.assertEqual(forced,[123])
        self.assertFalse(any(k=='--request-close' for _,k in calls))
        result,error,calls,forced,*_=self.run_mock_session('late-close',global_deadline=50)
        self.assertIsNone(result);self.assertIn('GLOBAL_DEADLINE',error)

    def test_fixed_version_readiness_and_status_suffix(self):
        resources=''.join('Loading resource: res://assets/cultivation/beasts/'+asset+'\n' for asset in gui.ASSETS)
        for version in gui.ALLOWED_VERSIONS:
            self.assertTrue(gui.boot_ready('UPDATE BOOT: '+version+'\n'+resources,version))
            self.assertTrue(gui.boot_ready('UPDATE BOOT: '+version+' / 更新已生效\n'+resources,version))
            for asset in gui.ASSETS:
                self.assertFalse(gui.boot_ready('UPDATE BOOT: '+version+'\n'+resources.replace(asset,'absent'),version))
        for text in ('UPDATE BOOT: 1.3.25-test.1\n','UPDATE BOOT: 1.3.26-test.10\n',
                     'UPDATE BOOT: 1.3.26-test.1junk\n',
                     'UPDATE BOOT: 1.3.26-test.1\nUPDATE BOOT: 1.3.25-test.1\n'):
            with self.subTest(text=text),self.assertRaises(RuntimeError):
                gui.boot_ready(text+resources,'1.3.26-test.1')
        with self.assertRaises(ValueError):gui.boot_ready(resources,'1.3.21-test.1')

    def test_partial_live_marker_not_misclassified(self):
        self.assertFalse(gui.boot_ready('UPDATE BOOT: 1.3.','1.3.25-test.1'))
        with self.assertRaises(RuntimeError):
            gui.boot_ready('UPDATE BOOT: 1.3.','1.3.25-test.1',terminal=True)

    def test_each_profile_returns_explicit_expected_version(self):
        for version in gui.ALLOWED_VERSIONS:
            result,error,*_=self.run_mock_session(expected_version=version)
            self.assertIsNone(error);self.assertEqual(result['expected_version'],version)

    def test_exact_audio_environment_filter_only_windows(self):
        with patch.object(gui.sys,'platform','win32'):
            filtered,observed=gui.filter_audio_environment(AUDIO_TRACE)
            self.assertTrue(observed);self.assertEqual(gui.unexpected_errors(filtered,'test'),[])
            for text in (AUDIO_TRACE.replace('WARNING: All audio drivers failed, falling back to the dummy driver.',''),
                         AUDIO_TRACE.replace('drivers/wasapi/audio_driver_wasapi.cpp:','other/unrelated.cpp:'),
                         AUDIO_TRACE.replace('   at: init','intervening line\n   at: init'),
                         AUDIO_TRACE+'ERROR: unrelated failure\n',
                         AUDIO_TRACE+'SCRIPT ERROR: invalid access\n',
                         AUDIO_TRACE+'WARNING: ObjectDB instances leaked at exit\n'):
                with self.subTest(text=text):
                    filtered,_=gui.filter_audio_environment(text)
                    self.assertTrue(gui.unexpected_errors(filtered,'test'))
        with patch.object(gui.sys,'platform','darwin'):
            filtered,observed=gui.filter_audio_environment(AUDIO_TRACE)
            self.assertFalse(observed);self.assertTrue(gui.unexpected_errors(filtered,'test'))

    def test_incomplete_init_stream_deferred_until_ready_or_terminal(self):
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/'partial.log';path.write_text(AUDIO_TRACE.splitlines()[0])
            with patch.object(gui.sys,'platform','win32'),patch.object(gui,'boot_ready',return_value=False):
                self.assertFalse(gui._logs_ok(root,[path],'1.3.26-test.1'))
                with self.assertRaises(RuntimeError):gui._logs_ok(root,[path],'1.3.26-test.1',terminal=True)
            path.write_text(AUDIO_TRACE)
            with patch.object(gui.sys,'platform','win32'),patch.object(gui,'boot_ready',return_value=True):
                self.assertTrue(gui._logs_ok(root,[path],'1.3.26-test.1'))

    def test_audio_fallback_reported_once_per_cycle(self):
        result,error,*_=self.run_mock_session('audio',system='win32')
        self.assertIsNone(error);self.assertTrue(result['audio_environment_fallback'])
        self.assertEqual(result['audible_audio'],'NOT_TESTED')
        self.assertEqual(len(self.last_audio_emits),1)

    def test_windows_and_intel_profiles(self):
        for system,machine in (('win32','AMD64'),('darwin','x86_64')):
            for version in gui.ALLOWED_VERSIONS:
                result,error,calls,forced,*_=self.run_mock_session(system=system,machine=machine,expected_version=version)
                self.assertIsNone(error);self.assertEqual(result['expected_version'],version)
                self.assertEqual(result['exit_code'],0);self.assertEqual(forced,[])
                self.assertEqual(sum(kind=='--request-close' for _,kind in calls),1)
        with patch.object(gui.sys,'platform','win32'):
            value=geometry();self.assertTrue(gui.visible_geometry(value,123))
            self.assertFalse(gui.visible_geometry(dict(value,window_width=0),123))
            self.assertFalse(gui.visible_geometry(dict(value,coordinate_units='points'),123))

    def test_audio_exception_does_not_weaken_version(self):
        resources=''.join('Loading resource: res://assets/cultivation/beasts/'+asset+'\n' for asset in gui.ASSETS)
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory);path=root/'engine.log'
            with patch.object(gui.sys,'platform','win32'):
                for version in gui.ALLOWED_VERSIONS:
                    path.write_text(AUDIO_TRACE+'UPDATE BOOT: '+version+'\n'+resources)
                    self.assertTrue(gui._logs_ok(root,[path],version,terminal=True))
                with self.assertRaises(RuntimeError):
                    gui._logs_ok(root,[path],'1.3.25-test.1',terminal=True)

    def test_unsupported_platform(self):
        with patch.object(gui.sys,'platform','linux'),self.assertRaises(RuntimeError):
            gui.session('none',Path('.'),'seed','1.3.26-test.1',[],[],720)


if __name__ == '__main__':unittest.main()
