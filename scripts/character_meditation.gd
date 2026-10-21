extends RefCounted
## Seated, joint-driven paper doll using the original aligned equipment artwork.
## amount 0 is the exact front-facing standing art; 1 is a folded-leg seat.
## The pelvis and tucked feet stay planted while the spine and shoulders breathe.

const PIXEL_SCALE := 136.0 / 512.0
const FOOT_ANCHOR := Vector2(256.0, 496.0)
const BODY_DROP := 48.0
const BREATH_PERIOD := 5.8
const REST_HIP := Vector2(231.0, 405.0)
const REST_KNEE := Vector2(226.0, 451.0)
const REST_ANKLE := Vector2(222.0, 482.0)
const REST_SHOULDER := Vector2(217.0, 343.0)
const REST_ELBOW := Vector2(202.0, 379.0)
const REST_WRIST := Vector2(196.0, 412.0)

## Set from the last walking direction before entry to prevent a facing pop.
var facing := 1.0


static func sample_pose(amount: float, clock: float) -> Dictionary:
	var blend := clampf(amount, 0.0, 1.0)
	var seated := blend * blend * (3.0 - 2.0 * blend)
	var breath := sin(clock * TAU / BREATH_PERIOD) * 1.65 * seated
	var pose := {"amount": blend, "seated": seated, "breath": breath,
		"body_shift": Vector2(0.0, BODY_DROP * seated), "clock": clock}
	for side in [0, 1]:
		var key := "left" if side == 0 else "right"
		var hip := _side(REST_HIP, side)
		var knee := _side(REST_KNEE, side)
		var ankle := _side(REST_ANKLE, side)
		var seat_hip := _side(Vector2(231.0, 453.0), side)
		var seat_knee := _side(Vector2(191.0, 470.0), side)
		# Shins fold toward the opposite side instead of hanging below the seat.
		var seat_ankle := Vector2(242.0, 486.0) if side == 0 else Vector2(270.0, 486.0)
		var shoulder := _side(REST_SHOULDER, side)
		var elbow := _side(REST_ELBOW, side)
		var wrist := _side(REST_WRIST, side)
		pose[key] = {"side": side, "rest_hip": hip, "rest_knee": knee,
			"rest_ankle": ankle, "hip": hip.lerp(seat_hip, seated),
			"knee": knee.lerp(seat_knee, seated),
			"ankle": ankle.lerp(seat_ankle, seated) + Vector2(0,-13.5*sin(PI*seated)),
			"foot_angle": (-2.55 if side == 0 else 2.55) * seated,
			"rest_shoulder": shoulder, "rest_elbow": elbow, "rest_wrist": wrist,
			"shoulder": _body_point(shoulder, pose),
			"elbow": elbow.lerp(_side(Vector2(192.0, 425.0), side), seated) + Vector2(0, -breath * 0.25),
			"wrist": wrist.lerp(_side(Vector2(195.0, 456.0), side), seated),
			"hand_angle": (-0.40 if side == 0 else 0.40) * seated}
	return pose


static func seated_hand_offset(side: int, amount: float, clock: float, scale: float = 1.0) -> Vector2:
	var pose := sample_pose(amount, clock)
	var arm: Dictionary = pose.left if side == 0 else pose.right
	return (Vector2(arm.wrist) - FOOT_ANCHOR) * PIXEL_SCALE * scale


static func resting_weapon_offset(scale: float = 1.0, weapon_key: String = "sword") -> Vector2:
	## Calibrated against the actual weapon alpha at host angles +.43 / -.32.
	## Place the grip here: the sword tassel/fan rim rests at the foot baseline.
	return (Vector2(48.0, -9.5) if weapon_key.trim_prefix("weapon_") == "fan" else Vector2(34.0, -20.0)) * scale


