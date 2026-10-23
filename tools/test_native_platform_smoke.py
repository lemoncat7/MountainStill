#!/usr/bin/env python3
"""Driver output regression; runnable without Godot or a Windows host."""
import io
import re
import sys
import unittest
from unittest.mock import patch

import native_platform_smoke as smoke


class OutputEncodingTests(unittest.TestCase):
    def test_narrow_windows_streams_preserve_utf8_and_error_detection(self):
        stdout_bytes, stderr_bytes = io.BytesIO(), io.BytesIO()
        stdout = io.TextIOWrapper(stdout_bytes, encoding='cp1252', errors='strict', newline='\n')
        stderr = io.TextIOWrapper(stderr_bytes, encoding='cp1252', errors='strict', newline='\n')
        diagnostic = 'ERROR: 山隐测试报错\n'
        payload = repr(diagnostic.encode('utf-8'))
        with patch.object(sys, 'stdout', stdout), patch.object(sys, 'stderr', stderr):
            smoke.configure_output()
            code, captured = smoke.run(
                [sys.executable, '-c', f'import sys; sys.stdout.buffer.write({payload})'], 10)
            print('stderr 中文', file=sys.stderr, flush=True)
        self.assertEqual(code, 0)
        self.assertEqual(captured, diagnostic)
        self.assertEqual(stdout_bytes.getvalue().decode('utf-8'), diagnostic)
        self.assertEqual(stderr_bytes.getvalue().decode('utf-8'), 'stderr 中文\n')
        self.assertEqual(smoke.unexpected_errors(captured, 'test_cultivation.gd'),
                         [diagnostic.strip()])
        stdout.close()
        stderr.close()


class ChapterPracticeMarkerTests(unittest.TestCase):
    def test_nine_tests_preserve_previous_coverage(self):
        self.assertEqual(set(smoke.TESTS), {
            'test_cultivation.gd', 'test_scene_art_layout.gd',
            'test_stone_recovery_contract.gd', 'test_practice_host.gd',
            'test_shutdown_lifecycle.gd', 'update_policy_test.gd',
            'update_store_test.gd', 'test_chapter_practice_navigation.gd',
            'test_practice_control_contribution.gd',
        })

    def test_chapter_marker_requires_positive_checks_and_zero_failures(self):
        pattern = smoke.TESTS['test_chapter_practice_navigation.gd']
        self.assertIsNotNone(re.fullmatch(pattern,
            'Chapter practice navigation: 386 checks, 0 failures'))
        for line in ('', 'Chapter practice navigation: 0 checks, 0 failures',
                     'Chapter practice navigation: 386 checks, 1 failures',
                     'Chapter practice navigation: 386 checks, 0 failures EXTRA'):
            self.assertIsNone(re.fullmatch(pattern, line), line)
        self.assertTrue(smoke.unexpected_errors(
            'ERROR: navigation failed', 'test_chapter_practice_navigation.gd'))


class ControlContributionMarkerTests(unittest.TestCase):
    def test_control_marker_requires_positive_checks_and_zero_failures(self):
        pattern = smoke.TESTS['test_practice_control_contribution.gd']
        self.assertIsNotNone(re.fullmatch(pattern,
            'Practice control contribution: 4973 checks, 0 failures'))
        for line in ('', 'Practice control contribution: 0 checks, 0 failures',
                     'Practice control contribution: 4973 checks, 1 failures',
                     'Practice control contribution: 4973 checks, 0 failures EXTRA'):
            self.assertIsNone(re.fullmatch(pattern, line), line)
        self.assertTrue(smoke.unexpected_errors(
            'ERROR: CONTROL CONTRIBUTION: bad delta',
            'test_practice_control_contribution.gd'))


if __name__ == '__main__':
    unittest.main()
