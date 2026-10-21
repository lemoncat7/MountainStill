extends Control
## Independent wardrobe/journal closeup. The scene is only a read-only source of
## equipped artwork and meditation state: opening or casting here never moves,
## pauses, redirects, or otherwise changes the character in the world.

const CharacterWalk = preload("res://scripts/character_walk.gd")
const CharacterMeditation = preload("res://scripts/character_meditation.gd")
const CAST_DURATION := 6.0
const TARGET_SCALE := 1.88
const PORTRAIT_HALF_WIDTH := 40.0
const DISPLAY_INSET := 12.0
const WEAPON_DISPLAY_GAP := 12.0
const WEAPON_DISPLAY_SCALE := 0.82
const WEAPON_LANE_WIDTH := 48.0
const WEAPON_HOVER_HEIGHT := 1.75

var host: Control
var reveal := 0.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		self_modulate = Color(1, 1, 1, reveal)
		queue_redraw()
var cast_time := 0.0

var _walker = CharacterWalk.new()
var _meditator = CharacterMeditation.new()
var _motion: Dictionary = {"phase":0.0, "blend":0.0, "facing":1.0, "bob":0.0, "body_tilt":0.0}
var _seat_amount := 0.0
var _breath_clock := 0.0
var _cast_clock := 0.0
var _cast_strength := 0.0
var _was_active := false
var _draw_transform := Transform2D.IDENTITY
var _display_clock := 0.0


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	clip_contents = true
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	self_modulate = Color(1, 1, 1, 0)
	set_process(false)
	set_physics_process(false)


func play_technique() -> void:
	## A repeat click restarts only this six-second demonstration.
	cast_time = CAST_DURATION
	_cast_clock = 0.0
	queue_redraw()


func cancel_technique() -> void:
	cast_time = 0.0
	_cast_clock = 0.0
	_cast_strength = 0.0
	_motion.erase("attack_phase")
	_motion.erase("attack_amount")
	queue_redraw()


func advance(delta: float, active: bool) -> void:
	## Called by the host. There is deliberately no _process or gameplay callback.
	if not is_instance_valid(host):
		return
	var dt := maxf(delta, 0.0)
	var scene_seat := clampf(float(host.get("meditation_amount")), 0.0, 1.0)
	# Wardrobe display stands for a clear view of pants and footwear. This pose
	# belongs only to this portrait; the world can stay seated and cultivating.
	if str(host.get("drawer_name")) == "wardrobe":scene_seat = 0.0
	if active and not _was_active:
		_seat_amount = scene_seat
		_breath_clock = float(host.get("meditation_clock"))
	if not active:
		# Closing a book cancels its local demonstration, including a later reopen.
		cast_time = 0.0
		_cast_strength = 0.0
		_cast_clock = 0.0
	else:
		_display_clock += dt
		cast_time = maxf(0.0, cast_time - dt)
		if cast_time > 0.0:
			_cast_clock += dt
	var target_seat := 0.0 if cast_time > 0.0 else scene_seat
	_seat_amount = move_toward(_seat_amount, target_seat, dt * 2.5)
	if cast_time <= 0.0 and _cast_strength <= 0.001:
		_breath_clock = float(host.get("meditation_clock"))
	else:
		_breath_clock += dt
	var show_cast := active and cast_time > 0.65 and _seat_amount < 0.015
	_cast_strength = move_toward(_cast_strength, 1.0 if show_cast else 0.0, dt * 3.8)
	_motion = _walker.update_motion(dt if active else 0.0, 0.0)
	# The closeup always faces the reader; its facing and pose are its own.
	_motion.facing = 1.0
	# Standing portrait soles stay planted; only the independent item hovers.
	_motion.bob = 0.0
	# A wardrobe weapon is a separate display item, never an implied grip.
	# Only free-palm spells gesture here. Weapon-art effects can be inspected
	# without making an empty hand swing or the displayed item orbit the body.
	var id := displayed_technique()
	var category := _technique_category(id)
	if cast_time > 0.0 and category in ["spell", "defense", "support"]:
		_motion.attack_phase = fposmod(_cast_clock, 2.1) / 2.1
		_motion.attack_amount = _cast_strength * 0.72
		_motion.attack_style = "unarmed"
		_motion.combat_move = {"ember":"ember_pulse", "frost":"frost_seal", "thunder":"thunder_strike", "barrier":"barrier_guard", "mending":"mending_bloom"}.get(id, "")
		_motion.action_kind = "spell"
	_meditator.facing = 1.0
	_was_active = active
	if active or reveal > 0.0:
		queue_redraw()


