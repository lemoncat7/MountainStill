# Encounter continuity and painted-body audit

## Concrete causes found

- Route travel previously ran at a fixed 48 screen pixels/second and used `move_toward` to stop abruptly at combat. Walking was separately fed a hard-coded 48 pixels/second, so the feet could continue stepping through a stopped landscape.
- The next monster and opportunity cairn were only drawn when their active phase began. Their screen coordinates were already inside the viewport, so they appeared suddenly. Pending opportunity restoration could also reassign the visible route distance during monster preparation.
- All monster poses were fitted by their complete 256 × 256 canvas. That canvas contains different amounts of padding, wings, tails, foliage and projectiles. For example, the moon spirit's idle alpha height is 204 pixels while its horizontal attack alpha height is 124 pixels. Equalizing those heights would incorrectly enlarge the flying pose; the skull is the useful shared anatomical landmark.
- The original effects were mostly 1–2 pixel translucent strokes rendered before the monster. Painted enemy pixels covered the contact flash. The weapon artwork used `weapon_pose`, while the old trail independently approximated its rotation.

## Changes

`route_motion.gd` integrates one screen-space velocity at bounded substeps. Cruise is 48 pixels/second, with 108 pixels/second² acceleration and braking. The exact frame displacement feeds the walk cycle. Fight endpoints are returned as the exact authored route distance after the subpixel braking integration. The finite panorama is no longer independently clamped; all visible props and creatures use the same distance.

Every unclaimed monster is drawn at a persistent world address from route arrival. Preparing its encounter changes which actor owns the display, not its position. The stone cairn stays in the landscape before and after an opportunity. The one-time 18% choice is resolved after the second victory; an empty shrine is passed without braking. A pending choice still stops at the actual 680-unit landmark, with no timeout or extra random roll. Resume position changes happen before the route is revealed.

`assets/cultivation/beasts/body-landmarks.json` records the actual alpha bounds, a painted face/skull landmark rectangle, an area-equivalent skull diameter and the original ground anchor for every one of the 36 route poses. `beast_presentation.gd` normalizes each pose to its own normal/boss idle skull diameter. The anchor is transformed with the image; crouching and flight retain their different silhouette heights. Original bitmap assets are unchanged. Attack front extents are measured from the normalized attack silhouette and passed to the duel's contact-distance model.

The host consumes each actor's own combat phase. Weapon effects use the same grip and rotation as the equipped artwork. Filled, tapered cream/cyan, pink, ember and water-colored ribbons remain visible in the 1200 × 320 strip. Foreground contact bursts are created only by actual damage or guard events; dodges never generate a hit flash. Filled ribbons use nondegenerate triangles, including straight thrusts and curved wrist paths.

## Regressions

Run:

- `godot --headless --path . --script tests/test_route_body_continuity.gd`
- `godot --headless --path . --script tests/test_all_route_transitions.gd`
- `godot --headless --path . --script tests/test_portal_transitions.gd`

The continuity test exercises 30/60/120 FPS displacement and acceleration limits, exact stopping and no drift, actual painted-pixel coverage of all skull landmarks, invariant normalized skull size and ground anchors, persistent next-monster positioning, displacement-driven gait, actual dodge/hit effects, and pending versus empty shrine approaches without random rerolls.

The measured-landmark checks verify the implementation contract. Native normal-speed captures remain necessary for perceptual body scale, attack readability and transparent desktop presentation; automated checks alone do not establish those qualities.
