extends SceneTree
## Render-only socket regression. Inspect raw mesh orientation BEFORE the
## renderer repairs triangle winding; valid bones alone cannot detect IK flips.
const Rig = preload("res://scripts/character_sidewalk.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Template = preload("res://assets/cultivation/sidewalk/template.gd")
const MOVES := {
	"sword": ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift", "weapon_sword_pierce"],
	"fan": ["basic_fan_sweep", "basic_fan_flick", "basic_fan_return", "weapon_fan_return"],
	"unarmed": ["basic_unarmed_jab", "basic_unarmed_palm"],
}
const PHASES := ["windup", "strike", "contact", "recovery"]
const DEFENSES := [["ready", 0.0], ["guard", 0.5], ["guard", 1.0], ["dodge", 1.0], ["hit", 1.0]]
const TRIANGLES := [[0, 1, 2], [0, 2, 3], [0, 1, 3], [1, 2, 3]]
const DENSE_STEPS := 500
const MAX_DENSE_ELBOW_STEP_PX := 0.90
const SMALL_TIP_TOLERANCE_PX := 1.0
# An explicit observation ceiling, not permission to move contact geometry.
# Exceeding the smaller one-pixel visual target is reported independently.
const TIP_REGRESSION_CEILING_PX := 1.75
var checks := 0
var failures: Dictionary = {}
var max_elbow_step_px := 0.0
var min_mesh_area := INF
var max_static_tip_px := 0.0
var max_live_tip_px := 0.0
var max_scheduled_tip_px := 0.0
var max_weapon_socket_shift_px := 0.0
var worst_static_tip: Dictionary = {}
var worst_live_tip: Dictionary = {}
var live_contacts := 0
var live_contacts_above_small_tolerance := 0
var provider_cache: Dictionary = {}

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	_test_dense_socket_continuity()
	_test_former_fold()
	_test_mesh_orientation()
	_test_contact_endpoints()
	_test_live_unarmed_contacts()
	for failure in failures:
		push_error(str(failure) + " (" + str(failures[failure]) + " occurrences)")
	print("Render socket continuity: %d checks, %d distinct failures; elapsed %.2fs" % [checks, failures.size(), (Time.get_ticks_msec() - started) / 1000.0])
	print("Socket measurements: elbow_step_px=%.6f raw_mesh_area_min=%.6f static_unarmed_tip_px=%.6f scheduled_tip_px=%.6f live_tip_px=%.6f contacts=%d contacts_over_1px=%d" % [max_elbow_step_px, min_mesh_area, max_static_tip_px, max_scheduled_tip_px, max_live_tip_px, live_contacts, live_contacts_above_small_tolerance])
	print("Original painted fist wrist-to-handle socket shift: %.6f native pixels; contact authority remains at the established grip" % max_weapon_socket_shift_px)
	if max_static_tip_px > SMALL_TIP_TOLERANCE_PX:
		print("TIP_VISUAL_REVIEW static=", worst_static_tip)
	if live_contacts_above_small_tolerance > 0:
		print("TIP_VISUAL_REVIEW live=", worst_live_tip)
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures[label] = int(failures.get(label, 0)) + 1

func _motion(style: String, move: String, phase: String, progress: float, defense: String = "ready", strength: float = 0.0) -> Dictionary:
	if not provider_cache.has(style):
		provider_cache[style] = Rig.AttackRegistry.default_registry().pose_provider("weapon." + style)
	return {"action_kind": "basic", "attack_style": style, "basic_style": style,
		"combat_move": move, "combat_phase": phase, "phase_progress": progress,
		"combat_stance": 1.0, "attack_amount": 1.0, "facing": 1.0,
		"defense_action": defense, "reaction_amount": strength,
		"pose_provider": provider_cache[style], "guard_provider": provider_cache[style],
		"strike_provider": provider_cache[style]}

func _test_dense_socket_continuity() -> void:
	for style in MOVES:
		for move in MOVES[style]:
			for defense in DEFENSES:
				for phase in PHASES:
					var previous: Dictionary = {}
					for frame in range(DENSE_STEPS + 1):
						var motion := _motion(style, move, phase, float(frame) / DENSE_STEPS, defense[0], defense[1])
						var pose := Rig.sample_pose(motion)
						_check_dense_step(pose, previous)
						if frame % 50 == 0:
							_check_preserved_socket_endpoints(pose)
						previous = pose
			# A stable pose can still flip as a defensive reaction fades.
			for phase in ["idle", "windup", "contact", "recovery"]:
				var previous: Dictionary = {}
				for frame in range(DENSE_STEPS + 1):
					var motion := _motion(style, move, phase, 0.6, "guard", float(frame) / DENSE_STEPS)
					var pose := Rig.sample_pose(motion)
					_check_dense_step(pose, previous)
					previous = pose

func _check_dense_step(pose: Dictionary, previous: Dictionary) -> void:
	for name in ["near_arm", "far_arm"]:
		var arm: Dictionary = pose[name]
		check(Vector2(arm.shoulder).is_finite() and Vector2(arm.elbow).is_finite() and Vector2(arm.wrist).is_finite(), "render socket joints stay finite")
		check(absf(Vector2(arm.shoulder).distance_to(arm.elbow) - 42.0) < 0.001, "socket fitting preserves upper-arm length")
		check(absf(Vector2(arm.elbow).distance_to(arm.wrist) - Vector2(10, 36).length()) < 0.001, "socket fitting preserves forearm length")
		if not previous.is_empty():
			var jump := Vector2(arm.elbow).distance_to(previous[name].elbow) * Rig.PIXEL_SCALE
			max_elbow_step_px = maxf(max_elbow_step_px, jump)
			check(jump <= MAX_DENSE_ELBOW_STEP_PX, "fixed IK pole prevents discontinuous elbow branch changes")

func _check_preserved_socket_endpoints(pose: Dictionary) -> void:
	# Reconstruct exactly the rendered pre-socket chain. Comparing against
	# contact authority here would also include intentional guard presentation.
	for side in [1.0, -1.0]:
		var source := Rig._arm(float(pose.phase), float(pose.blend), pose.shift, float(pose.body_angle), side, 0.0, pose.combat)
		var fitted: Dictionary = pose.near_arm if side > 0.0 else pose.far_arm
		check(Vector2(source.wrist).distance_to(fitted.wrist) < 0.0001, "socket IK preserves the exact pre-fit wrist")
		check(absf(angle_difference(float(source.grip_angle), float(fitted.grip_angle))) < 0.0001, "socket IK preserves the exact weapon grip angle")
	var sewn := Rig.shoulder_surface_point(Vector2(-24, -160), pose, true)
	check(sewn.distance_to(pose.near_arm.shoulder) < 0.0001, "painted torso socket follows the fitted near shoulder")

func _test_former_fold() -> void:
	var motion := _motion("unarmed", "basic_unarmed_palm", "recovery", 0.0, "dodge", 0.5)
	var pose := Rig.sample_pose(motion)
	var rect := Rig.torso_rect(Rig.TORSO_RECT)
	# This exact cell inverted in BOTH diagonals with the old symmetric
	# falloff. _quad_triangles reversing its winding concealed the defect.
	for col in [3, 4]:
		_check_surface_cell(pose, rect, Rect2(0, 0, 1, 1), false, col, 9)

func _test_mesh_orientation() -> void:
	var examples := [["sword", "basic_sword_thrust"], ["sword", "weapon_sword_pierce"], ["fan", "basic_fan_flick"], ["unarmed", "basic_unarmed_palm"]]
	for example in examples:
		for phase in PHASES:
			for progress in [0.0, 0.5, 1.0]:
				for defense in [["ready", 0.0], ["guard", 1.0], ["dodge", 0.5], ["hit", 0.5]]:
					var motion := _motion(example[0], example[1], phase, progress, defense[0], defense[1])
					var pose := Rig.sample_pose(motion)
					_check_surface(pose, Rig.torso_rect(Rig.TORSO_RECT), Rect2(0, 0, 1, 1), false)
					# All normalized shirts share one full canonical canvas.
					_check_surface(pose, Rig.torso_rect(Template.CHEST_RECT), Rect2(0, 0, 1, 1), true)

func _check_surface(pose: Dictionary, rect: Rect2, region: Rect2, garment: bool) -> void:
	for row in range(18):
		for col in range(12):
			_check_surface_cell(pose, rect, region, garment, col, row)

func _check_surface_cell(pose: Dictionary, rect: Rect2, region: Rect2, garment: bool, col: int, row: int) -> void:
	var uv0 := region.position + region.size * Vector2(float(col) / 12.0, float(row) / 18.0)
	var uv1 := region.position + region.size * Vector2(float(col + 1) / 12.0, float(row + 1) / 18.0)
	var points := PackedVector2Array()
	for uv in [uv0, Vector2(uv1.x, uv0.y), uv1, Vector2(uv0.x, uv1.y)]:
		points.append(Rig.shoulder_surface_point(rect.position + rect.size * uv, pose, garment))
	for indices in TRIANGLES:
		var area := (points[indices[1]] - points[indices[0]]).cross(points[indices[2]] - points[indices[0]])
		min_mesh_area = minf(min_mesh_area, area)
		check(is_finite(area) and area > 0.00001, "garment mesh stays positively oriented before winding normalization" if garment else "bare-body mesh stays positively oriented before winding normalization")

func _test_contact_endpoints() -> void:
	for style in MOVES:
		for move in MOVES[style]:
			for defense in DEFENSES:
				for aim in [-1.2, -0.6, 0.0, 0.6, 1.2]:
					for progress in [0.0, 0.5, 1.0]:
						var motion := _motion(style, move, "contact", progress, defense[0], defense[1])
						motion.strike_aim = aim
						motion.aim_crouch = 10.0
						motion.actor_lunge = 25.0
						var rendered := Rig.sample_pose(motion)
						var authority := Rig.sample_contact_pose(motion)
						var active := "far_arm" if str(authority.combat.attack_hand) == "far" else "near_arm"
						check(Vector2(rendered[active].wrist).distance_to(authority[active].wrist) < 0.0001, "committed rendered wrist agrees with contact authority")
						if style != "unarmed":
							var grip := Rig.weapon_pose(motion, 1.0, 0.0, style, rendered)
							var contact_grip := Rig.contact_weapon_pose(motion, 1.0, 0.0, style, authority)
							check(Vector2(grip.offset).distance_to(Vector2(contact_grip.offset)) < 0.0001, "committed visual weapon uses the original painted fist joint without a substitute socket")
							max_weapon_socket_shift_px = maxf(max_weapon_socket_shift_px, Vector2(grip.offset).distance_to(contact_grip.offset))
							check(Rig._grip_offset(rendered[active], str(rendered.combat.attack_hand), style) == Vector2.ZERO, "original fist has exactly zero visual handle shift")
							check(absf(angle_difference(float(grip.rotation), float(contact_grip.rotation))) < 0.0001, "committed weapon grip rotation agrees with contact authority")
						else:
							var drift := _tip_drift(motion, rendered, authority)
							if drift > max_static_tip_px:
								max_static_tip_px = drift
								worst_static_tip = {"move": move, "phase_progress": progress, "defense": defense[0], "reaction": defense[1], "strike_aim": aim, "drift_px": drift}
							if progress == 0.0:
								max_scheduled_tip_px = maxf(max_scheduled_tip_px, drift)
							check(drift <= TIP_REGRESSION_CEILING_PX, "unarmed contact-tip drift stays inside explicitly recorded visual ceiling")

func _tip_drift(motion: Dictionary, rendered: Dictionary, authority: Dictionary) -> float:
	var provider = motion.get("strike_provider", provider_cache.unarmed)
	var rendered_points: PackedVector2Array = provider.geometry_points(motion, rendered, {})
	var authority_points: PackedVector2Array = provider.geometry_points(motion, authority, {})
	check(rendered_points.size() == authority_points.size() and not rendered_points.is_empty(), "unarmed tip comparison uses the same bound geometry provider")
	return rendered_points[0].distance_to(authority_points[0])

func _test_live_unarmed_contacts() -> void:
	# Sample BEFORE each scheduled boundary so a resolved enemy reaction or
	# cursor increment cannot replace the pose that owns the actual contact.
	for route in ["bamboo_pass", "cloud_slope", "moon_marsh"]:
		for seed_value in [17, 377]:
			var contacts_before := live_contacts
			var duel := Duel.new()
			var hero := {"hp": 9999, "max_hp": 9999, "attack": 10, "defense": 2, "combat_qi_regen": 0.0, "battle_resources": {"qi": 0.0}, "heart_method": {}, "weapon_art": {}, "active_skills": [], "passive_methods": [], "weapon_skill": {}}
			var enemy := {"hp": 9999, "max_hp": 9999, "attack": 8, "defense": 1, "boss": true, "route_id": route}
			duel.start(hero, enemy, "stillness", "unarmed", seed_value)
			duel.advance(0.001)
			while duel.elapsed < 12.0 and not duel.finished:
				var next_time := minf(duel._next_boundary("hero"), duel._next_boundary("enemy"))
				if not is_finite(next_time) or next_time < float(duel.elapsed) - 0.00001:
					check(false, "live contact boundaries remain finite and monotonic")
					break
				var lane: Dictionary = duel._lanes.hero.action
				if not lane.is_empty() and not bool(lane.get("interrupted", false)) and int(lane.cursor) < lane.contacts.size():
					var contact: Dictionary = lane.contacts[int(lane.cursor)]
					var contact_time := float(lane.start) + float(contact.time)
					if bool(contact.prepared) and absf(contact_time - next_time) < 0.00001:
						var motion: Dictionary = duel._hero_motion_at(contact_time)
						var rendered := Rig.sample_pose(motion)
						var authority := Rig.sample_contact_pose(motion)
						var drift := _tip_drift(motion, rendered, authority)
						live_contacts += 1
						if drift > SMALL_TIP_TOLERANCE_PX:
							live_contacts_above_small_tolerance += 1
						if drift > max_live_tip_px:
							max_live_tip_px = drift
							worst_live_tip = {"route": route, "seed": seed_value, "time": contact_time, "move": motion.combat_move, "strike_aim": motion.get("strike_aim", 0.0), "drift_px": drift}
						check(drift <= TIP_REGRESSION_CEILING_PX, "live scheduled unarmed tip remains within recorded visual ceiling")
				duel.advance(maxf(0.000001, next_time - float(duel.elapsed)))
			check(live_contacts > contacts_before, "each live socket scenario reaches real scheduled hero contacts")