func _draw() -> void:
	if reveal <= 0.001 or not is_instance_valid(host) or size.x < 48.0 or size.y < 48.0:
		return
	var textures: Dictionary = host.get("equipment_assets")
	if not textures.has("base"):
		return
	var visual: Dictionary = host.state.gear.visual_loadout()
	var weapon := str(visual.get("weapon", "")).trim_prefix("weapon_")
	var character_scale := _character_scale(weapon)
	var feet := _feet_position(character_scale, weapon)
	var zoom := lerpf(0.97, 1.0, smoothstep(0.0, 1.0, reveal))
	_draw_transform = Transform2D(0.0, Vector2.ONE * zoom, 0.0, feet * (1.0 - zoom))

	# Only a faint ink contact shadow; the entire left area stays transparent.
	_scene_set_transform(feet + Vector2(0.0, 2.0), 0.0, Vector2(character_scale, character_scale * 0.13))
	draw_circle(Vector2.ZERO, 24.0, Color(0.20, 0.24, 0.19, 0.10))
	_scene_set_transform(Vector2.ZERO)
	_draw_heart_aura(feet, character_scale)
	_draw_technique(feet, character_scale, false)
	var cast_tilt := sin(_cast_clock * 2.4) * 0.018 * _cast_strength if not _technique_is_passive(displayed_technique()) else 0.0
	if _seat_amount > 0.0001:
		_meditator.draw_avatar_layers(self, feet, textures, visual, _seat_amount, _breath_clock, character_scale)
	else:
		_walker.draw_avatar_layers(self, feet, textures, visual, _motion, character_scale, cast_tilt)
	_draw_weapon(feet, character_scale, weapon)
	_draw_technique(feet, character_scale, true)
	draw_set_transform_matrix(Transform2D.IDENTITY)


func _weapon_dimensions(weapon: String) -> Vector2:
	return Vector2(26.0, 76.0) if weapon == "sword" else (Vector2(48.0, 40.0) if weapon == "fan" else Vector2.ZERO)


func _character_scale(_weapon: String) -> float:
	# The lane always reserves the largest supported weapon, even when empty.
	# Equipment changes must never resize or re-center the person.
	var footprint := PORTRAIT_HALF_WIDTH * 2.0 + WEAPON_LANE_WIDTH * WEAPON_DISPLAY_SCALE
	var width_scale := lerpf(1.80, TARGET_SCALE, smoothstep(218.0, 320.0, size.x))
	return maxf(0.1, minf(width_scale, minf((size.y - 34.0) / 124.0, (size.x - DISPLAY_INSET * 2.0 - WEAPON_DISPLAY_GAP) / footprint)))


func _feet_position(character_scale: float, _weapon: String) -> Vector2:
	var pair_width := (PORTRAIT_HALF_WIDTH * 2.0 + WEAPON_LANE_WIDTH * WEAPON_DISPLAY_SCALE) * character_scale + WEAPON_DISPLAY_GAP
	var center_x := (size.x - pair_width) * 0.5 + PORTRAIT_HALF_WIDTH * character_scale
	return Vector2(center_x, size.y - 20.0)


func weapon_placement(feet: Vector2, character_scale: float, weapon: String, _cast_tilt: float = 0.0) -> Dictionary:
	# Display position is intentionally independent of hand, attack, meditation
	# and cast transforms. A technique never swings or stows the floating item.
	var dimensions := _weapon_dimensions(weapon)
	var display_scale := character_scale * WEAPON_DISPLAY_SCALE
	var center := feet + Vector2(PORTRAIT_HALF_WIDTH * character_scale + WEAPON_DISPLAY_GAP + dimensions.x * display_scale * 0.5,
		-62.0 * character_scale + sin(_display_clock * 1.2) * WEAPON_HOVER_HEIGHT)
	return {"grip":center, "rotation":0.0, "stowed":false, "floating":true,
		"scale":display_scale, "rect":Rect2(-dimensions * 0.5, dimensions)}


