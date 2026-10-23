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

Launch arguments: `--verbose --max-fps 60 --quit-after 600`. This is graphical,
not headless or simulated fixed FPS. Collect startup/renderer logs, visible
PID-owned window geometry and actual DPI/scale, then full visible native-pixel window/client captures. First capture follows a late-resource load hint by two seconds, or falls back at 30 seconds; the second follows eight seconds later, at most 45 seconds. A resource hint is NOT proof of rendering. The lower 600 physical-frame quit budget allows normal exit on slower runners without simulated FPS. Termination begins at 55 seconds with up to four seconds reserved for kill/reap (60-second budget); terminate only our launched process
(tree on Windows). Normal `--quit-after` exit is **not** UI-close validation.

Windows: read input desktop; local helper thread DPI context; GDI BitBlt
SRCCOPY | CAPTUREBLT captures composited desktop including layered windows.
macOS: same compiled Swift executable preflights screen-capture permission and
uses ScreenCaptureKit display capture. A negative preflight stops capture and
never requests permission. Capture includes the display, not an isolated window
alpha image. Read-only display/window inspection; no System Events commands.

Images are at most two unscaled native-pixel captures of the entire visible application client area (Windows) or window (macOS), intersected with the desktop/display. Metadata says whether the full area is onscreen. A 16-million-pixel allocation limit rejects abnormal geometry. Combined PNG bytes must be <= 1 MiB. Oversize captures
are rejected, never downsampled. Offscreen portions may still be omitted; do not infer full visibility when the metadata says clipped.
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
Python compile tests are offline only. First real run 39920191118 compiled all helpers and captured five images, but ALL platforms remained inconclusive: Windows cropped out the main scene, macOS captured splash, all reached the deadline. These deficiencies motivated full-area/later capture; that revised behavior still requires another real run. Windows C#/PowerShell and Apple Swift/
ScreenCaptureKit compilation and runtime remain unverified until actual runners.
No GUI evidence is manufactured from Linux/headless tests.
Official API context: GitHub hosted runner and billing docs; Microsoft
BitBlt / GetDpiForWindow; Apple ScreenCaptureKit,
CGPreflightScreenCaptureAccess and NSScreen.backingScaleFactor.

Implementation note: managed CopyFromScreen rejects combined SourceCopy/CaptureBlt flags; direct BitBlt preserves layered-window capture without security changes.

## Diagnostic preservation (revision 2)
Logs include launch PID, window owner PID, termination/reap details, first16k
and last24k game-log characters. The first run did not establish a child-process
mismatch. Owned userdata deletion retries only the exact PermissionError-failing
operation; it never recreates/adopts an ownership marker after partial deletion.
Cleanup diagnostics are a separate result field, never replace primary failures.
Only exact WASAPI startup errors attributed to the WASAPI source are treated as
an audio environment limitation when the log explicitly reports automatic dummy
fallback. Other errors remain application/engine failures requiring triage.
The engine's automatic ANGLE/dummy fallback is recorded, never forced by flags.

## Controlled backdrop extension (revision 3)

V2 run39921371103 was independently viewed: all three native OS jobs displayed
actual street scene/characters and exited0 without deadline/cleanup errors.
This proves first-screen GUI display at the observed scale1 ONLY. Windows sky
showed the runner terminal; macOS black sky did not establish transparency.
Internal evidence retained separately, not for direct user image delivery.

The next probe adds only a disposable helper-owned ordinary opaque checkerboard
window, no system wallpaper, global setting, app source, renderer, focus/input,
accessibility or permission change. Each capture creates its own nonactivated
normal-level backdrop directly behind the exact PID-owned game window. Windows
uses ShowWithoutActivation and SetWindowPos(SWP_NOACTIVATE|SWP_NOOWNERZORDER);
macOS uses NSWindow order below without activate/makeKey. It verifies actual
adjacent z-order using GetWindow / read-only CGWindowList, not API success alone.
No verified placement means CAPTURE_INCONCLUSIVE and no image interpretation.
The helper always destroys its own backdrop on completion; helper timeouts are
bounded by the driver and terminate the helper process.

Palette1 uses #33CCD6 and #DB4DC9 alternating48-unit squares; palette2 swaps them.
Both captures are still composited desktops. Capture is horizontal-center720
native pixels, full vertical sky-to-ground range, with available16-pixel strips
outside the game window showing the known backdrop. No resized fonts/pixels.
This overrides revision2's full-width geometry, solely to fit two comparison
images within the unchanged combined1MiB limit. Oversize images still reject.
Geometry, palette, target/backdrop IDs, z-order and control strips are logged.

Independent review must see the actual chessboard control strip and verify
correct placement, then compare a static sky area with a static opaque ground
area in both palettes. Sky tracking the palette while opaque ground stays
unchanged supports transparency at this one observed configuration. Character
animation differences do not count as transparency. Black/unchanged sky without
a visible control strip or without verified backdrop rendering remains
inconclusive, not a proven transparency defect. Two normal exits do not prove
multi-DPI behavior, interactions, performance, UI-close or formal readiness.
