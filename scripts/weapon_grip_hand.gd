extends RefCounted
## Three AUTHORED anatomical views of a closed weapon hand, in native pixels.
##
## HAND-LOCAL axes: wrist/forearm enters from -Y; knuckles point toward +Y.
## The origin is the actual wrist, NOT the internal handle socket. Transform
## these two passes with arm.hand_angle, NEVER with weapon.rotation. Place the
## actual hilt at grip_socket().rotated(hand_angle) relative to the wrist, then
## apply the weapon's independent rotation. Keep a long pommel behind forearm.
##   Hand.draw_back(canvas, style, openness, tint, view, handedness)
##   ... draw the actual weapon using its independent hilt transform ...
##   Hand.draw_front(canvas, style, openness, tint, view, handedness)
##
## "dorsal": near-side back of hand, an uninterrupted metacarpal plane with
##             four distal knuckles; curled fingers live on the FAR side.
## "palm":   separate palmar art, four folded pads and an opposed thumb.
## "edge":   separate narrow side profile, a side knuckle and tucked digits.
## handedness +1 = right hand; -1 = left hand. Whole-actor facing mirrors AFTER
## this anatomical choice. In-plane wrist/weapon angles cannot select a view.
## Unarmed, stowed and inventory eligibility remains the caller's decision.

const SKIN := Color("f5bc8d")
const PALM := Color("eeb180")
const OUTLINE := Color("986546")
const CREASE := Color("bd8058")
const LIGHT := Color("ffe0b7")
const SHADE := Color("d89565")
const OUTLINE_WIDTH := 0.105
const VIEWS := ["dorsal", "palm", "edge"]

static func supports(style: String) -> bool:
	return style == "sword" or style == "fan"

static func grip_socket(style: String, view: String = "dorsal", handedness: float = 1.0) -> Vector2:
	## Native HAND-local offset from wrist to the centre of the held handle.
	## Sword passes through the ulnar half of the clenched fist, clear of the
	## wrist centre. A fan is pinched nearer the radial thumb/index junction.
	## View changes affect the camera projection of those anatomical sides.
	if not supports(style) or view not in VIEWS: return Vector2.ZERO
	var radial_sign := -1.0 if handedness < 0.0 else 1.0
	if view == "palm": radial_sign *= -1.0
	if style == "sword":
		return Vector2((-0.55 if view == "edge" else -1.35) * radial_sign, 1.65)
	return Vector2((0.18 if view == "edge" else 0.95) * radial_sign, 1.85)

static func presentation(arm_side: String, axial_roll: float = 0.0) -> Dictionary:
	## A caller without explicit forearm pronation data should keep zero roll:
	## near/right presents dorsum; far/left presents its opposing palm.
	## Never pass blade angle, wrist flexion, camera-facing sign or world angle.
	var far := arm_side == "far"
	var palmward := cos(axial_roll) * (-1.0 if far else 1.0)
	return {"view": "edge" if absf(palmward) < 0.45 else ("dorsal" if palmward > 0.0 else "palm"),
		"handedness": -1.0 if far else 1.0}

static func draw_back(host: CanvasItem, style: String, fan_open: float = 1.0, tint: Color = Color.WHITE, view: String = "dorsal", handedness: float = 1.0) -> void:
	var shapes := contours(style, fan_open, view, handedness)
	if shapes.is_empty(): return
	# These are genuinely the far-side finger returns and wrist/palm heel.
	# The weapon passes in front of them, but behind the near-side dorsum.
	_patch(host, shapes.rear, PALM, tint)
	for finger: PackedVector2Array in shapes.far_fingers:
		_patch(host, finger, PALM, tint)
	if shapes.surface_layer == "back": _draw_surface(host, shapes, tint)