func draw_avatar_layers(host: CanvasItem, feet: Vector2, textures: Dictionary,
		visual_loadout: Dictionary, amount: float, clock: float, scale: float = 1.0) -> void:
	if not textures.has("base"):
		return
	var pose := sample_pose(amount, clock)
	var base: Texture2D = textures.base
	var legs_key := str(visual_loadout.get("legs", ""))
	var shoes_key := str(visual_loadout.get("feet", ""))
	var chest_key := str(visual_loadout.get("chest", ""))
	var head_key := str(visual_loadout.get("head", ""))
	_set_transform(host,feet, 0.0, Vector2(-1.0 if facing < 0.0 else 1.0, 1.0) * PIXEL_SCALE * scale)
	# Both thighs are behind the folded shins. Clothes are attached to each bone,
	# rather than flattening a dressed standing sprite into a seated silhouette.
	for side in [0, 1]:
		_draw_base_leg(host, base, side, pose, 399.0, 451.0)
		if textures.has(legs_key):
			_draw_leg_region(host, textures[legs_key], side, pose, 397.0, 451.0, false)
	for side in [0, 1]:
		_draw_base_leg(host, base, side, pose, 451.0, 503.0)
		if textures.has(legs_key):
			_draw_leg_region(host, textures[legs_key], side, pose, 451.0, 488.0, false)
		if textures.has(shoes_key):
			_draw_leg_region(host, textures[shoes_key], side, pose, 437.0, 506.0, true)
	# The centre stays opaque throughout the transition, including bare shorts.
	_draw_torso(host, base, pose)
	_draw_pelvis(host, base, pose, false)
	if textures.has(legs_key):
		_draw_pelvis(host, textures[legs_key], pose, true)
	# Short sleeves follow the arm root; lapels/waist remain on the spine.
	if textures.has(chest_key):
		_draw_chest(host, textures[chest_key], pose, false)
	for side in [0, 1]:
		_draw_arm(host, base, side, pose)
		if textures.has(chest_key):
			_draw_chest_arm(host, textures[chest_key], side, pose)
	_draw_soft_eyes(host, base, pose)
	if textures.has(head_key):
		_draw_body_rect(host, textures[head_key], Rect2(0, 0, 512, 320), pose)
	_set_transform(host,Vector2.ZERO)


static func _side(point: Vector2, side: int) -> Vector2:
	return point if side == 0 else Vector2(512.0 - point.x, point.y)


static func _body_point(point: Vector2, pose: Dictionary) -> Vector2:
	# Breath pivots gently above the stable pelvis. No floor bob or floating feet.
	var spine_weight := 1.0 - smoothstep(340.0, 405.0, point.y)
	return point + Vector2(pose.body_shift) + Vector2(0.0, -float(pose.breath) * spine_weight)


static func _bone_point(point: Vector2, source_start: Vector2, source_end: Vector2,
		target_start: Vector2, target_end: Vector2) -> Vector2:
	var source_axis := source_end - source_start
	var target_axis := target_end - target_start
	var source_normal := Vector2(-source_axis.y, source_axis.x).normalized()
	var target_normal := Vector2(-target_axis.y, target_axis.x).normalized()
	var along := (point - source_start).dot(source_axis) / source_axis.length_squared()
	var across := (point - source_start).dot(source_normal)
	return target_start + target_axis * along + target_normal * across


static func skin_leg_point(point: Vector2, leg: Dictionary, pose: Dictionary, shoe: bool = false) -> Vector2:
	var upper := _bone_point(point, leg.rest_hip, leg.rest_knee, leg.hip, leg.knee)
	var lower := _bone_point(point, leg.rest_knee, leg.rest_ankle, leg.knee, leg.ankle)
	var foot := Vector2(leg.ankle) + (point - Vector2(leg.rest_ankle)).rotated(float(leg.foot_angle))
	if shoe:
		return lower.lerp(foot, smoothstep(457.0, 480.0, point.y))
	if point.y <= 416.0:
		return _body_point(point, pose).lerp(upper, smoothstep(397.0, 416.0, point.y))
	if point.y <= 460.0:
		return upper.lerp(lower, smoothstep(440.0, 460.0, point.y))
	return lower.lerp(foot, smoothstep(471.0, 485.0, point.y))


static func skin_arm_point(point: Vector2, arm: Dictionary, pose: Dictionary) -> Vector2:
	var upper := _bone_point(point, arm.rest_shoulder, arm.rest_elbow, arm.shoulder, arm.elbow)
	var lower := _bone_point(point, arm.rest_elbow, arm.rest_wrist, arm.elbow, arm.wrist)
	var hand := Vector2(arm.wrist) + (point - Vector2(arm.rest_wrist)).rotated(float(arm.hand_angle))
	if point.y <= 355.0:
		return _body_point(point, pose).lerp(upper, smoothstep(328.0, 355.0, point.y))
	if point.y <= 392.0:
		return upper.lerp(lower, smoothstep(368.0, 390.0, point.y))
	return lower.lerp(hand, smoothstep(401.0, 414.0, point.y))


