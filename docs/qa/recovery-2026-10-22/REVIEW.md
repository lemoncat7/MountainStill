# Recovered gameplay independent audit

2026-10-22. This report covers recovered sources, not the lost 2026-10-21 artifacts.

Read-only runtime review: tactics operate on eligible equipped, cooldown-ready skills; balanced preserves first-eligible affordability behavior. Skill cost greater than qi capacity is excluded by the existing timeline. No damage/stat bonus is introduced. Incoming hero dictionaries are deep-copied at encounter start.

Report observation occurs on committed hero turn and resolved contact. It aggregates actual HP loss, actual heal, generated shield and shield absorption separately; actions/contact IDs deduplicate notifications. The host records once per encounter, before leaving fight phase, and has no new reward callback. Saved reports retain at most five entries and bound types, values, finite numeric data, text and skill counts. Attribute values are a projection of actual stats, not a separate authority; they remain a selected main-attribute view rather than every combat modifier.

Independent `edge.gd`: 105 checks, zero failures. Covers all four strategies with zero regen and qi capacities 0, 1, 80; continued basic attacks, immutable tactic snapshot, report equality with fresh formal event aggregates, five-entry history and malformed/negative/nonfinite input sanitization.

`trace.gd` is a 12-configuration baseline/recovery comparison (three weapon styles times four seeds, 45 seconds each), using the same equipped support/offense definitions. Final results recorded separately below when complete. The initial baseline run lacked imported texture caches and was rejected, then normal editor import and a clean final run were performed. The failed initial run is not passed evidence.

Not covered here: Windows/macOS native operation, final exports/update payload loading, complete campaign balance or visual layout. Other agents own those stages. No source runtime edits or publication were performed.

## Final clean trace result

Both final processes exited 0; both logs contain no ERROR messages. All 12 scenario event arrays and ending HP are byte-identical: 1,760 events total (897 contacts, 727 turn starts, 136 poise breaks). Both SHA-256: `c67799feb3b45654418c12469053b3c6c41d7c8302464b7bebc8ab87d09d2db6`. Four audited core hashes were rechecked unchanged at 07:56 UTC; see reviewed-hashes.txt.

## Real earned-build baseline

Original v1.3.10 `test_encounter_balance.gd`, without measure-only: 4,474 checks, 2 failures (exit 1). Both are the existing sword / summit_gate / gate_sentinel pacing 6.82 s below 7.0 s minimum. Report has 180 encounters, 10 campaigns and 10 powered replays. This result was re-observed on the recovered baseline, not inferred from yesterday. Awaiting recovered candidate's same report for row-by-row comparison.

Candidate earned report comparison completed: all 180 encounter rows, all 10 complete campaigns, and all 10 powered replay records are exact-equal to baseline after removing only the newly added `combat_tactic` field recursively. Both report 4,474 checks / 2 identical pre-existing pacing failures. Evidence: earned-comparison.json. This is not an all-green release gate.

## Four-tactic paired actual runs

80/80 completed and won: five real earned final-chapter boss builds from dry reward seed 61, four shared duel seeds, four tactics. Actual saved encounter stats, skills, equipment, start HP and battle resources reused unchanged except tactic. Against balanced: assault faster in 5, slower in 3, tied in 12; incoming HP damage lower in 6, higher in 1, tied in 13. Guarded mostly identical (18/20 time ties), slower in 2, damage lower in 1/higher in 1. Frugal spends less qi in 4, but takes longer in 5; incoming damage lower in 2/higher in 2. Fire build mean frugal qi 109.51 vs balanced 119.85, time 34.101 s vs 31.314 s. No policy strictly dominates all three metrics across this sample. This small sample does not establish global balance; some builds have equivalent choices and guarded has limited observed advantage. All 80 rows and driver retained as tactic-pairs.json / tactic_pairs.gd; log clean exit 0.
