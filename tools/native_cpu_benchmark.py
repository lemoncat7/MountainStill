#!/usr/bin/env python3
"""Fixed published-source CPU ABBA; never GUI/FPS or formal performance acceptance."""
import argparse
import hashlib
import json
import math
import os
from pathlib import Path
import platform
import re
import shutil
import signal
import subprocess
import sys
import tarfile
import tempfile
import time
import uuid

COMMITS = {'A': 'a0f1ff4e066b1d0697d5918037bfc9902f004d5a',
           'B': '75827e1b51b799194fd8d81e8c52ed7e19adf3bf'}
SCENES = [('bamboo_pass', 'sword'), ('cloud_slope', 'unarmed'), ('cloud_slope', 'fan')]
ORDER = [('A1', 'A'), ('B1', 'B'), ('B2', 'B'), ('A2', 'A')]
TRACE_FIELDS = ["hero_hp", "hero_max_hp", "enemy_hp", "enemy_max_hp", "finished", "victory", "cancelled", "technique", "weapon_style", "turn_index", "elapsed", "_hero", "_enemy", "_profile", "_enemy_history", "_enemy_stamina_base", "_enemy_stamina_anchor", "_lanes", "_pending", "_hero_turns", "_enemy_turns", "_counter_ready", "_counter_kind", "_counter_source", "_counter_earned_at", "_last_contact", "_reactions", "_defense_releases", "_pressure", "_pressure_time", "_break_immunity", "_chase", "_finish_at", "_finish_started", "_finish_approach", "_hero_stance", "_started", "_qi_max", "_qi_regen", "_qi_base", "_qi_anchor", "_skill_lanes", "_skills", "_cooldowns", "_heart", "_weapon_art_form", "_passive_methods", "_skill_uses", "_enemy_slow_until", "_hero_slow_until", "_slow_fractions", "_shield", "_shield_until", "_cost_reduction", "_cooldown_reduction", "_basic_turns", "_technique_uses", "_must_basic", "_next_skill_index", "_enemy_module_definition", "_module_definitions", "_module_ids", "_hero_join", "_action_timing"]
PROBE_SHA256 = {'bench.gd': 'ef894db9ee7137ba2b54be95f2f1c013bd2786507c0b214472de413c1d13b0e5', 'semantic_probe.gd': 'c52a72dbee2f361312361040bfc80960e80ebc29f1368df81f067b7e6dae36c1'}
TICKS = 480
LOG_LIMIT = 10 * 1024 * 1024
ERROR = re.compile(r'^(?:SCRIPT ERROR:|ERROR:|FAIL:)|\b(?:leaked|orphan|crashed)\b', re.I)


