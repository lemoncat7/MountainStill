extends RefCounted
## Articulated paper-doll locomotion. Coordinates below refer to the original
## aligned 512px equipment canvases; no alternate, undressed walk sprite is used.
## Call update_motion with actual screen-space velocity and then draw in _draw.

const PIXEL_SCALE := 136.0 / 512.0
const FOOT_ANCHOR := Vector2(256.0, 496.0)
const STRIDE := 24.0
const WALK_LIFT := 8.0
const CONTACT := 0.60
const CYCLE_DISTANCE := 2.0 * STRIDE / CONTACT * PIXEL_SCALE
const HIP_LEFT := Vector2(231.0, 405.0)
const KNEE_LEFT := Vector2(226.0, 451.0)
const ANKLE_LEFT := Vector2(222.0, 482.0)
const UPPER_LENGTH := 46.2709412
const LOWER_LENGTH := 31.2569992
const SHOULDER_LEFT := Vector2(217.0, 343.0)
const ELBOW_LEFT := Vector2(202.0, 379.0)
const WRIST_LEFT := Vector2(196.0, 412.0)
const GRIP_RIGHT := Vector2(318.0, 414.0)

var phase := 0.0
var blend := 0.0
var facing := 1.0
var idle_time := 0.0


func update_motion(delta: float, velocity: float, scale: float = 1.0) -> Dictionary:
	var dt := maxf(delta, 0.0)
	var speed := absf(velocity)
	var moving := speed > 0.5
	idle_time += dt
	if moving:
		facing = signf(velocity)
		# One planted foot travels backward at exactly the character's velocity.
		phase = fposmod(phase + speed * dt / (CYCLE_DISTANCE * maxf(scale, 0.05)), 1.0)
	blend = move_toward(blend, 1.0 if moving else 0.0, dt * (10.0 if moving else 7.0))
	if blend < 0.0001:
		blend = 0.0
		phase = 0.0
	var bob := _support_drop(phase, blend) * PIXEL_SCALE
	var breath := (1.0 - blend) * sin(idle_time * 1.9) * 0.45
	return {"phase": phase, "blend": blend, "facing": facing,
		"bob": bob + breath, "body_tilt": blend * 0.012,
		"stride_lift": WALK_LIFT,
		"velocity": velocity, "moving": moving}


static func _support_drop(cycle: float, amount: float) -> float:
	# Lower the pelvis only enough to reach the planted foot. The old fixed
	# twenty-pixel crouch made every step look like a squat.
	var drop := 0.0
	var reach := UPPER_LENGTH + LOWER_LENGTH - 0.20
	for side in [0, 1]:
		var foot := _foot_travel(fposmod(cycle + side * 0.5, 1.0), WALK_LIFT)
		var dx := (-9.0 if side == 0 else 9.0) + float(foot.travel) * amount
		var vertical := sqrt(maxf(0.0, reach * reach - dx * dx))
		drop = maxf(drop, 77.0 - float(foot.lift) * amount - vertical)
	return maxf(0.0, drop) * smoothstep(0.0, 0.12, amount)


static func attachment_offset(source_point: Vector2, motion: Dictionary,
		scale: float = 1.0, cast_tilt: float = 0.0) -> Vector2:
	## The grip uses precisely the same articulated skinning as the visible hand.
	var pose := sample_pose(motion, cast_tilt)
	var point: Vector2
	if source_point.y >= 370.0 and (source_point.x < 218.0 or source_point.x > 294.0):
		point = skin_arm_point(source_point, pose.left_arm if source_point.x < 256.0 else pose.right_arm, pose)
	else:
		point = _body_point(source_point, pose)
	return (point - FOOT_ANCHOR) * Vector2(float(pose.facing), 1.0) * PIXEL_SCALE * scale


static func attachment_rotation(motion: Dictionary, cast_tilt: float = 0.0) -> float:
	## Canonical hand rotation, before the caller applies the shared facing mirror.
	return float(sample_pose(motion, cast_tilt).right_arm.hand_angle)


