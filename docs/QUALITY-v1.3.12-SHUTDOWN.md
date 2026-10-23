# Native-close cleanup fix

Independent integrated native GUI reproduced ObjectDB WARNING + ResourceCache ERROR after ordinary creek fights → stone practice → exit → AltF4. `quality-native-qa/second-verbose.log` identifies retained AudioStreamWAV/AudioStreamPlaybackWAV (ref1), **music.wav and equip.wav**.

Cause: host connected Window.close_requested but left SceneTree.auto_accept_quit=true. Native automatic quit could bypass existing .12s scene-free/.35s tree-quit cleanup and the failed-save refusal. `audio-immediate.log` reproduces the same music.wav leak with actual headless audio + immediate tree.quit; delayed `audio.log` does not leak.

Minimal runtime change: cultivation.gd _ready sets auto_accept_quit=false. Existing save gate/practice restore/audio stop/timers now own native close. No combat, save schema, update ABI or assets changed.

Final cultivation SHA256: ebf19da98e3218cb4b497d252ade06e99a83bfd36276f2a119bff411262dd729.

Targeted regression:
- tests/test_shutdown_audio.gd: actual audio and modeled WM auto-quit, fixed exit0/no warning; mechanic baseline deterministic failure exit1 because auto_accept_quit=true. Leak itself is intermittent and not needed for assertion.
- tests/test_shutdown_lifecycle.gd: **11 checks/0 failures**, exit0/no warning. Failed-save close stays alive beyond timer, practice close restores formal duel/pause before saving, no trial report/reward, repeated close idempotent, scene freed before final tree.quit.

All runs use isolated XDG/save roots. Independent native post-fix verification belongs to verify_integrated_quality_gui; no inferred Windows/macOS coverage. Deliberate immediate-quit probe is a negative diagnostic, not a passing gate. No log suppression.

Independent native confirmation (GUI agent, 2026-10-22 10:58 UTC): `postfix-verbose.log` was launched after verifying ebf19da hash; tested 960-wide three practices (balanced/aggressive/strip), finished trial and native global AltF4. Normal XR cleanup, **no ObjectDB/resource leak**. `fresh-verbose.log` with leak was a pre-fix in-memory process launched at 10:51:35; it is retained as failing evidence, not counted as post-fix. A final bootstrap reopen/close remains with GUI agent.

Final integrated verification: the later real bootstrap reopen/AltF4 also passed, and all three native rare-reward-run exits were clean. See QUALITY-v1.3.12-NATIVE-QA.md and QUALITY-v1.3.12-RARE-REWARD-NATIVE-QA.md; the preceding timed progress note is historical.
