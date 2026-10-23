# Final integrated 60-minute stability observation

2026-10-22 11:27:30–12:27:32 UTC. Final v1.3.12-test.1 runtime, isolated synthetic userdata; no real save touched.

## Result
- Real monotonic duration **3602.175 seconds**, not accelerated simulation time; requested3600, outer guard3900.
- **1531 cycles, 21180 assertions, 0 failures; process exit0**.
- 115 periodic observations. Observed nodes48–64 (panel/reconstruction phase), resources162 throughout, objects2179–2324, orphan nodes0 throughout. Final nodes64/resources162/orphans0.
- RSS first364800KiB, final/peak377104KiB: **+12.016MiB during the hour**. Last15min range376576–377104KiB; linear RSS slope **+0.03444MiB/min**. This is a bounded-duration observation with small remaining growth, not proof of zero leaks or indefinite stability. Harness timing/observation collections also remain in process.
- Final log has no ERROR, FAIL, ObjectDB residual or resources-still-in-use message. Normal XR teardown follows last observation.
- All64 runtime/config hashes match the frozen manifest before and after; recursive script/shader SHA files also exactly match.

## Actual exercise and limits

Linux headless production host (not mocked combat): alternating formal victory/retreat fixtures, sword/fan/unarmed, real save/load and report/battle-resource checks; panels wardrobe/practice/alchemy; ordinary/boss no-reward practice completion/cancel, pause and full formal-state isolation; scene destruction/reconstruction every10 cycles. Timers and settling waits use real engine time. Every cycle calls new_game and installs a controlled high-progression fixture: explicit 1HP enemy victory or highHP short retreat. Every10 cycles the host is reconstructed. Therefore this is not an hour of one continuous character, no-reconstruction cache stability, full natural combat clears, or first-time-player progression. Native AltF4 and update bootstrap are covered only by separate tests, not this harness.

This does not measure native rendering, actual Windows/macOS responsiveness, GPU frame time, audible sound, or unlimited-length leak freedom. The separate final CPU benchmark still has worst128.023ms and fails the33.3ms first-stable gate. Separate native Linux GUI and actual PCK upgrade results must not be represented as native Windows/macOS certification.

Reproduction/evidence: soak_integrated.gd, run-soak-integrated.sh, soak-integrated.json/.log/.exit, soak-summary.json, soak-source-before.sha256 and soak-source-after.sha256; runtime-freeze.json.

Independent read-only audit confirmed continuous1531 cycle timings (each real work442–5689ms), strictly increasing115 observations, clean logs, all61 recursive script/shader hashes equal, and all64 frozen runtime/config hashes current. Verdict: scoped loop-stability evidence passes; no native/indefinite-memory claim.
