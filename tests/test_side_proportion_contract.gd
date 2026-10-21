extends SceneTree
## Accepted shape / contact-authority regression against the frozen rig.
## New render-only defensive staging is tested separately; blade/head clearance
## below still samples actual current rendered poses.
## Native-render sheets remain the authority for seams and visual quality.
const Rig = preload("res://scripts/character_sidewalk.gd")
const Before = preload("res://tests/character_sidewalk_before.gd")
const Geometry = preload("res://scripts/melee_contact_geometry.gd")
const MOVES = {
	"sword": ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift", "mist_thrust", "mist_lift", "mist_combo", "weapon_sword_pierce"],
	"fan": ["basic_fan_sweep", "basic_fan_flick", "basic_fan_return", "petal_step", "petal_counter"],
	"unarmed": ["basic_unarmed_jab", "basic_unarmed_palm", "ember_palm", "frost_seal", "thunder_strike", "barrier_guard", "mending_bloom"]
}
var checks := 0
var failures: Array[String] = []
var states := 0
var head_rows := PackedVector2Array()

func _initialize() -> void:
	test_registered_parts()
	test_shape_maps()
	test_motion_contract()
	test_transformed_clearance()
	test_blade_clearance()
	for failure in failures.slice(0, 30): push_error(failure)
	print("SIDE_PROPORTION_CONTRACT: %d checks, %d failures, %d motion states compared to frozen baseline" % [checks, failures.size(), states])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures.append(reason)

func near(a: Vector2, b: Vector2) -> bool:
	return a.distance_to(b) < .0002

func expected_head(point: Vector2) -> Vector2:
	return Vector2(0, -202) + (point - Vector2(0, -202)) * .86 + Vector2(0, 15 * (1 - smoothstep(-225, -189, point.y)))

func inverse_rendered_head(point: Vector2) -> Vector2:
	# Invert the actual 32-strip interpolation, not a hypothetical single
	# rectangle. This also covers the compressed neck in blade-alpha tests.
	var source_y := -490.0 if point.y < head_rows[0].y else -188.0
	for index in range(head_rows.size() - 1):
		if point.y >= head_rows[index].y and point.y <= head_rows[index + 1].y:
			var fraction := inverse_lerp(head_rows[index].y, head_rows[index + 1].y, point.y)
			source_y = lerpf(head_rows[index].x, head_rows[index + 1].x, fraction)
			break
	return Vector2(point.x / .86, source_y)

func make_motion(style: String, move: String, phase_name: String, progress: float, defense: String, facing: float) -> Dictionary:
	return {
		"action_kind": "basic" if move.begins_with("basic_") else "weapon_art" if style != "unarmed" else "spell",
		"basic_style": style, "attack_style": style, "combat_move": move,
		"combat_phase": phase_name, "phase_progress": progress, "combat_stance": 1.0,
		"attack_amount": 1.0, "defense_action": defense, "reaction_amount": .72,
		"actor_lunge": 23.0, "facing": facing
	}

func test_registered_parts() -> void:
	expect(near(Rig.head_point(Vector2(0, -189)), Vector2(0, -202) + Vector2(0, 13) * .86), "Lower neck attachment stays fixed while skull settles")
	var base_head := Rect2(-150, -489, 267, 300)
	var shaped := Rig.head_rect(base_head)
	expect(near(shaped.position, expected_head(base_head.position)), "Skull shrinks and settles toward shoulder")
	expect(near(shaped.end, expected_head(base_head.end)), "Head bounds include compressed neck band")
	for ornament in [Rect2(-72, -429, 78, 37), Rect2(-40, -445, 43, 47)]:
		var mapped := Rig.head_rect(ornament)
		expect(near(mapped.position - shaped.position, (ornament.position - base_head.position) * .86), "Head accessory keeps original skull-relative registration")
		expect(near(mapped.size, ornament.size * .86), "Head accessory shares rigid skull scaling")
	for row in range(33):
		var source_y := -489.0 + 300.0 * float(row) / 32
		var target := Rig.head_point(Vector2(0, source_y))
		head_rows.append(Vector2(source_y, target.y))
		expect(near(target, expected_head(Vector2(0, source_y))), "Every head mesh row shares the specified settlement/taper")
		if row > 0: expect(head_rows[row].y > head_rows[row - 1].y, "Compressed neck strips never invert or fold")
	for y in range(-489, -188):
		var source := Vector2(24, y)
		var target := Rig.head_point(source)
		expect(near(target, expected_head(source)), "Head transform matches settled skull and tapered neck")
		if y <= -225:
			expect(near(target - Rig.head_point(Vector2(0, -225)), (source - Vector2(0, -225)) * .86), "Face and hairstyle remain uniformly scaled and undistorted")
		else:
			var inverse := inverse_rendered_head(target)
			var row_error := absf(expected_head(inverse).y - target.y) * Rig.PIXEL_SCALE
			expect(row_error < .25, "Continuous collision probe and actual neck mesh agree within quarter native pixel")
	for chest in [Rect2(-28, -204, 55, 96), Rect2(-34, -204, 72, 112), Rect2(-34, -204, 72, 99)]:
		var mapped := Rig.torso_rect(chest)
		expect(near(mapped.position, chest.position * Vector2(1.30, 1)), "Bare torso and chest gear share horizontal anchor")
		expect(near(mapped.size, chest.size * Vector2(1.30, 1)), "Torso and chest gear widen without changing height")
	expect(Rig.PIXEL_SCALE == Before.PIXEL_SCALE and Rig.CYCLE_DISTANCE == Before.CYCLE_DISTANCE, "Actor scale and stride clock are unchanged")
	for group in [["arm", "sleeve_blue", "sleeve_jade"], ["leg", "legs_blue", "legs_jade", "feet_cloth", "feet_boots"]]:
		var size: Vector2 = load(Rig.EquipmentTemplate.ASSET_ROOT + group[0] + ".png").get_size()
		for key in group:
			expect(load(Rig.EquipmentTemplate.ASSET_ROOT + key + ".png").get_size() == size, "Equipment uses same source canvas as bare limb: " + key)