func _draw_weapon(feet: Vector2, character_scale: float, weapon: String) -> void:
	var art: Dictionary = host.get("avatar_assets")
	if weapon.is_empty() or not art.has(weapon):return
	var placement := weapon_placement(feet, character_scale, weapon)
	_scene_set_transform(placement.grip, float(placement.rotation), Vector2.ONE * float(placement.scale))
	draw_texture_rect(art[weapon], placement.rect, false)
	_scene_set_transform(Vector2.ZERO)


func displayed_technique() -> String:
	# Inspection belongs to this portrait. Never write the host's active
	# technique or change the move profile of an in-progress world duel.
	var active := str(host.state.technique)
	if str(host.get("drawer_name")) == "wardrobe" and str(host.get("wardrobe_tab")) == "technique":
		var selected: Variant = host.get_meta("preview_technique", active)
		if selected is String and host.state.Content.TECHNIQUES.has(selected):
			return selected
	return active


func _technique_category(id: String) -> String:
	var definition: Dictionary = host.state.Content.TECHNIQUES.get(id, {})
	return str(definition.get("category", "heart" if id in ["stillness", "breath"] else ("weapon_art" if id in ["mist", "petal"] else "spell")))


func _technique_is_passive(id: String) -> bool:
	return float(host.state.Content.TECHNIQUES.get(id, {}).get("qi_cost", 0)) <= 0.0


func _draw_heart_aura(feet: Vector2, character_scale: float) -> void:
	var heart := str(host.state.get("equipped_heart"))
	if cast_time > 0.0 and _technique_is_passive(displayed_technique()):
		heart = displayed_technique()
	if heart not in ["stillness", "breath", "body"]:
		return
	_scene_set_transform(Vector2.ZERO)
	var center := feet + Vector2(0.0, -44.0 + _seat_amount * 12.0) * character_scale
	var breath := 0.5 + 0.5 * sin(_breath_clock * 1.15)
	var strength := 0.075 + breath * 0.035 + (_cast_strength * 0.10 if displayed_technique() == heart else 0.0)
	var radius := (22.0 + breath * 2.0) * character_scale
	if heart in ["stillness", "body"]:
		for i in range(2):
			draw_arc(center, radius + i * 5.0 * character_scale, 0.0, TAU, 50, Color(0.50 if heart == "stillness" else 0.64, 0.65 if heart == "stillness" else 0.57, 0.53 if heart == "stillness" else 0.39, strength * (1.0 - i * 0.28)), 0.8 * character_scale, true)
	else:
		for i in range(5):
			var t := fposmod(_breath_clock * 0.12 + i / 5.0, 1.0)
			var point := center + Vector2(sin(t * TAU) * 17.0, (0.5 - t) * 25.0) * character_scale
			draw_circle(point, character_scale * (1.0 + sin(t * PI) * 0.4), Color(0.46, 0.69, 0.66, strength * sin(t * PI)))


