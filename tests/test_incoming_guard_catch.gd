extends SceneTree
## Run normally for synthetic/contact-authority contracts. Optional:
## -- --native-events=/absolute/path/to/loot-loop-events.json
## Native captures are replayed from their saved loadouts; an older screenshot
## is never treated as evidence of the current render implementation.
const Rig = preload("res://scripts/character_sidewalk.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Template = preload("res://assets/cultivation/sidewalk/template.gd")
const SNAPSHOT_KEYS := ["type", "actor", "move", "time", "action_id", "contact_id", "resolution", "damage", "hero_hp", "enemy_hp", "counter", "counter_kind", "counter_source", "poise_broken", "qi", "qi_cost"]
var checks := 0
var failures: Dictionary = {}
var max_wrist_step_px := 0.0
var max_root_step_px := 0.0
var max_head_step_px := 0.0
var min_surface_area := INF
var native_guard_rows: Array = []
var native_held_failures: Array = []
var held_frames_checked := 0
var exact_native_contacts := 0
var max_capture_float_delta := 0.0
var head_image: Image
var head_rows := PackedVector2Array()
var sword_opaque_samples := PackedVector2Array()
var hilt_opaque_samples := PackedVector2Array()
var face_core := PackedVector2Array([Vector2(290,190),Vector2(430,235),Vector2(494,335),Vector2(510,451),Vector2(530,509),Vector2(506,534),Vector2(500,565),Vector2(470,605),Vector2(360,630),Vector2(228,538),Vector2(188,408),Vector2(206,286)])
var provider = Rig.AttackRegistry.default_registry().pose_provider("weapon.sword")

class MetadataFreeDuel extends Duel:
	func pose() -> Dictionary:
		var result: Dictionary = super.pose()
		for key in ["guard_contact_point", "guard_contact_valid", "guard_visual"]:
			result.hero.erase(key)
		return result

func _initialize() -> void:
	var started := Time.get_ticks_msec()
	_prepare_alpha_probe()
	_test_catch_and_isolation()
	_test_height_and_phase_continuity()
	_test_visual_tail()
	_test_fresh_anticipation_priority()
	_test_exact_damage_snapshots()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--native-events="):
			_test_native_capture(arg.trim_prefix("--native-events="))
	for failure in failures:
		push_error(str(failure) + " (" + str(failures[failure]) + " occurrences)")
	print("Incoming guard catch: %d checks, %d distinct failures; elapsed %.2fs" % [checks, failures.size(), (Time.get_ticks_msec() - started) / 1000.0])
	print("Catch measurements: wrist_step_px=%.6f root_step_px=%.6f head_step_px=%.6f raw_surface_area_min=%.6f exact_native_contacts=%d capture_float_delta=%.15f" % [max_wrist_step_px, max_root_step_px, max_head_step_px, min_surface_area, exact_native_contacts, max_capture_float_delta])
	if not native_guard_rows.is_empty():
		print("NATIVE_GUARD_DISTANCES ", JSON.stringify(native_guard_rows))
	if held_frames_checked > 0:
		print("NATIVE_HELD_ALPHA checked=", held_frames_checked, " failures=", JSON.stringify(native_held_failures))
	quit(0 if failures.is_empty() else 1)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures[label] = int(failures.get(label, 0)) + 1

func _motion(phase: String = "windup", progress: float = 0.8) -> Dictionary:
	return {"action_kind": "basic", "attack_style": "sword", "basic_style": "sword",
		"combat_move": "basic_sword_thrust", "combat_phase": phase, "phase_progress": progress,
		"combat_stance": 1.0, "attack_amount": 1.0, "facing": 1.0,
		"defense_action": "guard", "reaction_amount": 1.0,
		"guard_contact_valid": true, "guard_contact_point": Vector2(15, -30),
		"pose_provider": provider, "strike_provider": provider, "guard_provider": provider}

func _without_catch(motion: Dictionary) -> Dictionary:
	var result := motion.duplicate(true)
	result.erase("guard_contact_valid")
	result.erase("guard_contact_point")
	if result.has("impact_profile"):
		result.impact_profile.erase("contact_point_valid")
		result.impact_profile.erase("contact_point")
	return result

func _blade_distance(motion: Dictionary, point: Vector2) -> float:
	var grip := Rig.weapon_pose(motion, 1.0, 0.0, "sword")
	var facing := Vector2(float(grip.facing), 1.0)
	var start := Vector2(grip.offset) + Vector2(0, -12.0).rotated(float(grip.rotation) + 0.22) * facing
	var end := Vector2(grip.offset) + Vector2(0, -49.76).rotated(float(grip.rotation) + 0.22) * facing
	return point.distance_to(Geometry2D.get_closest_point_to_segment(point, start, end))

func _test_catch_and_isolation() -> void:
	for height in [-68.0, -55.0, -46.0, -42.0, -37.0, -30.0, -20.0]:
		var motion := _motion()
		motion.guard_contact_point = Vector2(15, height)
		var ordinary := _without_catch(motion)
		var pose := Rig.sample_pose(motion)
		var reference := Rig.sample_pose(ordinary)
		check(_blade_distance(motion, motion.guard_contact_point) < 0.001, "fully raised catch intersects the specified incoming blade line")
		check(pose.shift == reference.shift and pose.body_angle == reference.body_angle, "incoming-line catch does not translate or rotate the torso root")
		for leg in ["near_leg", "far_leg"]:
			check(pose[leg] == reference[leg], "incoming-line catch leaves leg pose unchanged")
			check(bool(pose[leg].planted) and absf(float(pose[leg].ankle.y) - Rig.REST_ANKLE.y) < 0.001, "stationary incoming catch retains planted soles")
		check(Rig.sample_contact_pose(motion) == Rig.sample_contact_pose(ordinary), "catch point is absent from contact-authority pose")
		check(Rig.contact_weapon_pose(motion) == Rig.contact_weapon_pose(ordinary), "catch point is absent from authoritative blade geometry")
		_check_arm_mesh(pose)
		_check_body_surface(pose)
	for phase in ["strike", "contact"]:
		var motion := _motion(phase, 1.0 if phase == "strike" else 0.0)
		var ordinary := _without_catch(motion)
		var rendered := Rig.sample_pose(motion)
		check(not rendered.combat.has("guard_catch"), "committed attack endpoint never receives a weapon catch")
		check(rendered.near_arm == Rig.sample_pose(ordinary).near_arm, "simultaneously committed sword chain remains unchanged")
		var contact := Rig.contact_weapon_pose(motion)
		var visible := Rig.weapon_pose(motion)
		check(Vector2(contact.offset).distance_to(visible.offset) < 0.001 and absf(angle_difference(contact.rotation, visible.rotation)) < 0.001, "committed sword and authority share the original painted fist joint")

func _test_height_and_phase_continuity() -> void:
	var previous: Dictionary = {}
	for frame in range(701):
		var motion := _motion()
		motion.guard_contact_point = Vector2(15, -75.0 + float(frame) * 0.1)
		var pose := Rig.sample_pose(motion)
		_check_step(pose, previous, 0.8, "continuous incoming-height catch")
		previous = pose
	for height in [-63.0, -30.0]:
		for phase in ["windup", "strike", "contact", "recovery"]:
			previous = {}
			for frame in range(501):
				var motion := _motion(phase, float(frame) / 500.0)
				motion.guard_contact_point = Vector2(15, height)
				var pose := Rig.sample_pose(motion)
				_check_step(pose, previous, 0.8, "continuous guard/action transition")
				if frame % 100 == 0:
					_check_arm_mesh(pose)
					_check_body_surface(pose)
				previous = pose
		for boundary in [["windup", "strike"], ["strike", "contact"], ["contact", "recovery"]]:
			var before := _motion(boundary[0], 1.0)
			var after := _motion(boundary[1], 0.0)
			before.guard_contact_point = Vector2(15, height)
			after.guard_contact_point = before.guard_contact_point
			_check_step(Rig.sample_pose(after), Rig.sample_pose(before), 0.02, "guard remains continuous across exact action boundary")

func _check_step(pose: Dictionary, previous: Dictionary, tolerance: float, label: String) -> void:
	if previous.is_empty():
		return
	var root_step := Vector2(pose.shift).distance_to(previous.shift) * Rig.PIXEL_SCALE
	max_root_step_px = maxf(max_root_step_px, root_step)
	check(root_step <= tolerance, label + ": torso-root step")
	var head_step := _head_probe(pose).distance_to(_head_probe(previous))
	max_head_step_px = maxf(max_head_step_px, head_step)
	check(head_step <= tolerance, label + ": head-pivot step")
	for arm in ["near_arm", "far_arm"]:
		var step := Vector2(pose[arm].wrist).distance_to(previous[arm].wrist) * Rig.PIXEL_SCALE
		max_wrist_step_px = maxf(max_wrist_step_px, step)
		check(step <= tolerance, label + ": wrist step")
		check(Vector2(pose[arm].elbow).distance_to(previous[arm].elbow) * Rig.PIXEL_SCALE <= tolerance * 1.25, label + ": elbow step")

func _head_probe(pose: Dictionary) -> Vector2:
	var point := Rig._body(Rig.head_point(Vector2(89, -253)), pose.shift, float(pose.body_angle))
	var pivot := Rig._body(Rig.head_point(Rig.NECK), pose.shift, float(pose.body_angle))
	return (pivot + (point - pivot).rotated(float(pose.combat.get("head_recoil", 0.0)))) * Rig.PIXEL_SCALE

func _test_visual_tail() -> void:
	var previous: Dictionary = {}
	var duration := 0.22558624
	for frame in range(401):
		var age := float(frame) / 1000.0
		var motion := _motion("idle", 0.0)
		motion.attack_amount = 0.0
		var profile := {"kind": "block", "contact_point_valid": true, "contact_point": Vector2(15, -30), "reaction_duration": duration, "reaction_magnitude": 0.4993, "knockback": 2.86}
		motion.erase("guard_contact_valid")
		motion.erase("guard_contact_point")
		if age < duration:
			motion.impact_profile = profile
			motion.contact_id = "tail:0"
			motion.reaction_age = age
			motion.reaction_amount = 1.0 - smoothstep(0.045, duration, age)
		else:
			motion.defense_action = "ready"
			motion.reaction_amount = 0.0
		if age < 0.36:
			motion.guard_visual = {"age": age, "profile": profile, "contact_id": "tail:0", "point": Vector2(18, -30)}
		var pose := Rig.sample_pose(motion)
		_check_step(pose, previous, 0.8, "resolved catch tail releases continuously")
		var no_tail := motion.duplicate(true)
		no_tail.erase("guard_visual")
		check(Rig.sample_contact_pose(motion) == Rig.sample_contact_pose(no_tail), "visual tail cannot prolong physical defense")
		previous = pose

func _test_fresh_anticipation_priority() -> void:
	# A rapid second hit can be anticipated before the previous catch's
	# render-only release tail expires. The old catch must not redirect the
	# raised blade away from the new incoming line.
	var fresh := _motion("windup", 0.8)
	fresh.reaction_age = -1.0
	fresh.contact_id = ""
	fresh.guard_contact_point = Vector2(71.90137, -64.3112)
	var stale := fresh.duplicate(true)
	stale.guard_visual = {"age": 0.31, "contact_id": "previous:0",
		"point": Vector2(63.17822, -63.72358),
		"profile": {"kind": "block", "contact_point_valid": true,
			"contact_point": Vector2(60.17822, -63.72358)}}
	var pose := Rig.sample_pose(stale)
	check(pose.combat.guard_catch.point == fresh.guard_contact_point, "new anticipation uses its fresh incoming point over the previous visual tail")
	check(pose == Rig.sample_pose(fresh), "stale catch metadata cannot redirect a new anticipation pose")
	check(Rig.sample_contact_pose(stale) == Rig.sample_contact_pose(fresh), "anticipation priority remains isolated from contact authority")

func _check_arm_mesh(pose: Dictionary) -> void:
	for name in ["near_arm", "far_arm"]:
		var arm: Dictionary = pose[name]
		check(absf(Vector2(arm.shoulder).distance_to(arm.elbow) - 42.0) < 0.001, "incoming catch preserves upper-arm length")
		check(absf(Vector2(arm.elbow).distance_to(arm.wrist) - Vector2(10, 36).length()) < 0.001, "incoming catch preserves lower-arm length")
		# Every normalized sleeve and bare arm now shares this exact canvas
		# and origin. No garment-specific registration is applied at runtime.
		for row in range(32):
			var top := float(row) / 32.0 * Template.ARM_CANVAS.y
			var bottom := float(row + 1) / 32.0 * Template.ARM_CANVAS.y
			var points := PackedVector2Array()
			for point in [Vector2(0, top), Vector2(Template.ARM_CANVAS.x, top), Vector2(Template.ARM_CANVAS.x, bottom), Vector2(0, bottom)]:
				points.append(Rig._skin_arm(point, arm))
			var triangles := Rig._quad_triangles(points, PackedVector2Array([Vector2.ZERO, Vector2.RIGHT, Vector2.ONE, Vector2.DOWN]))
			check(not triangles.is_empty(), "catch arm/sleeve strip retains renderable geometry")
			for triangle in triangles:
				for point in triangle.vertices:
					check(point.is_finite(), "catch arm/sleeve mesh vertices remain finite")

func _check_body_surface(pose: Dictionary) -> void:
	for garment in [false, true]:
		var rect := Rig.torso_rect(Template.CHEST_RECT) if garment else Rig.torso_rect(Rig.TORSO_RECT)
		for row in range(18):
			for col in range(12):
				var a := rect.position + rect.size * Vector2(float(col) / 12, float(row) / 18)
				var b := rect.position + rect.size * Vector2(float(col + 1) / 12, float(row + 1) / 18)
				var points := PackedVector2Array()
				for point in [a, Vector2(b.x, a.y), b, Vector2(a.x, b.y)]:
					points.append(Rig.shoulder_surface_point(point, pose, garment))
				for indices in [[0, 1, 2], [0, 2, 3], [0, 1, 3], [1, 2, 3]]:
					var area := (points[indices[1]] - points[indices[0]]).cross(points[indices[2]] - points[indices[0]])
					min_surface_area = minf(min_surface_area, area)
					check(area > 0.00001, "catch-driven shoulder surface stays unfolded before winding repair")

func _snapshot(event: Dictionary) -> Dictionary:
	var result: Dictionary = {}
	for key in SNAPSHOT_KEYS:
		if event.has(key):
			# JSON captures store every number as a float; normalize only that
			# representation difference, without rounding damage or timestamps.
			result[key] = float(event[key]) if typeof(event[key]) in [TYPE_INT, TYPE_FLOAT] else event[key]
	return result

func _test_exact_damage_snapshots() -> void:
	for route in ["bamboo_pass", "cloud_slope"]:
		var hero := {"hp": 9999, "max_hp": 9999, "attack": 10, "defense": 2}
		var enemy := {"hp": 9999, "max_hp": 9999, "attack": 8, "defense": 1, "boss": true, "route_id": route}
		var visible := Duel.new()
		var quiet := MetadataFreeDuel.new()
		visible.start(hero, enemy, "stillness", "sword", 17)
		quiet.start(hero, enemy, "stillness", "sword", 17)
		for frame in range(400):
			var actual: Array = visible.advance(0.05).map(_snapshot)
			var reference: Array = quiet.advance(0.05).map(_snapshot)
			check(actual == reference, "incoming-line/tail metadata leaves exact damage/action snapshots unchanged")
			var motion: Dictionary = visible.pose().hero
			Rig.sample_pose(motion)
			Rig.weapon_pose(motion)

func _matches_capture(actual: Dictionary, recorded: Dictionary) -> bool:
	if actual.size() != recorded.size():
		return false
	for key in recorded:
		if not actual.has(key):
			return false
		# Decimal JSON encoding and different advance increments can change
		# the final binary bit of event time. Damage, HP, counters and outcomes remain exact. Timestamp and fractional
		# qi regeneration allow only serialization/step-accumulation roundoff.
		var float_delta := absf(float(actual[key]) - float(recorded[key])) if key in ["time", "qi", "qi_cost"] else 0.0
		max_capture_float_delta = maxf(max_capture_float_delta, float_delta)
		var same: bool = float_delta <= 0.000000001 if key in ["time", "qi", "qi_cost"] else actual[key] == recorded[key]
		if not same:
			print("NATIVE_SNAPSHOT_FIELD_MISMATCH ", key, " current=", actual[key], " recorded=", recorded[key], " delta=", float_delta)
			return false
	return true

func _test_native_capture(path: String) -> void:
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(path))
	check(parsed is Dictionary and parsed.has("bouts") and parsed.has("events"), "native replay fixture is readable")
	if not parsed is Dictionary:
		return
	for bout_index in range(parsed.bouts.size()):
		var setup: Dictionary = parsed.bouts[bout_index].setup
		var recorded: Dictionary = {}
		for event in parsed.events:
			if int(event.get("bout", -1)) == bout_index and str(event.get("type", "")) == "contact":
				recorded[str(event.contact_id)] = _snapshot(event)
		var duel := Duel.new()
		duel.start(setup.hero, setup.enemy, setup.heart, setup.weapon, int(setup.seed))
		duel.advance(0.000001)
		var held_checks: Array[float] = []
		while duel.elapsed < 35.0 and not duel.finished:
			var boundary := minf(duel._next_boundary("hero"), duel._next_boundary("enemy"))
			if not held_checks.is_empty():
				boundary = minf(boundary, held_checks[0])
			for event in duel.advance(maxf(0.000001, boundary - float(duel.elapsed))):
				if str(event.type) != "contact":
					continue
				if recorded.has(str(event.contact_id)):
					var same_snapshot := _matches_capture(_snapshot(event), recorded[event.contact_id])
					check(same_snapshot, "current replay preserves captured native contact/damage snapshot")
					if same_snapshot:
						exact_native_contacts += 1
					elif exact_native_contacts == 0:
						print("NATIVE_SNAPSHOT_MISMATCH ", _snapshot(event), " recorded=", recorded[event.contact_id])
				if str(event.actor) != "enemy" or str(event.resolution) != "guard" or not event.has("enemy_contact"):
					continue
				held_checks.append(float(event.time) + 0.11)
				# The last near-full-hold instant exposed an inward return
				# hidden by coarser 25ms sweeps; retain that exact regression.
				held_checks.append(float(event.time) + 0.124)
				held_checks.sort()
				var motion: Dictionary = duel.pose().hero
				var pose := Rig.sample_pose(motion)
				var weapon := Rig.weapon_pose(motion)
				var weight := float(pose.combat.get("guard_hold", 0.0))
				var target_distance := _blade_distance(motion, event.enemy_contact.target)
				var body_distance := _blade_distance(motion, event.enemy_contact.point)
				var staged_point := Vector2(event.enemy_contact.point) + Vector2(clampf(Vector2(event.enemy_contact.target).x - Vector2(event.enemy_contact.point).x, 0.0, 3.0), 0)
				var classification := "full_catch" if pose.combat.has("guard_catch") and weight >= 0.999 and not weapon.stowed else "blending" if pose.combat.has("guard_catch") and not weapon.stowed else "stowed" if weapon.stowed else "committed_or_offhand"
				var alpha_hits := _alpha_face_hits(motion, pose, weapon)
				if classification == "full_catch":
					check(_blade_distance(motion, staged_point) < 0.001, "fully raised native guard intersects bounded body-surface staging point")
					check(body_distance <= 3.001, "fully raised native blade stays within 3px of measured authority contact")
					check(int(alpha_hits.face) == 0, "actual sword alpha, including hilt and tassel, clears the painted face")
				_check_arm_mesh(pose)
				_check_body_surface(pose)
				native_guard_rows.append({"route": setup.route, "contact": event.contact_id, "phase": motion.combat_phase, "kind": motion.action_kind, "classification": classification, "hold": weight, "target_gap_px": target_distance, "body_point_gap_px": body_distance, "opaque_alpha_overlap_samples": alpha_hits})
			while not held_checks.is_empty() and held_checks[0] <= float(duel.elapsed) + 0.000001:
				held_checks.pop_front()
				_check_held_native_catch(duel, str(setup.route))