static func _draw_base_leg(host: CanvasItem, texture: Texture2D, side: int,
		pose: Dictionary, top: float, bottom: float) -> void:
	var rows := [399.0,410.0,422.0,433.0,443.0,451.0,460.0,470.0,480.0,490.0,503.0]
	var outer := [211.0,210.0,205.0,198.0,198.0,198.0,197.0,194.0,192.0,192.0,192.0]
	for i in range(rows.size() - 1):
		if rows[i] < top or rows[i + 1] > bottom:
			continue
		_draw_leg_strip(host, texture, side, pose, float(outer[i]), float(outer[i+1]),
			float(rows[i]), float(rows[i+1]), false)


static func _draw_leg_region(host: CanvasItem, texture: Texture2D, side: int,
		pose: Dictionary, top: float, bottom: float, shoe: bool) -> void:
	var y := top
	while y < bottom:
		var next := minf(y + 6.0, bottom)
		_draw_leg_strip(host, texture, side, pose, 180.0, 180.0, y, next, shoe)
		y = next


static func _draw_leg_strip(host: CanvasItem, texture: Texture2D, side: int,
		pose: Dictionary, outer_top: float, outer_bottom: float,
		top: float, bottom: float, shoe: bool) -> void:
	var leg: Dictionary = pose.left if side == 0 else pose.right
	# Split width as well as height to avoid diagonal shears at deeply folded knees.
	for i in range(5):
		var a := float(i) / 5.0
		var b := float(i + 1) / 5.0
		var source := PackedVector2Array([Vector2(lerpf(outer_top,256.0,a),top),
			Vector2(lerpf(outer_top,256.0,b),top),Vector2(lerpf(outer_bottom,256.0,b),bottom),
			Vector2(lerpf(outer_bottom,256.0,a),bottom)])
		var vertices := PackedVector2Array()
		for j in range(source.size()):
			source[j] = _side(source[j], side)
			vertices.append(skin_leg_point(source[j], leg, pose, shoe))
		_draw_quad(host, texture, source, vertices)


static func _arm_boundary(y: float) -> float:
	var rows := [326.0,340.0,352.0,366.0,378.0,390.0,402.0,414.0,431.0]
	var inner := [218.0,226.0,225.0,220.0,218.0,214.0,210.0,207.0,203.0]
	for i in range(rows.size() - 1):
		if y <= rows[i + 1]:
			return lerpf(inner[i], inner[i+1], clampf((y-rows[i])/(rows[i+1]-rows[i]),0.0,1.0))
	return 203.0


static func _draw_arm(host: CanvasItem, texture: Texture2D, side: int, pose: Dictionary) -> void:
	var arm: Dictionary = pose.left if side == 0 else pose.right
	for y in range(326, 431, 3):
		var next := minf(float(y) + 3.0, 431.0)
		var source := PackedVector2Array([Vector2(165,y),Vector2(_arm_boundary(y),y),
			Vector2(_arm_boundary(next),next),Vector2(165,next)])
		var vertices := PackedVector2Array()
		for j in range(source.size()):
			source[j] = _side(source[j], side)
			vertices.append(skin_arm_point(source[j], arm, pose))
		_draw_quad(host, texture, source, vertices)


static func _draw_torso(host: CanvasItem, texture: Texture2D, pose: Dictionary) -> void:
	_draw_body_rect(host, texture, Rect2(0,0,512,326), pose)
	for y in range(326, 399, 3):
		var next := minf(float(y)+3.0,399.0)
		var left := _arm_boundary(y)
		var next_left := _arm_boundary(next)
		_draw_body_polygon(host, texture, PackedVector2Array([Vector2(left,y),Vector2(512-left,y),
			Vector2(512-next_left,next),Vector2(next_left,next)]), pose)


static func _draw_pelvis(host: CanvasItem, texture: Texture2D, pose: Dictionary, clothing: bool) -> void:
	if clothing:
		_draw_body_rect(host, texture, Rect2(180,373,152,25), pose)
	# Central shorts seam covers both thigh roots. Never replace it with skin.
	_draw_body_polygon(host, texture, PackedVector2Array([Vector2(232,397),Vector2(280,397),
		Vector2(277,424),Vector2(235,424)]), pose)


static func _draw_chest(host: CanvasItem, texture: Texture2D, pose: Dictionary, _unused: bool) -> void:
	_draw_body_rect(host, texture, Rect2(218,300,76,100), pose)
	_draw_body_rect(host, texture, Rect2(180,300,38,30), pose)
	_draw_body_rect(host, texture, Rect2(294,300,38,30), pose)


