#!/usr/bin/env python3
"""External monotonic watchdog/RSS witness for source headless same-host test."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import subprocess
import sys
import time

RSS_BOUND_BYTES = 128 * 1024 * 1024
MAX_ALIGNMENT_SECONDS = 2.0
SAMPLE_INTERVAL_SECONDS = 1.0


def finite_number(value):
    return isinstance(value, (int, float)) and not isinstance(value, bool) and math.isfinite(value)


def all_finite(value):
    if isinstance(value, float):
        return math.isfinite(value)
    if isinstance(value, dict):
        return all(all_finite(v) for v in value.values())
    if isinstance(value, list):
        return all(all_finite(v) for v in value)
    return True


def assess(text, process_samples, returncode, wall_seconds, duration):
    """Fail closed; the RSS clock is shared Unix time, duration uses monotonic time."""
    errors = [line for line in text.splitlines() if any(token in line for token in
              ('SCRIPT ERROR:', 'ERROR:', 'MIXED_FAIL', 'WARNING: ObjectDB instances leaked'))]
    reasons = []
    def markers(prefix):
        values = []
        for line in text.splitlines():
            if line.startswith(prefix):
                try:
                    value = json.loads(line[len(prefix):])
                    if not isinstance(value, dict) or not all_finite(value):
                        raise ValueError('non-object or nonfinite marker')
                    values.append(value)
                except (ValueError, TypeError):
                    reasons.append('Malformed ' + prefix.strip())
        return values
    engine_samples = markers('MIXED_SAMPLE ')
    results = markers('MIXED_RESULT ')
    if not finite_number(duration) or duration <= 0:
        reasons.append('Invalid requested duration')
    if not finite_number(wall_seconds) or wall_seconds < duration:
        reasons.append('Insufficient external monotonic duration')
    if returncode != 0:
        reasons.append('Nonzero process exit')
    if errors:
        reasons.append('Unexpected engine errors')
    if len(results) != 1:
        reasons.append('Expected exactly one result marker')
    else:
        r = results[0]
        for key in ('requested', 'measured_elapsed', 'failures', 'cycles'):
            if not finite_number(r.get(key)):
                reasons.append('Invalid result field ' + key)
        if r.get('requested') != duration:
            reasons.append('Result requested duration mismatch')
        if not finite_number(r.get('measured_elapsed')) or r['measured_elapsed'] < duration:
            reasons.append('Insufficient post-warmup measured duration')
        if r.get('failures') != 0:
            reasons.append('Engine assertions failed')
        if not finite_number(r.get('cycles')) or r['cycles'] < 3:
            reasons.append('Fewer than three complete cycles')
        if r.get('cycles') != len(engine_samples):
            reasons.append('Cycle/sample count mismatch')
    if len(engine_samples) < 3:
        reasons.append('Fewer than three settled samples')
    valid_process = []
    for sample in process_samples:
        if not isinstance(sample, dict) or not all_finite(sample):
            reasons.append('Malformed/nonfinite process sample')
            continue
        if sample.get('watchdog_timeout'):
            reasons.append('Watchdog timeout')
        if 'rss_bytes' in sample:
            if (not finite_number(sample.get('sample_unix_seconds')) or
                    not finite_number(sample['rss_bytes']) or sample['rss_bytes'] <= 0):
                reasons.append('Invalid process RSS/time sample')
            else:
                valid_process.append(sample)
    if not valid_process:
        reasons.append('No process RSS samples')
    settled = []
    for index, sample in enumerate(engine_samples, 1):
        stamp = sample.get('sample_unix_seconds')
        if not finite_number(stamp) or sample.get('cycle') != index or sample.get('failures') != 0:
            reasons.append('Invalid settled engine sample')
            continue
        if not valid_process:
            continue
        nearest = min(valid_process, key=lambda p: abs(p['sample_unix_seconds'] - stamp))
        gap = abs(nearest['sample_unix_seconds'] - stamp)
        if gap > MAX_ALIGNMENT_SECONDS:
            reasons.append('Settled/process sample alignment exceeds two seconds')
        settled.append({'cycle': sample['cycle'], 'engine_elapsed': sample.get('elapsed'),
                        'engine_sample_unix_seconds': stamp,
                        'process_sample_unix_seconds': nearest['sample_unix_seconds'],
                        'alignment_seconds': gap, 'rss_bytes': nearest['rss_bytes']})
    rss_ok = (len(settled) >= 3 and len(settled) == len(engine_samples)
              and all(s['alignment_seconds'] <= MAX_ALIGNMENT_SECONDS for s in settled)
              and all(s['rss_bytes'] <= settled[0]['rss_bytes'] + RSS_BOUND_BYTES for s in settled))
    if not rss_ok:
        reasons.append('Fixed settled RSS bound or sampling gate failed')
    return {'returncode': returncode, 'wall_seconds': wall_seconds, 'requested': duration,
            'rss_settled': settled, 'rss_bound_bytes': RSS_BOUND_BYTES, 'rss_pass': rss_ok,
            'engine_results': results, 'errors': errors, 'failure_reasons': reasons,
            'pass': not reasons}


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--output', type=Path, required=True)
    parser.add_argument('--duration', type=int, default=3600)
    args = parser.parse_args(argv)
    if args.duration < 1:
        parser.error('duration must be positive')
    if not sys.platform.startswith('linux'):
        parser.error('This /proc RSS driver is Linux source/headless only')
    out = args.output.resolve()
    out.mkdir(exist_ok=False)  # Never overwrite an earlier attempt.
    project = Path(__file__).resolve().parent.parent
    home = out / 'userdata'
    for directory in ('config', 'cache', 'data'):
        (home / directory).mkdir(parents=True)
    env = os.environ.copy()
    env.update({f'XDG_{key}_HOME': str(home / value)
                for key, value in [('CONFIG', 'config'), ('CACHE', 'cache'), ('DATA', 'data')]})
    cmd = ['godot', '--headless', '--audio-driver', 'Dummy', '--max-fps', '60', '--path', str(project),
           '--script', 'tests/test_retained_mixed_stability.gd', '--', f'--duration={args.duration}']
    meta = {'command': cmd, 'duration': args.duration, 'rss_bound_bytes': RSS_BOUND_BYTES,
            'engine_bound_source_sha256': hashlib.sha256(
                (project / 'tests/test_retained_mixed_stability.gd').read_bytes()).hexdigest(),
            'scope': 'Linux source/headless; not target native GUI',
            'rss_sampling': 'One-second /proc samples, shared Unix timestamps; nearest within two seconds',
            'duration_clock': 'External monotonic watchdog; engine monotonic post-warmup duration'}
    (out / 'invocation.json').write_text(json.dumps(meta, indent=2))
    samples = []
    start = time.monotonic()
    with (out / 'engine.log').open('w') as log, (out / 'process.jsonl').open('w') as sample_log:
        process = subprocess.Popen(cmd, stdout=log, stderr=subprocess.STDOUT, env=env)
        while process.poll() is None:
            tick = time.monotonic()
            elapsed = tick - start
            if elapsed > args.duration + 650:
                sample = {'watchdog_timeout': True, 'elapsed': elapsed}
                samples.append(sample)
                sample_log.write(json.dumps(sample) + '\n'); sample_log.flush()
                process.terminate()
                try:
                    process.wait(timeout=10)
                except subprocess.TimeoutExpired:
                    process.kill(); process.wait(timeout=10)
                break
            try:
                status = dict(line.split(':', 1) for line in Path(f'/proc/{process.pid}/status')
                              .read_text().splitlines() if ':' in line)
                sample = {'elapsed': elapsed, 'sample_unix_seconds': time.time(),
                          'rss_bytes': int(status['VmRSS'].split()[0]) * 1024,
                          'threads': int(status['Threads'])}
                samples.append(sample)
                sample_log.write(json.dumps(sample) + '\n'); sample_log.flush()
            except (FileNotFoundError, KeyError, ProcessLookupError):
                pass  # Process exit races are checked by exit/result/sample gates.
            time.sleep(max(0.0, SAMPLE_INTERVAL_SECONDS - (time.monotonic() - tick)))
    summary = assess((out / 'engine.log').read_text(), samples, process.returncode,
                     time.monotonic() - start, args.duration)
    (out / 'summary.json').write_text(json.dumps(summary, indent=2))
    print(json.dumps(summary, indent=2), flush=True)
    return 0 if summary['pass'] else 1


if __name__ == '__main__':
    sys.exit(main())
