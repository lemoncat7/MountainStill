#!/usr/bin/env python3
"""Offline contract tests only; no desktop, helper or game is launched."""
from contextlib import ExitStack
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_gui_stability_session as gui


def geometry(pid=123):
    return dict(status='GEOMETRY_READY', owner_pid=pid, window_id=5,
                window_width_points=1440, window_height_points=720)


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


class GuiSessionTests(unittest.TestCase):
    def test_visible_owned_geometry_required(self):
        self.assertTrue(gui.visible_geometry(geometry(), 123))
        for changes in ({'owner_pid':124}, {'owner_pid':True}, {'window_id':0},
                        {'window_width_points':float('nan')}, {'window_height_points':0},
                        {'status':'CAPTURE_INCONCLUSIVE'}):
            self.assertFalse(gui.visible_geometry(dict(geometry(), **changes),123))

    def test_request_sent_does_not_alone_pass(self):
        sent=dict(status='CLOSE_REQUEST_SENT',owner_pid=123,handler_handled='unknown')
        gui.require_close_request(sent,123)
        for changes in ({'status':'CLOSE_REQUEST_REFUSED'},{'owner_pid':124}):
            with self.assertRaises(RuntimeError):gui.require_close_request(dict(sent,**changes),123)
        for code,wall,close in ((0,29,True),(0,None,True),(1,31,True),(0,31,False)):
            with self.assertRaises(RuntimeError):
                gui.require_gui_terminal(code,wall,30,close,geometry(),geometry(),123)
        gui.require_gui_terminal(0,30,30,True,geometry(),geometry(),123)

    def run_mock_session(self, mode='normal'):
        clock=FakeClock()
        process=Process(clock,early=10 if mode=='early' else None)
        calls=[]; rows=[]; registry=[]; forced=[]
        with tempfile.TemporaryDirectory() as directory:
            root=Path(directory); binary=root/'actual-app';binary.touch();(root/'capture').touch()
            (root/'seed.engine.log').write_text('ready')
            def helper(command):
                calls.append((clock.now,command[-1]))
                if command[-1]=='--geometry-only':
                    return dict(status='CAPTURE_INCONCLUSIVE') if mode=='no-window' else geometry()
                if mode=='refused':return dict(status='CLOSE_REQUEST_REFUSED',owner_pid=123)
                if mode=='late-close':clock.now+=31
                if mode=='late-stage':clock.now+=121
                if mode!='hang':process.code=0
                return dict(status='CLOSE_REQUEST_SENT',owner_pid=123,handler_handled='unknown')
            def stop(child):
                forced.append(child.pid);child.code=-9
            with ExitStack() as stack:
                for target,value in ((gui.sys,'darwin'),):
                    stack.enter_context(patch.object(target,'platform',value))
                stack.enter_context(patch.object(gui.platform,'machine',return_value='arm64'))
                stack.enter_context(patch.object(gui.time,'monotonic',clock.monotonic))
                stack.enter_context(patch.object(gui.time,'sleep',clock.sleep))
                stack.enter_context(patch.object(gui.time,'time',clock.time))
                popen=stack.enter_context(patch.object(gui.subprocess,'Popen',return_value=process))
                stack.enter_context(patch.object(gui,'native_json',side_effect=helper))
                stack.enter_context(patch.object(gui,'boot_ready',return_value=mode!='no-boot'))
                stack.enter_context(patch.object(gui,'sample',return_value=dict(pid=123,identity='fixed',rss_bytes=1000,
                    cpu_seconds=1,nativefieldtype='test')))
                stack.enter_context(patch.object(gui,'emit'))
                stack.enter_context(patch.object(gui,'stop_failed_process',side_effect=stop))
                stack.enter_context(patch('builtins.print'))
                result=None;error=None
                try:result=gui.session(binary,root,'seed',30,120,rows,registry)
                except RuntimeError as exc:error=str(exc)
                command=popen.call_args.args[0]
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

    def test_non_arm_macos_is_not_supported(self):
        with patch.object(gui.sys,'platform','linux'),self.assertRaises(RuntimeError):
            gui.session('none',Path('.'),'seed',30,120,[],[])


if __name__ == '__main__':unittest.main()
