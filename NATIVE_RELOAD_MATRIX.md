# Fixed v20 current-save 50-process recovery sub-gate

## Scope and immutable evidence boundaries

Uses the already-published actual v1.3.20-test.1 Windows EXE / macOS Universal app,
with the existing immutable `native_package_stability` ZIP name/size/SHA pins.
Manual-only `native-reload-matrix.yml`: fixed public lemoncat7/MountainStill,
empty permissions, existing standard Windows2025/macOS15ARM/macOS15Intel runners.
No release/runtime edits, script injection, credentials, artifacts/cache,
new dependencies, AX/TCC requests, screenshots, display changes or paid runners.

The proposed first-stable gate says50 reloads separately for current, old and
post-update saves. This task covers ONLY CURRENT-SAVE independent processes.
No old-save migration, active hot-update pack,60-minute mixedGUI, visual/DPI,
physical close-button, rendered FPS, audio-output or formal-release acceptance.
Prior headless failures remain failures; this new profile does not erase them.

## Exact count and continuity

Each platform does one actual fresh seed boot, then50 recovery boots:51 processes
total. Seed is NOT counted toward50. All are real independent processes from the
same downloaded verified binary, not scene reloads, OS reboots, installation
resets or cold OS/disk-cache benchmarks. PID+creation identity is recorded; OS
reuse of a numeric PID is allowed if the creation identity differs and the old
owned process was fully reaped. Identical process identity is rejected.

An existing default userdata directory aborts before read/launch/delete. Only the
job-created owned directory is used. After normal seed exit, one explicitly
labelled external fixture sets normal-power gathering, no auto-advance and
repeating300-second bamboo fox journey. After that, no fixture rewrites,
timestamp resets or directory replacement occur. Before each process, the actual
primary SHA must equal the preceding after-exit SHA. Each next process restores
that same save. Fifty successful checks are mandatory; no silent retry,
shortened loop, discarded failure or replacement of a failed matrix.

## Each process

- Fixed version and settle/retract resource-loader lines plus actual visible
  owned-PID window establish ready. Geometry uses Windows physical-pixel fields
  versus macOS point fields explicitly; it is not image review or client-size
  equivalence.
- Real monotonic observation30s AFTER ready. No headless, quit-after or fixedfps.
- One ordinary native close: Windows WM_CLOSE / macOS application Quit. Helper
  acceptance does not prove handler execution. Actual exit0 within30s is required.
- Only after all owned processes are confirmed stopped, read bounded valid schema4
  primary and backup. Reject regressions of life/resources/gather/fox counters,
  settings loss, invalid-save recovery or unchanged save hash.
- Conservatively bound offline credit from ready_epoch minus previous saved_at+1.
  Require primary life gain beyond bound+10s and prior backup gain beyond bound+5s.
  Thus load-time offline processing/mtime change alone cannot prove live recovery.
  Real primary/backup interval may be short because Quit saves again; report it
  without fabricating an autosave interval or unique save-call attribution.

## Bounds and immediate stop

Each process has60s readiness,120s total and30s close-grace bounds; terminal checks
also enforce these limits even when the process has just exited. Driver overall
budget42min, job45min. Before starting another process, reserve150s for a full
120s stage plus30s bounded failure reporting/cleanup. Lack of budget is incomplete
FAIL, never50 PASS. No dynamic reduction of30s observations or50 recoveries.

First unexpected error, identity failure, abnormal/late exit, invalid/rolled-back
save or budget failure stops that platform. Other platforms may finish their
single attempt. Log attempted/completed counts, exact failed cycle and bounded
post-failure save summary only if processes exited. Forced cleanup is never normal
exit. If an owned process remains live, preserve its userdata rather than deleting
it. Job-owned directories are otherwise removed after evidence is recorded.

Raw engine/stdout log files share the existing12MiB budget. Helper output has64KiB
and wall-time bounds. No silent truncation accepted as success. Metrics describe
individual short processes; do not fit a long-running memory-leak slope across
51 distinct processes. Startup, readiness and close timings are reported separately
from any frame timing.

## Native helper reuse

Windows C# helper is compiled ONCE per job into the existing required direct
RUNNER_TEMP child `mountainstill-gui-*/capture.dll`; each call reuses it. macOS
compiles the existing Swift helper once for the native runner architecture.
No permission-grant, focus or capture branch is used. Preserve all existing native
helper/source/workflow files when adding these six new files.

Windows standard runners previously exposed no WASAPI output device. Only the
existing GUI probe's exact two known WASAPI initialization errors, immediately
attributed to drivers/wasapi/audio_driver_wasapi.cpp and accompanied by explicit
engine dummy-audio fallback, may be marked environment fallback. No other engine,
script or leak error is allowed; successful lifecycle does not test audio output.

## Offline review

Test exact50 counting (seed excluded), failures at1/25/50 without retries,
global deadlines before/after launch, Windows/macOS fields and helper paths,
PID identity changes versus numeric reuse, close refusal/hang/late exit,
only-after-exit save reads, offline-only false progress, real short backup gap,
resource/settings rollback, log budgets and non-owned filesystem refusal.

Budget precision:42min is checked before/after setup, between cycles, within each
game/helper stage and at final result. The inherited downloader uses45s per-I/O
network timeout, not a hard whole-download timer; it can overrun the42min check
before returning. No late completion can pass. The absolute external job bound
is45min. This limitation is not relabelled as a strict42min whole-network deadline.