static func draw_front(host: CanvasItem, style: String, fan_open: float = 1.0, tint: Color = Color.WHITE, view: String = "dorsal", handedness: float = 1.0) -> void:
	var shapes := contours(style, fan_open, view, handedness)
	if shapes.is_empty(): return
	if shapes.surface_layer == "front": _draw_surface(host, shapes, tint)
	# Dorsal has ZERO front pads. Its short creases terminate at the knuckle
	# ridge rather than running stripes across the back of the hand.
	for index in range(shapes.fingers.size()):
		_patch(host, shapes.fingers[index], SKIN, tint)
		_fill(host, shapes.finger_shadows[index], Color(SHADE, 0.54) * tint)
		_line(host, shapes.finger_lights[index], Color(LIGHT, 0.65) * tint, 0.12)
		_line(host, shapes.finger_creases[index], Color(CREASE, 0.64) * tint, 0.085)
	for line: PackedVector2Array in shapes.knuckle_lines:
		_line(host, line, Color(CREASE, 0.70) * tint, 0.095)
	_patch(host, shapes.thumb, SKIN.lightened(0.025), tint)
	_fill(host, shapes.thumb_shadow, Color(SHADE, 0.59) * tint)
	_line(host, shapes.thumb_light, Color(LIGHT, 0.69) * tint, 0.145)
	_line(host, shapes.thumb_crease, Color(CREASE, 0.65) * tint, 0.09)

static func _draw_surface(host: CanvasItem, shapes: Dictionary, tint: Color) -> void:
	_patch(host, shapes.surface, SKIN, tint)
	_fill(host, shapes.surface_light, Color(LIGHT, 0.39) * tint)
	_fill(host, shapes.surface_shadow, Color(SHADE, 0.47) * tint)
	for line: PackedVector2Array in shapes.surface_lines:
		_line(host, line, Color(CREASE, 0.40) * tint, 0.075)

static func contours(style: String, fan_open: float = 1.0, view: String = "dorsal", handedness: float = 1.0) -> Dictionary:
	if not supports(style) or view not in VIEWS: return {}
	var result := _dorsal(style, fan_open) if view == "dorsal" else (_palmar(style, fan_open) if view == "palm" else _edge(style, fan_open))
	result.view = view
	result.surface_layer = "back" if view == "palm" else "front"
	result.handedness = -1.0 if handedness < 0.0 else 1.0
	# The contours below are authored as a LEFT hand: with fingers toward
	# screen +Y, its dorsal thumb lies at -X and its palmar thumb at +X.
	# A right hand therefore mirrors the authored contour. In a right-facing
	# horizontal near/right thrust this places the dorsal thumb ABOVE the fist.
	if handedness > 0.0: result = _mirror(result)
	return result

static func _blank() -> Dictionary:
	return {"rear": PackedVector2Array(), "far_fingers": [],
		"surface": PackedVector2Array(), "surface_light": PackedVector2Array(),
		"surface_shadow": PackedVector2Array(), "surface_lines": [], "knuckle_lines": [],
		"fingers": [], "finger_shadows": [], "finger_lights": [], "finger_creases": [],
		"thumb": PackedVector2Array(), "thumb_shadow": PackedVector2Array(),
		"thumb_light": PackedVector2Array(), "thumb_crease": PackedVector2Array()}

