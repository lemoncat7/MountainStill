#!/usr/bin/env python3
"""Offline driver regression: archive paths, ownership refusal, evidence checks."""
import io
from pathlib import Path
import sys
import tempfile
from types import SimpleNamespace
import unittest
from unittest.mock import patch
import zipfile
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_package_smoke as smoke


class DriverSafety(unittest.TestCase):
    def archive(self, name, mode=0):
        stream = io.BytesIO()
        with zipfile.ZipFile(stream, 'w') as bundle:
            info = zipfile.ZipInfo(name)
            info.external_attr = mode << 16
            bundle.writestr(info, b'x')
        stream.seek(0)
        return zipfile.ZipFile(stream)

    def test_reject_unsafe_names(self):
        for name in ('../evil', '/abs', 'C:/evil', 'a\\b', 'a/../b', './b', 'a//b', 'CON.txt', 'x. /b', 'x./b'):
            # ZipInfo normalizes OS-native separators on Windows at construction
            # and on read. Inject the exact metadata string after construction so
            # this unit test actually exercises the rejected spelling on every OS.
            info = zipfile.ZipInfo('placeholder')
            info.filename = name
            info.file_size = 1
            bundle = SimpleNamespace(infolist=lambda: [info])
            with self.subTest(name=name), self.assertRaises(ValueError):
                smoke.safe_members(bundle)

    def test_windows_separator_normalization_still_rejects_traversal(self):
        # Exercise zipfile's Windows-specific canonicalization even on Linux.
        with patch('zipfile.os.sep', '\\'):
            with self.archive('a\\b') as bundle:
                self.assertEqual(bundle.infolist()[0].filename, 'a/b')
                self.assertEqual(len(smoke.safe_members(bundle)), 1)
            with self.archive('..\\evil') as bundle:
                self.assertEqual(bundle.infolist()[0].filename, '../evil')
                with self.assertRaises(ValueError):
                    smoke.safe_members(bundle)

    def test_reject_symlink(self):
        with self.archive('link', 0o120777) as bundle:
            with self.assertRaises(ValueError):
                smoke.safe_members(bundle)

    def test_accept_unicode_app(self):
        with self.archive(smoke.PACKAGES['darwin'][2], 0o100755) as bundle:
            self.assertEqual(len(smoke.safe_members(bundle)), 1)

    def test_never_adopt_existing_save(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'userdata'
            path.mkdir()
            save = path / 'cultivation_save.json'
            save.write_text('do not touch')
            with self.assertRaises(RuntimeError):
                smoke.claim_userdata(path, 'token')
            self.assertEqual(save.read_text(), 'do not touch')
            with self.assertRaises(RuntimeError):
                smoke.cleanup_userdata(path, 'token')
            self.assertEqual(save.read_text(), 'do not touch')

    def test_own_only_new_directory(self):
        with tempfile.TemporaryDirectory() as root:
            path = Path(root) / 'userdata'
            smoke.claim_userdata(path, 'token')
            with self.assertRaises(RuntimeError):
                smoke.cleanup_userdata(path, 'wrong')
            smoke.cleanup_userdata(path, 'token')
            self.assertFalse(path.exists())

    def test_offline_award_is_not_autosave(self):
        fixture = dict(herbs=123, dew=7, combat_tactic='guarded', lifetime_seconds=10)
        loaded = dict(fixture, lifetime_seconds=100)
        smoke.check_saved_progress(dict(loaded, lifetime_seconds=110), loaded, fixture)
        with self.assertRaises(AssertionError):
            smoke.check_saved_progress(loaded, loaded, fixture)
        with self.assertRaises(AssertionError):
            smoke.check_saved_progress(dict(loaded, lifetime_seconds=110, herbs=3), loaded, fixture)

    def test_boot_requires_resource_loader_and_version(self):
        valid = 'UPDATE BOOT: ' + smoke.VERSION + '\n' + ''.join('Loading resource: ' + asset + '\n' for asset in smoke.ASSETS)
        smoke.check_boot(valid)
        for text in ('', '\n'.join(smoke.ASSETS), valid.replace('Loading resource:', 'archive listing:'), valid + 'ERROR: failed\n', valid.replace(smoke.VERSION, '1.3.14-test.1')):
            with self.subTest(text=text), self.assertRaises(AssertionError):
                smoke.check_boot(text)
        for asset in smoke.ASSETS:
            with self.subTest(missing=asset), self.assertRaises(AssertionError):
                smoke.check_boot(valid.replace('Loading resource: ' + asset + '\n', ''))


if __name__ == '__main__':
    unittest.main()