static func sample_pose(motion: Dictionary, cast_tilt: float = 0.0) -> Dictionary:
	var amount := clampf(float(motion.get("blend", 0.0)), 0.0, 1.0)
	var cycle := fposmod(float(motion.get("phase", 0.0)), 1.0)
	var direction := -1.0 if float(motion.get("facing", 1.0)) < 0.0 else 1.0
	var combat := _combat_pose(motion)
	var stance := float(combat.amount)
	var body_shift := Vector2(1.5 * float(combat.extend), float(motion.get("bob", 0.0)) / PIXEL_SCALE + 2.4 * stance)
	var pose := {"body_shift": body_shift, "facing": direction,
		"body_angle": float(motion.get("body_tilt", 0.0)) + cast_tilt * direction + float(combat.tilt),
		"combat": combat, "blend": amount, "phase": cycle}
	# Older explicit pose callers may still request the original high step.
	# update_motion always emits the restrained contact-aware WALK_LIFT.
	var lift := float(motion.get("stride_lift", 22.0))
	pose.left = _leg_pose(0, cycle, amount, body_shift, lift, stance)
	pose.right = _leg_pose(1, fposmod(cycle + 0.5, 1.0), amount, body_shift, lift, stance)
	pose.left_arm = _arm_pose(0, pose)
	pose.right_arm = _arm_pose(1, pose)
	pose.combat_hand = pose.right_arm.wrist
	return pose


static func _combat_pose(motion: Dictionary) -> Dictionary:
	# Optional normalized attack timeline: gather, extend, follow through, settle.
	# Zero and one are exactly neutral, so interruption never leaves a held pose.
	var t := clampf(float(motion.get("attack_phase", 0.0)), 0.0, 1.0)
	var strength := clampf(float(motion.get("attack_amount", 1.0)), 0.0, 1.0)
	var gather := smoothstep(0.0, 0.22, t) * (1.0 - smoothstep(0.22, 0.43, t)) * strength
	var extend := smoothstep(0.22, 0.45, t) * (1.0 - smoothstep(0.57, 1.0, t)) * strength
	var active := maxf(gather, extend)
	var style := str(motion.get("attack_style", "sword"))
	var upper := 0.16 * gather - 0.80 * extend
	var lower := 0.34 * gather - 1.22 * extend
	# The sword source points upward. A clockwise wrist sweep sends the blade
	# ahead of the grip instead of sweeping it inward across the face.
	var hand := 0.40 * gather + 0.98 * extend
	if style == "fan":
		upper = 0.10 * gather - 0.62 * extend
		lower = 0.16 * gather - 1.08 * extend
		hand = 0.22 * gather - 0.58 * extend
	elif style == "unarmed":
		upper = 0.12 * gather - 0.91 * extend
		lower = 0.48 * gather - 1.15 * extend
		hand = lower
	return {"gather": gather, "extend": extend, "amount": active,
		"upper": upper, "lower": lower, "hand": hand,
		"tilt": -0.014 * gather + 0.026 * extend}


static func _arm_pose(side: int, pose: Dictionary) -> Dictionary:
	var shoulder := SHOULDER_LEFT if side == 0 else _mirror(SHOULDER_LEFT)
	var elbow := ELBOW_LEFT if side == 0 else _mirror(ELBOW_LEFT)
	var wrist := WRIST_LEFT if side == 0 else GRIP_RIGHT
	var body_angle := float(pose.body_angle)
	var swing := sin(float(pose.phase) * TAU) * float(pose.blend) * (1.0 - float(pose.combat.amount))
	var upper_angle := body_angle + swing * (0.13 if side == 0 else -0.13)
	var lower_angle := body_angle + swing * (0.17 if side == 0 else -0.17)
	var hand_angle := lower_angle
	if side == 1:
		upper_angle += float(pose.combat.upper)
		lower_angle += float(pose.combat.lower)
		hand_angle += float(pose.combat.hand)
	else:
		upper_angle -= float(pose.combat.amount) * 0.20
		lower_angle -= float(pose.combat.amount) * 0.65
		hand_angle = lower_angle
	var target_shoulder := _body_point(shoulder, pose)
	var target_elbow := target_shoulder + (elbow - shoulder).rotated(upper_angle)
	var target_wrist := target_elbow + (wrist - elbow).rotated(lower_angle)
	return {"rest_shoulder": shoulder, "rest_elbow": elbow, "rest_wrist": wrist,
		"shoulder": target_shoulder, "elbow": target_elbow, "wrist": target_wrist,
		"upper_angle": upper_angle, "lower_angle": lower_angle, "hand_angle": hand_angle}


