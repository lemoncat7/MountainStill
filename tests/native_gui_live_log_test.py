"""GUI evidence transport tests; portable subprocesses are not native GUI acceptance."""
import contextlib
import io
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import time
import unittest
from unittest.mock import patch

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_gui_probe as probe
from native_input_pty import OwnedPTYLog


def diagnostic(**changes):
    return 'DESKTOP DISPLAY: '+json.dumps(dict(schema=1, window_attached=True,
        native_window_ready=True, rendering_driver='opengl3', adapter_name='Intel HD Graphics',
        adapter_vendor='Intel', adapter_api='4.1 INTEL-20.0', **changes))


class BackendEvidence(unittest.TestCase):
    def test_observed_mac_adapters_do_not_conflate_driver_api_and_hardware(self):
        samples=[('4.1 APPLE-21.1.1', 'Apple Software Renderer', 'Apple Inc.', True),
                 ('OpenGL ES 3.0 (ANGLE 2.1.1 git hash: aaebda1c5a40)',
                  'ANGLE (Apple, ANGLE Metal Renderer: Apple Paravirtual device, Version 15.7.9 (Build 24G830))',
                  'Google Inc. (Apple)', False)]
        for api,name,vendor,native in samples:
            item=json.loads(diagnostic().split(': ',1)[1])
            item.update(adapter_api=api,adapter_name=name,adapter_vendor=vendor)
            with patch.object(probe.sys,'platform','darwin'):
                evidence=probe.renderer_evidence('DESKTOP DISPLAY: '+json.dumps(item),'project_default')
            self.assertEqual(evidence['native_opengl_verified'],native)
            self.assertEqual(evidence['actual_driver'],'opengl3')
            self.assertEqual(evidence['selection'],'REQUEST_MATCH')
            self.assertEqual(evidence['diagnostic']['adapter_name'],name)

    def test_native_requires_adapter_and_desktop_api_not_driver_id(self):
        for platform in ('darwin', 'win32'):
            with self.subTest(platform=platform), patch.object(probe.sys, 'platform', platform):
                self.assertTrue(probe.renderer_evidence(diagnostic(), 'opengl3')['native_opengl_verified'])
                for field, value in [('adapter_name', ''), ('adapter_vendor', None), ('adapter_api', ''),
                                     ('adapter_api', 'unknown'), ('adapter_api', 'OpenGL ES 3.0'),
                                     ('adapter_name', 'ANGLE (Apple, ANGLE Metal Renderer: Apple M1, Unspecified Version)'),
                                     ('adapter_api', '4.1 Metal'), ('rendering_driver', 'opengl3_angle')]:
                    item=json.loads(diagnostic().split(': ', 1)[1]);item[field]=value
                    evidence=probe.renderer_evidence('DESKTOP DISPLAY: '+json.dumps(item), 'opengl3')
                    self.assertFalse(evidence['native_opengl_verified'], (field,value))
                    self.assertEqual(evidence['actual_driver'],item['rendering_driver'])
                    self.assertEqual(evidence['diagnostic'],item)
                    self.assertFalse(evidence['pixel_transparency_verified'])


