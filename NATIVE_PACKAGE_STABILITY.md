# Pinned v20 actual-package 20-minute headless lifecycle precheck

Manual-only observation of the actual published v1.3.20 Windows EXE / macOS Universal app on existing standard public runners (`windows-2025`, `macos-15`, `macos-15-intel`). No runtime/asset modification, injected scripts, new dependency, paid/custom runner, credentials, artifacts, cache or automatic trigger. `permissions: {}`; fixed public repository; SHA/length-pinned ZIPs; archive traversal checks; one 30-minute job per platform. This driver has its own immutable v20 pins, independent of later ordinary smoke upgrades.

## Time and normal exit — no frame-count shortcut

1. A short real first boot creates the job's own normal save (1800 frames, at least 20 seconds measured after readiness).
2. After process exit, an explicit external fixture sets **gather + bamboo fox journey, 300 seconds, repeat** in that save. No live save edit.
3. Long boot uses `--headless --verbose --max-fps 60 --quit-after 78000`, **never `--fixed-fps` or time-scale**. Frame count only requests normal engine shutdown. At the product's normal 60 cap this targets about 1300 seconds, leaving margin.
4. The observer records monotonic readiness after the fixed version bootstrap and both settle/retract resource loader lines. To pass, **the last observation confirming the process alive must be at least 1200 real seconds after readiness**, followed by exit code zero. A premature engine exit is `DURATION_INSUFFICIENT`; phase times are never combined to reach the minimum. Poll/wait latency cannot inflate the proven live interval.
5. A final real restart (1800 frames, at least 20 seconds post-readiness) checks retained resources, journey choices and renewed automatic save.

Long-process guard is 1500 seconds, short guards 90 seconds, whole job 30 minutes. A timeout triggers owned-process cleanup and **failure**, never normal-exit evidence. The engine's frame-limited shutdown is not a native close button/save-guard test. Any process whose exit cannot be confirmed prevents userdata cleanup; leave it for the disposable VM's teardown rather than delete underneath a running game.

## Workload evidence, not an invented combat soak

First boot is cold idle meditation, not a warmed idle benchmark. The long fixture is normal realm-0 gathering and automatic fox excursions. End primary and atomic backup must prove meaningful progression, gathered counters, completed return(s), retained herbs/dew/bond, and autosave advancement. Startup/offline credit is conservatively bounded using the fixture timestamp and observed readiness; the bound must be below 120 seconds, shorter than one 300-second fox trip. Counts alone without retained resources fail. Restart must preserve progress and autosave again.

The report logs actual allocated wall-time fractions for seed idle, scheduled gather/fox, and restart. **Actual within-phase idle fraction is not directly observable without runtime instrumentation.** A configured fixture is not itself proof of activity: only resulting counters/resources/return records support the bounded workload claim. This is not chapter combat, trial combat, UI cycling or minimization. Restored chapter saves require an explicit continue action and cannot be honestly represented as ongoing battle here.

## Native process metrics

Sample only the owned `Popen` PID every 10 seconds, with process-liveness checks before/after and a stable creation identity across samples. Windows uses standard read-only process APIs: working set and cumulative kernel+user CPU seconds. macOS uses system `/bin/ps`, C locale, RSS KiB converted to bytes and cumulative CPU time. CPU delta / measured wall interval is **single-core-equivalent %**; multithreaded values above 100 are valid. Raw native field names are retained; Windows working set and macOS RSS are not strictly interchangeable private/retained memory.

Missing/malformed counters, identity changes or negative CPU increments fail evidence collection rather than become zero. A sample/exit race only skips the final already-exited sample. No Godot retained static memory, node/object/orphan counts, GPU time, FPS, energy or battery measurement is claimed.

## Existing thresholds are not changed

The historical `release-gates-qa/FIRST_STABLE_RELEASE_GATES.md` is explicitly a **proposal**, requiring 60 minutes of native mixed interaction; 20-minute headless is only lifecycle precheck. Its `evaluate_baseline.py` excludes the first 300 seconds and treats less than 1200 seconds as insufficient. This workflow preserves those durations but does not edit or replace that evaluator.

We report post-300-second RSS first/last/peak, growth and regression slope. The existing proposed 60-minute RSS budget (growth <=10% and slope <1 MiB/min) is only an alarm here: exceeding either returns `MEMORY_REVIEW_REQUIRED` (non-success); remaining below it **does not pass the formal memory gate**, whose static memory and 60-minute mixed workload are absent. CPU utilization has no established pass threshold and is reported only. The old v1.3.12 Linux 60-minute reset/reconstruction loop is separate historical evidence, not v20 native evidence.

## Ownership, observation and bounded output

Default Godot directory is allowed only on an official disposable hosted VM for this public repository. An existing directory causes refusal before any read/launch/delete. Only the newly claimed marker-owned leaf is used; automatic update-network checks are disabled through ordinary preferences. No real player save is touched.

Do **not** read primary/backup while the game runs: Windows reader handles can interfere with atomic rename. All save checks happen after confirmed process exit. Logs, not saves, are read during the run. stdout goes to regular files, not an undrained pipe. Unexpected engine errors/leaks/crashes are checked at sampling intervals and terminal exit; first diagnostic fails the observation. Complete bounded engine logs, hashes, roughly 140 metric rows and summaries go to Actions logs. Combined local engine/stdout log budget is 12 MiB, checked during and after execution; oversized logs fail instead of being silently truncated or read without a bound. No screenshots or artifacts are uploaded.

Offline checks:

```
python tests/native_package_driver_test.py
python tests/native_process_metrics_test.py
python tests/native_package_stability_test.py
```

Actual platform results must reach terminal states before reporting validation. A green scoped run is not first-stable readiness, GUI acceptance, indefinite leak freedom or performance certification.

## ARM-only diagnostic continuation (first run preserved)

Run 39959733545: Windows and Intel passed this scoped precheck; ARM reached the
1500-second watchdog and was forcibly cleaned up. That is a failure, not a crash
proof or successful lifecycle. Full original logs are preserved in the QA archive.

Manual input `target=arm-diagnostic` (default) selects only the existing `macos-15`
runner and additionally enables `--print-fps`. `target=all` retains the original
three-runner observation without diagnostic mode. No automatic trigger was added.
The exact v20 ZIP pins, normal-power gathering/fox fixture, 78000 frames,
1200-second required post-readiness wall time, 300-second warmup, 1500-second
watchdog, and 30-minute job timeout are unchanged.

The diagnostic reports the engine's process-frame buckets from Godot 4.6.3
`main/main.cpp` (`Project FPS` output). These are NOT rendered FPS, exact total
frames or a GUI performance result: initial buckets are suppressed and buffered
output may omit the tail. Each log is summarized separately; duplicate engine
and stdout streams must not be summed. All logs retain the existing 12 MiB budget.

If the long phase fails, first complete its existing failure cleanup and confirm
all owned processes have terminated. Only then read bounded primary/backup saves
from the job-created directory, emitting selected numeric deltas and fixed boolean
checks, never arbitrary state. Mark this `FAILED_PHASE_ONLY_NOT_PASS`; forced
SIGKILL is explicitly recorded. No restart or PASS is fabricated after failure.
Unavailable/invalid save evidence is reported without replacing the original error.
No SIGINT, new runtime control endpoint, script injection, lower frame count,
low-power substitution, threshold relaxation, additional dependencies or permissions.