static func _dorsal(style: String, fan_open: float) -> Dictionary:
	var shape := _blank()
	var fan := style == "fan"
	var tuck := lerpf(0.88, 1.0, clampf(fan_open, 0.0, 1.0)) if fan else 1.0
	shape.rear = _smooth([
		Vector2(-1.55,-1.94),Vector2(1.44,-1.94),Vector2(1.79,0.84),
		Vector2(1.89,2.80),Vector2(0.94,3.51),Vector2(-1.20,3.45),
		Vector2(-1.96,2.42),Vector2(-1.93,0.24)])
	# Four hooked returns are UNDER the shaft/dorsum, not painted pads on top.
	for index in range(4):
		var x := -1.55 + index * 1.02
		var y := 3.12 if index in [1,2] else 2.90
		shape.far_fingers.append(_smooth([
			Vector2(x-0.47,y-0.68),Vector2(x+0.42,y-0.66),
			Vector2(x+0.49,y+0.25),Vector2(x+0.18,y+0.57),
			Vector2(x-0.26,y+0.45),Vector2(x-0.48,y+0.13)]))
	shape.surface = _smooth([
		Vector2(-1.57,-1.88),Vector2(1.43,-1.88),
		Vector2(1.52,-0.45),Vector2(1.86,0.92),Vector2(2.16,1.82),
		Vector2(2.26,2.56),Vector2(2.07,2.99),Vector2(1.67,3.08),
		Vector2(1.43,3.35),Vector2(0.95,3.46),Vector2(0.62,3.22),
		Vector2(0.31,3.51),Vector2(-0.20,3.49),Vector2(-0.54,3.21),
		Vector2(-0.92,3.43),Vector2(-1.46,3.30),Vector2(-1.78,2.98),
		Vector2(-2.00,2.25),Vector2(-2.01,1.14),Vector2(-1.76,-0.26)])
	shape.surface_light = _smooth([
		Vector2(-1.24,-1.47),Vector2(-0.34,-1.48),Vector2(-0.09,-0.40),
		Vector2(0.40,1.27),Vector2(0.22,2.42),Vector2(-0.43,2.82),
		Vector2(-1.19,2.51),Vector2(-1.56,1.43),Vector2(-1.41,0.19)])
	shape.surface_shadow = _smooth([
		Vector2(1.19,-0.71),Vector2(1.66,0.95),Vector2(2.02,1.94),
		Vector2(2.06,2.64),Vector2(1.55,2.87),Vector2(1.37,3.16),
		Vector2(0.89,3.24),Vector2(0.62,3.04),Vector2(0.28,3.26),
		Vector2(-0.20,3.26),Vector2(-0.54,3.02),Vector2(-0.94,3.17),
		Vector2(-1.41,3.04),Vector2(-1.72,2.63),Vector2(-0.88,2.82),
		Vector2(0.02,2.86),Vector2(1.03,2.60),Vector2(1.40,1.75)])
	# Restrained dorsal tendon suggestions, never palmar life-lines or pads.
	shape.surface_lines = [
		_points([Vector2(-0.86,0.12),Vector2(-0.79,0.93),Vector2(-0.67,1.67)]),
		_points([Vector2(0.32,0.56),Vector2(0.47,1.33),Vector2(0.54,1.90)])]
	shape.knuckle_lines = [
		_points([Vector2(-0.60,2.66),Vector2(-0.57,2.98),Vector2(-0.54,3.18)]),
		_points([Vector2(0.58,2.74),Vector2(0.61,3.01),Vector2(0.62,3.19)]),
		_points([Vector2(1.55,2.57),Vector2(1.59,2.83),Vector2(1.65,3.02)])]
	# Authored left-hand thumb: -X/radial edge. Only its side is visible in dorsal
	# view; it tucks underneath the index, never lies across the dorsal plane.
	shape.thumb = _smooth([
		Vector2(-1.64,0.06),Vector2(-2.23,0.37),Vector2(-2.64,1.12),
		Vector2(-2.61,1.92),Vector2(-2.30,2.60),Vector2(-1.82,2.91),
		Vector2(-1.39,2.73),Vector2(-1.34,2.34),Vector2(-1.72,1.76),
		Vector2(-1.78,1.16),Vector2(-1.42,0.61)])
	shape.thumb_shadow = _smooth([
		Vector2(-2.40,1.36),Vector2(-2.34,2.03),Vector2(-1.94,2.55),
		Vector2(-1.51,2.52),Vector2(-1.50,2.75),Vector2(-1.88,2.79),
		Vector2(-2.29,2.49),Vector2(-2.51,1.93)])
	shape.thumb_light = _points([Vector2(-2.12,0.64),Vector2(-2.36,1.19),Vector2(-2.33,1.68)])
	shape.thumb_crease = _points([Vector2(-2.20,2.06),Vector2(-1.97,1.96),Vector2(-1.78,1.99)])
	if fan:
		# Pivot pinch: index-side thumb is slightly more abducted; ulnar two
		# knuckles tuck closer. This is still a dorsal view, not a palm swap.
		shape.thumb = _smooth([
			Vector2(-1.65,-0.02),Vector2(-2.29,0.22),Vector2(-2.68,0.84),
			Vector2(-2.66,1.53),Vector2(-2.23,2.20),Vector2(-1.82,2.35),
			Vector2(-1.48,2.16),Vector2(-1.52,1.79),Vector2(-1.82,1.26),
			Vector2(-1.83,0.77),Vector2(-1.42,0.48)])
		shape.thumb_shadow = _smooth([
			Vector2(-2.46,1.13),Vector2(-2.35,1.62),Vector2(-1.99,2.04),
			Vector2(-1.68,1.99),Vector2(-1.65,2.17),Vector2(-1.89,2.24),
			Vector2(-2.25,2.03),Vector2(-2.50,1.57)])
		shape.thumb_light = _points([Vector2(-2.17,0.47),Vector2(-2.39,0.88),Vector2(-2.37,1.29)])
		shape.thumb_crease = _points([Vector2(-2.22,1.66),Vector2(-2.01,1.55),Vector2(-1.82,1.61)])
		shape = _tuck(shape, tuck)
	return shape