func _check_held_native_catch(duel: Duel, route: String) -> void:
	# A clean impact frame is insufficient: absorption and ongoing footwork
	# can pull the blade back through the face during its held visual tail.
	var motion: Dictionary = duel.pose().hero
	var pose := Rig.sample_pose(motion)
	var weapon := Rig.weapon_pose(motion, 1.0, 0.0, "sword", pose)
	if not pose.combat.has("guard_catch") or float(pose.combat.get("guard_hold", 0.0)) < 0.999 or bool(weapon.stowed):
		return
	held_frames_checked += 1
	var hits := _alpha_face_hits(motion, pose, weapon)
	check(int(hits.face) == 0, "full held guard keeps whole sword alpha outside the painted face")
	if int(hits.face) > 0:
		native_held_failures.append({"route": route, "contact": motion.get("contact_id", ""), "time": duel.elapsed, "age": motion.get("reaction_age", -1), "phase": motion.combat_phase, "hits": hits})

func _prepare_alpha_probe() -> void:
	# Read source alpha directly, so a fresh checkout does not silently skip
	# the probe merely because Godot has not imported the normalized PNG yet.
	head_image = _source_png(Template.ASSET_ROOT + "head.png")
	for row in range(33):
		var source_y := Rig.HEAD_RECT.position.y + Rig.HEAD_RECT.size.y * float(row) / 32.0
		head_rows.append(Vector2(source_y, Rig.head_point(Vector2(0, source_y)).y))
	var sword_image := _source_png("res://assets/cultivation/avatars/sword.png")
	for y in range(0, sword_image.get_height(), 2):
		for x in range(0, sword_image.get_width(), 2):
			if sword_image.get_pixel(x, y).a < 0.65:
				continue
			var point := Vector2(-7.8, -53.7) + (Vector2(x, y) + Vector2(0.5, 0.5)) / Vector2(sword_image.get_size()) * Vector2(26, 76)
			sword_opaque_samples.append(point)
			if y >= 360:
				hilt_opaque_samples.append(point)
	check(sword_opaque_samples.size() > 500 and hilt_opaque_samples.size() > 100, "actual sword/hilt alpha probe is populated")