static func _foot_travel(cycle: float, lift_height: float) -> Dictionary:
	if cycle <= CONTACT:
		return {"travel": lerpf(STRIDE, -STRIDE, cycle / CONTACT), "lift": 0.0}
	var t := (cycle - CONTACT) / (1.0 - CONTACT)
	return {"travel": lerpf(-STRIDE, STRIDE, t * t * (3.0 - 2.0 * t)),
		"lift": sin(t * PI) * lift_height}


static func _leg_pose(side: int, cycle: float, amount: float, body_shift: Vector2,
		lift_height: float = 22.0, stance: float = 0.0) -> Dictionary:
	var rest_hip := HIP_LEFT if side == 0 else _mirror(HIP_LEFT)
	var rest_knee := KNEE_LEFT if side == 0 else _mirror(KNEE_LEFT)
	var rest_ankle := ANKLE_LEFT if side == 0 else _mirror(ANKLE_LEFT)
	var foot := _foot_travel(cycle, lift_height)
	var travel := float(foot.travel)
	var lift := float(foot.lift)
	var planted := cycle <= CONTACT or amount <= 0.0001
	var hip := rest_hip + body_shift
	var ankle := rest_ankle + Vector2(travel * amount + (-2.0 if side == 0 else 2.0) * stance, -lift * amount)
	if amount <= 0.0001 and stance <= 0.0001:
		# Exact original rest silhouette, including breathing as one coherent body.
		return {"hip": hip, "knee": rest_knee + body_shift,
			"ankle": rest_ankle + body_shift, "rest_hip": rest_hip,
			"rest_knee": rest_knee, "rest_ankle": rest_ankle,
			"upper_angle": 0.0, "lower_angle": 0.0, "foot_angle": 0.0,
			"planted": true, "lift": 0.0, "cycle": cycle}
	# Fixed-length two-bone inverse kinematics. The kneecap remains attached;
	# translation of the foot is never implemented by stretching a leg image.
	var delta := ankle - hip
	var distance := clampf(delta.length(), absf(UPPER_LENGTH - LOWER_LENGTH) + 0.001,
		UPPER_LENGTH + LOWER_LENGTH - 0.001)
	var axis := delta.normalized()
	ankle = hip + axis * distance
	var along := (UPPER_LENGTH * UPPER_LENGTH - LOWER_LENGTH * LOWER_LENGTH + distance * distance) / (2.0 * distance)
	var perpendicular := sqrt(maxf(0.0, UPPER_LENGTH * UPPER_LENGTH - along * along))
	# Both knees bend toward the walking direction. Rest pose bypasses IK above.
	var knee := hip + axis * along + Vector2(axis.y, -axis.x) * perpendicular
	var upper_angle := (knee - hip).angle() - (rest_knee - rest_hip).angle()
	var lower_angle := (ankle - knee).angle() - (rest_ankle - rest_knee).angle()
	var foot_angle := 0.0 if planted else -sin((cycle - CONTACT) / (1.0 - CONTACT) * PI) * 0.13 * amount
	return {"hip": hip, "knee": knee, "ankle": ankle, "rest_hip": rest_hip,
		"rest_knee": rest_knee, "rest_ankle": rest_ankle,
		"upper_angle": upper_angle, "lower_angle": lower_angle, "foot_angle": foot_angle,
		"planted": planted, "lift": lift * amount, "cycle": cycle}


static func _mirror(point: Vector2) -> Vector2:
	return Vector2(512.0 - point.x, point.y)