func test_shape_maps() -> void:
	# Convert to authored bone coordinates, widen around the anatomical
	# centerline, and compare with the frozen original skinning function.
	for strength in [0.0, .5, 1.0]:
		var m := make_motion("sword", "basic_sword_thrust", "strike", strength, "guard", 1)
		var pose := Rig.sample_pose(m)
		for key in ["near_arm", "far_arm"]:
			var arm: Dictionary = pose[key]
			for y in [0.0, 20.0, 34.0, 42.0, 49.0, 66.0, 72.0, 78.0, 87.0]:
				var center := lerpf(0, 4, clampf(y / 42, 0, 1)) if y <= 42 else lerpf(4, 14, clampf((y - 42) / 36, 0, 1))
				var width := lerpf(1.20, 1.08, smoothstep(66, 78, y))
				for lateral in [-12.0, 0.0, 12.0]:
					var q := Vector2(center + lateral, y)
					var source := Rig.EquipmentTemplate.ARM_ORIGIN + q / .245
					var expected_source := Vector2(54, 38) + Vector2(center + lateral * width, y) / .245
					expect(near(Rig._skin_arm(source, arm), Before._skin_arm(expected_source, arm)), "Arm skin adds width without longitudinal stretch")
			var wrist_source := Rig.EquipmentTemplate.ARM_WRIST_GRIP
			expect(near(Rig._skin_arm(wrist_source, arm), arm.wrist), "Painted hand remains registered at original weapon wrist")
		for key in ["near_leg", "far_leg"]:
			var leg: Dictionary = pose[key]
			for y in [0.0, 30.0, 46.0, 53.0, 60.0, 87.0, 93.0, 96.0, 98.0, 109.0]:
				var center := lerpf(0, -5, clampf((y - 53) / 43, 0, 1))
				var width := lerpf(1.18, 1.08, smoothstep(87, 98, y))
				for lateral in [-12.0, 0.0, 12.0]:
					var q := Vector2(center + lateral, y)
					var source := Vector2(102, 20) + q / .225
					var expected_source := Vector2(102, 20) + Vector2(center + lateral * width, y) / .225
					expect(near(Rig._skin_leg(source, leg), Before._skin_leg(expected_source, leg)), "Leg skin widens around original knee/ankle centerline")
			var sole_source := Vector2(102, 20) + Vector2(-5, 109) / .225
			expect(near(Rig._skin_leg(sole_source, leg), Before._skin_leg(sole_source, leg)), "Original sole center follows identical path")

func test_motion_contract() -> void:
	for style in MOVES:
		for move in MOVES[style]:
			for phase_name in ["windup", "strike", "contact", "recovery"]:
				for i in range(9):
					for defense in ["ready", "guard", "dodge", "hit"]:
						for facing in [-1.0, 1.0]:
							var m := make_motion(style, move, phase_name, float(i) / 8, defense, facing)
							compare_motion(m, style)
	for i in range(101):
		for facing in [-1.0, 1.0]:
			compare_motion({"phase": float(i) / 100, "blend": 1.0, "facing": facing}, "sword")

