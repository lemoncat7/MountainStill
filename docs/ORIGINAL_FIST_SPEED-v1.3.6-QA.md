# v1.3.6 — original painted fist and effective combat speed

This source-only revision follows the requested simplification: retain the
original painted fist, put the real weapon behind it, and let the wrist move.
It also implements the separately requested actual speed-stat effect on both
combatants. No installable binaries were built.

## Visible change

The existing normalized arm PNG is unchanged. Its original 32-row skinned mesh
is split at an existing row boundary: the final eight rows draw once after the
held sword/fan. No miniature procedural hand replaces the fist, and no hand
scaling or new painted pixels are introduced. The weapon shares the original
fist joint. Sword rear-hilt occlusion remains behind the forearm. Unarmed,
stowed and independent inventory-portrait behavior keep their own paths.

Registered sword/fan modules now author bounded wrist flexion continuously.
This removes a wrapped-weapon-heading clamp that could flip a wrist during a
single attack. Hand artwork, shoulder/sleeve template and accepted proportions
remain unchanged. The contact-authority rig retains its prior geometry.

## Deliberate mechanics change

Effective speed 100 is the original timing. Both combatants use a cached rate
`clamp(speed/100, .65, 1.60)` for action phases and between-action intervals.
Existing earned haste migrates into speed, without multiplying twice. Light
and heavy attacks retain their original relative base timing. Cooldowns,
opening AI wait, status/control durations and real-time local hitstop remain
independent. Attributes show effective speed and the baseline.

Unlike the previous presentation-only work, this deliberately changes timing
for non-baseline speed, including the action hold/interval omissions in the
old haste path. Full contracts, safeguards, examples and inherited campaign
limits are in [the speed report](combat-regression/speed/README.md).

## Native verification

- Same-joint-pose and same-scale old hand versus original-fist sheet. The old
  hand painter uses the current shared joint sampler only for this diagnostic;
  the separate frozen-v8 fixture remains byte-identical and hash-pinned.
- Native Godot 4.6.3 wrist inspection: 301 frames, 5.0167s, 1200×680 at 60fps.
  Upper views are 5.2×, lower views are native actor size. This is explicitly
  labeled action-phase inspection, not speed-stat evidence. The video is silent.
- Native speed comparison: same earned checkpoint, opponent, equipment, all
  input fields except speed, and seed. Both actors are speed 100 on top and
  speed 140 below. Both captures use engine time scale 1, unmodified elapsed
  seconds, actual contact resolution and original HP/damage. Each reports
  `failed=false`, `source_frozen=true`; runtime hashes match this source.
  The stacked review is 8.05s, 1200×640 at 60fps and silent to avoid overlapping
  two simultaneous soundtracks.
- In the 8.0167s observed interval, hero contacts increase from 6 to 9 and enemy
  contacts from 5 to 6. First hero contact is .580000s versus .414286s; first
  enemy contact is 1.340000s versus 1.008571s. Actual guards and whiffs remain.
  This demonstrates event timing, not a promise that every faster encounter
  yields proportionally more damage or a shorter fight.

Native input/event fixtures and the verified same-input assertion are under
`docs/qa-v1.3.6/`. Contact sound synchronization retains prior resolved-event
behavior; these silent review edits do not constitute listening verification.

## Results and remaining limits

See [painted-fist validation](ORIGINAL_PAINTED_FIST_QA.md) for source-pixel,
mesh-row, fixed-socket, wrist continuity and live contact checks. The final
ordinary regression summary is in `qa-v1.3.6/regression-results.json`.
All 63 ordinary suites passed against frozen runtime/assets. Test-only audit
updates separated the immutable v8 baseline from the same-pose art diagnostic;
the affected hash-pinned fist gate passed again after those updates, with
2,311,399 checks. The raw aggregate retains its test-source-change warning.
Final campaign verification: 4,551 checks, 180 victories, five known failures.
Baseline-speed mechanics match all 1,231 v8 event rows exactly. The separate
speed suite has 881 checks; actual-host pause/hitstop adds 16.

The campaign retains five inherited pacing failures: fire/crane 44.6955s and
support/crane 49.4725s exceed 42s for each of two seeds; 80% of boss fights finish
within 35s versus the 85% goal. No pacing thresholds or enemy stats were retuned.

Known limitations are explicit: synthetic held hit/dodge reactions crossing
exact phase joins retain whole-arm/root jumps; authored wrist changes do not
fix those whole-body transitions. Static unarmed tip deviation remains 1.508px
in the extreme synthetic case, while 58 live contacts remain within .172px.
The near-edge-on guarded fan is less readable at native size. Sampled native
frames show no disconnected fist/wrist seam, but user motion acceptance is
still pending.
