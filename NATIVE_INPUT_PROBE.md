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

## Explicit macOS input follow-on (separate manual workflow)

`native-macos-input-probe.yml` opts in with `--macos-input`, fixed macos-15 and
macos-15-intel only. The original workflow's Mac behavior remains preflight-only;
Windows is not repeated. Both preflight-only jobs previously observed existing
permissions, but that observation is never trusted as a lasting grant.

The exact new Swift executable preflights existing post-event and capture access
before any game boot, and AGAIN immediately before each actual CGEvent post.
False stops; no request/AX/AppleScript/TCC changes. Inspect alone may request one
ordinary app.activate(options:[]) then check frontmost PID; subsequent lost focus
stops without reactivation. CGEvent.postToPid addresses only the verified owned
PID, with exact visible window identity rechecked; no global event broadcast.
Down/up are adjacent but not atomic: both events are pre-created, modifier/button
and requested-key state checked before down. Each post rechecks permission,
foreground and geometry. If a guard fails after down, no forbidden release is
sent; input_state_uncertain is reported and the owned application is closed.
Click-state is explicitly1, click spacing remains1s, never a double-click probe.

Geometry is deliberately limited to scale1 normal windows. Before launching the
input process the normally-exited geometry-seed SAVE must report960x540. Runtime
SCWindow outer width must match960, and outer height minus saved540 must be a
20..40point title inset. Derived client origin=(outer.minX,outer.minY+inset); this
is an inference for this supported window style, NOT direct OS client access.
Unexpected style/width/inset/scale or changing frame is rejected, not compensated.
SC/CG global coordinates are top-left; points equal pixels only under this scale1
gate. Mouse position is derived client origin+logical target, not a Windows
border constant and not a second AppKit Y-flip. Every capture records both frames,
inset, scale, ROI/global mapping, and the inference source. Same3original-pixel
ROI/1MiB budget and43/45/55second bounds; no live save reads.

Images and final offline assertions must independently demonstrate actual pages,
trial pause and formal return. Successful post requests or permission flags alone
do not establish an application callback, macOS coverage, physical input or60min
mixed-operation stability. Original Windows pass and all probe failures persist.

Mac postToPid is deliberately process-targeted, unlike Windows global SendInput
with WindowFromPoint hit-testing. It does not certify physical mouse hit-routing
through other windows. Native captured pixels and exact foreground ownership must
still show the intended app UI; overlays or contradictory evidence are not a pass.
Each helper result is compared against Inspect PID/window/outer/client/origin and
scale before continuing, so cross-call window movement cannot silently remap the
script. An input_state_uncertain result is logged intact, aborts subsequent
inputs, and proceeds only to bounded own-application normal-close/cleanup.

API references: Apple CGEvent (public postToPid), NSRunningApplication activation,
and NSWorkspace frontmostApplication:
https://developer.apple.com/documentation/coregraphics/cgevent
https://developer.apple.com/documentation/appkit/nsrunningapplication
https://developer.apple.com/documentation/appkit/nsworkspace/frontmostapplication

## macOS late-log readiness transport retry

First Mac input run39991938744 compiled the helpers and preflighted existing
permissions, but both fresh-seed boots reached20s readiness timeout before any
input. Normal Quit exited0; final logs contained the exact late texture marker.
Godot4.6.3 release StdLogger uses vprintf and only explicitly flushes when the
flush-on-print setting is enabled. Redirected stdout tail buffering is therefore
a plausible tool-level cause, not a demonstrated product crash or a proven fix.
Reference: https://raw.githubusercontent.com/godotengine/godot/4.6.3-stable/core/io/logger.cpp

The narrow Mac-only retry attaches stdout/stderr to an owned stdlib PTY so terminal
line buffering can expose the SAME late marker while running. stdin is DEVNULL;
nothing writes to the PTY and it is never an application-input control channel.
Windows transport and native CGEvent behavior are unchanged. Marker, settling,
window checks,20s readiness and43/45/55s safety limits are not relaxed. The driver
records when the marker was actually seen live; no surviving-process fallback.

A nonblocking daemon drain flushes bounded chunks to a fresh owned log. Maximum
stored prefix4MiB; overflow/error is explicit and aborts the probe while drain
continues discarding to avoid child blockage. EOF/EIO finish normally. After game
termination close allows.2s EOF drain then.2s stop/join; only the worker closes its
read fd, preventing a concurrent fd-reuse race. Forced incomplete drain is an
error, never complete logging evidence. Initialization/Popen failures close both
owned fd ends. Logs remain available for post-exit scanning; no save is read live.

Local PTY tests demonstrate transport behavior with disposable Python children,
not actual macOS game readiness. Actual two-Mac retry remains necessary; prior
failure stays archived even if this transport succeeds.

## Current diagnostic: one ARM guide mouse click only
The previous Mac full-loop attempt39993694879 did NOT open the guide or trial;
all six images and failed save assertions remain in internal QA. PTY transport
observed readiness, but posted events were not proof of correct game callbacks.
The Mac workflow now runs only macos-15 ARM with --macos-guide-click. It is NOT
a retry of the full keyboard/trial loop. Existing Windows behavior is unchanged.

After the same normally-exited fresh/geometry seeds and offlinepaused=true,
post only a mouse move/down/up to the guide note(client268,514), via the normal
session event stream. No keyboard, I/G/Esc, trial or alternative-coordinate
fallback. A single original700x140guide ROI plus normal exit/offlinearrival_seen
false-to-true is required; formal activity, entire settings and resource state
must stay unchanged. The same20/43/45/55secondlimits and1MiBPNGbudget apply.

Every individual move/down/up requires existing samehelper posting/capture
preflight, exactownedPID/window/geometry, foregroundowner and the official
NSWindow mouse-down hit-test at the point returning the exactownedwindow.
Windowidentity is also tied to PID using CGwindowinfo. Unlike rectangle-only
z-order, this API accounts for transparent/ignoresMouseEvents windows. Unknown
or obstructed target stops, including between down/up; never force a release
past failed guards. Only one scale1screen with compatible zeroorigin geometry
is accepted, with explicitCGtop-left toAppKitbottom-left conversion. No AX/TCC
requests, display changes, eventtap installation or production-package edits.

Apple's post(tap:) documents entry into the event stream; routing through
WindowServer rather than process-specific posting is a plausible correction
for missingwindowassociation, NOT guaranteed by the docs or yet verified.
Godot4.6.3 reads NSEvent.locationInWindow and maps clientHeight-localY.
No blindglobalYflip, fabricatedwindowfields, Unicodepatch or tapfallback.
If this bounded diagnostic fails, report the tool capability limitation rather
than cycling through alternate coordinates/taps. A helper guard/check result
is not gamecallback evidence; root must inspect the actualguideimage.

Sources:
- https://developer.apple.com/documentation/coregraphics/cgevent/post(tap:)
- https://developer.apple.com/documentation/appkit/nswindow/windownumber(at:belowwindowwithwindownumber:)
- https://developer.apple.com/documentation/appkit/nsevent/locationinwindow
- https://github.com/godotengine/godot/blob/4.6.3-stable/platform/macos/godot_content_view.mm
- https://github.com/godotengine/godot/blob/4.6.3-stable/platform/macos/display_server_macos.mm

The same compiled Swift helper's Preflight executes2positive/9negative pure
coordinate fixtures before any game launch. Guide mode requires those reported
counts and success; Python source-contract tests do not substitute for executing
Swift. This localLinuxenvironment cannot compile AppKit: nativecompilation and
these Swift fixtures remain pending the approved ARM job.
