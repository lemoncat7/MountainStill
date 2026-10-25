# Retained-host mixed stability harness — 2026-10-25

Status: **the bounded 60-minute Linux source/headless run passed**. It completed 95 mixed cycles (one warmup plus 94 post-baseline), 5,807 checks, 96 explicit verified save calls and final actual host reload, with 0 failures and exit 0. The final settled sample reached 3,616.408 seconds after warmup; external monotonic wall time was 3,662.834 seconds. This is not native Windows/macOS GUI or formal-release acceptance.

This is a **Linux source/headless** test using Godot 4.6.3, not native Windows/macOS GUI, physical input, rendered graphics, audio quality, or full-release certification. Runtime production code and native package pins are unchanged from `00db9460fafdb6dfbf3be8d26bc1a94530507c1a`.

## Scope and fixed gates

`tests/test_retained_mixed_stability.gd` retains one normal host, State and formal Duel, using a unique disposable save. It uses actual engine frames, `Engine.time_scale == 1`, and monotonic real-time waits. It never calls `_process` manually or `new_game` per cycle. Ordinary missing-file initialization is allowed; the host is rebuilt only for final disk reload.

Each cycle opens/closes wardrobe, practice, alchemy and settings panels; completes an unarmed/bamboo-sprite practice; repeats and pauses/resumes/cancels practice; checks weak references to its session, Duel, providers and replaced controls; resumes formal cultivation; travels normally into the first bamboo fight; globally pauses; presses the actual retreat control signal; returns home while paused; legally abandons the retained route through `State.cancel_stage`; and writes/checks the actual atomic save and backup. This narrow scenario does not establish every style/enemy/chapter or naturally earned campaign coverage.

Formal snapshots remain exact within memory except `saved_at`. Disk comparisons normalize both JSON representations through the same parser/serializer because Godot parses integer tokens as floats; no field is omitted beyond `saved_at` and no numeric tolerance is used. Final reload is globally paused, must load the actual disk file without repair/recovery/offline awards, and must match the full canonical snapshot.

Settled measurements follow one real second plus four deferred frames while formal simulation is paused. The first complete cycle warms all selected paths and fixes the baseline. Subsequent limits are immutable:

- Object count: baseline + 64.
- Resources: baseline + 8.
- Nodes and orphan nodes: no increase.
- Engine static memory: baseline + 32 MiB.
- External process RSS: baseline + 128 MiB (supplementary, not the sole leak oracle).

The requested duration starts **after** that first settled baseline. A 3,600-second run therefore retains the host for longer than one hour; at least three full cycles are required. Timing, counts, weak-reference assertions and serialized state checks all remain separate gates. These are bounded stability observations, not proof that no possible leak exists.

Run on an isolated Linux source checkout:

```sh
python3 tools/run_retained_mixed_stability.py --output /absolute/new/output-dir --duration 120
python3 tools/run_retained_mixed_stability.py --output /absolute/new/long-run-dir --duration 3600
```

The runner refuses an existing output directory, supplies workspace-local XDG config/cache/data, keeps engine/raw process logs and exact invocation identity, and applies a monotonic watchdog. No credentials, remote CI, package rebuild, or publication is involved.

## Final observed evidence

| Settled metric | First baseline | Maximum increase | Fixed allowance |
| --- | ---: | ---: | ---: |
| Objects | 2,229 | 0 | +64 |
| Resources | 172 | 0 | +8 |
| Nodes | 48 | 0 | +0 |
| Orphan nodes | 0 | 0 | +0 |
| Engine static memory | 274,822,841 bytes | 1,273,628 bytes | +33,554,432 bytes |
| Correlated process RSS | 400,273,408 bytes | 856,064 bytes | +134,217,728 bytes |

Independent final read-only audit recomputed the stored summary exactly from the raw evidence, checked executed-source identity, and validated the final save/backup. All 95 settled samples passed. There were 3,656 external one-second process samples; maximum RSS across all sampled phases was 406,196,224 bytes. Settled-correlated RSS uses nearest shared-clock observations, with maximum timestamp separation 0.497 seconds; it is not an exact instantaneous measurement. The final engine result includes 3,620.566 post-warmup seconds because teardown/reload adds time after the last settled sample. The 3,600-second requirement was already met before teardown.

The formal Duel, State and host identities remain unchanged throughout cycles. Trial weak-reference releases and replaced controls were checked after deferred/tween settle. Every cycle used a genuine but brief advancing formal fight followed promptly by global pause and retreat; this is not full-fight damage, victory, loot, all-enemy, or campaign coverage. Final reload matched the full JSON-canonical saved state, stayed paused at home, and reported loaded with no recovery/repair/migration/invalid-clock/save error or offline award.

Additional evidence: final short preflight 196 checks/0 failures over 3 cycles, 4 explicit verified saves and reload; unchanged practice lifetime regression 237 checks/0 failures, including its deliberately retained-session negative control; unchanged paused-retreat regression 376 checks/0 failures; 21 offline monitor unit tests passed. The earlier corrected runtime preflight passed 317 checks/0 failures but its old RSS alignment is explicitly superseded by the final monitor.

Runtime source identity: all 1,294 tracked blobs match main `00db9460fafdb6dfbf3be8d26bc1a94530507c1a`, including both current native-package pin files. Only a test harness, its external runner/unit tests, and this report were added. No production code, native package, remote CI, release, or public repository state was changed in this work.

Frozen long-run harness SHA-256: `34ce34372f70ceba5a8b5b81394dd44491c57be0ed2bf40596b10db647e1d3d6`.
Frozen external runner SHA-256: `e65c950761155bc5b66b469b3aee63ad1bf70cd48036bf61e9ee18a94e27db09`.

Raw logs, timed process samples, invocation, frozen executed sources, actual disposable save/backup, preflight failures, unit results, independent review, source manifest and early Library verification receipts accompany the complete source in the QA archive. The hour run made no production change or threshold adjustment after starting.

## Preserved preflight findings

- Initial editor import could not create the default `/home/agent/.config/godot`; stopped and rerun with explicit writable XDG directories. Original error log preserved.
- Initial harness parse rejected inference of `WeakRef` from a Variant; explicit typing fixed the test only. Original parse log preserved.
- Independent review caught the legitimate first-practice-page `arrival_seen` transition and report history cap of five before preflight. Warmup acknowledges the tutorial once and assertions use the actual cap.
- Preflights 1 and 2 stopped on disk snapshot string equality. Diagnostic raw witnesses were semantically identical JSON; only `1` versus `1.0` token formatting differed. Independent review confirmed this before symmetric canonicalization. Both failed runs and raw witnesses remain in QA.
- Independent review required full post-warmup timing, strict successful reload checks, external RSS timestamp alignment, and watchdog escalation. These are harness integrity fixes, not gameplay fixes.

Existing release gates are not waived: the unchanged 33.3 ms CPU budget and two known summit-sword balance assertions remain open. Native GUI/DPI/audio/GPU/FPS and broader long-term reliability and crash recovery remain unverified. Unsigned/ad-hoc disclosure is unchanged; no signing certificate or paid service was purchased.
