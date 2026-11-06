#!/usr/bin/env python3
"""Prebuild omission regressions and preservation of the actual-payload gate."""
import json
import os
from pathlib import Path, PureWindowsPath
import shutil
import subprocess
import sys
import tempfile
import unittest
import zipfile

ROOT = Path(__file__).resolve().parents[1]
sys.path.insert(0, str(ROOT/'tools'))
from verify_export_dependencies import resource_uri, verify_prebuild, verify_payload


class ExportDependencyPrebuildTest(unittest.TestCase):
    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        self.addCleanup(self.tmp.cleanup)
        self.root = Path(self.tmp.name)
        (self.root/'scripts').mkdir()
        (self.root/'scripts/main.gd').write_text('extends Node\n')
        (self.root/'scripts/active_replacement_pages.gd').write_text('extends RefCounted\n')
        self.paths = ['res://scripts/main.gd', 'res://scripts/active_replacement_pages.gd']
        self.write_config([self.paths]*3)

    def write_config(self, lists):
        (self.root/'export_presets.cfg').write_text('\n'.join(
            f'[preset.{i}]\nname="{name}"\nexport_filter="resources"\n'
            f'export_files=PackedStringArray({", ".join(json.dumps(p) for p in entries)})\n'
            for i, (name, entries) in enumerate(zip(['Windows', 'macOS', 'Linux'], lists))))

    def test_all_explicit_platforms(self):
        self.assertEqual(verify_prebuild(self.root), {'scripts': 2, 'presets': ['Windows', 'macOS', 'Linux']})

    def test_windows_resource_path_uses_forward_slashes(self):
        self.assertEqual(resource_uri(PureWindowsPath('scripts/modules/active.gd')),
                         'res://scripts/modules/active.gd')

    def test_missing_new_helper_on_each_platform(self):
        for index, name in enumerate(['Windows', 'macOS', 'Linux']):
            with self.subTest(platform=name):
                lists = [self.paths.copy() for _ in range(3)]; lists[index].remove(self.paths[1])
                self.write_config(lists)
                with self.assertRaisesRegex(AssertionError, name + r'.*active_replacement_pages\.gd'):
                    verify_prebuild(self.root)

    def test_nested_runtime_script_required(self):
        (self.root/'scripts/modules').mkdir()
        (self.root/'scripts/modules/attack.gd').write_text('extends RefCounted\n')
        with self.assertRaisesRegex(AssertionError, r'scripts/modules/attack\.gd'):
            verify_prebuild(self.root)

    def test_missing_or_malformed_list_rejected(self):
        for value in ['', 'not-an-array', 'PackedStringArray(7)', 'PackedStringArray("unterminated)']:
            with self.subTest(value=value):
                (self.root/'export_presets.cfg').write_text('[preset.0]\nexport_filter="resources"\nexport_files=' + value + '\n')
                with self.assertRaisesRegex(AssertionError, 'malformed or missing'):
                    verify_prebuild(self.root)

    def test_no_explicit_preset_rejected(self):
        (self.root/'export_presets.cfg').write_text('[preset.0]\nexport_filter="all_resources"\n')
        with self.assertRaisesRegex(AssertionError, 'No explicit resource presets'):
            verify_prebuild(self.root)

    def test_implicit_mode_does_not_hide_explicit_failure(self):
        self.write_config([self.paths, self.paths[:1]])
        with (self.root/'export_presets.cfg').open('a') as f:
            f.write('\n[preset.9]\nexport_filter="all_resources"\n')
        with self.assertRaisesRegex(AssertionError, 'macOS.*active_replacement_pages'):
            verify_prebuild(self.root)

    def test_current_project_all_three_lists(self):
        result = verify_prebuild(ROOT)
        self.assertEqual(result['scripts'], len(list((ROOT/'scripts').rglob('*.gd'))))
        self.assertEqual(len(result['presets']), 3)

    def test_build_stops_before_godot_or_output_creation(self):
        self.write_config([self.paths[:1], self.paths, self.paths])
        (self.root/'tools').mkdir()
        for name in ['build_updater_release.sh', 'verify_export_dependencies.py']:
            shutil.copyfile(ROOT/'tools'/name, self.root/'tools'/name)
        marker = self.root/'unexpected-godot-call'
        fake = self.root/'fake-godot'
        fake.write_text('#!/bin/sh\ntouch "' + str(marker) + '"\nexit 0\n')
        fake.chmod(0o700)
        result = subprocess.run(['bash', str(self.root/'tools/build_updater_release.sh')],
                                env=dict(os.environ, GODOT_BIN=str(fake), PYTHONDONTWRITEBYTECODE='1'),
                                capture_output=True, text=True, timeout=15)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn('explicit export_files missing res://scripts/active_replacement_pages.gd', result.stderr)
        self.assertFalse(marker.exists(), 'Godot must not run before prebuild coverage passes')
        self.assertFalse((self.root/'builds').exists(), 'No export output should be created before coverage passes')

    def test_actual_payload_gate_retains_missing_and_stale_detection(self):
        for name in ['main.tscn', 'bootstrap.tscn']:
            (self.root/name).write_text('[gd_scene format=3]\n')
        archive = self.root/'export.zip'
        def pack(omit=None, stale=None):
            with zipfile.ZipFile(archive, 'w') as z:
                for path in sorted(self.root.rglob('*')):
                    if path.suffix not in ['.gd', '.tscn'] or path == omit: continue
                    z.writestr(path.relative_to(self.root).as_posix(), b'stale' if path == stale else path.read_bytes())
        helper = self.root/'scripts/active_replacement_pages.gd'
        pack(); self.assertEqual(verify_payload(self.root, archive)['sources'], 4)
        pack(omit=helper)
        with self.assertRaisesRegex(AssertionError, 'runtime source: missing scripts/active_replacement_pages'):
            verify_payload(self.root, archive)
        pack(stale=helper)
        with self.assertRaisesRegex(AssertionError, 'stale/different exported source'):
            verify_payload(self.root, archive)


if __name__ == '__main__':
    unittest.main()
