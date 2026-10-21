# Continuous combat: measured CPU performance

Measured 2026-10-20, Godot 4.6.3.stable.official.7d41c59c4.

## Result

- Final median CPU workload cost fell **24.7%**, from 3.067s to 2.310s for the same 480-tick workload.
- Tick p50: 3.869 → 2.743ms; tick p95: 10.054 → 8.191ms.
- The cache-only control preserves the baseline code except the immutable geometry-source cache and reduces median workload cost by **17.1%**. Its final state and pose checksum match baseline exactly.
- Rare action-start planning spikes remain: the longest final measured CPU tick was **263.925ms**. Lower p50/p95 must not hide this.
- This measures headless CPU simulation + pose sampling. It is **not a native rendered-frame-rate or GPU benchmark**. No native 60fps claim follows from it.

## Controlled workload

- Seed 377; mist technique; sword; bamboo-pass boss. Hero HP 420, attack 11, defense 1. Enemy HP 780, attack 8, defense 1; enemy dodge/guard probabilities zero.
- 480 ticks at 1/60s, totaling 8 simulated seconds per trial. Two whole-workload warmups followed by five measured trials in each arm.
- Each tick times Duel.advance(dt), Duel.pose(), then Rig.sample_pose(pose.hero). Setup/prewarming and event/checksum bookkeeping are outside the tick timings. Whole-workload wall cost includes small loop bookkeeping.
- All three arms use the identical benchmark source SHA-256. Complete source manifests were recorded before and verified after the run; final snapshot also matched live production after measurement.
- The baseline and cache-control are frozen projects. The cache-control differs from baseline in only scripts/melee_contact_geometry.gd. The final arm includes registered providers, choreography, shared rig samples, resource-snapshot reduction, immutable source records and packed body-polygon caching.
- Native Godot, video extraction and other planned heavy tests were confirmed stopped for this coordinated clean lane (08:26:21–08:27:22 UTC). Machine-wide exclusive CPU affinity was not imposed, so ordinary host scheduling noise remains.
- Earlier preliminary runs overlapped other activity; their numbers are excluded from every improvement claim here.

## Before / control / after

Values are medians of the five per-trial summaries. Tick percentiles use nearest-rank selection within each 480-tick trial. Each column is independently aggregated.

| Arm | 480-tick cost | Tick mean | Tick p50 | Tick p95 | Median trial maximum |
|---|---:|---:|---:|---:|---:|
| Frozen baseline | 3066.742ms | 6.384ms | 3.869ms | 10.054ms | 348.887ms |
| Baseline + source cache only | 2542.429ms | 5.292ms | 3.045ms | 9.105ms | 269.406ms |
| Final registered-provider revision | 2310.177ms | 4.809ms | 2.743ms | 8.191ms | 213.430ms |

Per-trial whole-workload costs (milliseconds):

| Trial | Baseline | Cache only | Final |
|---|---:|---:|---:|
| 1 | 3066.742 | 2557.678 | 2215.952 |
| 2 | 3083.160 | 2445.696 | 2367.482 |
| 3 | 3079.748 | 2530.981 | 2310.177 |
| 4 | 2992.266 | 2542.429 | 2223.327 |
| 5 | 2992.689 | 2614.576 | 2400.955 |

### Timed sections

| Section | Baseline total | Final total | Baseline p50 / p95 | Final p50 / p95 |
|---|---:|---:|---:|---:|
| advance | 774.762ms | 508.985ms | 0.009 / 0.102ms | 0.007 / 0.104ms |
| pose | 2264.712ms | 1745.953ms | 3.783 / 8.876ms | 2.654 / 7.514ms |
| rig | 21.809ms | 23.150ms | 0.039 / 0.086ms | 0.042 / 0.076ms |

Standalone rig sampling was slightly higher in final (median total +1.341ms across 480 ticks); this is small relative to total cost and no per-function universal speedup is claimed.

Warm setup/start median, excluded from tick cost: baseline 7.784ms; cache-only 4.449ms; final 4.318ms.

## Determinism and memory limits

- Every arm is internally deterministic over all five trials: 12 actions, 12 contacts, 25 events, hero HP 400 and enemy HP 715 after 8s; no duel finishes early.
- Baseline and cache-only pose checksum: 276.472087928993. Final checksum: 275.321133698730, reflecting intentional pose/choreography changes. Event/HP counts remain matched.
- Live Godot Object counts are unchanged within every measured trial: 1,472 → 1,472 baseline/control and 1,487 → 1,487 final. The final configuration retains provider objects at setup.
- Godot Object count does not count Dictionary/Array allocations. Static retained-byte readings include benchmark arrays/results and caches. Neither is a reliable allocation-count comparison; no reduced-allocation or leak-free claim is made.

## Remaining hot paths

A separate final instrumented run records inclusive method timings. Nested methods overlap, so shares must not be summed. Instrumentation numbers are diagnostic and are not used for the before/after speedup.

| Method | Calls | Inclusive CPU share | Longest call |
|---|---:|---:|---:|
| _apply_enemy_motion | 513 | 69.74% | 6.810ms |
| _plan_melee_approach | 6 | 19.20% | 193.228ms |
| _enemy_clearance_previews | 513 | 6.35% | 0.666ms |
| _resolve_contact | 12 | 1.90% | 8.391ms |
| battle_resource_snapshot | 515 | 1.22% | 0.262ms |
| _predicted_enemy_motion | 20 | 0.69% | 1.415ms |
| _measure_melee_contact | 8 | 0.05% | 0.201ms |

Enemy motion includes pixel/silhouette body separation and dominates sampled CPU. Melee approach fitting is less frequent but remains the largest hitch source. Fourteen neighboring clearance samples preserve physical continuity; removing them or caching dynamic defense/separation across ticks would need separate correctness proof.

Resource-snapshot calls fell from 1,914 in the baseline diagnostic run to 515 in final. Provider binding and immutable caches reduce repeated work, while string dispatch alone was not the dominant original cost.

## Geometry cache correctness

The geometry change caches only per-source image/rows, landmarks-derived rect/scale/skull and fixed registration. Current origin, rotation, motion, defense and clearance remain per sample. Records are read-only. World-coordinate changes do not create new source records.

Targeted checks after the change:

- test_geometry_source_cache.gd: 36,111 exact differential checks, 0 failures, against the frozen pre-cache source calculation; covers six routes, bosses, painted phases, reactions, fallbacks and changed world origins.
- test_monster_pose_renderer.gd: 12,667 checks, 0 failures.
- test_basic_attack_forms.gd: 971,188 checks, 0 failures.
- test_side_proportion_contract.gd: 51,380 checks, 0 failures; 5,674 motion states.

These targeted passes do not substitute for the separately run broad gameplay/native-render verification.

## Reproduction and evidence

From the desired frozen project:

    HOME=/tmp/mountain-performance XDG_DATA_HOME=/tmp/mountain-performance/.local/share XDG_CACHE_HOME=/tmp/mountain-performance/.cache godot --headless --path . --script tests/benchmark_combat_hotpath.gd -- --ticks=480 --warmups=2 --trials=5 --label=rerun --report=/absolute/path/report.json

For diagnostic inclusive timers add --profiler=res://tests/profile_duel_hotpath.gd and use one warmup plus one measured trial. Keep all rendering, extraction and heavy tests stopped during timing.

Raw reports are in [combat-performance/](combat-performance/): baseline-clean.json, cache-only-clean.json, final-clean.json, final-profile.json and clean-source-manifests.json. Benchmark code and exact cache oracle are included in tests/.
