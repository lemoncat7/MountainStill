# Final independent review — pure-GDScript approach pruning

2026-10-23 17:58 UTC. Scope: isolated candidate, source/evidence inspection only. No Godot, benchmark, build, production change or publication performed by reviewer.

## Decision

**Eligible for builder integration and integration QA; not publication approval and not formal-release performance acceptance.** No remaining source/evidence blocker was found for handing over these two frozen files. Preserve the default-false opt-in and exact builtin provider scope; do not widen eligibility during transfer. Re-run the established build/platform/save/update/regression gates on the integrated revision. Any new source changes invalidate the frozen-source performance attribution until rechecked.

Verified actual source SHA-256:
- `scripts/melee_contact_geometry.gd`: `22f6d2e77daa089f14eed6bd4982c89561193f42aac485201beb704464b15752`
- `scripts/duel_timeline.gd`: `c71e5419b10010fc2b3225e515fc8c448676475e7d0b6dce18a9398b9b5432f9`

This is GDScript only, not any previously explored native extension. It does not introduce a new native ABI/library delivery requirement. That does not by itself verify an exported package or updater.

## Evidence independently checked

Read FINAL_RESULTS.json, final benchmark/check/matrix/fixture logs, logic-final.json, pair-final-guard.log and pair-eviction-confirm.log. Independently recomputed all reported worst tick, median maximum, median p95 and median total statistics from the 12 raw benchmark JSON files. Verified all 12 recorded benchmark states match within each scenario, and benchmark candidate source hashes match the frozen source.

Compared complete baseline/candidate check binary files directly (not just log claims): all three identical, respective SHA-256:
- bamboo_pass/sword: `00457d579bd8fb828ae50f6262f8fe36fbd40340a7fb9e5412be4b9a4bbfd8f9`
- cloud_slope/unarmed: `e8dce2cf1a04661c9a80e77e6d73a31afec5e82c5fdf72f1ef374776d1b3761f`
- cloud_slope/fan: `7ccea41b8548e7b20bc3125dbc1d37c9a761c654be42d9adc45d03e73c70ed7a`
These include the recorded cold/warm fit/trace/provider-field checks, not proof of all possible mutable Object state.

72-scenario matrix JSON files are byte-identical, SHA `a79d60b15dba838bbad98ea4c49e7af5caa1eac3ebbc04497b2b8c216efcf888`; both logs report completion. Both source variants report source-cache 36,111 / module-registry 2,525 / melee 127,844 checks with zero failures. Logic fixture reports 12 checks / zero failures; symmetric tie preserves negative aim and early contact retains two measure calls. Both final pair logs report 69 checks / zero failures; eviction confirmation records pose-cache eviction in all 13 eviction cases, pixel eviction 26 times across the pair and front eviction twice. This confirms exercised eviction, not every cache eviction policy combination.

## Performance interpretation

Headless CPU simulation only; not rendered FPS or GPU/UI responsiveness. ABBA contains three measured trials per block, not a statistically powered hardware/general-workload guarantee.

| Scenario | A worst ms (A1 / A2) | B worst ms (B1 / B2) | Interpretation |
|---|---:|---:|---|
| bamboo_pass / sword | 51.329 / 63.736 | 53.398 / 63.548 | No definite peak improvement |
| cloud_slope / unarmed | 69.492 / 67.922 | 68.998 / 62.954 | No robust general improvement established |
| cloud_slope / fan | 105.637 / 118.497 | 53.776 / 55.787 | Clear observed peak reduction in both B blocks |

Cloud fan's observed peak reduction is roughly half, **not** a doubling of overall speed: its median total time changes only modestly. Its median p95 increases from 4.293/4.203 ms to 4.495/4.475 ms. Sword and unarmed also have some higher p95 observations. Thus do not claim stable zero performance regression or universal speedup. All measured B worst times still exceed the **33.3 ms gate**. Formal performance acceptance remains failed, despite useful progress on the targeted worst spike.

## Contract and remaining limits

As reviewed in PROOF_REVIEW.md, original operation order and strict winner comparison are preserved; the first neutral candidate cannot be pruned. Legacy/default calls evaluate fully. Only two timeline calls opt in with locally owned planning samples; exact builtin pose and strike provider identities, finite inputs, and valid Object checks are required. Explicitly opting in with external poisoned samples is outside this internal contract. Cache contents/eviction order may differ, while supported outputs must agree. Unknown/custom providers retain the old path.

Evidence covers selected deterministic scenarios and fixtures, not all arbitrary finite magnitudes, all game states, concurrent mutation or future provider implementations. Windows/macOS exported runtime behavior, graphical stability, real-device frame pacing and integrated updater/save compatibility remain builder/integration QA responsibilities. No formal release readiness or blanket stability claim follows from this review.
