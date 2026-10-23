import contextlib
import copy
import importlib.util
import io
import json
from pathlib import Path
import sys
import tempfile
import unittest
from unittest.mock import Mock, patch

spec = importlib.util.spec_from_file_location('bench', Path(__file__).resolve().parents[1] / 'tools/native_cpu_benchmark.py')
b = importlib.util.module_from_spec(spec)
spec.loader.exec_module(b)


def report():
    trial = {'samples': {}, 'early_finish': False, 'total_ms': 2}
    for field in ('advance', 'pose', 'rig', 'tick'):
        values = [3.0 if field == 'tick' else 1.0] * 480
        trial['samples'][field + '_us'] = values
        trial[field] = b.stats(values)
    result = {'engine': {'hash': '7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3'}, 'technique': 'mist', 'hero': {'hp': 420, 'max_hp': 420, 'attack': 11, 'defense': 1}, 'schema': 'mountainstill.cpu.v1', 'ticks': 480, 'seed': 377, 'warmups': 1, 'trials': 3,
            'dt': 1 / 60, 'headless_cpu_only': True,
            'warmup_results': [copy.deepcopy(trial)],
            'results': [copy.deepcopy(trial) for _ in range(3)]}
    for phase, rows in [('warmup', result['warmup_results']), ('measured', result['results'])]:
        for i, row in enumerate(rows): row.update(trial_index=i, phase=phase, seed=377, reset='fresh_duel_process_caches_retained')
    return result


def trace():
    rows = [{'tick': i, 'state_sha256': 'a' * 64, 'event_sha256': 'b' * 64} for i in range(480)]
    return {'engine': {'hash': '7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3'}, 'schema': 'mountainstill.gameplay-trace.v1', 'ticks': 480, 'seed': 377, 'dt': 1 / 60,
            'route': 'cloud_slope', 'weapon': 'fan', 'duel_fields': b.TRACE_FIELDS,
            'trials': [{'trial': i, 'ticks': 480, 'cache_phase': 'cold_process' if i == 0 else 'warm_process', 'trace_sha256': 'c' * 64, 'events_sha256': 'd' * 64, 'tick_hashes': copy.deepcopy(rows)} for i in range(2)]}


class BenchmarkTests(unittest.TestCase):
    def test_historical_optional_source_files(self):
        with tempfile.TemporaryDirectory() as directory:
            project = Path(directory); (project / 'scripts').mkdir()
            (project / 'scripts/duel_timeline.gd').write_text('fixture')
            result = b.expected_source_hashes(project)
            self.assertEqual(set(result), {'duel_timeline'})
            self.assertEqual(result['duel_timeline'], b.hashlib.sha256(b'fixture').hexdigest())

    def test_nearest_rank(self):
        s = b.stats(list(range(480)))
        self.assertEqual((s['p50_us'], s['p95_us'], s['max_us']), (239, 455, 479))
        self.assertEqual(s['total_us'], sum(range(480)))

    def test_all_samples_required(self):
        for values in ([0] * 479, [0] * 481, [float('nan')] * 480,
                       [float('inf')] * 480, [-1] * 480, [True] * 480):
            with self.assertRaises(ValueError): b.stats(values)

    def test_valid_and_corrupt_summary(self):
        b.validate_bench(report())
        r = report(); r['results'][2]['tick']['max_us'] = 0
        with self.assertRaises(ValueError): b.validate_bench(r)
        r = report(); r['warmup_results'] = []
        with self.assertRaises(ValueError): b.validate_bench(r)
        r = report(); r['results'][0]['early_finish'] = True
        with self.assertRaises(ValueError): b.validate_bench(r)

    def test_trace_every_tick_and_cold_warm(self):
        b.compare_traces(trace(), trace())
        r = trace(); r['trials'][1]['tick_hashes'][479]['state_sha256'] = 'c' * 64
        with self.assertRaises(ValueError): b.validate_trace(r)
        r = trace()
        for t in r['trials']: t['tick_hashes'][3]['event_sha256'] = 'c' * 64
        with self.assertRaises(ValueError): b.compare_traces(trace(), r)
        r = trace(); r['trials'][0]['tick_hashes'].pop()
        with self.assertRaises(ValueError): b.validate_trace(r)
        r = trace(); r['schema'] = 'different'
        with self.assertRaises(ValueError): b.compare_traces(trace(), r)

    def test_metadata_and_time_failures(self):
        for mutate in (lambda r: r.update(engine={}), lambda r: r.update(schema='bad'),
                       lambda r: r['results'][0].update(total_ms=float('nan')),
                       lambda r: r['results'][0].update(total_ms=0),
                       lambda r: r['results'][0].update(seed=378)):
            r = report(); mutate(r)
            with self.assertRaises(ValueError): b.validate_bench(r)
        for mutate in (lambda r: r.update(duel_fields=[]),
                       lambda r: r['trials'][0]['tick_hashes'][0].update(tick=1),
                       lambda r: r['trials'][0].update(trial=1)):
            r = trace(); mutate(r)
            with self.assertRaises(ValueError): b.validate_trace(r)

    def test_deadline_and_process_output_budget(self):
        log = b.Log(); log.deadline = 0
        with self.assertRaises(RuntimeError): b.run([sys.executable, '-c', 'pass'], 1, log)
        with contextlib.redirect_stdout(io.StringIO()):
            with self.assertRaises(RuntimeError):
                b.run([sys.executable, '-c', 'import sys;sys.stdout.write("x"*200000)'], 5, b.Log(100000))

    def test_failed_tree_kill_still_reaps_parent(self):
        process = Mock(pid=123)
        with patch.object(b.os, 'name', 'nt'), patch.object(b.subprocess, 'run', side_effect=b.subprocess.TimeoutExpired('taskkill', 10)):
            with self.assertRaises(RuntimeError): b.stop_tree(process)
        process.kill.assert_called_once()
        process.wait.assert_called_once_with(timeout=10)

    def test_late_exit_is_not_accepted(self):
        log = b.Log(); log.deadline = 1000
        process = Mock(); process.poll.return_value = 0
        with patch.object(b.subprocess, 'Popen', return_value=process), patch.object(b.time, 'monotonic', side_effect=[100, 101, 103]):
            with self.assertRaises(RuntimeError): b.run(['fake'], 1, log)

    def test_log_budget_fails_not_truncates(self):
        log = b.Log(100)
        with contextlib.redirect_stdout(io.StringIO()) as sink:
            log.emit('ok')
            with self.assertRaises(RuntimeError): log.emit('x' * 100)
        self.assertEqual(sink.getvalue(), 'ok\n')

    def test_process_errors_unicode_timeout(self):
        with contextlib.redirect_stdout(io.StringIO()):
            output = b.run([sys.executable, '-c', 'import sys;sys.stdout.buffer.write("中文\\n".encode())'], 5, b.Log())
            self.assertIn('中文', output)
            with self.assertRaises(RuntimeError):
                b.run([sys.executable, '-c', 'print("ERROR: bad")'], 5, b.Log())
            with self.assertRaises(RuntimeError):
                b.run([sys.executable, '-c', 'raise SystemExit(7)'], 5, b.Log())
            with self.assertRaises(RuntimeError):
                b.run([sys.executable, '-c', 'import time;time.sleep(5)'], .05, b.Log())


if __name__ == '__main__': unittest.main()
