# v1.3.5 — guard, gripping hands and shared equipment slots

## Scope

Source-only revision of v1.3.4. Existing head scale 0.86, torso width 1.30,
short-neck mapping, inventory portrait root and its independently floating
weapon are retained. Loot/search/crafting and the faint translucent aqua active
barrier remain intact. No executable builds were generated.

### Guard and recovery

Registered sword, fan and unarmed modules supply their own guard tracks. Sword
catch staging places the real blade on the incoming line, fits both fixed-length
arm chains to the common garment sockets, bends the planted stance, and tucks
the head around its existing neck pivot. The initial catch is unchanged by the
subsequent small outward edge roll. The torso/shoulder yields, the brace is held,
and the release blends into the next action. Committed striking hands retain
their action; simultaneous defenses may use the off hand. Stowed spell weapons
are not claimed as sword interceptions.

Rendering has separate samples from authoritative contact geometry. Damage,
hit/miss/evasion, cooldown, stamina, qi and counter eligibility still come from
the existing duel. The render-only first-strike progression is p^1.5: it keeps
both endpoints but gives anticipation followed by acceleration.

### Hands and equipment

The near hand has an authored dorsal/metacarpal plane, knuckle ridge and correctly
sided thumb. Palm and edge views are independent shapes, selected by anatomical
hand side and axial roll, not by blade angle. Forearm/wrist orientation remains
independent of weapon rotation. The hand origin stays at the anatomical wrist;
the actual handle uses an internal socket from `weapon_grip_hand.gd`. The sword's
rear hilt is behind its holding forearm, with the blade/crossguard in front and
the hand wrapping between passes. Fan variants use a pivot pinch. Unarmed and
inventory hands are not replaced with the sword fist.

All 14 current character/equipment slices use canonical family canvases and
joint/overlap positions. Legacy sleeve registration and trouser/cuff adjustments
were baked once by the importer. Runtime clothing paths have no individual blue
or jade sleeve offsets. Originals are retained. The template includes transparent
blank PNGs, SVG guides, JSON/GDScript constants, a reproducible normalizer and an
authoring guide. See [the template specification](EQUIPMENT_ATTACHMENT_TEMPLATE.md).

### Reciprocal contact weight

Actual resolved contacts drive light/heavy/blocked hitstop, articulated receiver
compression and recovery, and region-sensitive head/body/limb responses. Current
articulated monster coverage is the moss beast and crane; other families retain
their existing renderers. Planted support rows stay fixed while receiving body
parts move. Hero head/torso reactions preserve active attack authority. Misses,
dodges, heals and unsupported events cannot generate new impact feedback or
extra damage. Contact audio uses the resolved event and local random variation,
not the combat RNG. Audio was signal/track checked, not claimed as listened to.

## Native evidence

- Enlarged no-VFX before/after guard sheet, using the same input state.
- Enlarged clothed sword raised guard, low catch and thrust; closed/open fan;
  unarmed control. Independent image review found continuous wrists, dorsal near
  hands and correct thumb/shaft relationships in these sampled holds. Static
  evidence is not full-motion acceptance.
- Mixed blue/jade outfits, cloth shoes/boots and head ornaments on the canonical
  template, rendered natively.
- Native Godot 4.6.3 MovieWriter recording: 1200×320, 60fps, ordinary engine speed,
  earned boss checkpoints. No enemy statistics, outcome, inventory or hit rules
  are overridden. The edited review retains normal-speed examples and explicitly
  labeled 0.5× silent repeats, with a simultaneous 2× spatial detail crop from
  the same native frames. Hero hits, sword guard and crane direct hits are shown.
  Moss aftershock damage is area damage and is not presented as a physical peck.

The earlier palm-facing grip image was rejected and is superseded. These
corrections still need the user's subjective motion review.

## Validation and limitations

- 61/61 ordinary suites passed. After the final narrow guard-target/edge-roll
  changes, 15 affected suites passed again with runtime files frozen. The final
  stale-tail regression was also rerun independently: 193,327 checks, no failures.
- 78 importer pixel/seam checks and 13,128 equipment registration/motion checks;
  8,094 hand checks; 1,307,196 socket/mesh continuity checks passed.
- 44,746 continuous-duel checks passed without relaxing the 5px no-pop gate;
  51,380 proportion/authority checks compare 5,674 states to the frozen old rig.
- Damage/resource/action snapshots match the prior implementation across 1,231
  rows. Native replay matches 33 recorded contacts exactly (apart from allowed
  floating-point serialization roundoff below 1e-9 in time/qi).
- All 14 fully held sword impact catches clear the painted face; maximum
  body-surface distance is 2.964 native pixels. The early-strike blend sample is
  3.031px. Committed/off-hand and stowed actions are classified separately.
- A 2ms sweep covers 19 guard windows/848 full-hold samples. Resolved held poses
  are clear; one later raising/follow-through path briefly projects the blade edge over
  the cheek/chin for about 4ms around a strike that resolves as WHIFF (maximum
  36 source-alpha samples at <=0.272 native-pixel spacing, not 36 screen pixels).
  Wrist steps remain below0.75px at2ms spacing. There is no hilt overlap or fake
  blocked-contact claim for this transient crossing.
- Frozen campaign rerun: 4,523 checks, 180 victories, exactly the five inherited
  pacing failures listed below. No source-change failure in that final run.
- Final native capture is 34.05s at 1200x320/60fps; source hashes match the packaged
  runtime, capture reports `failed=false`, and engine time scale is 1.0. The
  edited review is 19.53s at 1200x780 with normal-speed and labeled slow repeats.

Machine-readable results, source hashes and a portable captured-contact replay
fixture are in `docs/qa-v1.3.5/`. The overall build is **not** labeled all-green.
The pre-existing campaign pacing failures are not waived or rebalanced: four
crane boss runs exceed 42s (fire 44.6955s; support 49.4725s, two seeds each), and
80% of boss fights finish below 35s against an 85% threshold. Other campaign
outcomes remain separately reported, rather than calling this an all-green build.

The shared rig is a segmented side-view cutout, not a full 3D hand or universal
animation library. Hands simplify at native display size; all independent held
weapon orientations should continue using the same hand-side/view/socket
contract. No user acceptance of final motion is inferred from automated tests.
