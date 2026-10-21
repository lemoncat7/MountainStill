extends SceneTree
## Original painted-fist contract. Native visual review is still required.
## The v8 fixture is historical evidence only; it is not a live drawing path.
const Rig := preload("res://scripts/character_sidewalk.gd")
const Before := preload("res://tests/fixtures/character_sidewalk_v135.gd")
const Template := preload("res://assets/cultivation/sidewalk/template.gd")
const V8_RIG_SHA256 := "a585aeec1597618eb4a90b5e1503588da368b1d80ce2441405ee1f06a04f6c0b"
const V8_ARM_SHA256 := "90ddb120aadcb75787371a19c22b5cb44c3c8e54de251a080517377fc6dcc3be"
const MOVES := {
	"sword": ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift", "weapon_sword_pierce"],
	"fan": ["basic_fan_sweep", "basic_fan_flick", "basic_fan_return", "weapon_fan_return"]
}
const PHASES := ["windup", "strike", "contact", "recovery"]
const DENSE_STEPS := 500
var checks := 0
var failures: Dictionary = {}
var max_hand_step := 0.0
var max_hand_excursion := 0.0
var max_wrist_step_px := 0.0
var wrist_jumps: Array = []
var synthetic_reaction_joins: Array = []

func _initialize() -> void:
	_test_original_payload_and_draw_path()
	_test_mesh_partition()
	_test_moving_fist_and_weapon()
	for failure in failures:
		push_error(str(failure) + " (%d occurrences)" % int(failures[failure]))
	print("WEAPON_GRIP_HAND original painted fist: %d checks, %d distinct failures" % [checks, failures.size()])
	print("Painted fist motion: max_hand_step_rad=%.6f max_hand_excursion_rad=%.6f max_wrist_step_px=%.6f" % [max_hand_step, max_hand_excursion, max_wrist_step_px])
	if not wrist_jumps.is_empty(): print("PAINTED_FIST_WRIST_JUMPS ", JSON.stringify(wrist_jumps))
	if not synthetic_reaction_joins.is_empty(): print("SYNTHETIC_REACTION_JOINS ", JSON.stringify(synthetic_reaction_joins))
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures[reason] = int(failures.get(reason, 0)) + 1

func _function(source: String, name: String) -> String:
	var start := source.find("func " + name + "(")
	if start < 0: return ""
	var end := source.find("\nfunc ", start + 1)
	var static_end := source.find("\nstatic func ", start + 1)
	if end < 0 or (static_end >= 0 and static_end < end): end = static_end
	return source.substr(start, source.length() - start if end < 0 else end - start)

