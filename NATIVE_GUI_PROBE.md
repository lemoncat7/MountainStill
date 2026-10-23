# Native GUI capability probe (not release acceptance)

Baseline: `1ebc8363fb0b04ec9d3fc374d28070a93d56f025`.
Manual workflow only; fixed public lemoncat7/MountainStill, standard Windows 2025,
macOS 15 ARM and Intel runners. No paid runner, cache/artifact upload, secret,
third-party action, privilege/driver/TCC/accessibility/OS settings changes.

## Scope
Downloads actual immutable v1.3.17-test.1 public Windows/macOS ZIPs, verifies
pinned SHA256 and size, validates every archive member before extraction.
Uses existing reviewed package-smoke safety helpers but independently pins the
release, so upgrading the package-smoke constants does not change this probe.
No game source, resources, package, renderer or project setting is modified.
The default new userdata directory is atomically claimed; any pre-existing path
blocks launch. Only owned synthetic userdata is removed. Auto-update network
checking is disabled via normal user preference to retain the pinned app.

Launch arguments: `--verbose --max-fps 60 --quit-after 1800`. This is graphical,
not headless or simulated fixed FPS. Collect startup/renderer logs, visible
PID-owned window geometry and actual DPI/scale, then native-pixel crops at about
5 and 12 seconds. Termination begins at 55 seconds with up to four seconds reserved for kill/reap (60-second budget); terminate only our launched process
(tree on Windows). Normal `--quit-after` exit is **not** UI-close validation.

Windows: read input desktop; local helper thread DPI context; GDI BitBlt
SRCCOPY | CAPTUREBLT captures composited desktop including layered windows.
macOS: same compiled Swift executable preflights screen-capture permission and
uses ScreenCaptureKit display capture. A negative preflight stops capture and
never requests permission. Capture includes the display, not an isolated window
alpha image. Read-only display/window inspection; no System Events commands.

Images are at most two unscaled native-pixel application-top-left crops,
720 x 480 maximum each. Combined PNG bytes must be <= 1 MiB. Oversize captures
are rejected, never downsampled. This may omit UI; do not infer full visibility.
Logs contain framed base64, 4000 characters per data line:
`BEGIN_GUI_PNG <name> <bytes> <sha256>` ... `END_GUI_PNG <name>`.
Use only this disposable synthetic public-app runner; not a personal desktop.

## Classification and required independent review
- `ENVIRONMENT_UNAVAILABLE`: no capture permission/accessible desktop, or
  renderer initialization unavailable (requires triage, not proof of app fault).
- `CAPTURE_INCONCLUSIVE`: missing/window-only evidence, helper error/compile
  failure, oversized image, timeout, or captured image awaiting human/independent
  agent inspection. Successful workflow exit is **not** a GUI pass.
- `APPLICATION_FAILURE`: nonzero game exit or engine/script error, requiring
  separate diagnosis (environment may still be cause).
- `GUI_OBSERVED`: assigned **only by independent reviewer after downloading the
  Actions log, verifying framed bytes+SHA and viewing the actual screenshot**,
  with readable recognizable game content and expected startup/renderer logs.
  Driver deliberately never assigns this status based on window existence.

Black/blank/background-only, covered/partly offscreen or unverifiable images
remain inconclusive. Record OS/architecture, run ID, image hashes, renderer,
window/display/DPI data, normal vs forced exit, and review finding separately.
This first probe does not establish transparent-background behavior, interactions,
UI close/relaunch, multiple DPI/layouts, native target performance, real hardware,
signed/notarized installation, or formal-release readiness.

## Local verification and next gate
`python tests/native_gui_driver_test.py` checks framing budget, pin, launch args,
permission-contract structure and guard rejection outside disposable CI.
Python compile tests are offline only. Windows C#/PowerShell and Apple Swift/
ScreenCaptureKit compilation and runtime remain unverified until actual runners.
No GUI evidence is manufactured from Linux/headless tests.
Official API context: GitHub hosted runner and billing docs; Microsoft
BitBlt / GetDpiForWindow; Apple ScreenCaptureKit,
CGPreflightScreenCaptureAccess and NSScreen.backingScaleFactor.

Implementation note: managed CopyFromScreen rejects combined SourceCopy/CaptureBlt flags; direct BitBlt preserves layered-window capture without security changes.