@unittest.skipUnless(hasattr(os, 'openpty'), 'POSIX PTY required')
class LiveTransport(unittest.TestCase):
    def session(self, platform='darwin', code=None, pty_factory=OwnedPTYLog, fail_helper=False):
        # Accelerate the unchanged 55s session timing, not the child's IO. A child
        # waits for our close helper, so a live result cannot be an exit flush.
        real_popen=subprocess.Popen;real_sleep=time.sleep;clock=[0.0];children=[];logs=[]
        registry=[];self.output=io.StringIO()
        def sleep(seconds):
            clock[0]+=seconds*10
            real_sleep(.01)
        def launch(command, **kwargs):
            if platform=='win32':self.assertFalse(isinstance(kwargs['stdout'],int));self.assertNotIn('stdin',kwargs)
            else:self.assertIsInstance(kwargs['stdout'],int);self.assertEqual(kwargs['stdin'],subprocess.DEVNULL)
            child=real_popen([sys.executable, '-c', code or "import time; print("+repr(diagnostic())+"); time.sleep(20)"], **kwargs)
            children.append(child);return child
        def capture_log(path):
            log=pty_factory(path);logs.append(log)
            original_close=log.close
            def close():
                for child in children:self.assertIsNotNone(child.poll(), 'PTY closed before child stopped')
                original_close()
            log.close=close
            return log
        def helper(command, timeout):
            if fail_helper:raise KeyboardInterrupt('test exceptional teardown')
            if '--request-close' in command or '-RequestClose' in command:
                children[0].terminate();children[0].wait(timeout=2)
                return {'status':'CLOSE_REQUEST_SENT'}
            return {}
        try:
            with tempfile.TemporaryDirectory() as tmp:
                root=Path(tmp)
                with patch.object(probe.sys,'platform',platform), patch.object(probe.subprocess,'Popen',side_effect=launch), \
                     patch.object(probe,'OwnedPTYLog',side_effect=capture_log), patch.object(probe,'native_json',side_effect=helper), \
                     patch.object(probe,'owned_save_snapshot',return_value={'status':'not_created_yet'}), \
                     patch.object(probe.time,'monotonic',side_effect=lambda:clock[0]), patch.object(probe.time,'sleep',side_effect=sleep), \
                     contextlib.redirect_stdout(self.output):
                    return probe.run_session(root/'fake',root,root/'userdata','token','seed',False,0,registry)
        finally:
            for child in children:
                self.assertIsNotNone(child.poll(), 'child must be stopped before returning')
            self.assertEqual(registry,[])
            for log in logs:
                self.assertIsNone(log.master_fd);self.assertIsNone(log.slave_fd)

    def test_unflushed_diagnostic_is_initial_live_evidence(self):
        result,_=self.session()
        self.assertTrue(result['initial_renderer']['diagnostic']['native_window_ready'])
        self.assertTrue(result['initial_renderer']['native_opengl_verified'])

    def test_windows_keeps_file_and_does_not_invent_live_diagnostic(self):
        result,_=self.session(platform='win32')
        self.assertIsNone(result['initial_renderer']['diagnostic'])

    def test_early_exit_diagnostic_not_promoted_to_initial(self):
        result,_=self.session(code='print('+repr(diagnostic())+')')
        self.assertIsNone(result['initial_renderer']['diagnostic'])
        self.assertTrue(result['renderer']['diagnostic']['native_window_ready'])

    def test_exception_stops_child_before_pty_close(self):
        with self.assertRaisesRegex(KeyboardInterrupt,'exceptional teardown'):
            self.session(fail_helper=True)

    def test_overflow_rejects_prefix_and_stops_child(self):
        with self.assertRaisesRegex(RuntimeError,'overflow'):
            self.session(code="import os,time; os.write(1,b'x'*10000); time.sleep(20)",
                         pty_factory=lambda path:OwnedPTYLog(path,budget=100))
        self.assertNotIn('INITIAL_RENDERER_EVIDENCE',self.output.getvalue())

    def test_capture_error_rejects_prefix_and_stops_child(self):
        class FailedLog(OwnedPTYLog):
            def _store(self,chunk):
                super()._store(chunk)
                self._record_error('injected capture failure')
        with self.assertRaisesRegex(RuntimeError,'injected capture failure'):
            self.session(pty_factory=FailedLog)
        self.assertNotIn('INITIAL_RENDERER_EVIDENCE',self.output.getvalue())

    def test_real_thread_start_failure_stops_child_before_error_close(self):
        with patch('native_input_pty.threading.Thread.start',side_effect=RuntimeError('real thread start failure')):
            with self.assertRaisesRegex(RuntimeError,'real thread start failure'):
                self.session()

    def test_started_failure_stops_child_before_context_exit(self):
        class FailedStart(OwnedPTYLog):
            def started(self, **kwargs):raise RuntimeError('injected started failure')
        with self.assertRaisesRegex(RuntimeError,'injected started failure'):
            self.session(pty_factory=FailedStart)


if __name__=='__main__':unittest.main()
