# Independent side-proportion QA

Final candidate: head scale 0.86, settled down 15 source units, with neck taper from −225 to −189; torso width 1.30, arms 1.20, legs 1.18, hand/foot width 1.08.

## Visual findings

Reviewed original `qa/comparison` and corrected `qa/neck-corrected` mixed and bare sheets, both zoom and native. The smaller skull and wider trunk/limbs reduce top-heaviness. The corrected neck is visibly shorter than the first proportion pass and remains connected in all four displayed states: idle, walking, attack, and guard. No new detached equipment, visible neck/collar gap, face aspect distortion, wrist/sword displacement, knee seam, or floating sole was visible in those samples.

These are limited native-render samples, not an exhaustive animation or every-outfit judgment. The displayed mixed gear is pin / jade chest / blue legs / boots. Other gear registration is covered structurally by shared canvas dimensions and transform tests, rather than a native screenshot of every combination.

## New independent regression

`tests/test_side_proportion_contract.gd`: 51,380 checks, zero failures; 5,674 motion states compared with frozen `tests/character_sidewalk_before.gd`. The baseline copy was byte-identical to the original guard/evasion rig at review time.

The contract covers:
- Exact original pose dictionaries, wrist attachments, weapon pose/reach, and fixed bone lengths across basic attacks, arts/spells, guards, dodges, hits, both facings, and walking
- Width-only arm/leg skin transforms and the unchanged authored wrist and sole-center paths
- Skull/accessory registration, fixed lower-neck endpoint, rigid face/hair scaling above the taper, and noninverted head mesh strips
- Transformed head/torso physical-clearance samples and agreement with rendered neck mesh within 0.25 native pixels
- Blade clearance against actual transformed head alpha, inverted through the 32-strip rendered mesh

The existing `test_basic_attack_forms.gd` blade-alpha test still assumes the former head rectangle. Its passing result alone is therefore insufficient for the revised head; the new contract fills that gap.

## Existing focused suite

All of these completed with zero failures:
- Sidewalk rig: 852 checks (before neck-settle; new contract independently covers final skeletal invariants)
- Basic attack forms: 971,188 checks
- Guard/evasion visuals: 9,155 checks
- Sword guard render: 6,841 checks
- Evasion stat: 674 checks
- Evasion UI: 113 checks
- Equipment: 290 checks
- Combat pose: 23,856 checks
- Motion transitions: 85 checks
- Route/body continuity: 3,935 checks
- Monster-root continuity: four scenarios
- Manual portrait grip: 271 checks (earlier portrait implementation; separate inventory change is outside this QA scope)

Final settled-neck melee-contact geometry: 127,795 checks, zero failures; 497 real hits, 20 whiffs, minimum body clearance 3.000, maximum 60 Hz approach step 2.318.
Pre-settle melee geometry: 125,770 checks, zero failures; 497 real hits, 20 whiffs, minimum body clearance 3.000, maximum 60 Hz approach step 2.319.

## Isolation and limits

Tests used Godot 4.6.3 headless and isolated HOME / XDG paths under `qa/independent-home`; logs are in this directory. No runtime files were changed by this reviewer. The independent proportion test was added; subsequently only the stale head-envelope expectation in `test_monster_moves.gd` was updated. Shared desktop and real saves were not used.

No full campaign pacing test was run. The known baseline aggregate 83.3 versus 85 issue was not retuned. Physical artwork and enemy parameters were not modified in this QA work.

## Candidate hashes

- `scripts/character_sidewalk.gd`: `6e849d4eeef42a09bcbf8bb470cebc28d75f7d3078e3f20cb3080f610c7fd888`
- `scripts/melee_contact_geometry.gd`: `84fa008cbbf3a427e5a93480cadab6a606ad907cf1c7884438b2717644cf1965`
- `tests/test_side_proportion_contract.gd`: `bc230a31d07a406bd2e5ac11ac6108e5e35c00f743eb9bb6ba772ceda4902cbc`

## Subsequent full-suite findings

The final full suite exposed one stale head-envelope assertion and the pacing issue documented in `PACING_COMPARISON.md`. The old `test_monster_moves.gd` required the skull top to stay below an absolute −95 world-coordinate height; the approved smaller, settled head invalidates that fixed-coordinate assumption. The replacement independently reconstructs the opaque authored core, requires every transformed sample in the physical envelope, preserves dense upper-face samples, and checks that the painted tall bun remains above and excluded from the core. No physical contract or pacing threshold was widened.

Focused reruns after this test-only update:
- Monster choreography: 3,820 checks, zero failures
- Side proportion contract: 51,380 checks, zero failures across 5,674 states

Balance does not fully pass: support/cloud_guardian rises from 37.0589 to 42.3868 seconds in both seeds, 0.3868 seconds beyond the unchanged 42-second bound. All 180 encounters still win. The inherited aggregate remains 50/60 bosses within 35 seconds (83.33%). See the separate bounded report comparison for measured action/resource/contact changes and causal limitations.
