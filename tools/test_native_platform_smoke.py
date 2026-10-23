#!/usr/bin/env python3
"""Driver output regression; runnable without Godot or a Windows host."""
import io
import json
import contextlib
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
    def test_twelve_tests_preserve_previous_coverage(self):
        self.assertEqual(set(smoke.TESTS), {
            'test_cultivation.gd', 'test_scene_art_layout.gd',
            'test_stone_recovery_contract.gd', 'test_practice_host.gd',
            'test_shutdown_lifecycle.gd', 'update_policy_test.gd',
            'update_store_test.gd', 'test_chapter_practice_navigation.gd',
            'test_practice_control_contribution.gd', 'test_exact_planner_guard.gd',
            'test_provider_lifecycle_guard.gd', 'test_chapter_objective_ui.gd',
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


class ChapterObjectiveMarkerTests(unittest.TestCase):
    def test_objective_marker_requires_positive_checks_and_zero_failures(self):
        test = 'test_chapter_objective_ui.gd'
        good = 'Chapter objective UI: 1844 checks, 0 failures'
        self.assertTrue(smoke.test_passed(0, good, test))
        for bad in ('', good.replace('1844 checks', '0 checks'),
                    good.replace('0 failures', '1 failures'), good + ' EXTRA',
                    good + '\nSCRIPT ERROR: bad objective', good + '\nERROR: bad objective'):
            self.assertFalse(smoke.test_passed(0, bad, test), bad)
        self.assertFalse(smoke.test_passed(1, good, test))


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


class ExactPlannerMarkerTests(unittest.TestCase):
    def test_planner_marker_is_complete_and_fail_closed(self):
        pattern = smoke.TESTS['test_exact_planner_guard.gd']
        good = 'Exact planner guard: 217 checks, 0 failures; neutral early returns=1, exact ties=0'
        self.assertIsNotNone(re.fullmatch(pattern, good))
        for bad in ('', good.replace('217 checks', '0 checks'),
                    good.replace('0 failures', '1 failures'),
                    good.replace('early returns=1', 'early returns=0'),
                    good.replace(', exact ties=0', ''), good + ' EXTRA'):
            self.assertIsNone(re.fullmatch(pattern, bad), bad)
        self.assertTrue(smoke.unexpected_errors('ERROR: planner mismatch',
                                              'test_exact_planner_guard.gd'))


class ProviderLifecycleGateTests(unittest.TestCase):
    def output(self):
        from qa_verify_provider_lifecycle import EXPECTED_CASES
        result = {'schema': 1, 'checks': 62, 'failures': 0, 'cases': EXPECTED_CASES, 'engine': '4.6.3.stable.official'}
        return ''.join('PROVIDER_LIFECYCLE_CASE ' + c + '\n' for c in EXPECTED_CASES) + 'PROVIDER_LIFECYCLE_RESULT ' + json.dumps(result) + '\n'

    def test_structured_contract_not_marker_alone(self):
        test = 'test_provider_lifecycle_guard.gd'
        self.assertTrue(smoke.test_passed(0, self.output(), test))
        for value in [self.output().replace('"checks": 62', '"checks": 0'), self.output().replace('"failures": 0', '"failures": 1'), self.output() + self.output(), 'PROVIDER_LIFECYCLE_RESULT {}\n']:
            self.assertFalse(smoke.test_passed(0, value, test))
        self.assertFalse(smoke.test_passed(1, self.output(), test))

    def test_real_zero_exit_script_error_on_either_stream_is_rejected(self):
        for stream in ['stdout', 'stderr']:
            command = 'import sys;sys.stdout.write(' + repr(self.output()) + ');sys.' + stream + '.write("SCRIPT ERROR: freed provider\\n")'
            with contextlib.redirect_stdout(io.StringIO()):
                code, output = smoke.run([sys.executable, '-c', command], 10)
            self.assertEqual(code, 0)
            self.assertFalse(smoke.test_passed(code, output, 'test_provider_lifecycle_guard.gd'))


if __name__ == '__main__':
    unittest.main()