func draw_avatar_layers(host: CanvasItem, feet: Vector2, textures: Dictionary,
		visual_loadout: Dictionary, motion: Dictionary, scale: float = 1.0,
		cast_tilt: float = 0.0) -> void:
	if not textures.has("base"):
		return
	var pose := sample_pose(motion, cast_tilt)
	var direction := float(pose.facing)
	var body_shift: Vector2 = pose.body_shift
	var world_scale := PIXEL_SCALE * scale
	var base: Texture2D = textures.base
	# All limbs, sleeves and headgear share the same facing and anchor.
	_set_transform(host, feet, 0.0, Vector2(direction, 1.0) * world_scale)
	var legs_key := str(visual_loadout.get("legs", ""))
	var shoes_key := str(visual_loadout.get("feet", ""))
	var chest_key := str(visual_loadout.get("chest", ""))
	var head_key := str(visual_loadout.get("head", ""))
	var order := ["left", "right"] if float(pose.left.lift) <= float(pose.right.lift) else ["right", "left"]
	for name in order:
		var side := 0 if name == "left" else 1
		var leg: Dictionary = pose[name]
		_draw_base_leg(host, base, side, leg, body_shift)
		if textures.has(legs_key):
			_draw_rig_region(host, textures[legs_key], side, leg, body_shift, 397.0, 488.0, false)
		if textures.has(shoes_key):
			_draw_rig_region(host, textures[shoes_key], side, leg, body_shift, 437.0, 506.0, true)
	# Source contours isolate arms rather than rotating the whole standing sprite.
	_draw_torso(host, base, pose)
	_draw_pose_region(host, base, Rect2(233, 397, 46, 27), pose)
	if textures.has(legs_key):
		_draw_pose_region(host, textures[legs_key], Rect2(180, 373, 152, 25), pose)
		_draw_pose_region(host, textures[legs_key], Rect2(232, 397, 48, 28), pose)
	if textures.has(chest_key):
		_draw_pose_region(host, textures[chest_key], Rect2(218, 300, 76, 100), pose)
		_draw_pose_region(host, textures[chest_key], Rect2(180, 300, 38, 30), pose)
		_draw_pose_region(host, textures[chest_key], Rect2(294, 300, 38, 30), pose)
	for side in [0, 1]:
		_draw_arm(host, base, side, pose, false)
		if textures.has(chest_key):
			_draw_arm(host, textures[chest_key], side, pose, true)
	if textures.has(head_key):
		_draw_pose_region(host, textures[head_key], Rect2(0, 0, 512, 320), pose)
	_set_transform(host, Vector2.ZERO)


static func _body_point(point: Vector2, pose: Dictionary) -> Vector2:
	var waist := Vector2(256.0, 405.0)
	return waist + (point - waist).rotated(float(pose.body_angle)) + Vector2(pose.body_shift)


static func skin_arm_point(point: Vector2, arm: Dictionary, pose: Dictionary) -> Vector2:
	var upper := Vector2(arm.shoulder) + (point - Vector2(arm.rest_shoulder)).rotated(float(arm.upper_angle))
	var lower := Vector2(arm.elbow) + (point - Vector2(arm.rest_elbow)).rotated(float(arm.lower_angle))
	var hand := Vector2(arm.wrist) + (point - Vector2(arm.rest_wrist)).rotated(float(arm.hand_angle))
	if point.y <= 355.0:
		return _body_point(point, pose).lerp(upper, smoothstep(328.0, 355.0, point.y))
	if point.y <= 392.0:
		return upper.lerp(lower, smoothstep(368.0, 390.0, point.y))
	return lower.lerp(hand, smoothstep(401.0, 412.0, point.y))


static func _arm_boundary(y: float) -> float:
	# Traced from the original base pixels. Shorts are outside this contour.
	var rows := [326.0,340.0,352.0,366.0,378.0,390.0,402.0,414.0,431.0]
	var inner := [218.0,226.0,225.0,220.0,218.0,214.0,210.0,207.0,203.0]
	for i in range(rows.size() - 1):
		if y <= rows[i + 1]:
			return lerpf(inner[i], inner[i+1], clampf((y-rows[i])/(rows[i+1]-rows[i]),0.0,1.0))
	return 203.0