static func _palmar(style: String, fan_open: float) -> Dictionary:
	var shape := _blank()
	shape.rear = _smooth([
		Vector2(-1.47,-1.90),Vector2(1.51,-1.90),Vector2(1.90,0.16),
		Vector2(2.06,2.40),Vector2(1.36,3.43),Vector2(-1.44,3.35),
		Vector2(-2.12,2.32),Vector2(-1.82,0.13)])
	shape.surface = _smooth([
		Vector2(-1.43,-1.88),Vector2(1.44,-1.88),Vector2(1.62,-0.28),
		Vector2(2.09,0.90),Vector2(1.88,2.39),Vector2(1.09,2.89),
		Vector2(-0.29,2.84),Vector2(-1.72,2.54),Vector2(-2.03,1.33),
		Vector2(-1.74,-0.15)])
	shape.surface_light = _smooth([
		Vector2(0.50,-1.40),Vector2(1.13,-1.35),Vector2(1.59,0.21),
		Vector2(1.24,1.28),Vector2(0.74,1.30),Vector2(0.18,0.48)])
	shape.surface_shadow = _smooth([
		Vector2(-1.66,0.20),Vector2(-1.79,1.36),Vector2(-1.46,2.29),
		Vector2(-0.32,2.61),Vector2(0.91,2.58),Vector2(0.64,2.77),
		Vector2(-0.58,2.66),Vector2(-1.67,2.40),Vector2(-1.89,1.37)])
	shape.surface_lines = [
		_points([Vector2(0.74,-0.06),Vector2(0.22,0.41),Vector2(-0.66,0.60)]),
		_points([Vector2(-1.28,1.00),Vector2(-0.84,1.31),Vector2(-0.25,1.37)])]
	# Four longitudinal pads fold back from the knuckles toward the palm.
	# This topology is independent of the dorsal silhouette, not a rotated
	# version of it and not the old horizontal shaft-crossing stripes.
	var xs := [-1.48,-0.47,0.51,1.39]
	for index in range(4):
		var x: float = xs[index]
		var y := 0.12 if index in [1,2] else -0.10
		var width := 0.88 if index==3 else 1.0
		var placement := Vector4(x, y, width, 0.02 * (index-1))
		var finger := _palmar_finger(placement)
		shape.fingers.append(finger.shape)
		shape.finger_shadows.append(finger.shadow)
		shape.finger_lights.append(finger.light)
		shape.finger_creases.append(finger.crease)
	# Same authored LEFT hand seen from its palm: radial thumb is now on +X.
	shape.thumb = _smooth([
		Vector2(1.37,-0.12),Vector2(2.05,0.08),Vector2(2.54,0.73),
		Vector2(2.53,1.46),Vector2(1.88,2.16),Vector2(0.90,2.46),
		Vector2(0.35,2.37),Vector2(0.13,2.00),Vector2(0.36,1.64),
		Vector2(1.15,1.32),Vector2(1.40,0.74),Vector2(1.15,0.30)])
	shape.thumb_shadow = _smooth([
		Vector2(2.31,0.99),Vector2(2.25,1.49),Vector2(1.71,1.98),
		Vector2(0.80,2.24),Vector2(0.37,2.14),Vector2(0.43,2.36),
		Vector2(0.90,2.37),Vector2(1.87,2.07),Vector2(2.37,1.50)])
	shape.thumb_light = _points([Vector2(1.90,0.34),Vector2(2.15,0.80),Vector2(2.05,1.17)])
	shape.thumb_crease = _points([Vector2(1.13,1.60),Vector2(1.24,1.85),Vector2(1.22,2.03)])
	if style=="fan":
		shape = _tuck(shape, lerpf(0.86,0.95,clampf(fan_open,0.0,1.0)))
	return shape

