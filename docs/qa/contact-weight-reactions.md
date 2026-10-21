# Contact weight revision

## Scope

Changed production files: `scripts/combat_impact.gd` and `scripts/monster_pose_renderer.gd`.

- Contact profiles retain the exact existing `reaction_duration`, `reaction_magnitude`, and `knockback` values consumed by simulation sampling.
- Host-only hitstop is approximately 27–39 ms for light contacts, 40–49 ms for guards, 66–82 ms for heavy hits, and at most 99 ms for a true guard break. Aftershocks retain their reduced hold. Existing earned-counter/deflection minimums remain.
- `Impact.reaction` supplies independent, event-gated compression, load-transfer, and delayed follow-through envelopes. Each is one-shot and settles exactly to zero. It never produces periodic shake.
- The supported moss/crane renderer removes the pre-existing whole-root hit slide/tilt only from its draw transform, redistributing the receiver load into the intact skull, chest/shoulder, foreground leg, and trailing wing. The source/collision transform is untouched. Lower support rows stay fixed, and the skull is a rigid region with preserved distances and scale.
- Head, torso, and leg contacts emphasize different regions. The profile copies actual contact points from resolved geometry. Hero regions use those points directly. The timeline can supply an exact enemy `contact_region` and `contact_region_measured`. A missing region falls back to a clearly marked, unmeasured family/body presentation choice.
- A committed striker gets 32% of the ordinary receiver articulation, retaining its attack. A genuine guard break remains the sole full interrupt case.
- Audio has a dry initial contact transient followed by a low-mid pressure body. Heavy hits get stronger, longer body energy; guards retain a shorter hard catch. Host gains remain conservative, PCM peaks stay below 0.60, endpoints are zero, and synthesis uses a private deterministic RNG.
- Miss, evade, dodge, whiff, support, and heal resolutions never create contact sound, hitstop, or receiver impulse, even with contradictory damage metadata.

No HP/damage, move selection, gameplay RNG, attack timing, source art, head-size calibration, collision masks, camera shake, or extra flashes were changed by these two files. No human listening claim is made by automated checks.

## Automated verification

Run with a writable Godot data/cache directory, for example:

```sh
export XDG_DATA_HOME=/tmp/mountain-impact-qa/data
export XDG_CACHE_HOME=/tmp/mountain-impact-qa/cache
godot --headless --path . --script tests/test_contact_weight_reactions.gd
```

Results from this revision:

- Contact weight reactions: 25,008 checks, 0 failures
- Existing combat impact: 240 checks, 0 failures
- Existing monster renderer: 12,667 checks, 0 failures
- Counter/barrier feedback: 242 checks, 0 failures
- Geometry-source cache: 36,111 checks, 0 failures
- Monster root continuity: 4 scenarios, 0 failures
- Combat feedback host: 14 checks, 0 failures

New tests cover skull pairwise distances, fixed support rows, finite/bounded displacement, non-inverting mesh triangles, server submission, immutable source/collision data, strict contact gating, region selection, attack restraint, host-gain audio energy hierarchy, and global RNG isolation.

## Native review fixture

`tests/show_contact_weight_reactions.gd` renders production moss/crane receiver reactions at ordinary 174px display size. It is a deliberately staged sampler, not a claim of production gameplay evidence. Run under the reviewer's native display or Xvfb:

```sh
godot --path . --script tests/show_contact_weight_reactions.gd -- --output=/tmp/mountain-contact-weight
```

The resulting `contact-weight-reactions.png` compares ready/contact/50/130/250 ms for light, heavy, and guard contacts. Native capture and listening review are separate from the automated results above.
