# Original painted fist and animated wrist regression

Scope: restore the original painted fist at its existing size, keep the held
weapon behind it, and retain a moving, anatomically bounded wrist. No source
art, template canvas, bone length, weapon reach, combat timing, or balance value
is changed by this restoration.

## Rendering contract

- `normalized/arm.png` is byte-identical to v8: SHA-256
  `90ddb120aadcb75787371a19c22b5cb44c3c8e54de251a080517377fc6dcc3be`.
- All 38 original/normalized PNG and authoring-overlay SVG files under the
  sidewalk asset directory match v8. The 14-asset importer passes all 78
  pixel/seam checks and its read-only generated-output check.
- The active rig has no procedural holding-hand preload, socket or draw calls.
  The old implementation is retained for the historical comparison fixture.
- Sword/fan origin is the original fist joint with exactly zero local socket
  offset. Both facings and multiple actor scales retain that equality.
- The 32-row original arm mesh is split at row 24, source y=297. Avatar rows
  0–23 and front-occlusion rows 24–31 have the original UVs and skinning, without
  overlap, gaps, redrawing, resampling or resizing. The latter rows draw once
  after the weapon. The old back-hand hook draws nothing.
- The original hand/arm widths and actor scale are unchanged. Authored render
  wrist-flex tracks avoid the former wrapped blade-angle clamp flip. The
  contact-authority hand geometry remains unchanged; the new flex annotation
  does not enter that path.

## Focused checks

The machine-readable run record and individual logs are in
[`qa/original-painted-fist/`](qa/original-painted-fist/focused-summary.json).
The record includes runtime SHA-256 hashes at the start and end of the run;
they match. The painted-fist gate was rerun after separating the art-comparison
helper from the genuinely frozen v8 fixture. Its independent
[frozen-fixture rerun record](qa/original-painted-fist/frozen-fixture-rerun.json)
pins fixture SHA-256
`a585aeec1597618eb4a90b5e1503588da368b1d80ce2441405ee1f06a04f6c0b`.
All 12 focused Godot tests pass, including the unchanged
continuous-duel gate (44,746 checks), action joins (3,179 checks), and the
melee-contact geometry sweep. The proportion gate passes 51,380 checks across
5,674 frozen-baseline motion states.

The new painted-fist test exercises 8 sword/fan moves, both facings, 4 defense
states and 4 action phases at 501 samples per phase. It performs 2,311,399
checks, including all original source-row mappings, fixed grip placement,
unchanged v8 joint paths, bounded moving wrists and exact ready/guard joins.
The measured maximum within-phase hand-angle step is 0.029725 radians and the
maximum wrist-position step is 0.215131 native pixels. The authored wrist-flex
value is continuous at every exact phase join.

Existing guard and contact gates are preserved, including raw triangle
orientation, dense elbow continuity, incoming-line contact, all previous
contact-authority fields and joint values, real scheduled contacts, and the
independent continuous-duel 5-pixel motion limit. The authority dictionary
comparison omits only the two newly introduced non-geometric annotations,
`wrist_flex` and `contact_authority`; it still compares all established fields
exactly.

## Remaining limitations

1. A synthetic test that holds `reaction_amount=0.72` across an exact attack
   phase change still exposes the v8 whole-arm/root discontinuities for hit
   and dodge. The paired v8/current values are recorded in
   [`test_weapon_grip_hand.log`](qa/original-painted-fist/test_weapon_grip_hand.log).
   All 48 right-facing reported boundaries retain exactly the v8 wrist-position
   jumps; the mirrored cases are also covered by the joint equality gate.
   Hand-angle jumps are separately measured against the frozen fixture because
   the authored wrist animation deliberately changes them. At a 0.00001-radian
   comparison tolerance, 13 reported jumps are smaller, 9 are larger and 26 are
   unchanged. The largest current jump is 0.635040 radians versus the v8 maximum
   of 0.810432 radians. For example, the fan-flick dodge contact→recovery join
   increases from 0.131335 to 0.471744 radians. The largest positional wrist jump
   remains 15.655686 native pixels. These cases are reported separately rather
   than claimed to be smooth or concealed by a higher tolerance. Ready/guard
   exact joins pass. The live-duel gate remains unchanged.
2. The pre-existing static unarmed tip deviation is 1.508359 pixels, exceeding
   the separate 1-pixel visual target but remaining below the existing
   1.75-pixel regression ceiling. The 58 scheduled live unarmed contacts have
   a maximum deviation of 0.171762 pixels, with none over one pixel.
3. These numerical/source checks do not establish appearance. Native actor-size
   and enlarged visual review must still inspect the painted fist, grip
   occlusion, guard posture and actual wrist movement. This test work did not
   produce or substitute screenshots for that review.

The earlier paired boundary log used a diagnostic fixture with current joint
samplers and is superseded by the frozen-fixture rerun. It must not be used to
claim that the new hand-angle animation equals v8. The current test explicitly
checks the frozen fixture hash to prevent that comparison error recurring.

The initial wrapped-angle failure is retained in
[`pre-wrist-fix.log`](qa/original-painted-fist/pre-wrist-fix.log): a 1%-phase step
could change the hand by 0.841011 radians. The final dense test exercises the
corrected authored wrist-flex path without weakening geometry or live-motion
thresholds.
