extends SceneTree
## Headless rig/contact regression. Add -- --render for a graphical pose sheet.
## The optional sheet is written to res://builds/Adventure-Combat-Poses.png.
const Walk = preload("res://scripts/character_walk.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_exact_rest_and_endpoints()
	_test_fixed_arms_and_attachments()
	_test_restrained_contact()
	_test_combat_continuity()
	_test_shoulder_seams()
	_test_arm_skin_triangles()
	_test_sword_tip_direction()
	print("Character combat pose: %d checks, %d failures" % [checks, failures])
	if "--render" in OS.get_cmdline_user_args() and not failures:
		root.size = Vector2i(1200, 1080)
		root.add_child(PoseCanvas.new())
		_capture.call_deferred()
	else:
		quit(1 if failures else 0)

func _check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _test_exact_rest_and_endpoints() -> void:
	var rest := Walk.sample_pose({})
	for name in ["left_arm", "right_arm"]:
		var arm: Dictionary = rest[name]
		for y in range(326, 431, 3):
			var p := Vector2(204 if name == "left_arm" else 308, y)
			_check(Walk.skin_arm_point(p, arm, rest).is_equal_approx(p), "idle retains original arm pixels")
	for style in ["sword", "fan", "unarmed"]:
		for phase in [0.0, 1.0]:
			var pose := Walk.sample_pose({"attack_phase": phase, "attack_style": style})
			_check(pose.body_shift.is_equal_approx(Vector2.ZERO), "attack endpoints return pelvis to rest")
			for name in ["left_arm", "right_arm"]:
				for joint in ["shoulder", "elbow", "wrist"]:
					_check(pose[name][joint].is_equal_approx(rest[name][joint]), "attack endpoints return every arm joint to rest")
			_check(is_zero_approx(Walk.attachment_rotation({"attack_phase": phase, "attack_style": style})), "weapon settles exactly at rest")

func _test_fixed_arms_and_attachments() -> void:
	for style in ["sword", "fan", "unarmed"]:
		for i in range(101):
			var phase := float(i) / 100.0
			for facing in [-1.0, 1.0]:
				var motion := {"attack_phase": phase, "attack_style": style, "facing": facing}
				var pose := Walk.sample_pose(motion)
				for name in ["left_arm", "right_arm"]:
					var arm: Dictionary = pose[name]
					_check(absf(arm.shoulder.distance_to(arm.elbow) - arm.rest_shoulder.distance_to(arm.rest_elbow)) < 0.0001, "attack never stretches upper arm")
					_check(absf(arm.elbow.distance_to(arm.wrist) - arm.rest_elbow.distance_to(arm.rest_wrist)) < 0.0001, "attack never stretches forearm")
					_check(Walk.skin_arm_point(arm.rest_shoulder, arm, pose).is_equal_approx(arm.shoulder), "arm root remains connected to torso")
					_check(Walk.skin_arm_point(arm.rest_wrist, arm, pose).is_equal_approx(arm.wrist), "hand remains connected to forearm")
				for scale in [1.0, 1.8]:
					var grip := Walk.attachment_offset(Walk.GRIP_RIGHT, motion, scale)
					var hand: Vector2 = (pose.right_arm.wrist - Walk.FOOT_ANCHOR) * Vector2(facing, 1.0) * Walk.PIXEL_SCALE * scale
					_check(grip.is_equal_approx(hand), "held weapon follows actual mirrored and scaled hand")
					var tilted := Walk.sample_pose(motion, 0.07)
					var tilted_grip := Walk.attachment_offset(Walk.GRIP_RIGHT, motion, scale, 0.07)
					var tilted_hand: Vector2 = (tilted.right_arm.wrist - Walk.FOOT_ANCHOR) * Vector2(facing, 1.0) * Walk.PIXEL_SCALE * scale
					_check(tilted_grip.is_equal_approx(tilted_hand), "cast tilt cannot detach the weapon")
		var strike := Walk.sample_pose({"attack_phase": 0.48, "attack_style": style})
		_check(strike.right_arm.wrist.x > Walk.GRIP_RIGHT.x + 30.0, "lead hand extends forward")
		_check(strike.right_arm.wrist.y < Walk.GRIP_RIGHT.y - 30.0, "lead forearm visibly rises for attack")
		_check(strike.body_shift.length() < 4.0, "attack movement comes from joints instead of whole-body bounce")

func _test_restrained_contact() -> void:
	var max_drop := 0.0
	var max_upper := 0.0
	var max_lower := 0.0
	for i in range(240):
		var walker := Walk.new()
		walker.phase = float(i) / 240.0
		walker.blend = 1.0
		var motion := walker.update_motion(0.0, 46.0)
		var pose := Walk.sample_pose(motion)
		max_drop = maxf(max_drop, float(motion.bob))
		_check(pose.left.planted or pose.right.planted, "restrained gait always has a supporting foot")
		for name in ["left", "right"]:
			var leg: Dictionary = pose[name]
			_check(absf(leg.hip.distance_to(leg.knee) - Walk.UPPER_LENGTH) < 0.001, "new gait keeps thigh length")
			_check(absf(leg.knee.distance_to(leg.ankle) - Walk.LOWER_LENGTH) < 0.001, "new gait keeps calf length")
			if leg.planted:
				_check(absf(leg.ankle.y - 482.0) < 0.02, "support stays on ground in actual update_motion gait")
			_check(float(leg.lift) <= Walk.WALK_LIFT + 0.001, "swing lift remains restrained")
			max_upper = maxf(max_upper, absf(float(leg.upper_angle)))
			max_lower = maxf(max_lower, absf(float(leg.lower_angle)))
	_check(max_drop < 2.1, "walking does not retain old five-pixel crouch")
	_check(max_upper < 0.78 and max_lower < 0.95, "walking avoids deeply folded knees")
	# Check contact at multiple new-gait phases using the actual world-distance clock.
	for start in [0.07, 0.17, 0.28, 0.39, 0.49]:
		var walker := Walk.new()
		walker.phase = start
		walker.blend = 1.0
		var before := Walk.sample_pose(walker.update_motion(0.0, 46.0))
		var delta := 0.01
		var after := Walk.sample_pose(walker.update_motion(delta, 46.0))
		_check(absf((after.left.ankle.x - before.left.ankle.x) * Walk.PIXEL_SCALE + 46.0 * delta) < 0.001, "real update_motion cancels stance foot sliding")

func _test_combat_continuity() -> void:
	for style in ["sword", "fan", "unarmed"]:
		for i in range(200):
			var a := Walk.sample_pose({"attack_phase": float(i) / 200.0, "attack_style": style})
			var b := Walk.sample_pose({"attack_phase": float(i + 1) / 200.0, "attack_style": style})
			for name in ["left_arm", "right_arm"]:
				for joint in ["shoulder", "elbow", "wrist"]:
					_check(a[name][joint].distance_to(b[name][joint]) < 4.0, "windup, strike and recovery stay continuous")
			for name in ["left", "right"]:
				_check(absf(a[name].ankle.y - 482.0) < 0.02, "attack stance stays planted")
				_check(a[name].knee.distance_to(b[name].knee) < 3.0, "stance recovery stays continuous")

func _test_shoulder_seams() -> void:
	for style in ["sword", "fan", "unarmed"]:
		for t in [0.0, 0.15, 0.28, 0.45, 0.65, 0.85, 1.0]:
			var pose := Walk.sample_pose({"attack_phase": t, "attack_style": style})
			for name in ["left_arm", "right_arm"]:
				for sleeve in [false, true]:
					for y in range(330, 351, 2):
						var x := 218.0 if sleeve else Walk._arm_boundary(y)
						var point := Vector2(x if name == "left_arm" else 512.0 - x, y)
						_check(Walk.skin_arm_surface(point, pose[name], pose, sleeve).is_equal_approx(Walk._body_point(point, pose)), "skin and sleeves stay stitched at inner shoulder")


func _test_arm_skin_triangles() -> void:
	for style in ["sword", "fan", "unarmed"]:
		for i in range(21):
			var pose := Walk.sample_pose({"attack_phase": float(i) / 20.0, "attack_style": style})
			for name in ["left_arm", "right_arm"]:
				for sleeve in [false, true]:
					for y in range(330, 397 if sleeve else 430, 6):
						var edge := 218.0 if sleeve else Walk._arm_boundary(y)
						var next_edge := 218.0 if sleeve else Walk._arm_boundary(y + 6)
						var source := PackedVector2Array([Vector2(180,y), Vector2(edge,y), Vector2(next_edge,y+6), Vector2(180,y+6)])
						var vertices := PackedVector2Array()
						var uv := PackedVector2Array()
						for point in source:
							if name == "right_arm": point.x = 512.0 - point.x
							vertices.append(Walk.skin_arm_surface(point, pose[name], pose, sleeve))
							uv.append(point / 512.0)
						for triangle in Walk._quad_triangles(vertices, uv):
							_check(Geometry2D.triangulate_polygon(triangle.vertices).size() == 3, "articulated bare arms and either short sleeve remain renderable")


func _test_sword_tip_direction() -> void:
	# Actual sword source tip (66,29), projected through the host's draw rect.
	# Its grip is the source anchor (66,396); both use the same attachment API.
	var local_tip := Vector2(-7.8, -53.7) + Vector2(66.0 / 220.0 * 26.0, 29.0 / 560.0 * 76.0)
	for i in range(31):
		var phase := 0.4 + float(i) * 0.01
		for facing in [-1.0, 1.0]:
			for scale in [1.0, 1.8]:
				var motion := {"attack_phase": phase, "attack_style": "sword", "facing": facing}
				var grip := Walk.attachment_offset(Walk.GRIP_RIGHT, motion, scale)
				var angle := 0.22 + Walk.attachment_rotation(motion)
				var tip: Vector2 = grip + local_tip.rotated(angle) * Vector2(facing, 1.0) * scale
				_check((tip.x - grip.x) * facing > 30.0 * scale, "extended sword tip sweeps ahead of the hand and away from the face")
				_check((grip.x + (tip.x - grip.x) * 0.25) * facing > 20.0 * scale, "first quarter of extended blade remains outside head center")


class PoseCanvas extends Node2D:
	var rig = Walk.new()
	var textures: Dictionary = {}
	var weapons: Dictionary = {}
	func _ready() -> void:
		for key in ["base", "head_crown", "head_pin", "chest_blue", "chest_jade", "legs_blue", "legs_jade", "feet_cloth", "feet_boots"]:
			textures[key] = load("res://assets/cultivation/equipment/" + key + ".png")
		for key in ["sword", "fan"]:
			weapons[key] = load("res://assets/cultivation/avatars/" + key + ".png")
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 1080), Color("f5f2e9"))
		var labels := ["Restrained contact / original white shorts", "Restrained contact / complete jade gear / mirrored", "Sword / gather, strike, recovery", "Fan / gather, cast, recovery", "Unarmed / mirrored, articulated strike"]
		var times := [0.0, 0.15, 0.28, 0.45, 0.65, 0.85]
		for row in range(5):
			draw_string(ThemeDB.fallback_font, Vector2(20, 24 + row * 212), labels[row], HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("32443e"))
			for col in range(6):
				var motion: Dictionary
				var feet := Vector2(100 + col * 200, 200 + row * 212)
				var visual := {}
				if row < 2:
					var walker := Walk.new()
					walker.phase = float(col) / 6.0
					walker.blend = 1.0
					motion = walker.update_motion(0.0, -46.0 if row == 1 else 46.0)
				else:
					motion = {"attack_phase": times[col], "attack_style": ["sword", "fan", "unarmed"][row - 2], "facing": -1.0 if row == 4 else 1.0}
				if row == 1 or row == 3:
					visual = {"head": "head_pin", "chest": "chest_jade", "legs": "legs_jade", "feet": "feet_cloth"}
				elif row == 2:
					visual = {"head": "head_crown", "chest": "chest_blue", "legs": "legs_blue", "feet": "feet_boots"}
				rig.draw_avatar_layers(self, feet, textures, visual, motion, 1.3)
				if row in [2, 3]:
					var key := "sword" if row == 2 else "fan"
					var grip := feet + Walk.attachment_offset(Walk.GRIP_RIGHT, motion, 1.3)
					draw_set_transform(grip, Walk.attachment_rotation(motion) + (0.22 if row == 2 else 0.0), Vector2.ONE * 1.3)
					draw_texture_rect(weapons[key], Rect2(-7.8, -53.7, 26, 76) if row == 2 else Rect2(-23.3, -25.6, 48, 40), false)
					draw_set_transform(Vector2.ZERO)
				draw_line(feet + Vector2(-65, 0), feet + Vector2(65, 0), Color(0.5, 0.5, 0.5, 0.3))

func _capture() -> void:
	await process_frame
	root.size = Vector2i(1200, 1080)
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot:
		var result := screenshot.save_png("res://builds/Adventure-Combat-Poses.png")
		print("COMBAT_POSES_RENDER: ", result, " res://builds/Adventure-Combat-Poses.png")
	quit()
