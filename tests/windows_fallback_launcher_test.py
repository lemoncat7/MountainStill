#!/usr/bin/env python3
"""Offline one-shot launcher contract; not Windows process execution."""
from pathlib import Path
import unittest, zipfile, os, tempfile
ROOT = Path(__file__).resolve().parents[1]
EXPECTED = b'@echo off\r\nrem Exit any running MountainStill first. This requests OpenGL for this launch only.\r\nstart "" "%~dp0MountainStill.exe" --rendering-driver opengl3\r\n'
class LauncherTest(unittest.TestCase):
    def test_exact_local_only_launcher(self):
        self.assertEqual((ROOT/'tools/Start-OpenGL.cmd').read_bytes(), EXPECTED)
    def test_packager_uses_reviewed_launcher(self):
        self.assertIn("z.write(ROOT/'tools/Start-OpenGL.cmd','MountainStill/Start-OpenGL.cmd')", (ROOT/'tools/package_updater_delivery.py').read_text())
    def test_source_retains_launcher_and_regression(self):
        source = (ROOT/'tools/package_source.py').read_text()
        self.assertIn('"tools/Start-OpenGL.cmd"', source)
        self.assertIn('"tests/windows_fallback_launcher_test.py"', source)
    @unittest.skipUnless(os.environ.get('MOUNTAINSTILL_WINDOWS_ZIP'), 'requires actual candidate ZIP')
    def test_actual_zip_local_target(self):
        with zipfile.ZipFile(os.environ['MOUNTAINSTILL_WINDOWS_ZIP']) as archive:
            self.assertIsNone(archive.testzip())
            self.assertEqual(archive.read('MountainStill/Start-OpenGL.cmd'), EXPECTED)
            self.assertEqual(archive.read('MountainStill/MountainStill.exe')[:2], b'MZ')
            with tempfile.TemporaryDirectory(prefix='Mountain Still path with spaces ') as folder:
                archive.extract('MountainStill/Start-OpenGL.cmd', folder)
                archive.extract('MountainStill/MountainStill.exe', folder)
                script = Path(folder)/'MountainStill/Start-OpenGL.cmd'
                # %~dp0 is cmd.exe's script directory; both operands are quoted.
                self.assertTrue((script.parent/'MountainStill.exe').is_file())
                self.assertIn('"%~dp0MountainStill.exe" --rendering-driver opengl3', script.read_text())
if __name__ == '__main__': unittest.main()