func compare_motion(m: Dictionary, style: String) -> void:
	states += 1
	var p := Rig.sample_contact_pose(m)
	var geometry := p.duplicate(true)
	# These annotations select render-only wrist flex; all established contact
	# fields and geometry must still equal the frozen original dictionary.
	geometry.combat.erase("wrist_flex")
	geometry.combat.erase("contact_authority")
	expect(geometry == Before.sample_pose(m), "All original bones, soles, arm joints and body motion are identical")
	expect(Rig.contact_weapon_pose(m, 1.0, 0.0, style, p) == Before.weapon_pose(m, 1.0, 0.0, style), "Weapon reach, orientation and attachments remain identical")
	expect(Vector2(Rig.contact_weapon_pose(m, 1.0, 0.0, style, p).offset) == Vector2(Before.weapon_pose(m, 1.0, 0.0, style).offset), "Authoritative active grip remains identical")
	expect(Rig.approach_footwork(m) == Before.approach_footwork(m), "Approach root and planted foot motion remain identical")
	for key in ["near_leg", "far_leg"]:
		var leg: Dictionary = p[key]
		expect(absf(leg.hip.distance_to(leg.knee) - 53) < .001 and absf(leg.knee.distance_to(leg.ankle) - 43) < .001, "Both fixed leg bone lengths are preserved")
	for key in ["near_arm", "far_arm"]:
		var arm: Dictionary = p[key]
		expect(absf(arm.shoulder.distance_to(arm.elbow) - 42) < .001 and absf(arm.elbow.distance_to(arm.wrist) - Vector2(10, 36).length()) < .001, "Both fixed arm bone lengths are preserved")

func test_transformed_clearance() -> void:
	# Independently reconstruct the original painted solid-core samples.
	var image: Image = load("res://assets/cultivation/sidewalk/head.png").get_image()
	var core := PackedVector2Array([Vector2(290,190), Vector2(430,235), Vector2(494,335), Vector2(510,451), Vector2(530,509), Vector2(506,534), Vector2(500,565), Vector2(470,605), Vector2(360,630), Vector2(228,538), Vector2(188,408), Vector2(206,286)])
	var locals := PackedVector2Array()
	for y in range(190, 631, 8):
		for x in range(mini(image.get_width() - 1, 530), 187, -1):
			if Geometry2D.is_point_in_polygon(Vector2(x, y), core) and image.get_pixel(x, y).a >= .65:
				locals.append(Vector2(-150, -489) + Vector2(x, y) / Vector2(image.get_size()) * Vector2(267, 300))
				break
	for defense in ["ready", "guard", "dodge", "hit"]:
		for i in range(11):
			var m := make_motion("sword", "basic_sword_cut", "strike", float(i) / 10, defense, 1)
			var p := Rig.sample_contact_pose(m)
			var actual := Geometry.hero_body_fronts(m)
			var expected := PackedVector2Array()
			for local in locals:
				expected.append(Rig._body(expected_head(local), p.shift, p.body_angle) * Rig.PIXEL_SCALE)
			var nose := expected_head(Vector2(89, -253))
			var anchors := PackedVector2Array()
			for local in [nose, Vector2(31 * 1.30, -175), Vector2(28 * 1.30, -125)]:
				anchors.append(Rig._body(local, p.shift, p.body_angle) * Rig.PIXEL_SCALE)
			for index in range(2):
				var count := maxi(1, ceili(absf(anchors[index + 1].y - anchors[index].y) / 1.5))
				for step in range(count): expected.append(anchors[index].lerp(anchors[index + 1], float(step) / count))
			expected.append(anchors[-1])
			expect(actual.size() == expected.size(), "Clearance covers transformed head and widened torso continuously")
			for index in range(mini(actual.size(), expected.size())):
				expect(near(actual[index], expected[index]), "Authoritative collision outline retains accepted transformed coordinates")
			expect(near(Geometry.hero_front(m), anchors[0]), "Legacy collision nose uses the same neck-anchored head")

func test_blade_clearance() -> void:
	# Existing test_basic_attack_forms uses the old head rect. Check the
	# newly transformed alpha here so that passing the old test is not enough.
	var image: Image = load("res://assets/cultivation/sidewalk/head.png").get_image()
	for move in MOVES.sword:
		for phase_name in ["windup", "strike", "contact", "recovery"]:
			for i in range(13):
				for defense in ["ready", "guard", "dodge", "hit"]:
					var m := make_motion("sword", move, phase_name, float(i) / 12, defense, 1)
					var p := Rig.sample_pose(m)
					var weapon := Rig.weapon_pose(m)
					var intersects := false
					for part in range(10, 50, 2):
						for edge in [-.7, 0.0, .7]:
							var world: Vector2 = (weapon.offset + Vector2(edge, -part).rotated(float(weapon.rotation) + .22)) / Rig.PIXEL_SCALE
							var body: Vector2 = Rig.HIP + (world - p.shift - Rig.HIP).rotated(-float(p.body_angle))
							var original := inverse_rendered_head(body)
							var uv := (original - Vector2(-150, -489)) / Vector2(267, 300)
							if uv.x >= 0 and uv.x < 1 and uv.y >= 0 and uv.y < 1:
								intersects = intersects or image.get_pixel(int(uv.x * image.get_width()), int(uv.y * image.get_height())).a > .7
					expect(not intersects, "Blade stays outside transformed head alpha: " + move + "/" + phase_name + "/" + defense)
