MOUNTAINSTILL — SIDE-PROFILE ARTICULATED CHARACTER

Original raster artwork generated with the built-in image generation tool on
2026-10-19. Reference: this project's original blue-haired adult chibi base.
No third-party sprite sheets or copyrighted game artwork were used.
The base prompt and unmodified generation output are retained in sources/.
Alpha is preserved; prepare_sidewalk_assets.py only crops isolated atlas parts.

The runtime rig uses genuinely right-facing head, torso, arm and leg anatomy.
It is not a skewed or mirrored front-facing base. Left travel mirrors the whole
rig, including equipment and hand attachment. Natural alternation uses fixed
length hip/knee/ankle bones and a 60% stance phase with stationary world-space
contacts; the remaining 40% is a lifted swing. Phase is driven by actual distance.

New script: res://scripts/character_sidewalk.gd
Call the same update_motion and draw_avatar_layers interfaces as character_walk.
The host can be any CanvasItem and transforms are reset to identity afterward.
For a host that wraps scene transforms, _scene_set_transform is respected.

The original front-facing assets and character preview are unchanged. The side
rig is intended for walking, in-route idle, attacks and pickup approach. Keep the
same rig active in route scenes even at zero speed. Full-front seated/standing
transitions remain an integration responsibility. An immediate reverse resets
motion.turn then widens the side silhouette over about 0.11 seconds.

attack_phase (0..1), attack_amount and attack_style (sword/fan/unarmed) animate
this same side-view arm/body. pickup_amount (0..1) leans the body and extends the
hand toward a pickup. attachment_offset/attachment_rotation share that pose.
Weapon sprites remain the independent existing sword/fan assets.

Graphical proof (requires native display):
  ../godot-tools/godot-env.sh --path . --script tests/show_sidewalk_proof.gd
Saves builds/full-v1/sidewalk-proof.png. Set SIDEWALK_LIVE=1 to leave it open.
Headless invariants:
  ../godot-tools/godot-env.sh --headless --path . --script tests/test_character_sidewalk.gd

Modular slot map:
  head: head_pin or head_crown (or absent)
  chest: chest_blue or chest_jade; matching sleeve is derived ONLY from chest
  legs: legs_blue or legs_jade (or absent, revealing white shorts)
  feet: feet_cloth or feet_boots (or absent, revealing bare feet)
  weapon: unchanged existing weapon_sword / weapon_fan / absent, caller draws
No full-outfit preset is selected. Blue chest + jade trousers + boots + crown
and jade chest + blue trousers + cloth shoes + pin are covered by visual proof.

Exact duel contact support:
  combat_phase: windup / strike / contact / recovery
  phase_progress: 0..1; strike_index identifies repeated impacts
  combat_move: mist_thrust, mist_lift, mist_combo, petal_step, petal_counter,
    ember_palm, ember_pulse, stillness_palm, stillness_push
  defense_action: ready / guard / dodge / hit; reaction_amount 0..1
The full contact pose is held during the same phase in which the duel engine
resolves damage. Multi-hit strikes recoil and re-extend without teleporting the
arms. Each move returns to the same side-facing neutral stance.

12-second native live gait proof:
  ../godot-tools/godot-env.sh --path . --script tests/show_sidewalk_live.gd \
    --write-movie builds/full-v1/sidewalk-live.avi --fixed-fps 60

Attack steps and independent weapon presentation:
  actor_lunge is consumed INSIDE the side rig in screen-pixel units. Do not also
  add it to the actor's root position. It advances the pelvis and lead foot;
  the trailing foot remains planted and both leg bone lengths stay fixed.

  CharacterSidewalk.weapon_pose(motion, scale, cast_tilt, weapon_key) returns:
    offset, rotation, stowed, draw_behind, facing
  For ember/stillness palm techniques, it returns a back/hip attachment. Draw
  this independent equipped weapon BEFORE body layers (draw_behind=true), using
  its returned stowed rotation directly. Active sword rotation can add the
  caller's existing +0.22 source-art correction. Active weapons draw AFTER the
  rig. attachment_offset is ALWAYS the attacking hand; use it for palm effects.

Static close-up contact / defense / weapon-grip proof:
  ../godot-tools/godot-env.sh --path . --script tests/show_sidewalk_combat.gd
Saves builds/full-v1/sidewalk-combat.png. Contains no substitute equipment set.

Latest headless suite: 852 checks, zero failures (2026-10-19), including phase
contact holds, repeated-strike continuity, lunge rear-foot plants and stowing.

Render quality at native actor size:
All runtime side PNG import settings generate mipmaps. The rig wraps each in a
CanvasTexture using LINEAR_WITH_MIPMAPS, so small shoulder/waist/boot details do
not alias into dotted edges. This filtering is local to the actor textures and
does not change the host's texture filter or any original front-facing source.
CharacterSidewalk.filtered_weapon(original_texture) creates a similarly filtered
actor-only sword/fan copy. Cache it once at load time, never each draw.
Native side-combat screenshots were reviewed after this fix. The lifting-cut
elbow/forearm and sword now sweep ahead and upward clear of the face.

Dodge revision: pelvis retreats 27 source pixels (~7.3 screen pixels), knees
bend while ankle contacts stay fixed, and the large head tilts only 0.14 rad.
Sword wrist presentation also uses a forward-diagonal resting hold and a
waist-level forward windup. Guard/dodge wrist angles keep the blade clear of
the large face. Source grip and arm attachment remain unchanged; the rotation
blends through the same timing envelope as the pose.