func _test_original_payload_and_draw_path() -> void:
	expect(FileAccess.get_sha256("res://tests/fixtures/character_sidewalk_v135.gd") == V8_RIG_SHA256, "v8 baseline fixture remains byte-identical to the frozen v8 runtime")
	var arm_path := Template.ASSET_ROOT + "arm.png"
	expect(FileAccess.get_sha256(arm_path) == V8_ARM_SHA256, "normalized arm PNG remains byte-identical to the v8 painted source")
	var image := Image.new()
	expect(image.load_png_from_buffer(FileAccess.get_file_as_bytes(arm_path)) == OK, "original painted arm PNG decodes")
	expect(image.get_size() == Vector2i(219, 396), "painted arm keeps its original padded canvas")
	var source := FileAccess.get_file_as_string("res://scripts/character_sidewalk.gd")
	var host := FileAccess.get_file_as_string("res://scripts/cultivation.gd")
	expect(not source.contains("GripHand") and not source.contains("weapon_grip_hand.gd"), "live rig has no procedural holding-hand preload, socket, or draw call")
	for file in DirAccess.get_files_at("res://scripts"):
		if not file.ends_with(".gd") or file == "weapon_grip_hand.gd": continue
		var runtime := FileAccess.get_file_as_string("res://scripts/" + file)
		expect(not runtime.contains('preload("res://scripts/weapon_grip_hand.gd")') and not runtime.contains('load("res://scripts/weapon_grip_hand.gd")'), "no active runtime script loads the historical procedural hand: " + file)
	var front := _function(source, "draw_grip_front")
	var back := _function(source, "draw_grip_back")
	var avatar := _function(source, "draw_avatar_layers")
	var limb := _function(source, "_draw_limb")
	var held := _function(host, "_draw_weapon")
	expect(front.contains('_filtered_texture(ASSET_ROOT+"arm.png")'), "front occlusion samples the original normalized arm texture")
	expect(front.contains("range(PAINTED_FIST_FIRST_ROW,32)"), "front occlusion draws only the original remaining eight mesh rows")
	expect(front.count("_draw_quad(") == 1 and not front.contains("draw_colored_polygon") and not front.contains("draw_texture_rect"), "front hand is one unchanged mesh pass, without replacement contours or resized cutout")
	expect(front.contains("target.append(_skin_arm(point,arm));uv.append(point/sz)"), "front pass retains the original arm skinning and full-canvas UV coordinates")
	expect(front.contains("*PIXEL_SCALE*scale") and front.contains("_set_transform(host,feet,0.0,facing_scale)"), "front fist retains the same actor scale and facing transform")
	expect(back.contains("pass") and not back.contains("host.draw") and not back.contains("_draw_quad("), "historical back-hand compatibility hook draws nothing")
	expect(avatar.contains('active_arm.hand_form="painted_fist_front"'), "only the actively held fist moves to front occlusion")
	expect(limb.contains('"painted_fist_front"') and limb.contains("float(PAINTED_FIST_FIRST_ROW)/rows*sz.y"), "avatar stops at the exact shared mesh-row boundary")
	expect(held.find("CharacterSidewalk.draw_held_weapon(") >= 0 and held.find("CharacterSidewalk.draw_grip_front(") > held.find("CharacterSidewalk.draw_held_weapon("), "world weapon is drawn before the original painted fist occlusion")
	expect(held.count("CharacterSidewalk.draw_grip_front(") == 1, "world weapon draw has exactly one front-fist pass")
	expect(Rig.PIXEL_SCALE == Before.PIXEL_SCALE and Rig.HAND_WIDTH == Before.HAND_WIDTH and Rig.ARM_WIDTH == Before.ARM_WIDTH, "painted fist, forearm, and actor dimensions retain v8 natural scale")

func _test_mesh_partition() -> void:
	expect(Rig.PAINTED_FIST_FIRST_ROW == 24, "the source split starts at mesh row 24")
	var size := Vector2(Template.ARM_CANVAS)
	var boundary := float(Rig.PAINTED_FIST_FIRST_ROW) / 32.0 * size.y
	expect(is_equal_approx(boundary, 297.0), "row 24 is source y=297, not a new hand crop")
	for style in MOVES:
		for facing in [-1.0, 1.0]:
			var motion := _motion(style, MOVES[style][0], "contact", .5, facing)
			var pose := Rig.sample_pose(motion)
			for side in ["near_arm", "far_arm"]:
				var previous_bottom := 0.0
				for row in range(32):
					var top := float(row) / 32.0 * size.y
					var bottom := float(row + 1) / 32.0 * size.y
					expect(is_equal_approx(top, previous_bottom), "original row split has neither a gap nor overlap")
					previous_bottom = bottom
					var in_avatar := row < Rig.PAINTED_FIST_FIRST_ROW
					var in_front := row >= Rig.PAINTED_FIST_FIRST_ROW
					expect(in_avatar != in_front, "each original mesh row has exactly one draw owner")
					for point in [Vector2(0, top), Vector2(size.x, top), Vector2(size.x, bottom), Vector2(0, bottom)]:
						var uv: Vector2 = point / size
						expect((uv * size).distance_to(point) < .0001, "split uses full original source UVs without remapping")
						expect(Rig._skin_arm(point, pose[side]).distance_to(Before._skin_arm(point, pose[side])) < .00001, "every source mesh vertex retains v8 mapping for the same animated arm pose")
				expect(is_equal_approx(previous_bottom, size.y), "all source rows remain represented through the bottom of the painted fist")

func _motion(style: String, move: String, phase: String, progress: float, facing: float) -> Dictionary:
	return {"action_kind": "basic", "attack_style": style, "basic_style": style,
		"combat_move": move, "combat_phase": phase, "phase_progress": progress,
		"combat_stance": 1.0, "attack_amount": 1.0, "facing": facing}