static func _edge(style: String, fan_open: float) -> Dictionary:
	var shape := _blank()
	shape.rear = _smooth([
		Vector2(-1.04,-1.89),Vector2(0.95,-1.89),Vector2(1.35,0.33),
		Vector2(1.65,2.74),Vector2(0.81,3.48),Vector2(-0.94,3.25),
		Vector2(-1.31,1.63)])
	shape.surface = _smooth([
		Vector2(-0.98,-1.86),Vector2(0.88,-1.86),Vector2(1.15,-0.17),
		Vector2(1.47,1.16),Vector2(1.49,2.51),Vector2(1.21,3.10),
		Vector2(0.55,3.38),Vector2(-0.18,3.14),Vector2(-0.67,2.58),
		Vector2(-1.12,1.39),Vector2(-1.19,0.31)])
	shape.surface_light = _smooth([
		Vector2(-0.51,-1.47),Vector2(0.09,-1.44),Vector2(0.55,0.03),
		Vector2(0.92,1.53),Vector2(0.58,2.70),Vector2(0.11,2.86),
		Vector2(-0.35,1.89),Vector2(-0.53,0.45)])
	shape.surface_shadow = _smooth([
		Vector2(1.00,0.18),Vector2(1.29,1.35),Vector2(1.30,2.51),
		Vector2(0.93,2.96),Vector2(0.40,3.10),Vector2(-0.07,2.92),
		Vector2(0.29,3.21),Vector2(0.65,3.25),Vector2(1.14,3.02),
		Vector2(1.39,2.48),Vector2(1.32,1.20)])
	shape.knuckle_lines = [
		_points([Vector2(0.56,2.60),Vector2(0.85,2.73),Vector2(1.12,2.73)]),
		_points([Vector2(0.19,2.06),Vector2(0.57,2.18),Vector2(0.95,2.18)])]
	shape.thumb = _smooth([
		Vector2(-0.79,0.02),Vector2(-1.44,0.35),Vector2(-1.71,1.04),
		Vector2(-1.61,1.94),Vector2(-0.95,2.59),Vector2(-0.37,2.70),
		Vector2(-0.13,2.39),Vector2(-0.34,1.98),Vector2(-0.81,1.59),
		Vector2(-0.89,0.99),Vector2(-0.58,0.51)])
	shape.thumb_shadow = _smooth([
		Vector2(-1.46,1.31),Vector2(-1.37,1.90),Vector2(-0.84,2.36),
		Vector2(-0.31,2.40),Vector2(-0.39,2.59),Vector2(-0.93,2.48),
		Vector2(-1.50,1.92)])
	shape.thumb_light = _points([Vector2(-1.29,0.65),Vector2(-1.44,1.04),Vector2(-1.38,1.51)])
	shape.thumb_crease = _points([Vector2(-1.09,1.88),Vector2(-0.86,1.79),Vector2(-0.67,1.84)])
	if style=="fan":shape = _tuck(shape,lerpf(0.88,0.97,clampf(fan_open,0.0,1.0)))
	return shape

