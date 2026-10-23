# Fixed v20 ARM GUI wall-clock lifecycle observation

Independent profile, not a retry that erases headless failures39959733545/39964781148.
Manual-only `.github/workflows/native-gui-stability.yml`, anonymous fixed public
repository, `permissions: {}`, one existing standard `macos-15` runner, 30-minute
job limit. No artifacts/cache/secrets/dependencies/AX/TCC/display-setting changes.

Uses `native_package_stability` immutable v1.3.20-test.1 ZIP size/SHA and safe
extractor, actual app binary, fresh job-owned Godot userdata. Existing userdata
aborts without reading/deleting. Runtime and release assets remain untouched.
Existing `native_gui_capture.swift` is compiled using installed swiftc; only its
read-only `--geometry-only` and normal `--request-close` branches are used.
No screenshot capture or permission request; visible-window metadata is not
visual readability/proportion acceptance.

Stages: normal GUI seed (30 seconds after fixed boot/resource/visible-window
readiness); external fixture from that actual job-created save sets normal-power
gathering and repeating300-second bamboo fox journey; long GUI stage requires
1200 real monotonic seconds after readiness, with initial300 seconds excluded
from memory trend; normal GUI restart again30 seconds. No `--headless`,
`--quit-after`, fixed FPS, injected scripts or fake rendering. Stage watchdog:
120 seconds for short stages,1500 for long. A single PID-targeted normal
NSRunningApplication.terminate is sent after the wall requirement, followed by
at most30 seconds to exit naturally. Request acceptance alone does not prove
handler execution. Only actual exit0, valid retained saves/progress and restart
can pass. Any forced cleanup remains failure.

CPU/RSS samples identify the owned process. Same historical proposed RSS alarms
are observations, not formal memory acceptance; no static/object counters.
GUI/headless measurements are not directly comparable. Collection and fox timers
are not sustained chapter combat; within-phase idle fraction is unmeasured.

Normal `_quit` saves again, unlike engine frame-limit exit. Thus primary/backup
lifetime gap may legitimately be less than10 seconds. Validate actual prior
backup already has progress beyond startup offline allowance, primary retains
resources/returns and startup settings, and restart retains and advances state.
Report real backup gap; do not fabricate an autosave interval or attribute the
write uniquely to normal Quit. No live-save reads during game process lifetime.

This is not60-minute mixed-GUI certification, physical red-button interaction,
rendered-FPS/GPU performance, formal memory-budget passage, or a stable release.

Only OS-visible owned-window geometry and engine logs are observed. No claim of
20-minute visual correctness or continuously healthy rendered game imagery is made.
Earlier initial-screen captures remain separate evidence, not new long-run image review.

Restart additionally bounds possible startup/offline credit from the observed
restart readiness timestamp: both primary and previous backup must contain new
lifetime progress beyond that bound. Paused/auto-advance/power/journey selections
must be retained. Offline loading alone cannot satisfy restart validation.
