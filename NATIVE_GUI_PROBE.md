# Native GUI evidence probe — v20 two-size increment

This is a manual evidence workflow, **not formal-release acceptance**. Pin:
`v1.3.20-test.1`, unmodified published EXE/universal app, independently fixed
archive SHA256 and byte lengths in `tools/native_gui_probe.py`. A future change
to package-smoke constants cannot silently retarget this driver.

## Safety and execution

Only public lemoncat7/MountainStill on standard free `windows-2025`, `macos-15`,
`macos-15-intel`; workflow_dispatch only, `permissions: {}`, anonymous exact-SHA
source fetch. No secret, artifact/cache upload, third-party action, paid runner,
OS display/DPI/security/permission change, game patch or package script injection.

Each job has a five-minute outer deadline. The package downloads once with
fixed size/SHA verification and safe archive extraction. Existing userdata
blocks launch. A new default app userdata path is atomically claimed with an
ownership marker; only that disposable synthetic path is read/modified/removed.
Update auto-check is disabled by the normal preference so the pin stays fixed.

All three boots use `--verbose --max-fps 60`, default graphical renderer, real
wall time, no headless/fixed-FPS/frame-count quit. Each boot retains the v4 close
budget: capture finishes by43s, normal-close helper gets at most2s/by45s, own
process safety termination begins55s, bounded kill/reap reserve. Only PID-owned
Windows WM_CLOSE or macOS NSRunningApplication.terminate requests are sent.
They are not physical mouse/red-button tests; handler handling and save-write
causality remain unknown. Failures/refusals never trigger permission workarounds.

## Three sequential boots; two evidence images total

1. **Seed:** actual GUI boot creates its valid save and closes normally. No image
   output and no geometry/visual acceptance claimed. Missing valid save or bad
   exit blocks fixture creation; no synthetic replacement schema is guessed.
2. **Window:** after exit, edit only explicit legitimate geometry settings of a
   deep copy of that seed. Request window_mode=window, normal_width=960,
   normal_height=540, geometry_version=2, ui_scale=1.5.
3. **Strip:** after exit, apply another seed copy requesting window_mode=strip,
   strip_width=1200, ui_scale=1.5. At scale1 the product computes height400.

Both fixtures log the complete settings mutation: compatibility width/height,
normal/window positions derived from measured work-area origin, and explicit
always_on_top=false, click_through=false, transparent=true. No gameplay state,
assets, scripts, renderer or global setting is changed. Valid saved positions
avoid the product's never-positioned default-size scale-multiplication branch.

Do not rely on `--resolution`: `desktop.initialize()` overwrites the initial
CLI dimensions using saved settings. The driver does not force/repair the game
window afterward, fake strip mode, or secretly compensate for a layout defect.

## Requested versus actual geometry

The unmodified product reserves24 horizontal pixels and56 vertical pixels from
the usable work area. At current scale1:
- 960x540 ordinary window is expected where that work area permits it.
- 1200x400 strip needs usable width>=1224. The historical1024-wide Win/ARM
  runners therefore expect **1000x400**, explicitly LOW_RESOLUTION_ADAPTATION,
  NOT exact1200x400 acceptance. A1920-wide Intel runner can attempt exact size.
- Effective uniform content scale inferred from source is min(1.5,width/960,
  height/320): normal960=>1; strip1200=>1.25; clamped1000=>about1.0417. This is a
  source expectation, not secretly read runtime state or measured HiDPI evidence.

Read-only geometry is sampled before capture and again by the capture helper;
outer bounds and scale must agree. Log work area, screen, outer frame, coordinate
units/origin, DPI/backing scale, pixel image size, and post-exit game-saved
geometry. Unexpected size/mode/OS-client discrepancy is reported, not corrected.

Windows GetClientRect+ClientToScreen gives actual native client geometry under
thread-local DPI awareness (restored afterward). macOS CGWindowList and SCWindow
expose **outer frame in points only**; `client_frame` is null. Mac client-size
corroboration is the product's own saved `_window.size` plus OS outer frame,
backing scale and screenshot, never labeled direct OS client measurement.
Unexpected scale!=1 remains outside this matrix; no OS DPI adjustment is made.

## Images, backdrop and review

One full-window composited-desktop PNG per tested mode, with available16px
outside control strips. The previous720px center crop is removed. Geometry
outside the captured screen or abnormal/fractional native pixel extents is
rejected rather than silently clipped/resampled. No text/image scaling. Maximum
16M capture pixels; maximum2 output PNGs and1MiB combined per job. Oversize output
is rejected, not downsampled. Framing is `BEGIN_GUI_PNG <name> <bytes> <sha256>`,
4000-character base64 lines, then `END_GUI_PNG <name>`. Names are `window.png`
and `strip.png`. Output is deferred until the owned process has closed/reaped.

The retained ordinary nonactivating checkerboard backdrop is placed directly
behind the PID-owned game window; native z-order is verified. Both size cases
use palette1 for consistent visual comparison; **this is not a new two-palette
transparency comparison**. macOS preflights screen-capture access in the same
helper and never requests it. Geometry-only inspection uses CGWindowList without
SCShareableContent/TCC. Windows captures via BitBlt SRCCOPY|CAPTUREBLT.

Independent reviewer must verify framed bytes/SHA and view original pixels:
- actual game not splash/blank/covered, complete relevant window area visible;
- scene/character proportions retain uniform x/y scale (use static platform or
  landmark geometry; animation differences are not aspect distortion evidence);
- actual visible text such as journal prompt/small seal remains readable, without
  clipping or stretched glyphs. This does not certify unopened inventory panels.
Geometry_observed is not a visual PASS. All images remain CAPTURE_INCONCLUSIVE
until independently reviewed. No HiDPI, real-input, GPU/performance, signing,
long-run stability or first-formal-release claim follows from this workflow.

## Failure/partial outcomes

Package/hash mismatch, unsafe archive, nonowned existing data: refuse execution.
No desktop/capture permission or unsupported scale: environment/unverified.
Missing/oversize capture or unstable geometry: inconclusive.
Wrong size relative to the real product clamp rule, unexpected mode, invalid
save/recovery, script/runtime errors, nonzero exit: retained failures requiring
triage. Own-process timeout and cleanup failures remain explicit. A requested
1200 strip correctly clamped to1000 is adaptation evidence, not an exact-size
failure/pass substitution. Full-window screenshots still require review.

## Prior evidence retained, not silently upgraded

v17 V4 run39924599649 established native firstscreen and own normal-close/save
evidence at Windows96DPI/macOSscale1; Windows had only the second PNG after its
first helper timed out. V3 supplied all3OS two-palette sky-transparency evidence,
but CLI-frame quit leaked music on Windows and timed out on Intel. Those failed
methods/results remain archived. They do not substitute for v20 images. v20
headless package/source tests and Linux GUI checks are complementary, not native
Windows/macOS visual evidence.

Local tests validate safety, pins, fixture isolation, exact/clamped expectations,
Mac client-evidence limits and mocked lifecycle; they do not compile/run native
AppKit/WinForms here. Native jobs and independent images are the next gate.