func _source_png(path: String) -> Image:
	var image := Image.new()
	var error := image.load_png_from_buffer(FileAccess.get_file_as_bytes(path))
	check(error == OK and not image.is_empty(), "source alpha is available: " + path)
	return image

func _inverse_rendered_head(point: Vector2) -> Vector2:
	# Match the renderer's 32-strip neck interpolation exactly.
	var source_y := -490.0 if point.y < head_rows[0].y else -188.0
	for index in range(head_rows.size() - 1):
		if point.y >= head_rows[index].y and point.y <= head_rows[index + 1].y:
			source_y = lerpf(head_rows[index].x, head_rows[index + 1].x, inverse_lerp(head_rows[index].y, head_rows[index + 1].y, point.y))
			break
	return Vector2(point.x / Rig.HEAD_SCALE, source_y)

func _alpha_face_hits(_motion: Dictionary, pose: Dictionary, weapon: Dictionary) -> Dictionary:
	# Sample the whole actual texture, not a zero-width blade proxy. The
	# 2-source-pixel spacing is at most 0.272 native pixels. Face-core masking
	# excludes decorative loose hair; full-head hits are still reported.
	var result := {"face": 0, "head": 0, "hilt_face": 0, "sample_spacing_px": 76.0 / 560.0 * 2.0}
	var direction := Vector2(float(weapon.facing), 1.0)
	var head_scale := Vector2(float(pose.facing) * lerpf(0.40, 1.0, float(pose.turn)), 1.0)
	var angle := float(weapon.rotation) + (0.0 if weapon.stowed else 0.22)
	var pivot := Rig._body(Rig.head_point(Rig.NECK), pose.shift, float(pose.body_angle))
	for point in sword_opaque_samples:
		var world := (Vector2(weapon.offset) + point.rotated(angle) * direction) / Rig.PIXEL_SCALE / head_scale
		world = pivot + (world - pivot).rotated(-float(pose.combat.get("head_recoil", 0.0)))
		var body := Rig.HIP + (world - Vector2(pose.shift) - Rig.HIP).rotated(-float(pose.body_angle))
		var original := _inverse_rendered_head(body)
		var uv := (original - Rig.HEAD_RECT.position) / Rig.HEAD_RECT.size
		if uv.x < 0 or uv.x >= 1 or uv.y < 0 or uv.y >= 1:
			continue
		var pixel := uv * Vector2(head_image.get_size())
		if head_image.get_pixel(int(pixel.x), int(pixel.y)).a < 0.65:
			continue
		result.head += 1
		if Geometry2D.is_point_in_polygon(pixel, face_core):
			result.face += 1
			if result.face == 1:
				result.first_face_overlap_world = [float(weapon.offset.x + (point.rotated(angle) * direction).x), float(weapon.offset.y + (point.rotated(angle) * direction).y)]
				result.first_face_overlap_head_source = [pixel.x, pixel.y]
			if point in hilt_opaque_samples:
				result.hilt_face += 1
				if result.hilt_face == 1:
					result.first_hilt_overlap_world = [float(weapon.offset.x + (point.rotated(angle) * direction).x), float(weapon.offset.y + (point.rotated(angle) * direction).y)]
	return result
