# Crane encounter pacing revision

Godot 4.6.3-stable. Scope: chapter-three encounter balance, preserving the
accepted artwork, anatomy, contact authority and existing pacing thresholds.

## Change and diagnosis

The only production balance change is `cloud_guardian.hp`: **550 → 450**
(-18.18%). Its attack 9, defense 2, 12% ready evasion, weighted move selection,
three attack families, coefficients, windups, recoveries and landing modifier
are unchanged. Ordinary cranes remain at 240 / 245 HP. The evasive boss now has
less raw vitality than the 500-HP stone guardian, while retaining substantially
more than an ordinary crane.

The reproduced v1.3.6 baseline had 180 victories and five pacing failures.
Support's crane fight had no geometric whiffs, but seven enemy dodges and three
guards; its healing and barriers also consumed real actions. This was an
over-budget encounter for slower builds, rather than a reason to increase all
hero damage or weaken physical contact checks.

All 180 baseline rows and their source metadata exactly reproduce the archived
v1.3.6 measurement. A smaller 475-HP diagnostic still left support at 39.28s.
The 450-HP budget brings that canonical support fight into the typical range
without removing its defensive choices or the crane's evasive behavior.
Duration changes are nonlinear: the shorter fight and existing below-35%-HP
move weighting can change action overlap and subsequent defense rolls. The
HP reduction does not imply a fixed percentage speedup for every seed.

## Complete canonical campaign verification

The final integrated runtime passes **4,502 checks, zero failures, 180/180
victories**, including the whole-runtime source-freeze assertion. No threshold
was relaxed. Contact-dependent assertions naturally occur fewer times in the
shorter fights; the test source itself is byte-identical to the baseline.

| Measure | Before | After |
|---|---:|---:|
| Bosses at or below 35s | 48/60 (80%) | 54/60 (90%) |
| Ordinary fights at or below 15.5s | 110/120 (91.67%) | 110/120 (91.67%) |
| Ordinary duration range | 7.7216–16.7923s | 7.7216–16.7923s |
| Boss duration range | 21.2118–49.4725s | 19.9477–36.3390s |

The two reward seeds yield the same learned builds and encounter times here;
60 measured bosses are not 60 independent build scenarios.

| Crane boss build | Before | After | Remaining HP, before → after |
|---|---:|---:|---:|
| Sword | 23.6551s | 19.9477s | 60 → 67 |
| Fire | 44.6955s | 36.3390s | 89 → 91 |
| Guard | 40.1207s | 32.3622s | 61 → 70 |
| Control | 41.0995s | 31.4015s | 36 → 54 |
| Support | 49.4725s | 31.9318s | 100 → 105 |

Every crane fight still demonstrates all three attack forms and 17–30 enemy
contacts. Every non-crane encounter retains exactly the same measured combat
outcomes and duration. The only differing non-crane snapshot field is peaceful
cultivation progress, because the shorter battle genuinely advances less time.
Earned stronger-character replay checks remain enabled and pass.

The fire/crane encounter remains a bounded 36.34s tail rather than meeting the
35s typical goal individually. Broad combat RNG is reported separately below;
the 42s canonical envelope is not a promise about every random seed.

## Focused checks

- `test_crane_encounter_budget.gd`: 31 checks, zero failures.
- `test_enemy_attack_modules.gd`: 1,157 checks, zero failures.
- `test_monster_moves.gd`: 3,821 checks, zero failures.
- `test_campaign_builds.gd`: 505 checks, zero failures; all 180 real duels won.
- Hash comparison confirms the 93 checked combat implementation / enemy-art
  inputs remain identical to the baseline. The content difference is exactly
  the boss HP field plus its explanatory comment.

The focused budget test protects ordinary crane HP, boss attack/armor,
evasion identity, physical contact capability, all three attack coefficients
and timings, and the same vitality budget at multiple window sizes.

## Broader paired crane audit

The 32-seed-per-build diagnostic covers **160 paired chapter-three routes**,
with **640 unique duels simulated**: 320 shared ordinary fights and 160 boss
fights for each vitality budget. Both versions won all 160 complete routes.
There were no ordinary-fight failures and no new losses.

It uses genuinely earned chapter-three snapshots, carries HP, qi and keyed
cooldowns through the two ordinary fights, applies only the actual nine-second
travel recovery, then compares the old 550-HP and new 450-HP bosses from the
identical pre-boss state. Seed offsets are `index * 10007`, indices 0–31. All
five index-zero pairs reproduce the complete before/after campaign timing and
inherited HP exactly.

| Build | Median, before → after | P95, before → after | New maximum | New wins |
|---|---:|---:|---:|---:|
| Sword | 22.44 → 18.94s | 26.18 → 21.63s | 21.76s | 32/32 |
| Fire | 33.76 → 27.53s | 41.65 → 34.73s | 36.34s | 32/32 |
| Guard | 39.05 → 32.33s | 43.90 → 38.01s | 41.02s | 32/32 |
| Control | 30.45 → 24.53s | 35.60 → 30.47s | 32.90s | 32/32 |
| Support | 37.80 → 32.59s | 47.94 → 40.19s | 41.21s | 32/32 |

Across these 160 bosses, fights over 35s drop from **71 to 14**; fights over 42s
drop from **14 to zero**. Combined P95 falls from **44.89s to 37.10s**, and the
maximum from **49.47s to 41.21s**. The lowest victorious route-end HP rises from
34 to 45. Percentiles use linear interpolation on sorted durations.

This is a matched chapter-three combat diagnostic, not 160 complete campaign
replays or a guarantee for all seeds. The new broad-seed minimum is 15.31s for
the stronger sword build; there is no minimum fight timer. Defensive builds
retain occasional 38–41s tails.

## Scope and reproduction

The legacy campaign build plan invokes the existing compatibility reward path.
These combat runs do **not** validate the new corpse-search/crafting economy
or establish a zero-drop seed for that economy. The separate actual-corpse
campaign tests cover that behavior.

With writable Godot HOME/XDG directories:

```sh
godot4 --headless --path . --script tests/test_crane_encounter_budget.gd
godot4 --headless --path . --script tests/test_encounter_balance.gd -- \
  --report=/tmp/encounter-after.json
godot4 --headless --path . --script tests/test_campaign_builds.gd
godot4 --headless --path . --script tests/measure_crane_pacing.gd -- \
  --input=res://docs/qa/campaign-pacing-revision/before.json \
  --report=/tmp/crane-paired-sensitivity.json --seed-count=32
```

Raw measurements and logs: [campaign-pacing-revision](qa/campaign-pacing-revision/).
The portable diagnostic is `tests/measure_crane_pacing.gd`; the exact fixed-path
runner used for the recorded audit is retained with the raw evidence.
