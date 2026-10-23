# Native OS input: narrow, synthetic, actual v20

Manual official public-repository CI only. Empty permissions, anonymous pinned
source/package fetch; no dependency install, secrets, caches, artifact action,
driver, renderer, DPI/display change, security setting or permission request.
Adds new tools/workflow only; retains every existing native/reload/compatibility
and stability gate unchanged. The immutable actual-v20 executable is not patched
or supplied an injected script. Synthetic native input is not a physical person.

Windows first normally boots a new owned save, then applies the previously
approved V5 geometry-only fixture and normally exits a second time. This explicit
extra layout preparation produces a legitimate960x540 save; CLI resolution alone
would be overridden by application settings. After that exit only the legal
settings.paused=true value is changed; its full formal state is the baseline.
No input-session code reads a save while any game process is alive. Every save
read asserts all registered processes are terminal plus exact ownership marker.

Input sequence: mouse arrival note, capture guide; I, combat attributes, enemies,
mirror practice; Space pauses that practice session only, capture actual trial;
Esc exits practice, G selects gathering in the formal input branch, normal own
WM_CLOSE. After exit read valid save: arrival_seen false->true, activity
meditate->gather, paused still true, all formal gameplay fields unchanged except
those expected values and saved_at/settings. The initial formal pause prevents
idle resources from confounding reward-free trial assertions. Trial results are
runtime-only: save cannot prove trial started/paused. Independent image review
must identify actual trial/pause UI, not just a static enemy page. G is ignored
inside practice, so persisted gather corroborates the return before close; normal
Quit alone would also clean up practice and is insufficient return evidence.

Every helper event checks exact owned PID/HWND, real client960x540/96DPI,
foreground ownership, no modifiers/buttons already pressed. Only Space/I/Esc/G
and within-client clicks allowed. At most one ordinary SetForegroundWindow per
input helper call; no focus trick or UIPI workaround. Click hit-testing must
belong to the exact window. SendInput down/up uses one packet; inserted counts
alone do not establish game callbacks. Helpers are precompiled once in immediate
owned RUNNER_TEMP child; DLLs/PNG paths reject aliases/reparse/preexisting output.

Three native-pixel UI crops retain complete source coordinates/window metadata:
guide header(202,20,700,140), trial controls/label(16,10,700,72),
trial character/enemy/ground(300,300,400,240). No resize or unrelated full desktop.
The three raw32bpp pixel buffers total977600bytes (+452scanline filters);
PNG/deflate overhead remains well below the1MiB ceiling. Original first-run
fullguide remains separate evidence, not silently replaced. Combined PNG cap1MiB; reject over limit. Parent independent hash/size+visual review
is mandatory. No screenshot is user-facing by default.

Each game process retains43s work/45s close-request/55s hard owned-stop bounds;
readiness must occur by20s. If full input sequence cannot finish, stop safely and
report incomplete rather than speeding through animation or extending safety.
Job hardlimit5min. Helpers/output/logs bounded. Subsequent save reads happen only
after owned process termination. Normal WM_CLOSE is not a physical close-click.

macOS ARM/Intel only compile/run the same helper's CGPreflightPostEventAccess and
CGPreflightScreenCaptureAccess. No game boot/input, permission request, AX,
AppleScript or TCC modification. False is ENVIRONMENT_UNAVAILABLE, true is only
preflight capability, not successful native interaction or consent expansion.

Failures: missing foreground/permission/geometry => environment/input unconfirmed;
wrong screenshots => visual inconclusive; runtime errors/nonzero exit/resource or
save assertion mismatch => failure; deadlines/cleanup retained explicitly. Even
all passing establishes only this narrow new-save route, not all menus, HiDPI,
physical inputs, performance, or60minute mixed-operation stability.