func _draw_technique(feet: Vector2, character_scale: float, foreground: bool) -> void:
	var technique := displayed_technique()
	if _cast_strength < 0.001 or _technique_is_passive(technique):
		return
	_scene_set_transform(Vector2.ZERO)
	var phase := fposmod(_cast_clock, 2.1) / 2.1
	var pulse := sin(phase * PI) * _cast_strength
	var center := feet + Vector2(0.0, -59.0) * character_scale
	var hand := feet + CharacterWalk.attachment_offset(CharacterWalk.GRIP_RIGHT, _motion, character_scale)
	var spell := _technique_category(technique) in ["spell", "defense", "support"]
	# Spells are visible marks from the free palm, not rings hidden behind the
	# large head. Passive hearts retain their separate faint background aura.
	if foreground != spell:return
	if technique in ["ember", "frost", "thunder"]:center=hand+Vector2(-4.0,-16.0)*character_scale
	var radius_limit := maxf(8.0, minf(38.0 * character_scale, minf(center.x - 12.0, size.x - center.x - 12.0)))
	var radius := minf(radius_limit, (20.0 + phase * 13.0) * character_scale)
	if spell:
		var hue := Color("c3824b") if technique == "ember" else (Color("8dbabd") if technique == "frost" else (Color("a69ac7") if technique == "thunder" else Color("8ca77d")))
		draw_circle(hand, (2.4 + pulse * 1.7) * character_scale, Color(hue, pulse * 0.36))
	match technique:
		"mist":
			for i in range(2):
				var r := radius - float(i) * 5.0 * character_scale
				draw_arc(center, r, -PI * 0.82 + phase * 0.65, PI * 0.69 + phase * 0.65, 44,
					Color(0.51,0.64,0.60,pulse * (0.32 - i * 0.07)), 1.1 * character_scale, true)
		"petal":
			for i in range(7):
				var theta := float(i) * TAU / 7.0 + _cast_clock * 0.55
				var point := center + Vector2(cos(theta) * radius, sin(theta) * radius * 0.65)
				_scene_set_transform(point, theta + 0.65, Vector2.ONE * character_scale)
				draw_colored_polygon(PackedVector2Array([Vector2(-2.8,0),Vector2(0,-1.8),Vector2(3.8,0),Vector2(0,2.0)]), Color(0.77,0.58,0.54,pulse * 0.46))
			_scene_set_transform(Vector2.ZERO)
		"ember":
			for i in range(6):
				var t := fposmod(phase + float(i)/6.0, 1.0)
				var xx := sin(float(i) * 2.5 + _cast_clock * 0.9) * radius * 0.50
				var point := hand + Vector2(xx - 8.0, -t * 27.0 * character_scale)
				var r := (1.6 + sin(t * PI)) * character_scale
				draw_colored_polygon(PackedVector2Array([point+Vector2(-r,r),point+Vector2(-r*0.7,0),point+Vector2(0,-r*2.6),point+Vector2(r,0),point+Vector2(r,r)]), Color(0.81,0.48,0.29,sin(t*PI)*_cast_strength*0.38))
		"frost":
			for i in range(6):
				var theta := float(i) * TAU / 6.0 + 0.12
				var point := center + Vector2(cos(theta), sin(theta) * 0.7) * radius
				var ice := PackedVector2Array([point+Vector2(0,-5)*character_scale,point+Vector2(3,0)*character_scale,point+Vector2(0,5)*character_scale,point+Vector2(-3,0)*character_scale,point+Vector2(0,-5)*character_scale])
				draw_polyline(ice, Color(0.51,0.71,0.75,pulse*0.52), character_scale*0.65, true)
			draw_arc(center, radius*0.80, 0, TAU, 40, Color(0.48,0.66,0.69,pulse*0.27), character_scale, true)
		"thunder":
			for i in range(3):
				var xx := center.x + (float(i)-1.0) * radius * 0.52
				var top := center.y-radius*0.7
				var bolt := PackedVector2Array([Vector2(xx,top),Vector2(xx-5,top+radius*0.43),Vector2(xx+4,top+radius*0.39),Vector2(xx-3,top+radius*0.92)])
				draw_polyline(bolt, Color(0.65,0.58,0.78,pulse*0.48), character_scale*1.15, true)

		"barrier":
			var half_width := radius * 0.55
			var shield := PackedVector2Array([center+Vector2(-half_width,-radius*0.5),center+Vector2(0,-radius*0.7),center+Vector2(half_width,-radius*0.5),center+Vector2(half_width,radius*0.1),center+Vector2(0,radius*0.7),center+Vector2(-half_width,radius*0.1),center+Vector2(-half_width,-radius*0.5)])
			draw_polyline(shield, Color(0.62,0.67,0.45,pulse*0.42),character_scale*1.4,true)
			draw_colored_polygon(shield,Color(0.66,0.72,0.51,pulse*0.045))
		"mending":
			for i in range(6):
				var t := fposmod(phase + i / 6.0,1.0)
				var point := center+Vector2(sin(i*2.4+phase)*radius*0.65,(0.5-t)*radius)
				var leaf := PackedVector2Array([point+Vector2(-4,1)*character_scale,point+Vector2(0,-3)*character_scale,point+Vector2(5,-1)*character_scale,point+Vector2(0,3)*character_scale])
				draw_colored_polygon(leaf,Color(0.49,0.66,0.41,sin(t*PI)*_cast_strength*0.4))


func _scene_set_transform(origin: Vector2, rotation: float = 0.0, scale_value: Vector2 = Vector2.ONE) -> void:
	## Both independent rigs use this hook, so their transform resets preserve the
	## preview's reveal scale. Nothing is forwarded to the world's drawing hooks.
	draw_set_transform_matrix(_draw_transform * Transform2D(rotation, scale_value, 0.0, origin))