func _test_moving_fist_and_weapon() -> void:
	for style in MOVES:
		for move in MOVES[style]:
			for facing in [-1.0, 1.0]:
				for defense in ["ready", "guard", "dodge", "hit"]:
					var movement := 0.0
					var phase_end: Dictionary = {}
					var phase_end_before: Dictionary = {}
					for phase in PHASES:
						var previous: Dictionary = {}
						for frame in range(DENSE_STEPS + 1):
							var motion := _motion(style, move, phase, frame / float(DENSE_STEPS), facing)
							motion.defense_action = defense
							motion.reaction_amount = .72
							var pose := Rig.sample_pose(motion)
							var before := Before.sample_pose(motion)
							var side := str(pose.combat.get("attack_hand", "near"))
							var active: Dictionary = pose.far_arm if side == "far" else pose.near_arm
							for arm_key in ["near_arm", "far_arm"]:
								var arm: Dictionary = pose[arm_key]
								expect(is_finite(float(arm.hand_angle)), "painted hand angle stays finite")
								expect(absf(angle_difference(float(arm.lower_angle), float(arm.hand_angle))) <= .421, "painted fist retains bounded anatomical wrist rotation")
								for joint in ["shoulder", "elbow", "wrist"]:
									expect(Vector2(arm[joint]).distance_to(before[arm_key][joint]) < .00001, "original fist does not move v8 joints")
								if frame == 0 and not phase_end.is_empty():
									var join_step := absf(angle_difference(float(phase_end[arm_key].hand_angle), float(arm.hand_angle)))
									expect(absf(float(phase_end.combat.get("wrist_flex", 0.0)) - float(pose.combat.get("wrist_flex", 0.0))) < .00001, "authored wrist flex stays continuous across every exact action-phase join")
									if defense in ["ready", "guard"]:
										expect(join_step < .001, "ready and guard painted-fist wrists stay continuous across exact action-phase joins")
									elif join_step >= .001 and facing == 1.0:
										# A held synthetic hit/dodge reaction has existing root/arm jumps.
										# Audit them explicitly; the independent live-duel gate remains.
										var wrist_join_px := Vector2(phase_end[arm_key].wrist).distance_to(arm.wrist) * Rig.PIXEL_SCALE
										var before_wrist_px := Vector2(phase_end_before[arm_key].wrist).distance_to(before[arm_key].wrist) * Before.PIXEL_SCALE
										expect(absf(wrist_join_px - before_wrist_px) < .00001, "synthetic held hit/dodge keeps the established v8 joint jump without hiding a geometry change")
										synthetic_reaction_joins.append({"move": move, "next_phase": phase, "defense": defense, "arm": arm_key, "hand_step_rad": join_step, "v8_hand_step_rad": absf(angle_difference(float(phase_end_before[arm_key].hand_angle), float(before[arm_key].hand_angle))), "wrist_step_px": wrist_join_px, "v8_wrist_step_px": before_wrist_px})
								if not previous.is_empty():
									var hand_step := absf(angle_difference(float(previous[arm_key].hand_angle), float(arm.hand_angle)))
									max_hand_step = maxf(max_hand_step, hand_step)
									movement += hand_step
									if hand_step >= .081 and facing == 1.0: wrist_jumps.append({"move": move, "phase": phase, "progress": frame / float(DENSE_STEPS), "defense": defense, "arm": arm_key, "step_rad": hand_step})
									expect(hand_step < .081, "painted fist rotates continuously through each action phase")
									var wrist_step := Vector2(previous[arm_key].wrist).distance_to(arm.wrist) * Rig.PIXEL_SCALE
									max_wrist_step_px = maxf(max_wrist_step_px, wrist_step)
							var first := Rig.sample_pose(_motion(style, move, phase, 0.0, facing))
							max_hand_excursion = maxf(max_hand_excursion, absf(angle_difference(float(first.near_arm.hand_angle), float(pose.near_arm.hand_angle))))
							for scale_value in [.6, 1.0, 2.0]:
								var weapon := Rig.weapon_pose(motion, scale_value, 0.0, style, pose)
								var expected: Vector2 = Vector2(active.wrist) * Rig.PIXEL_SCALE * Vector2(facing * lerpf(.40, 1.0, float(pose.turn)), 1.0) * scale_value
								expect(not weapon.stowed and Vector2(weapon.offset).distance_to(expected) < .0001, "weapon stays at the moving painted fist joint in both facings and every actor scale")
								expect(Rig._grip_offset(active, side, style, float(motion.get("grip_axial_roll", 0.0))) == Vector2.ZERO, "weapon uses no replacement-hand socket")
							previous = pose
							if frame == DENSE_STEPS:
								phase_end = pose
								phase_end_before = before
					expect(movement > .1, "each weapon move retains animated wrists instead of a frozen holding pose")
