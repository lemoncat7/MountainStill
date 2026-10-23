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
        self.assertEqual(probe.ARGS, ['--verbose','--max-fps','60','--quit-after','600'])
    def test_pin(self):
        self.assertEqual(probe.TAG, 'v1.3.17-test.1')
        self.assertEqual(len(probe.PACKAGES),2)
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
