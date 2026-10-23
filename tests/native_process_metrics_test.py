#!/usr/bin/env python3
"""Pure offline tests: never inspect other processes or depend on native APIs."""
from pathlib import Path
import sys
import unittest
from unittest.mock import patch
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'tools'))
import native_process_metrics as metrics


class NativeMetricsTests(unittest.TestCase):
    def test_cpu_formats(self):
        for text, expected in [('0:00.00', 0), ('01:02.50', 62.5), ('123:45.6', 7425.6),
                               ('1:02:03.25', 3723.25), ('2-03:04:05.5', 183845.5)]:
            with self.subTest(text=text):
                self.assertEqual(metrics.parse_cpu_time(text), expected)

    def test_reject_cpu_corruption(self):
        for text in ('', 'nan', '-1:00', '1:60', '1:60:00', '1-24:00:00',
                     '1-10:00', '1:02.3junk', '1:2', '1:00:60'):
            with self.subTest(text=text), self.assertRaises(ValueError):
                metrics.parse_cpu_time(text)

    def test_macos_units_identity(self):
        row = metrics.parse_macos_ps(' 123 Fri Oct 23 13:01:00 2026 2048 01:02.50\n', 123)
        self.assertEqual(row['rss_bytes'], 2097152)
        self.assertEqual(row['cpu_seconds'], 62.5)
        self.assertEqual(row['identity'], 'macos:123:Fri Oct 23 13:01:00 2026')
        self.assertEqual(metrics.parse_macos_ps('123 Mon Oct  5 01:02:03 2026 1 0:00\n', 123)['rss_bytes'], 1024)

    def test_macos_missing_or_wrong_process(self):
        valid = '123 Fri Oct 23 13:01:00 2026 2048 01:02.50\n'
        for text in ('', valid + valid, valid.replace('123 ', '124 ', 1),
                     valid.replace('2048', '0'), valid.replace('2048', '-1'),
                     valid.replace('Oct 23', 'Oct 99'), valid.replace('Fri', 'Mon'),
                     valid.replace('01:02.50', 'nan')):
            with self.subTest(text=text), self.assertRaises(ValueError):
                metrics.parse_macos_ps(text, 123)

    def test_pid_validation_before_native_access(self):
        for pid in (None, True, 0, -1, 1.5, '123', 2**32):
            with self.subTest(pid=pid), self.assertRaises(ValueError):
                metrics.sample(pid)

    def test_cpu_single_core_percentage(self):
        first = dict(pid=123, identity='fixed', cpu_seconds=2, nativefieldtype='test')
        self.assertEqual(metrics.cpu_percent(first, dict(first, cpu_seconds=5), 2), 150)
        self.assertEqual(metrics.cpu_percent(first, first, 2), 0)

    def test_cpu_identity_and_counter_guards(self):
        first = dict(pid=123, identity='fixed', cpu_seconds=2, nativefieldtype='test')
        for changes in ({'identity': 'reused'}, {'identity': ''}, {'pid': 124},
                        {'nativefieldtype': 'different'}, {'cpu_seconds': 1},
                        {'cpu_seconds': float('nan')}, {'cpu_seconds': float('inf')},
                        {'cpu_seconds': True}):
            with self.subTest(changes=changes), self.assertRaises(ValueError):
                metrics.cpu_percent(first, dict(first, **changes), 1)
        for wall in (0, -1, float('nan'), float('inf'), True, None):
            with self.subTest(wall=wall), self.assertRaises(ValueError):
                metrics.cpu_percent(first, first, wall)
        with self.assertRaises(ValueError):
            metrics.cpu_percent(dict(first, identity=''), first, 1)

    def test_unsupported_platform_is_not_zero(self):
        with patch.object(metrics.sys, 'platform', 'linux'), self.assertRaises(RuntimeError):
            metrics.sample(123)


if __name__ == '__main__':
    unittest.main()
