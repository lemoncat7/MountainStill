"""Offline negative controls for the Linux retained mixed-stability evidence gate."""
import copy
import importlib.util
import json
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location('mixed_driver', Path(__file__).resolve().parents[1] / 'tools/run_retained_mixed_stability.py')
driver = importlib.util.module_from_spec(spec)
spec.loader.exec_module(driver)


class EvidenceGateTests(unittest.TestCase):
    def setUp(self):
        self.engine = [dict(cycle=i, sample_unix_seconds=1000.0 + i * 40,
                            elapsed=i * 40, failures=0) for i in range(1, 4)]
        self.samples = [dict(sample_unix_seconds=x['sample_unix_seconds'] + .2,
                             rss_bytes=400_000_000, elapsed=x['elapsed'] + 9)
                        for x in self.engine]
        self.result = dict(requested=120, measured_elapsed=121, failures=0, cycles=3)
        self.returncode = 0
        self.wall = 165
        self.extra = ''

    def assess(self, results=None):
        if results is None:
            results = [self.result]
        text = '\n'.join('MIXED_SAMPLE ' + json.dumps(x) for x in self.engine)
        text += '\n' + '\n'.join('MIXED_RESULT ' + json.dumps(x) for x in results)
        return driver.assess(text + '\n' + self.extra, self.samples, self.returncode, self.wall, 120)

    def test_positive_and_clock_offset(self):
        result = self.assess()
        self.assertTrue(result['pass'], result)
        self.assertAlmostEqual(result['rss_settled'][0]['alignment_seconds'], .2)

    def test_wrong_duration(self):
        self.result['requested'] = 119
        self.assertFalse(self.assess()['pass'])

    def test_missing_result(self):
        self.assertFalse(self.assess([])['pass'])

    def test_duplicate_result(self):
        self.assertFalse(self.assess([self.result, self.result])['pass'])

    def test_insufficient_measurement(self):
        self.result['measured_elapsed'] = 119.9
        self.assertFalse(self.assess()['pass'])

    def test_insufficient_external_duration(self):
        self.wall = 119
        self.assertFalse(self.assess()['pass'])

    def test_rss_bound_fixed_from_first(self):
        self.samples[1]['rss_bytes'] += driver.RSS_BOUND_BYTES
        self.samples[2]['rss_bytes'] += driver.RSS_BOUND_BYTES + 1
        self.assertFalse(self.assess()['pass'])

    def test_rss_exact_bound_allowed(self):
        self.samples[2]['rss_bytes'] += driver.RSS_BOUND_BYTES
        self.assertTrue(self.assess()['pass'])

    def test_missing_process_samples(self):
        self.samples = []
        self.assertFalse(self.assess()['pass'])

    def test_missing_engine_samples(self):
        self.engine = []
        self.assertFalse(self.assess()['pass'])

    def test_unaligned_samples(self):
        self.samples[1]['sample_unix_seconds'] += 3
        self.assertFalse(self.assess()['pass'])

    def test_error_text(self):
        self.extra = 'ERROR: test failure'
        self.assertFalse(self.assess()['pass'])

    def test_nonzero_exit(self):
        self.returncode = 1
        self.assertFalse(self.assess()['pass'])

    def test_nan_result(self):
        self.result['measured_elapsed'] = float('nan')
        self.assertFalse(self.assess()['pass'])

    def test_nan_process(self):
        self.samples[0]['rss_bytes'] = float('nan')
        self.assertFalse(self.assess()['pass'])

    def test_malformed_marker(self):
        self.extra = 'MIXED_RESULT {bad json'
        self.assertFalse(self.assess()['pass'])

    def test_cycle_count_mismatch(self):
        self.result['cycles'] = 4
        self.assertFalse(self.assess()['pass'])

    def test_failed_sample(self):
        self.engine[0]['failures'] = 1
        self.assertFalse(self.assess()['pass'])

    def test_watchdog(self):
        self.samples.append({'watchdog_timeout': True})
        self.assertFalse(self.assess()['pass'])

    def test_one_sample_cannot_pass(self):
        self.engine = self.engine[:1]
        self.result['cycles'] = 1
        self.assertFalse(self.assess()['pass'])

    def test_import_has_no_cli_side_effects(self):
        self.assertTrue(callable(driver.main))


if __name__ == '__main__':
    unittest.main()