static func _draw_chest_arm(host: CanvasItem, texture: Texture2D, side: int, pose: Dictionary) -> void:
	var arm: Dictionary = pose.left if side == 0 else pose.right
	for y in range(330, 397, 3):
		var next := minf(float(y)+3.0,397.0)
		var source := PackedVector2Array([Vector2(180,y),Vector2(218,y),Vector2(218,next),Vector2(180,next)])
		var vertices := PackedVector2Array()
		for j in range(source.size()):
			source[j] = _side(source[j], side)
			vertices.append(skin_arm_point(source[j], arm, pose))
		_draw_quad(host, texture, source, vertices)


static func _draw_body_rect(host: CanvasItem, texture: Texture2D, region: Rect2, pose: Dictionary) -> void:
	var p := region.position
	var e := region.end
	_draw_body_polygon(host, texture, PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)]), pose)


static func _draw_body_polygon(host: CanvasItem, texture: Texture2D, source: PackedVector2Array, pose: Dictionary) -> void:
	var vertices := PackedVector2Array()
	for point in source:
		vertices.append(_body_point(point, pose))
	_draw_quad(host, texture, source, vertices)


static func _draw_quad(host: CanvasItem, texture: Texture2D, source: PackedVector2Array, vertices: PackedVector2Array) -> void:
	for indices in [[0,1,2],[0,2,3]]:
		var a: Vector2 = vertices[indices[0]]
		var b: Vector2 = vertices[indices[1]]
		var c: Vector2 = vertices[indices[2]]
		if absf((b-a).cross(c-a)) < 0.00001:
			continue
		if (b-a).cross(c-a) < 0.0:
			indices = [indices[0],indices[2],indices[1]]
		var triangle := PackedVector2Array()
		var uv := PackedVector2Array()
		for i in indices:
			triangle.append(vertices[i] - FOOT_ANCHOR)
			uv.append(source[i] / 512.0)
		host.draw_polygon(triangle, PackedColorArray([Color.WHITE]), uv, texture)


static func _draw_soft_eyes(host: CanvasItem, texture: Texture2D, pose: Dictionary) -> void:
	# Tiny curved cheek-texture patches close the existing eyes. Sampling the same
	# face keeps watercolor color/shading, unlike opaque, flat skin-colored discs.
	var closure := smoothstep(0.60, 0.78, float(pose.seated))
	if closure <= 0.0:
		return
	var eyes := [
		PackedVector2Array([Vector2(193,248),Vector2(201,242),Vector2(213,239),Vector2(228,241),
			Vector2(241,249),Vector2(239,260),Vector2(231,268),Vector2(215,270),Vector2(202,266),Vector2(195,259)]),
		PackedVector2Array([Vector2(270,247),Vector2(278,238),Vector2(291,234),Vector2(305,234),
			Vector2(319,240),Vector2(317,253),Vector2(309,263),Vector2(293,267),Vector2(281,263),Vector2(273,256)])]
	for side in [0, 1]:
		var vertices := PackedVector2Array()
		var uv := PackedVector2Array()
		for point in eyes[side]:
			vertices.append(_body_point(point, pose) - FOOT_ANCHOR)
			var source_x := clampf(point.x, 204.0, 238.0) if side == 0 else clampf(point.x, 277.0, 308.0)
			uv.append(Vector2(source_x, 272.0 + (point.y - 245.0) * 0.12) / 512.0)
		host.draw_polygon(vertices, PackedColorArray([Color(1,1,1,closure)]), uv, texture)
	var lines := [PackedVector2Array([Vector2(198,252),Vector2(204,255),Vector2(213,257),Vector2(222,257),Vector2(231,254),Vector2(237,250)]),
		PackedVector2Array([Vector2(275,248),Vector2(282,252),Vector2(291,254),Vector2(300,254),Vector2(308,251),Vector2(315,246)])]
	for source in lines:
		var line := PackedVector2Array()
		for point in source:
			line.append(_body_point(point, pose) - FOOT_ANCHOR)
		host.draw_polyline(line, Color(0.25,0.14,0.12,closure), 2.3, true)


static func _set_transform(host:CanvasItem,origin:Vector2,rotation:float=0.0,scale_value:Vector2=Vector2.ONE):
	if host.has_method("_scene_set_transform"):host._scene_set_transform(origin,rotation,scale_value)
	else:host.draw_set_transform(origin,rotation,scale_value)