static func skin_arm_surface(point: Vector2, arm: Dictionary, pose: Dictionary, sleeve: bool = false) -> Vector2:
	var articulated := skin_arm_point(point, arm, pose)
	if point.y >= 366.0:
		return articulated
	# Keep the shoulder's inner fabric/skin edge stitched to the torso. Three
	# strips across the sleeve let its outer edge rotate without opening a crack.
	var left_point := point if float(arm.rest_shoulder.x) < 256.0 else _mirror(point)
	var edge := 218.0 if sleeve else _arm_boundary(point.y)
	var across := smoothstep(0.0, 15.0, edge - left_point.x)
	var free := lerpf(across, 1.0, smoothstep(350.0, 366.0, point.y))
	return _body_point(point, pose).lerp(articulated, free)


static func _draw_arm(host: CanvasItem, texture: Texture2D, side: int, pose: Dictionary, sleeve: bool) -> void:
	var arm: Dictionary = pose.left_arm if side == 0 else pose.right_arm
	var first := 330 if sleeve else 326
	var last := 397 if sleeve else 431
	for y in range(first, last, 3):
		var next := minf(float(y) + 3.0, float(last))
		var edge := 218.0 if sleeve else _arm_boundary(y)
		var next_edge := 218.0 if sleeve else _arm_boundary(next)
		var outer := 180.0 if sleeve else 165.0
		for strip in range(3):
			var a := float(strip) / 3.0
			var b := float(strip + 1) / 3.0
			var source := PackedVector2Array([Vector2(lerpf(outer,edge,a),y),Vector2(lerpf(outer,edge,b),y),
				Vector2(lerpf(outer,next_edge,b),next),Vector2(lerpf(outer,next_edge,a),next)])
			var vertices := PackedVector2Array()
			for j in range(source.size()):
				if side == 1: source[j] = _mirror(source[j])
				vertices.append(skin_arm_surface(source[j], arm, pose, sleeve))
			_draw_pose_quad(host, texture, source, vertices)


static func _draw_torso(host: CanvasItem, texture: Texture2D, pose: Dictionary) -> void:
	_draw_pose_region(host, texture, Rect2(0, 0, 512, 326), pose)
	for y in range(326, 399, 3):
		var next := minf(float(y) + 3.0, 399.0)
		var left := _arm_boundary(y)
		var next_left := _arm_boundary(next)
		var source := PackedVector2Array([Vector2(left,y),Vector2(512-left,y),Vector2(512-next_left,next),Vector2(next_left,next)])
		var vertices := PackedVector2Array()
		for point in source: vertices.append(_body_point(point, pose))
		_draw_pose_quad(host, texture, source, vertices)


static func _draw_pose_region(host: CanvasItem, texture: Texture2D, region: Rect2, pose: Dictionary) -> void:
	var p := region.position
	var e := region.end
	var source := PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
	var vertices := PackedVector2Array()
	for point in source: vertices.append(_body_point(point, pose))
	_draw_pose_quad(host, texture, source, vertices)


static func _draw_pose_quad(host: CanvasItem, texture: Texture2D, source: PackedVector2Array, points: PackedVector2Array) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for i in range(source.size()):
		vertices.append(points[i] - FOOT_ANCHOR)
		uv.append(source[i] / 512.0)
	for triangle in _quad_triangles(vertices, uv):
		host.draw_polygon(triangle.vertices, PackedColorArray([Color.WHITE]), triangle.uv, texture)


static func _draw_base_leg(host: CanvasItem, texture: Texture2D, side: int,
		leg: Dictionary, body_shift: Vector2) -> void:
	# The inner boundary runs through the source's transparent crotch. The outer
	# contour keeps the unmoving hands out of the thigh region (not a half-image).
	var rows := [399.0, 410.0, 422.0, 433.0, 443.0, 452.0, 464.0, 477.0, 489.0, 502.0]
	var outer := [211.0, 210.0, 205.0, 198.0, 198.0, 198.0, 195.0, 192.0, 192.0, 192.0]
	for index in range(rows.size() - 1):
		var x0 := float(outer[index])
		var x1 := float(outer[index + 1])
		var source := PackedVector2Array([Vector2(x0,rows[index]),Vector2(256,rows[index]),Vector2(256,rows[index+1]),Vector2(x1,rows[index+1])])
		if side == 1:
			for j in range(source.size()):source[j] = _mirror(source[j])
		_draw_skinned_quad(host, texture, source, leg, body_shift, false)