class Log:
    def __init__(self, limit=LOG_LIMIT):
        self.safe_cleanup = True
        self.deadline = time.monotonic() + 840
        self.used = 0
        self.limit = limit

    def emit(self, text):
        data = (text + '\n').encode('utf-8')
        if self.used + len(data) > self.limit - min(65536, self.limit // 4):
            raise RuntimeError('Log budget exceeded; run INCOMPLETE, not truncated to pass')
        self.used += len(data)
        print(text, flush=True)

    def record(self, kind, value):
        self.emit(kind + ' ' + json.dumps(value, ensure_ascii=False, separators=(',', ':'), allow_nan=False))


def stop_tree(process):
    failure = None
    try:
        if os.name == 'nt':
            subprocess.run(['taskkill', '/PID', str(process.pid), '/T', '/F'],
                           stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                           timeout=10, check=True)
        else:
            try:
                os.killpg(process.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
    except Exception as error:
        failure = error
    finally:
        try:
            process.kill()
            process.wait(timeout=10)
        except Exception as error:
            failure = error
    if failure is not None:
        raise RuntimeError('Process tree termination unconfirmed; preserve userdata') from failure


def run(command, timeout, log):
    if time.monotonic() + timeout > log.deadline:
        raise RuntimeError('Insufficient remaining job budget; refusing incomplete block')
    with tempfile.TemporaryFile() as capture:
        process = subprocess.Popen(command, stdout=capture, stderr=subprocess.STDOUT,
                                   start_new_session=(os.name != 'nt'))
        started = time.monotonic()
        reason = None
        while process.poll() is None:
            if capture.tell() + log.used > log.limit - 65536:
                reason = 'Process log budget exceeded'
            elif time.monotonic() - started > timeout:
                reason = f'Process timeout after {timeout}s'
            if reason:
                try:
                    stop_tree(process)
                except Exception:
                    log.safe_cleanup = False
                    raise
                raise RuntimeError(reason + '; INCOMPLETE, no filtered retry')
            time.sleep(.05)
        if time.monotonic() - started > timeout or time.monotonic() > log.deadline:
            raise RuntimeError('Process completed after deadline; INCOMPLETE')
        capture.seek(0)
        output = capture.read(log.limit + 1).decode('utf-8', errors='replace')
    log.emit(output)
    if process.returncode or any(ERROR.search(line.strip()) for line in output.splitlines()):
        raise RuntimeError(f'Process/diagnostic failure: exit {process.returncode}')
    return output


def stats(values):
    if len(values) != TICKS or any(type(v) not in (int, float) or not math.isfinite(v) or v < 0 for v in values):
        raise ValueError('Expected 480 finite nonnegative timing samples')
    ordered = sorted(values)
    return {'count': len(values), 'total_us': sum(values), 'mean_us': sum(values) / len(values),
            'p50_us': ordered[math.ceil(len(values) * .5) - 1],
            'p95_us': ordered[math.ceil(len(values) * .95) - 1], 'max_us': ordered[-1]}


def validate_bench(report):
    if report.get('engine', {}).get('hash') != '7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3':
        raise ValueError('Unexpected engine provenance')
    if report.get('technique') != 'mist' or report.get('hero') != {'hp': 420, 'max_hp': 420, 'attack': 11, 'defense': 1}:
        raise ValueError('Unexpected hero/technique input')
    if report.get('schema') != 'mountainstill.cpu.v1':
        raise ValueError('Unexpected timing schema')
    if report.get('ticks') != 480 or report.get('warmups') != 1 or report.get('trials') != 3 or report.get('seed') != 377:
        raise ValueError('Benchmark input/count mismatch')
    if not report.get('headless_cpu_only') or not math.isclose(report.get('dt', 0), 1 / 60, rel_tol=0, abs_tol=1e-16):
        raise ValueError('Unexpected benchmark clock/scope')
    if len(report.get('results', [])) != 3 or len(report.get('warmup_results', [])) != 1:
        raise ValueError('Missing trials, including warmup')
    for phase, collection in [('warmup', report['warmup_results']), ('measured', report['results'])]:
        for index, trial in enumerate(collection):
            if trial.get('trial_index') != index or trial.get('phase') != phase or trial.get('seed') != 377 or trial.get('reset') != 'fresh_duel_process_caches_retained':
                raise ValueError('Benchmark trial/reset metadata missing')
    for trial in report['warmup_results'] + report['results']:
        for field in ('advance', 'pose', 'rig', 'tick'):
            actual = stats(trial['samples'][field + '_us'])
            for key, expected in actual.items():
                if not math.isclose(trial[field][key], expected, rel_tol=1e-12, abs_tol=1e-9):
                    raise ValueError(f'Summary/sample mismatch: {field}/{key}')
        if not math.isfinite(trial['total_ms']) or trial['total_ms'] < trial['tick']['total_us'] / 1000:
            raise ValueError('Invalid total loop time')
        for i in range(TICKS):
            if trial['samples']['tick_us'][i] != sum(trial['samples'][f + '_us'][i] for f in ('advance', 'pose', 'rig')):
                raise ValueError('Timing boundary samples do not add up')
        if trial['early_finish']:
            raise ValueError('Early finish changes workload')
    return report


def validate_trace(report):
    if report.get('engine', {}).get('hash') != '7d41c59c457bd5a245092b4e7eb2d833e3b3f8c3':
        raise ValueError('Unexpected trace engine provenance')
    if report.get('ticks') != TICKS or report.get('seed') != 377 or not math.isclose(report.get('dt', 0), 1 / 60, rel_tol=0, abs_tol=1e-16) or report.get('schema') != 'mountainstill.gameplay-trace.v1':
        raise ValueError('Trace input/schema mismatch')
    trials = report.get('trials', [])
    if len(trials) != 2:
        raise ValueError('Expected cold and warm semantic trials')
    collected = []
    if report.get('duel_fields') != TRACE_FIELDS:
        raise ValueError('Unexpected semantic field contract')
    for trial_index, trial in enumerate(trials):
        if trial.get('trial') != trial_index or trial.get('ticks') != 480 or trial.get('cache_phase') != ('cold_process' if trial_index == 0 else 'warm_process'):
            raise ValueError('Semantic trial/reset metadata missing')
        for key in ('trace_sha256', 'events_sha256'):
            if not re.fullmatch('[0-9a-f]{64}', trial.get(key, '')):
                raise ValueError('Missing complete trace digest')
        rows = trial.get('tick_hashes', [])
        if len(rows) != TICKS:
            raise ValueError('Missing semantic trace ticks')
        for tick, row in enumerate(rows):
            if row.get('tick') != tick:
                raise ValueError('Semantic tick order invalid')
            for key in ('state_sha256', 'event_sha256'):
                if not re.fullmatch('[0-9a-f]{64}', row.get(key, '')):
                    raise ValueError('Invalid semantic digest')
        collected.append(rows)
    if collected[0] != collected[1]:
        raise ValueError('Cold/warm semantic trace differs')
    return collected


def compare_traces(a, b):
    left, right = validate_trace(a), validate_trace(b)
    for field in ('schema', 'route', 'weapon', 'seed', 'ticks', 'dt', 'duel_fields'):
        if a.get(field) != b.get(field):
            raise ValueError('Semantic metadata mismatch: ' + field)
    if left != right:
        raise ValueError('Semantic mismatch; no floating point tolerance is applied')


def userdata_markers(output):
    # Preserve path bytes/spaces; only consume an optional CR in CRLF line endings.
    return re.findall(r'^CPU_USER=([^\r\n]+)\r?$', output, re.M)


def user_base():
    if sys.platform == 'win32':
        return Path(os.environ['APPDATA'])
    if sys.platform == 'darwin':
        return Path.home() / 'Library' / 'Application Support'
    return Path(os.environ.get('XDG_DATA_HOME', Path.home() / '.local/share'))


def extract_commit(repo, commit, target, log):
    target.mkdir()
    archive = target.parent / (target.name + '.tar')
    with archive.open('wb') as stream:
        subprocess.run(['git', '-C', str(repo), 'archive', commit], stdout=stream, check=True, timeout=90)
    try:
        with tarfile.open(archive) as bundle:
            for member in bundle:
                destination = (target / member.name).resolve()
                if not destination.is_relative_to(target.resolve()) or not (member.isfile() or member.isdir()):
                    raise ValueError('Unsafe source archive member')
                if member.isdir():
                    destination.mkdir(parents=True, exist_ok=True)
                else:
                    destination.parent.mkdir(parents=True, exist_ok=True)
                    with bundle.extractfile(member) as src, destination.open('wb') as dst:
                        shutil.copyfileobj(src, dst)
    finally:
        archive.unlink(missing_ok=True)
    log.record('SOURCE', {'commit': commit, 'files': sum(p.is_file() for p in target.rglob('*'))})


def expected_source_hashes(project):
    return {name: hashlib.sha256((project / 'scripts' / (name + '.gd')).read_bytes()).hexdigest() for name in ('duel_timeline', 'character_sidewalk', 'melee_contact_geometry', 'monster_move_library', 'monster_pose_renderer', 'cultivation_content', 'combat_action_registry', 'combat_rig_registry') if (project / 'scripts' / (name + '.gd')).is_file()}


def read_report(path):
    if path.stat().st_size > 8 * 1024 * 1024:
        raise ValueError('Report exceeds bounded size')
    return json.loads(path.read_text(encoding='utf-8'), parse_constant=lambda value: (_ for _ in ()).throw(ValueError(value)))


def main():
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, 'reconfigure'):
            stream.reconfigure(encoding='utf-8', errors='backslashreplace')
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--repo', type=Path, required=True)
    parser.add_argument('--godot', type=Path, required=True)
    parser.add_argument('--work', type=Path, required=True)
    parser.add_argument('--require-free-gib', type=float, default=4)
    args = parser.parse_args()
    log = Log()
    if os.environ.get('NATIVE_CPU_JOB_STARTED'):
        log.deadline = min(log.deadline, time.monotonic() + float(os.environ['NATIVE_CPU_JOB_STARTED']) + 840 - time.time())
    owned_userdata = []
    okay = False
    summaries = []
    try:
        if args.work.exists():
            raise ValueError('Work directory must not exist; never delete unknown files')
        args.work.parent.mkdir(parents=True, exist_ok=True)
        free = shutil.disk_usage(args.work.parent).free
        if free < args.require_free_gib * 1024 ** 3:
            raise ValueError('Insufficient runner free space; require 4GiB in CI')
        args.work.mkdir()
        log.record('ENVIRONMENT', {'platform': sys.platform, 'architecture': platform.machine(),
                   'os': platform.platform(), 'cpu_count': os.cpu_count(), 'free_bytes': free,
                   'commits': COMMITS, 'image_version': os.environ.get('ImageVersion', ''),
                   'headless_cpu_only': True, 'budget_ms': 33.3})
        version = run([str(args.godot.resolve()), '--version'], 15, log)
        if not version.strip().startswith('4.6.3.stable.'):
            raise ValueError('Expected Godot 4.6.3 stable')
        projects = {}
        expected_sources = {}
        expected_states = {}
        probes = Path(__file__).resolve().parent / 'native_cpu_probes'
        for label, commit in COMMITS.items():
            project = args.work / label
            extract_commit(args.repo.resolve(), commit, project, log)
            name = 'MountainStillCPU-' + uuid.uuid4().hex
            userdata = user_base() / name
            if userdata.exists() or (project / 'override.cfg').exists():
                raise ValueError('Isolation collision')
            userdata.mkdir(parents=True)
            (userdata / '.native-cpu-owner').write_text(name, encoding='utf-8')
            owned_userdata.append((userdata, name))
            (project / 'override.cfg').write_text('[application]\nconfig/use_custom_user_dir=true\nconfig/custom_user_dir_name="' + name + '"\n', encoding='utf-8')
            for filename, expected in PROBE_SHA256.items():
                file = probes / filename
                if hashlib.sha256(file.read_bytes()).hexdigest() != expected:
                    raise ValueError('Frozen probe hash mismatch')
                shutil.copyfile(file, project / ('native_cpu_' + file.name))
            (project / 'native_cpu_user.gd').write_text('extends SceneTree\nfunc _initialize():\n print("CPU_USER=" + OS.get_user_data_dir())\n quit()\n', encoding='utf-8')
            common = [str(args.godot.resolve()), '--headless', '--path', str(project)]
            output = run(common + ['--script', 'res://native_cpu_user.gd'], 30, log)
            paths = userdata_markers(output)
            if len(paths) != 1 or Path(paths[0]).resolve() != userdata.resolve():
                raise ValueError('Native userdata isolation failed')
            run(common + ['--editor', '--import'], 240, log)
            projects[label] = common
            expected_sources[label] = expected_source_hashes(project)
        # Separate equivalence from timing: no canonicalization/hash inside timed loops.
        for route, weapon in SCENES:
            traces = {}
            for label in ('A', 'B'):
                path = args.work / f'trace-{route}-{weapon}-{label}.json'
                run(projects[label] + ['--script', 'res://native_cpu_semantic_probe.gd', '--',
                    '--route=' + route, '--weapon=' + weapon, '--report=' + str(path)], 60, log)
                traces[label] = read_report(path)
                validate_trace(traces[label])
                expected = {'duel': expected_sources[label]['duel_timeline'], 'geometry': expected_sources[label]['melee_contact_geometry']}
                if traces[label].get('source_sha256') != expected:
                    raise ValueError('Semantic source provenance mismatch')
                if traces[label].get('route') != route or traces[label].get('weapon') != weapon:
                    raise ValueError('Semantic scene mismatch')
                log.record('SEMANTIC_TRACE', {'version': label, 'route': route, 'weapon': weapon, 'report': traces[label]})
            compare_traces(traces['A'], traces['B'])
            for i in range(2):
                for key in ('trace_sha256', 'events_sha256'):
                    if traces['A']['trials'][i][key] != traces['B']['trials'][i][key]:
                        raise ValueError('Complete trace digest mismatch')
            log.record('EQUIVALENCE', {'route': route, 'weapon': weapon, 'status': 'PASS', 'scope': 'declared semantic schema only'})
        for route, weapon in SCENES:
            for block, label in ORDER:
                path = args.work / f'bench-{route}-{weapon}-{block}.json'
                run(projects[label] + ['--script', 'res://native_cpu_bench.gd', '--',
                    '--route=' + route, '--weapon=' + weapon, '--ticks=480', '--warmups=1',
                    '--trials=3', '--label=' + block, '--report=' + str(path)], 60, log)
                report = validate_bench(read_report(path))
                if report.get('weapon') != weapon or report.get('enemy', {}).get('route_id') != route or report.get('label') != block:
                    raise ValueError('Benchmark scene/block mismatch')
                if report.get('source_sha256') != expected_sources[label]:
                    raise ValueError('Timing source provenance mismatch')
                scene = (route, weapon)
                for trial in report['warmup_results'] + report['results']:
                    if scene not in expected_states:
                        expected_states[scene] = trial['state']
                    if trial['state'] != expected_states[scene]:
                        raise ValueError('Timing trial terminal state/reset mismatch')
                log.record('CPU_RAW_BLOCK', {'route': route, 'weapon': weapon, 'block': block, 'version': label, 'report': report})
                for index, trial in enumerate(report['results']):
                    summaries.append({'route': route, 'weapon': weapon, 'block': block, 'trial': index + 1,
                        'p95_ms': trial['tick']['p95_us'] / 1000, 'peak_ms': trial['tick']['max_us'] / 1000,
                        'total_ms': trial['total_ms'], 'within_33_3ms': trial['tick']['max_us'] <= 33300})
        log.record('CPU_ALL_MEASURED_TRIALS', summaries)
        okay = len(summaries) == 36 and time.monotonic() <= log.deadline
    except Exception as error:
        print('CPU_BENCH_INCOMPLETE: ' + str(error), flush=True)
    finally:
        if time.monotonic() > log.deadline:
            okay = False
            print('CPU_BENCH_INCOMPLETE: total deadline exceeded', flush=True)
        if not log.safe_cleanup:
            okay = False
            print('CPU_BENCH_INCOMPLETE: preserving userdata because process tree termination unconfirmed', flush=True)
        for path, name in owned_userdata if log.safe_cleanup else []:
            try:
                if path.is_symlink() or (path / '.native-cpu-owner').is_symlink() or (path / '.native-cpu-owner').read_text(encoding='utf-8') != name:
                    raise OSError('Ownership marker changed; refusing cleanup')
                shutil.rmtree(path)
            except OSError as error:
                okay = False
                print('CPU_BENCH_CLEANUP_FAILED: ' + str(error), flush=True)
        summary = '## Native headless CPU ABBA\n\n' + ('Measurement complete' if okay else 'FAILED / INCOMPLETE')
        summary += '\n\nNot GPU/FPS/GUI/HiDPI/consumer hardware or formal 33.3ms acceptance. ABBA does not remove all drift.\n'
        if summaries:
            summary += '\n| scene | block/trial | p95 ms | peak ms | total ms | peak <=33.3 |\n|---|---|---:|---:|---:|---|\n'
            for row in summaries:
                summary += f"| {row['route']}/{row['weapon']} | {row['block']}/{row['trial']} | {row['p95_ms']} | {row['peak_ms']} | {row['total_ms']} | {row['within_33_3ms']} |\n"
        print(summary, flush=True)
        if os.environ.get('GITHUB_STEP_SUMMARY'):
            Path(os.environ['GITHUB_STEP_SUMMARY']).write_text(summary, encoding='utf-8')
    return 0 if okay else 1


if __name__ == '__main__':
    sys.exit(main())