static func _palmar_finger(placement: Vector4) -> Dictionary:
	var shape := _smooth([
		Vector2(-0.41,1.19),Vector2(-0.16,0.99),Vector2(0.21,1.04),
		Vector2(0.41,1.29),Vector2(0.44,2.09),Vector2(0.50,2.77),
		Vector2(0.35,3.26),Vector2(0.04,3.43),Vector2(-0.29,3.32),
		Vector2(-0.47,3.04),Vector2(-0.49,2.36),Vector2(-0.40,1.82)])
	var shadow := _smooth([
		Vector2(0.24,1.26),Vector2(0.28,1.94),Vector2(0.35,2.70),
		Vector2(0.23,3.13),Vector2(-0.05,3.27),Vector2(-0.29,3.14),
		Vector2(-0.17,3.34),Vector2(0.12,3.34),Vector2(0.35,3.14),
		Vector2(0.41,2.75),Vector2(0.36,1.80)])
	var light := _points([Vector2(-0.19,1.35),Vector2(-0.24,2.00),Vector2(-0.26,2.60)])
	var crease := _points([Vector2(-0.27,2.23),Vector2(-0.04,2.30),Vector2(0.22,2.23)])
	return {"shape":_place(shape,placement),"shadow":_place(shadow,placement),
		"light":_place(light,placement),"crease":_place(crease,placement)}

static func _points(values: Array) -> PackedVector2Array:
	return PackedVector2Array(values)

static func _smooth(values: Array) -> PackedVector2Array:
	var points := PackedVector2Array(values)
	var result := PackedVector2Array()
	for index in range(points.size()):
		var next := points[(index+1)%points.size()]
		result.append(points[index].lerp(next,0.19))
		result.append(points[index].lerp(next,0.81))
	return result

static func _place(points: PackedVector2Array, placement: Vector4) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:
		result.append(Vector2(point.x*placement.z,point.y).rotated(placement.w)+Vector2(placement.x,placement.y))
	return result

static func _map_points(points: PackedVector2Array, scale: Vector2) -> PackedVector2Array:
	var result := PackedVector2Array()
	for point in points:result.append(point*scale)
	return result

static func _map_shapes(shapes: Dictionary, scale: Vector2) -> Dictionary:
	var result := shapes.duplicate(true)
	for key in result:
		if result[key] is PackedVector2Array:
			result[key]=_map_points(result[key],scale)
		elif result[key] is Array:
			for index in range(result[key].size()):
				if result[key][index] is PackedVector2Array:result[key][index]=_map_points(result[key][index],scale)
	return result

static func _mirror(shapes: Dictionary) -> Dictionary:
	return _map_shapes(shapes,Vector2(-1.0,1.0))

static func _tuck(shapes: Dictionary, amount: float) -> Dictionary:
	return _map_shapes(shapes,Vector2(amount,1.0))

static func _patch(host: CanvasItem, points: PackedVector2Array, base: Color, tint: Color) -> void:
	if points.is_empty():return
	var colors := PackedColorArray()
	for point in points:
		var light := clampf(-point.x*0.025-point.y*0.018,-0.06,0.06)
		colors.append((base.lightened(light) if light>0.0 else base.darkened(-light))*tint)
	host.draw_polygon(points,colors)
	var boundary:=points.duplicate()
	boundary.append(points[0])
	host.draw_polyline(boundary,OUTLINE*tint,OUTLINE_WIDTH,true)

static func _fill(host: CanvasItem, points: PackedVector2Array, color: Color) -> void:
	if not points.is_empty():host.draw_colored_polygon(points,color)

static func _line(host: CanvasItem, points: PackedVector2Array, color: Color, width: float) -> void:
	if points.size()>1:host.draw_polyline(points,color,width,true)
