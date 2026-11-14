# Independent review — combat qi comparison increment

Reviewed against origin/main 65a44bf. Runtime delta is two display rows in equipment_comparison_pages.gd; tests extend readable_rows. Review hashes are retained alongside this report.

No blocking runtime correctness finding. Both fields come from existing equipment_comparison before/after stats snapshots; DuelTimeline consumes the same combat_qi_max and combat_qi_regen fields and applies the same caps. The preview is detached from live state, and no mutation, persistence schema or update protocol change is introduced by these rows. Two rows preserve section/page alignment and existing controls. Existing UI coverage checks all pages, readable text, geometry, same/full inventory, method variants, explicit equip and stale combat lock; independent focus test checks real Viewport dispatch and formal state/RNG immutability.

Six independent Linux headless tests passed, 14,593 checks, zero failures: equipment comparison UI 13,592; state 153; focus 21; cache 5; battle qi state 272; battle qi timeline 550. Raw stdout and exit/timing records are in this directory. No script/error/failure markers were observed in these logs.

Integration action: native_platform_smoke.py and test_native_platform_smoke.py use an exact old focus marker of 19 checks; update both to the observed 21 without weakening exact-marker validation before native CI. This was sent to the implementation owner.

Nonblocking test robustness suggestion: the added source-text check only looks for the character 不. Checking the specific no-refill / growth-qi distinction phrases would better protect the intended explanation.

Cache observation: 180 frames 2979.90 ms; full inventory quote mean 0.395 ms. This single bounded Linux headless observation proves neither performance improvement nor GPU/frame-budget or long-term stability. Independent review does not provide Windows/macOS graphical, audio, DPI, transparency, signing or physical-device acceptance. Historical sword pacing failures are outside these six tests; full regression remains the implementation owner's responsibility.

## Follow-up integration review

The implementation owner strengthened text assertions to the actual no-refill / growth-qi distinction, updated the focus marker to exact 21, and added the comparison UI exact 13592 marker to native smoke. Missing, duplicate, wrong-count, extra text, nonzero exit and error/leak outputs are rejected. Previous 31 native source cases remain and the new case increases the set to 32. Default 60-second timeout and the sole prior 180-second contact exception are unchanged. No resource/RSS/GUI acceptance threshold was relaxed.

Version metadata changes to 1.3.41 and forward-update fixtures to 1.3.42-test.1 preserve the intended newer-version activation path. Native installed-package, GUI, stability and representative compatibility pins were updated to the actual local final ZIP/PCK/manifest sizes and SHA-256; 12 binding checks passed, recorded in package-pin-verification.json. Historical old v1.3.26 pins remain unchanged. This verifies local-byte bindings, not public release downloads or target-platform execution.

Seven Python modules ran in independent processes and passed: native source marker tests 30, package driver 9, package stability 13, GUI driver 40, input driver 28, compatibility 8, compatibility session 20 (148 total). Exact logs and exits are in integration-results.json and per-module logs.

Minor coverage issue found and reported: unsupported-version list in native_compat_session_test.py duplicated 1.3.41-test.1 after replacement; retain distinct future-candidate rejection with 1.3.42-test.1. No blocking implementation defect found. Full regression, GUI teardown leak investigation, remote native checks and Library persistence are owned by the implementation parent and are not certified by this review.
