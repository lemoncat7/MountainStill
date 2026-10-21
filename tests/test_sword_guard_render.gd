extends SceneTree
## Pure render-geometry contracts. Native snapshots are still required;
## these assertions alone do not judge the appearance or animation.
const Rig = preload("res://scripts/character_sidewalk.gd")
var checks := 0
var failures: Array[String] = []

func _initialize() -> void:
	test_edge_trace()
	test_guard_and_dodge()
	for failure in failures: push_error(failure)
	print("SWORD_GUARD_RENDER %d checks, %d failures" % [checks, failures.size()])
	quit(0 if failures.is_empty() else 1)

func expect(ok: bool, reason: String) -> void:
	checks += 1
	if not ok: failures.append(reason)

func motion(move: String, phase: String, progress: float, facing: float = 1.0) -> Dictionary:
	return {"combat_stance": 1.0, "action_kind": "basic", "basic_style": "sword", "attack_style": "sword", "attack_amount": 1.0, "combat_move": move, "combat_phase": phase, "phase_progress": progress, "facing": facing, "technique": "mist"}

func test_edge_trace() -> void:
	var nonempty := 0
	for move in ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"]:
		for phase in ["idle", "windup", "strike", "contact", "recovery"]:
			for frame in range(51):
				var sample := motion(move, phase, frame / 50.0)
				var trail: PackedVector2Array = Rig.sword_edge_trace(sample)
				if phase not in ["strike", "contact"]:
					expect(trail.is_empty(), "No edge residue before motion or through recovery")
					continue
				var length := 0.0
				for index in range(1, trail.size()):
					length += trail[index - 1].distance_to(trail[index])
				expect(length <= 14.001, "Ordinary edge trace is bounded to fourteen native pixels")
				for point in trail: expect(point.is_finite(), "Every edge sample is finite")
				if trail.size() > 1:
					nonempty += 1
					var grip: Dictionary = Rig.weapon_pose(sample, 1.0, 0.0, "sword")
					var tip: Vector2 = Vector2(grip.offset) + Vector2(0, -49.76).rotated(float(grip.rotation) + 0.22)
					expect(trail[-1].distance_to(tip) < .001, "Short edge trace ends on the real rendered sword tip")
					var other := sample.duplicate()
					other.facing = -1.0
					var mirrored: PackedVector2Array = Rig.sword_edge_trace(other)
					expect(mirrored.size() == trail.size(), "Mirroring cannot create a second weapon-shaped trace")
					for index in range(mini(mirrored.size(), trail.size())):
						expect(mirrored[index].distance_to(trail[index] * Vector2(-1, 1)) < .001, "Trace follows the actual mirrored weapon")
	expect(nonempty > 100, "Trace test exercises actual swing samples")

func test_guard_and_dodge() -> void:
	for defense in ["guard", "dodge"]:
		for frame in range(51):
			var strength := frame / 50.0
			var sample := motion("", "idle", 0.0)
			sample.attack_amount = 0.0
			sample.defense_action = defense
			sample.reaction_amount = strength
			var pose: Dictionary = Rig.sample_pose(sample)
			var grip: Dictionary = Rig.weapon_pose(sample, 1.0, 0.0, "sword")
			expect(not grip.stowed, "Physical sword defense retains its real weapon")
			expect(Vector2(grip.offset).distance_to(Rig.attachment_offset(Vector2.ZERO, sample)) < .001, "Defensive sword remains at the original painted fist joint")
			for name in ["near_leg", "far_leg"]:
				var leg: Dictionary = pose[name]
				expect(absf(Vector2(leg.knee).distance_to(leg.hip) - Rig.UPPER_LENGTH) < .001, "Defense keeps fixed thigh length")
				expect(absf(Vector2(leg.ankle).distance_to(leg.knee) - Rig.LOWER_LENGTH) < .001, "Defense keeps fixed calf length")
				expect(float(leg.ankle.y) <= Rig.REST_ANKLE.y + .001, "Defensive step does not penetrate ground")
			if defense == "dodge":
				var neutral := sample.duplicate()
				neutral.reaction_amount = 0.0
				var rest: Dictionary = Rig.sample_pose(neutral)
				expect(Vector2(pose.near_leg.ankle).distance_to(rest.near_leg.ankle) < .001, "Evasion keeps its lead sole planted")
				expect(absf(float(pose.far_leg.ankle.x) - float(rest.far_leg.ankle.x) + 32.0 * strength) < .001, "Evasion includes a genuine rear-foot displacement")
				expect(float(pose.shift.x) <= float(rest.shift.x) + .001, "Evasion slips hips away from incoming attack")
				expect(absf(float(pose.body_angle)) <= .14001, "Evasion avoids a large-head flip")
			elif strength == 1.0:
				var tip_delta := Vector2(0, -49.76).rotated(float(grip.rotation) + .22)
				expect(tip_delta.x > 20.0, "Guard blade rises ahead of chest")
				expect(tip_delta.y < -28.0, "Guard blade has a real upward braced angle")