static func _draw_rig_region(host: CanvasItem, texture: Texture2D, side: int,
		leg: Dictionary, body_shift: Vector2, top: float, bottom: float, shoe: bool) -> void:
	var left := 180.0 if side == 0 else 256.0
	var right := 256.0 if side == 0 else 334.0
	var y := top
	while y < bottom:
		var next := minf(y + 8.0, bottom)
		var source := PackedVector2Array([Vector2(left,y),Vector2(right,y),Vector2(right,next),Vector2(left,next)])
		_draw_skinned_quad(host, texture, source, leg, body_shift, shoe)
		y = next


static func _draw_skinned_quad(host: CanvasItem, texture: Texture2D,
		source: PackedVector2Array, leg: Dictionary, body_shift: Vector2, shoe: bool) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	for p in source:
		vertices.append(_skin_point(p, leg, body_shift, shoe) - FOOT_ANCHOR)
		uv.append(p / 512.0)
	# Skinning can make a strip concave at a deeply bent knee. Feed explicit
	# triangles instead of asking CanvasItem to triangulate a possibly crossed
	# quad. UVs follow the same indices, including the mirrored source half.
	for triangle in _quad_triangles(vertices, uv):
		host.draw_polygon(triangle.vertices, PackedColorArray([Color.WHITE]), triangle.uv, texture)


static func _quad_triangles(vertices: PackedVector2Array, uv: PackedVector2Array) -> Array:
	var result: Array = []
	for indices in [[0,1,2],[0,2,3]]:
		var a: Vector2 = vertices[indices[0]]
		var b: Vector2 = vertices[indices[1]]
		var c: Vector2 = vertices[indices[2]]
		var area := (b-a).cross(c-a)
		# A collapsed edge is genuinely zero-area, so it must not be submitted.
		if absf(area) < 0.00001:
			continue
		if area < 0.0:
			indices = [indices[0],indices[2],indices[1]]
		result.append({"vertices":PackedVector2Array([vertices[indices[0]],vertices[indices[1]],vertices[indices[2]]]),
			"uv":PackedVector2Array([uv[indices[0]],uv[indices[1]],uv[indices[2]]])})
	return result


static func _skin_point(p: Vector2, leg: Dictionary, body_shift: Vector2, shoe: bool) -> Vector2:
	var upper: Vector2 = leg.hip + (p - Vector2(leg.rest_hip)).rotated(float(leg.upper_angle))
	var lower: Vector2 = leg.knee + (p - Vector2(leg.rest_knee)).rotated(float(leg.lower_angle))
	var foot: Vector2 = leg.ankle + (p - Vector2(leg.rest_ankle)).rotated(float(leg.foot_angle))
	if shoe:
		# Boot shafts follow the calf; soles stay flat during ground contact.
		return lower.lerp(foot, smoothstep(459.0, 480.0, p.y))
	if p.y <= 416.0:
		return (p + body_shift).lerp(upper, smoothstep(397.0, 416.0, p.y))
	if p.y <= 462.0:
		return upper.lerp(lower, smoothstep(440.0, 462.0, p.y))
	return lower.lerp(foot, smoothstep(472.0, 486.0, p.y))


static func _draw_body_region(host: CanvasItem, texture: Texture2D, region: Rect2,
		shift: Vector2, angle: float) -> void:
	var p := region.position
	var e := region.end
	_draw_body_polygon(host, texture, PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)]), shift, angle)


static func _draw_body_polygon(host: CanvasItem, texture: Texture2D,
		source: PackedVector2Array, shift: Vector2, angle: float) -> void:
	var vertices := PackedVector2Array()
	var uv := PackedVector2Array()
	var waist := Vector2(256.0, 405.0)
	for p in source:
		vertices.append(waist + (p - waist).rotated(angle) + shift - FOOT_ANCHOR)
		uv.append(p / 512.0)
	host.draw_polygon(vertices, PackedColorArray([Color.WHITE]), uv, texture)


static func _set_transform(host:CanvasItem,origin:Vector2,rotation:float=0.0,scale_value:Vector2=Vector2.ONE):
	if host.has_method("_scene_set_transform"):host._scene_set_transform(origin,rotation,scale_value)
	else:host.draw_set_transform(origin,rotation,scale_value)
