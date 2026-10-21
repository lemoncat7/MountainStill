extends RefCounted
## Contact-only, event-authored physical feedback. No node, global clock, camera,
## background, UI or combat state is changed here. The host applies `hitstop` to
## its local duel presentation, and calls draw() from a CanvasItem._draw().
##
## describe(event) -> immutable-by-convention presentation profile
## stream(profile) -> cached, deterministic, self-authored AudioStreamWAV
## draw(canvas, {profile, position, age, scale = 1.0}) -> small contact marks
##
## All ordinary contacts carry actor, target, move, resolution, poise_broken,
## raw_damage, damage, action_kind, skill_id and basic_style. Optional metadata:
## enemy_visual_type, hero_style, move_family, impact_weight, impact_direction,
## contact_role, target_material, guard_material and shield_absorbed.
const ResponseCues = preload("res://scripts/combat_response_cues.gd")
const SAMPLE_RATE := 32000
const VARIATIONS := 4
const MAX_CACHE_ENTRIES := 192
const MATERIALS := ["body", "moss", "feather", "stone", "metal", "wood",
	"air", "shield", "ember", "frost", "thunder"]
const FAMILY_WEIGHT := {
	"moss_rush": 1.30, "moss_pounce": 0.80, "moss_slam": 1.50,
	"crane_peck": 0.58, "crane_sweep": 1.05, "crane_dive": 1.32,
}
const MATERIAL_COLORS := {
	"body": Color("a17c5d"), "moss": Color("78855b"),
	"feather": Color("a8b9b3"), "stone": Color("8a8d81"),
	"metal": Color("a8b5aa"), "wood": Color("a48a62"),
	"air": Color("a5b8aa"), "shield": Color("83aba0"),
	"ember": Color("bd8254"), "frost": Color("92b4b3"),
	"thunder": Color("aaa3b5"),
}
static var _streams: Dictionary = {}


static func describe(event: Dictionary) -> Dictionary:
	var response_cue := ResponseCues.contact_cue(event)
	var actor := str(event.get("actor", "hero"))
	var target := str(event.get("target", "enemy"))
	var move := str(event.get("move", ""))
	var resolution := str(event.get("resolution", "hit"))
	var role := str(event.get("contact_role", "strike"))
	var action_kind := str(event.get("action_kind", "basic"))
	var skill := str(event.get("skill_id", ""))
	var style := str(event.get("basic_style", "unarmed"))
	var family := _move_family(event)
	var raw := maxf(0.0, _number(event.get("raw_damage", event.get("damage", 0.0)), 0.0))
	var damage := maxf(0.0, _number(event.get("damage", 0.0), 0.0))
	var absorbed := maxf(0.0, _number(event.get("shield_absorbed", 0.0), 0.0))
	var broken := bool(event.get("poise_broken", false))
	var active := not resolution in ["miss", "evade", "dodge", "whiff", "support", "heal"]
	active = active and (damage > 0.0 or resolution in ["guard", "block"] or absorbed > 0.0 or broken)
	var blocked := resolution in ["guard", "block"] or (absorbed > 0.0 and damage <= 0.0)
	var weight := _number(event.get("impact_weight", _authored_weight(family, move, skill, action_kind)), 0.85)
	weight = clampf(weight, 0.38, 1.65)
	if role == "aftershock":
		weight = minf(weight, 0.69)
	# Damage progression never turns a late-game tap into a huge special effect.
	var intensity := clampf(weight + minf(raw, 60.0) * 0.0007, 0.4, 1.65)
	var kind := "guardbreak" if broken else "block" if blocked else "heavy" if intensity >= 1.12 else "light"
	var material := _target_material(event)
	if blocked or broken:
		material = _guard_material(event, material, absorbed)
	var strike_material := _strike_material(actor, family, move, skill, style)
	var hitstop := 0.027 + clampf((intensity - 0.5) / 0.65, 0.0, 1.0) * 0.012
	var reaction_duration := 0.18 + intensity * 0.055
	var reaction_magnitude := 0.48 + intensity * 0.24
	var knockback := 2.0 + intensity * 3.0
	var duration := 0.21
	var gain_db := -11.6
	if kind == "heavy":
		hitstop = 0.066 + clampf((intensity - 1.1) / 0.5, 0.0, 1.0) * 0.016
		reaction_duration = 0.29 + intensity * 0.04
		reaction_magnitude = 0.92 + (intensity - 1.1) * 0.23
		knockback = 7.0 + (intensity - 1.1) * 7.0
		duration = 0.29
		gain_db = -8.9
	elif kind == "block":
		hitstop = 0.037 + minf(intensity, 1.5) * 0.008
		reaction_duration = 0.18 + intensity * 0.035
		reaction_magnitude = 0.33 + intensity * 0.13
		knockback = 1.3 + intensity * 1.2
		duration = 0.24
		gain_db = -10.4
	elif kind == "guardbreak":
		hitstop = 0.090 + minf(intensity, 1.5) * 0.006
		reaction_duration = 0.40
		reaction_magnitude = 1.20
		knockback = 10.5 + minf(intensity, 1.5) * 2.0
		duration = 0.34
		gain_db = -9.4
	# Earned punish has its own crisp contact beat. It never asserts a stagger,
	# modifies pressure/damage, or promotes the event to a guardbreak.
	if str(response_cue.get("kind","")) == "counter_hit":
		hitstop = maxf(hitstop,0.062)
		duration = maxf(duration,0.30)
		gain_db += 1.1
	if str(response_cue.get("kind","")) == "deflection":
		hitstop = maxf(hitstop,0.045)
		duration = maxf(duration,0.30)
	if absorbed > 0.0:
		duration = maxf(duration,0.32) # Keep the final ward fragments alive until fully dissolved.
	if role == "aftershock":
		hitstop *= 0.58
		reaction_magnitude *= 0.70
		knockback *= 0.65
		gain_db -= 2.0
	var direction := Vector2.RIGHT if target == "enemy" else Vector2.LEFT
	var supplied_direction: Variant = event.get("impact_direction", direction)
	if supplied_direction is Vector2 and supplied_direction.is_finite() and supplied_direction.length_squared() > 0.001:
		direction = supplied_direction.normalized()
	var seed_text := "%s/%s/%s/%s/%s" % [
		move, str(event.get("action_id", 0)), str(event.get("hit_index", 0)),
		str(event.get("contact_id", "")), str(event.get("variation_seed", 0))]
	var variation := (seed_text.hash() & 0x7fffffff) % VARIATIONS
	var pitch: float = [0.962, 0.987, 1.018, 1.043][variation]
	var sound_key := "%s:%s:%s:%s:%s:%d" % [kind, material, strike_material, family, role, variation]
	var contact_metadata := _contact_metadata(event, target, family)
	return {
		"active": active, "kind": kind, "intensity": intensity, "response_cue": response_cue,
		"material": material, "strike_material": strike_material,
		"family": family, "contact_role": role, "actor": actor, "target": target,
		"contact_point": contact_metadata.point, "contact_point_valid": contact_metadata.point_valid,
		"contact_region": contact_metadata.region, "contact_region_measured": contact_metadata.measured,
		"move": move, "resolution": resolution, "poise_broken": broken,
		"raw_damage": raw, "damage": damage, "action_kind": action_kind,
		"skill_id": skill, "basic_style": style,
		"hitstop": hitstop if active else 0.0,
		"reaction_duration": reaction_duration if active else 0.0,
		"reaction_magnitude": reaction_magnitude if active else 0.0,
		"knockback": knockback if active else 0.0,
		"direction": direction, "duration": duration if active else 0.0,
		"gain_db": gain_db, "pitch": pitch, "variation": variation,
		"sound_key": sound_key, "color": MATERIAL_COLORS.get(material, MATERIAL_COLORS.body),
		"debris_count": 6 if broken else 5 if kind == "heavy" else 3,
		"screen_shake": 0.0, "global_time_scale": 1.0,
	}


## These fields describe already-resolved geometry; they do not select damage,
## target, strike coverage or a new contact. Geometry uses hero-feet-local pixels.
## A supplied enemy region is classified at contact time by the timeline. Without
## those metadata, use only a clearly marked family/body presentation fallback.
static func _contact_metadata(event:Dictionary,target:String,family:String)->Dictionary:
	var result:Dictionary={"point":Vector2.ZERO,"point_valid":false,
		"region":"head" if family in ["crane_peck","crane_dive"] else "torso","measured":false}
	var geometry:Dictionary=event.get("enemy_contact",{}) if target=="hero" else event.get("melee_contact",{})
	var point:Variant=geometry.get("point" if target=="hero" else "target")
	if bool(geometry.get("contact",false)) and point is Vector2 and point.is_finite():
		result.point=point;result.point_valid=true
		if target=="hero":
			result.region="head" if point.y<=-58.0 else "torso" if point.y<=-25.0 else "leg"
			result.measured=true
	var explicit:String=str(event.get("contact_region",""))
	if explicit in ["head","torso","leg"]:
		result.region=explicit;result.measured=bool(event.get("contact_region_measured",false))
	return result


static func _authored_weight(family: String, move: String, skill: String, action_kind: String) -> float:
	if FAMILY_WEIGHT.has(family):
		return float(FAMILY_WEIGHT[family])
	if skill == "thunder" or move in ["thunder_strike", "weapon_sword_pierce", "petal_counter"]:
		return 1.32
	if move in ["stillness_push", "ember_palm", "basic_unarmed_palm"]:
		return 1.15
	if move in ["basic_unarmed_jab", "basic_fan_flick", "mist_combo"]:
		return 0.59
	if skill in ["frost", "ember"] or action_kind in ["spell", "weapon"]:
		return 1.06
	if "burst" in move or "slam" in move:
		return 1.30
	if "charge" in move:
		return 1.14
	return 0.84


static func _move_family(event: Dictionary) -> String:
	var family := str(event.get("move_family", ""))
	if not family.is_empty():
		return family
	var move := str(event.get("move", ""))
	if "moss" in move:
		if "slam" in move or "burst" in move:
			return "moss_slam"
		if "pounce" in move or "sweep" in move:
			return "moss_pounce"
		return "moss_rush"
	if "crane" in move:
		if "peck" in move or "burst" in move:
			return "crane_peck"
		if "sweep" in move:
			return "crane_sweep"
		return "crane_dive"
	return move


static func _species_material(species: String) -> String:
	if "moss" in species or "bamboo" in species:
		return "moss"
	if "crane" in species or "feather" in species:
		return "feather"
	if "stone" in species or "keeper" in species:
		return "stone"
	if "ember" in species:
		return "ember"
	if "wisp" in species:
		return "air"
	return "body"


static func _target_material(event: Dictionary) -> String:
	var explicit := str(event.get("target_material", ""))
	if explicit in MATERIALS:
		return explicit
	if str(event.get("target", "enemy")) == "hero":
		return "body"
	var species := str(event.get("enemy_visual_type", event.get("enemy_species", event.get("target_species", event.get("species", "")))))
	return _species_material(species)


static func _guard_material(event: Dictionary, target_material: String, absorbed: float) -> String:
	var explicit := str(event.get("guard_material", ""))
	if explicit in MATERIALS:
		return explicit
	if absorbed > 0.0:
		return "shield"
	if str(event.get("target", "enemy")) == "hero":
		var style := str(event.get("hero_style", event.get("defender_style", "unarmed")))
		return "metal" if style == "sword" else "wood" if style == "fan" else "shield"
	return "wood" if target_material == "moss" else "air" if target_material in ["air", "feather"] else "stone" if target_material == "stone" else "shield"


static func _strike_material(actor: String, family: String, move: String, skill: String, style: String) -> String:
	if actor != "hero":
		if family.begins_with("moss"):
			return "moss"
		if family == "crane_peck" or family == "crane_dive":
			return "wood" # A short beak tap over the soft feather/air body.
		if family == "crane_sweep":
			return "feather"
		return _species_material(move)
	if skill == "thunder" or move == "thunder_strike":
		return "thunder"
	if skill == "frost" or move == "frost_seal":
		return "frost"
	if skill == "ember" or move.begins_with("ember"):
		return "ember"
	if style == "sword" or "sword" in move:
		return "metal"
	if style == "fan" or "fan" in move:
		return "wood"
	return "body"


## A contact first compresses, then transfers its weight through the body,
## then lets the loose limb/wing settle. These are positive, one-shot envelopes,
## never a periodic shake. The source event and simulation clock stay untouched.
static func reaction(profile: Dictionary, age: float) -> Dictionary:
	var empty := {"amount": 0.0, "offset": Vector2.ZERO, "compression": 0.0,
		"impulse": 0.0, "recoil": 0.0, "followthrough": 0.0}
	var duration := float(profile.get("reaction_duration", 0.0))
	if not bool(profile.get("active", false)) or not is_finite(age) or age < 0.0 or duration <= 0.0 or age >= duration:
		return empty
	var magnitude := float(profile.get("reaction_magnitude", 0.0))
	var amount := 1.0 - smoothstep(duration * 0.15, duration, age)
	var impulse := 1.0 - smoothstep(duration * 0.10, duration * 0.55, age)
	var recoil := smoothstep(0.0, minf(0.055, duration * 0.18), age) * amount
	var followthrough := smoothstep(duration * 0.12, duration * 0.40, age) * (1.0 - smoothstep(duration * 0.48, duration, age))
	var kind := str(profile.get("kind", "light"))
	var compression := 0.025 if kind == "block" else 0.085 if kind == "guardbreak" else 0.065 if kind == "heavy" else 0.040
	return {
		"amount": amount * magnitude,
		"offset": Vector2(profile.get("direction", Vector2.RIGHT)) * float(profile.get("knockback", 0.0)) * recoil,
		"compression": impulse * compression * magnitude,
		"impulse": impulse * magnitude, "recoil": recoil * magnitude,
		"followthrough": followthrough * magnitude,
	}


## The host calls this only at a planted travel step. These are dry sole/ground
## textures, deliberately much softer than contact, never periodic ambience.
static func footstep_profile(material: String = "earth", serial: int = 0) -> Dictionary:
	var surface := "stone" if material in ["stone", "gravel"] else "wood" if material == "wood" else "moss"
	var variation := posmod(serial, VARIATIONS)
	return {
		"active": true, "kind": "footstep", "material": surface,
		"strike_material": "body", "contact_role": "step",
		"variation": variation, "pitch": [0.94, 1.03, 0.98, 1.07][variation],
		"gain_db": -18.8 if surface == "stone" else -18.0,
		"hitstop": 0.0, "reaction_duration": 0.0, "reaction_magnitude": 0.0,
		"knockback": 0.0, "duration": 0.0, "screen_shake": 0.0,
		"sound_key": "footstep:%s:%d" % [surface, variation],
	}


## Cached samples have no external assets or runtime file dependencies.
## Host gain leaves headroom; a dry transient is followed by a short body thud.
static func stream(profile: Dictionary) -> AudioStreamWAV:
	if not bool(profile.get("active", true)):
		return null
	var key := str(profile.get("sound_key", "light:body:body:strike:0"))
	if _streams.has(key):
		return _streams[key] as AudioStreamWAV
	var kind := str(profile.get("kind", "light"))
	var material := str(profile.get("material", "body"))
	var strike := str(profile.get("strike_material", "body"))
	var family := str(profile.get("family", ""))
	var variation := int(profile.get("variation", 0)) % VARIATIONS
	var pitch := float(profile.get("pitch", 1.0))
	var duration := 0.096 if kind == "footstep" else 0.112 if kind == "light" else 0.172 if kind == "heavy" else 0.185 if kind == "block" else 0.236
	if material in ["feather", "air"]:
		duration += 0.014
	var count := int(ceil(duration * SAMPLE_RATE))
	var floats := PackedFloat32Array()
	floats.resize(count)
	var rng := RandomNumberGenerator.new()
	rng.seed = 14287 + variation * 8191 + (key.hash() & 0x7fffffff)
	var low_noise := 0.0
	var middle_noise := 0.0
	var previous_input := 0.0
	var high_pass := 0.0
	var peak := 0.0
	for i in range(count):
		var t := float(i) / float(SAMPLE_RATE)
		var noise := rng.randf_range(-1.0, 1.0)
		low_noise = lerpf(low_noise, noise, 0.085)
		middle_noise = lerpf(middle_noise, noise, 0.43)
		var grain := middle_noise - low_noise
		var heavy := kind in ["heavy", "guardbreak"]
		var body_f := 98.0 if heavy else 148.0
		var body_damp := 34.0 if heavy else 49.0
		if family == "moss_slam":
			body_f = 78.0
			body_damp = 28.0
		elif family == "moss_rush":
			body_f = 111.0
			body_damp = 40.0
		elif family == "moss_pounce":
			body_f = 128.0
			body_damp = 46.0
		elif family == "crane_peck":
			body_f = 187.0
			body_damp = 74.0
		elif family == "crane_dive":
			body_f = 118.0
			body_damp = 37.0
		var body_phase := TAU * pitch * (body_f * t - (180.0 if heavy else 280.0) * t * t)
		var body := (sin(body_phase) * 0.31 + sin(body_phase * 1.74) * 0.09) * exp(-t * body_damp)
		# A very short contact slap precedes the low-mid pressure body. The
		# delayed body is stronger/longer on heavy strikes, while a guard
		# keeps its hard, compact ringing catch instead of sounding fleshy.
		var contact := grain * exp(-t * (210.0 if heavy else 285.0)) * (0.66 if heavy else 0.50)
		var load_t := maxf(0.0, t - (0.006 if heavy else 0.003))
		var load_gate := smoothstep(0.0, 0.004, load_t)
		var load := sin(TAU * pitch * ((76.0 if heavy else 119.0) * load_t - 115.0 * load_t * load_t))
		load *= load_gate * exp(-load_t * (31.0 if heavy else 58.0)) * (0.33 if heavy else 0.15)
		var wave := body + contact + load + _material_layer(material, t, pitch, noise, low_noise, grain, true) * 0.58
		wave += _material_layer(strike, t, pitch, noise, low_noise, grain, false) * 0.45
		if kind == "block":
			wave = body * 0.44 + contact * 0.88 + _guard_layer(material, t, pitch, grain) * 1.18 + wave * 0.24
		elif kind == "guardbreak":
			# Three close fractures with a low body. No explosion or bright ping.
			wave += _fracture(t, pitch, grain, noise) * 0.52
		elif kind == "footstep":
			wave = body * 0.29 + low_noise * exp(-t * 55.0) * 0.45
			wave += _material_layer(material, t, pitch, noise, low_noise, grain, true) * 0.35
		if str(profile.get("contact_role", "")) == "aftershock":
			wave = wave * 0.78 + low_noise * exp(-t * 28.0) * 0.2
		# Remove DC and end every sample at zero; avoid hard single-sample clicks.
		high_pass = wave - previous_input + 0.995 * high_pass
		previous_input = wave
		var envelope := smoothstep(0.0, 0.0009, t) * (1.0 - smoothstep(duration - 0.012, duration - 1.0 / SAMPLE_RATE, t))
		floats[i] = high_pass * envelope
		peak = maxf(peak, absf(floats[i]))
	var ceiling := 0.29 if kind == "footstep" else 0.58 if kind == "guardbreak" else 0.54 if kind == "heavy" else 0.48
	var normalize := ceiling / maxf(peak, 0.001)
	var samples := PackedByteArray()
	samples.resize(count * 2)
	for i in range(count):
		samples.encode_s16(i * 2, roundi(clampf(floats[i] * normalize, -ceiling, ceiling) * 32767.0))
	var audio := AudioStreamWAV.new()
	audio.format = AudioStreamWAV.FORMAT_16_BITS
	audio.mix_rate = SAMPLE_RATE
	audio.stereo = false
	audio.data = samples
	if _streams.size() >= MAX_CACHE_ENTRIES:
		_streams.erase(_streams.keys()[0])
	_streams[key] = audio
	return audio


static func _material_layer(material: String, t: float, pitch: float, noise: float,
		low: float, grain: float, target: bool) -> float:
	match material:
		"moss":
			var earthy := low * 0.80 * exp(-t * 35.0)
			var grit := grain * 0.30 * exp(-t * 66.0)
			var seed_crackle := (sin(t * 790.0) * sin(t * 1130.0)) * grain * exp(-t * 28.0) * 0.18
			return earthy + grit + seed_crackle
		"feather", "air":
			return grain * (0.27 if target else 0.50) * exp(-t * 34.0) + sin(TAU * 510.0 * pitch * t) * exp(-t * 75.0) * 0.045
		"metal":
			var ring := sin(TAU * 1743.0 * pitch * t) * 0.23 * exp(-t * 41.0)
			ring += sin(TAU * 2861.0 * pitch * t) * 0.11 * exp(-t * 69.0)
			ring += sin(TAU * 4139.0 * pitch * t) * 0.045 * exp(-t * 96.0)
			return ring + grain * 0.28 * exp(-t * 190.0)
		"wood":
			return sin(TAU * 638.0 * pitch * t) * 0.24 * exp(-t * 80.0) + sin(TAU * 1139.0 * pitch * t) * 0.085 * exp(-t * 120.0) + grain * 0.31 * exp(-t * 101.0)
		"stone":
			return grain * 0.31 * exp(-t * 48.0) + sin(TAU * 863.0 * pitch * t) * 0.12 * exp(-t * 66.0) + low * 0.45 * exp(-t * 26.0)
		"shield":
			return _guard_layer(material, t, pitch, grain) * 0.65
		"ember":
			return low * 0.62 * exp(-t * 28.0) + grain * 0.32 * exp(-t * 45.0) * (0.6 + 0.4 * sin(t * 715.0))
		"frost":
			return sin(TAU * 1237.0 * pitch * t) * 0.14 * exp(-t * 39.0) + sin(TAU * 2089.0 * pitch * t) * 0.055 * exp(-t * 50.0) + grain * 0.20 * exp(-t * 100.0)
		"thunder":
			return low * 0.51 * exp(-t * 27.0) + noise * 0.23 * exp(-t * 90.0) + grain * sin(t * 970.0) * 0.22 * exp(-t * 42.0)
	return low * 0.48 * exp(-t * 45.0) + grain * 0.17 * exp(-t * 120.0)


static func _guard_layer(material: String, t: float, pitch: float, grain: float) -> float:
	var frequency := 1281.0 if material == "metal" else 473.0 if material in ["wood", "moss"] else 687.0
	var damp := 25.0 if material in ["shield", "air"] else 42.0 if material == "metal" else 58.0
	var tone := sin(TAU * frequency * pitch * t) * exp(-t * damp) * 0.25
	tone += sin(TAU * frequency * 1.57 * pitch * t) * exp(-t * (damp + 12.0)) * 0.09
	return tone + grain * exp(-t * (45.0 if material == "air" else 140.0)) * 0.23


static func _fracture(t: float, pitch: float, grain: float, noise: float) -> float:
	var result := 0.0
	for tick in [0.0, 0.013, 0.031]:
		var local := t - float(tick)
		if local >= 0.0:
			var envelope := smoothstep(0.0, 0.0007, local) * exp(-local * 150.0)
			result += (noise * 0.43 + grain * 0.28 + sin(TAU * 811.0 * pitch * local) * 0.19) * envelope
	return result


## Local hand-painted marks: pigment fragments for moss/stone, feather barbs,
## short directional slashes for flesh, shield arcs only for an actual block.
## Never fills the screen or draws a white flash disc.
static func draw(canvas: CanvasItem, record: Dictionary) -> void:
	var profile: Dictionary = record.get("profile", {})
	if profile.is_empty():
		profile = describe(record.get("event", record))
	if not bool(profile.get("active", false)):
		return
	var age := maxf(0.0, _number(record.get("age", 0.0), 0.0))
	var duration := float(profile.get("duration", 0.21))
	if age >= duration or duration <= 0.0:
		return
	var position := Vector2(record.get("position", Vector2.ZERO))
	var scale_value := clampf(_number(record.get("scale", 1.0), 1.0), 0.25, 4.0)
	var direction := Vector2(profile.get("direction", Vector2.RIGHT))
	var normal := direction.orthogonal()
	var kind := str(profile.get("kind", "light"))
	var material := str(profile.get("material", "body"))
	var color: Color = profile.get("color", MATERIAL_COLORS.body)
	var intensity := float(profile.get("intensity", 0.85))
	var progress := age / duration
	var fade := pow(1.0 - progress, 1.6)
	var spread := (1.0 - pow(1.0 - progress, 2.0)) * scale_value
	var variation := float(profile.get("variation", 0))
	# The host supplies the striking forepaw's ground point, independently from
	# the target-body contact point. This never moves the scenery or the actors.
	var ground_anchor: Variant = record.get("ground")
	if ground_anchor is Vector2 and ground_anchor.is_finite():
		_draw_ground_contact(canvas, ground_anchor, profile, age, scale_value)
	ResponseCues.draw_contact(canvas,profile.get("response_cue",{}),position,age,scale_value)
	if kind == "block" and str(profile.get("response_cue",{}).get("kind","")) == "deflection":return
	if kind == "block":
		var radius := 7.0 * scale_value + spread * 7.0
		var angle := direction.angle() + PI
		canvas.draw_arc(position, radius, angle - 0.90, angle + 0.90, 13, Color(color, fade * 0.72), 1.4 * scale_value, true)
		canvas.draw_arc(position + direction * scale_value, radius * 0.73, angle - 0.53, angle + 0.57, 9, Color(color.darkened(0.18), fade * 0.35), 0.8 * scale_value, true)
		for i in range(2):
			var edge := position + normal * (-1.0 if i == 0 else 1.0) * (4.0 + spread * 4.0)
			canvas.draw_line(edge, edge - direction * 3.0 * scale_value, Color(color, fade * 0.56), scale_value, true)
		return
	if kind == "guardbreak":
		_draw_fracture(canvas, position, direction, progress, scale_value, color, fade)
	var count := int(profile.get("debris_count", 3))
	var heavy := kind in ["heavy", "guardbreak"]
	var distance := (10.0 if heavy else 6.0) * intensity
	for i in range(count):
		var side := -1.0 if i % 2 == 0 else 1.0
		var angle := side * (0.42 + float(i) * 0.29) + (variation - 1.5) * 0.055
		var ray := direction.rotated(angle)
		var outward := (3.0 * scale_value + spread * (distance + float(i) * 1.4))
		var point := position + ray * outward + Vector2(0, progress * progress * (7.0 if material in ["moss", "stone"] else 2.0)) * scale_value
		var length := (3.0 + float(i % 3) * 1.1) * scale_value * (1.0 - progress * 0.25)
		if material in ["moss", "stone", "wood"]:
			var polygon := PackedVector2Array([point - ray * length * 0.4,
				point + normal * length * 0.34, point + ray * length * 0.52,
				point - normal * length * 0.28])
			canvas.draw_colored_polygon(polygon, Color(color.darkened(float(i % 2) * 0.12), fade * 0.70))
			if heavy and i < 2:
				canvas.draw_line(point - ray * length, point - ray * length * 1.6, Color(color, fade * 0.33), scale_value, true)
		elif material in ["feather", "air"]:
			canvas.draw_line(point - ray * length, point + ray * length * 0.65, Color(color, fade * 0.72), scale_value, true)
			for j in range(2):
				var middle := point - ray * float(j) * scale_value
				canvas.draw_line(middle, middle - ray * scale_value * 1.4 + normal * side * scale_value * 1.2, Color(color, fade * 0.48), 0.8 * scale_value, true)
		else:
			canvas.draw_line(point - ray * length * 0.5, point + ray * length, Color(color.darkened(0.19), fade * 0.62), (1.5 if heavy else 1.1) * scale_value, true)
	# The contact edge is sharp and brief, smaller than either combatant's face.
	if age < 0.075:
		var edge_alpha := (1.0 - age / 0.075) * 0.65
		var edge := normal.rotated(-0.28) * (4.0 if heavy else 2.7) * scale_value
		canvas.draw_line(position - edge, position + edge, Color(color.lightened(0.19), edge_alpha), 1.15 * scale_value, true)
		if str(profile.get("strike_material", "")) == "metal":
			canvas.draw_line(position - direction * 4.0 * scale_value, position + direction * 2.0 * scale_value, Color("a9b6b0", edge_alpha * 0.70), 0.85 * scale_value, true)


## Pure sampling allows the stomp's bounded ground footprint to be tested
## separately from its native painter. Misses never create this contact trace.
static func ground_contact(profile: Dictionary, age: float) -> Dictionary:
	if not bool(profile.get("active", false)) or str(profile.get("family", "")) != "moss_slam":
		return {}
	if str(profile.get("resolution", "")) in ["dodge", "whiff"] or age < 0.0:
		return {}
	var aftershock := str(profile.get("contact_role", "")) == "aftershock"
	var duration := minf(float(profile.get("duration", 0.0)), 0.19 if aftershock else 0.28)
	if duration <= 0.0 or age >= duration:
		return {}
	var progress := age / duration
	var fade := pow(1.0 - progress, 1.65)
	var expand := 1.0 - pow(1.0 - progress, 2.0)
	return {
		"progress": progress, "fade": fade, "aftershock": aftershock,
		"radius": (4.0 if aftershock else 6.0) + expand * (12.0 if aftershock else 24.0),
		"height": 2.0 if aftershock else 3.5,
		"wave_alpha": fade * (0.24 if aftershock else 0.40),
		"compression_alpha": maxf(0.0, 1.0 - age / (0.043 if aftershock else 0.065)) * (0.28 if aftershock else 0.48),
		"dust_count": 3 if aftershock else 5,
		"dust_alpha": fade * (0.32 if aftershock else 0.48),
		"dust_lift": (3.3 if aftershock else 6.5) * sin(progress * PI),
	}


static func _draw_ground_contact(canvas: CanvasItem, anchor: Vector2, profile: Dictionary,
		age: float, scale_value: float) -> void:
	var contact := ground_contact(profile, age)
	if contact.is_empty():
		return
	var radius := float(contact.radius) * scale_value
	var height := float(contact.height) * scale_value
	var earth := Color("837d60")
	var moss := Color("77825a")
	# Two broken, flattened pigment sweeps imply a pressure wave in the soil.
	# Their shallow profile and open ends avoid a glowing circular shock ring.
	for half in range(2):
		var points := PackedVector2Array()
		for i in range(9):
			var angle := (0.12 + float(i) / 8.0 * 0.74 + float(half)) * PI
			points.append(anchor + Vector2(cos(angle) * radius, sin(angle) * height))
		canvas.draw_polyline(points, Color(earth, float(contact.wave_alpha) * (0.70 if half == 0 else 1.0)), scale_value, true)
	if float(contact.compression_alpha) > 0.0:
		var extent := (4.0 if bool(contact.aftershock) else 7.0) * scale_value
		var line := PackedVector2Array([anchor + Vector2(-extent, -0.4 * scale_value),
			anchor + Vector2(-extent * 0.3, 0.7 * scale_value),
			anchor + Vector2(extent, 0.0)])
		canvas.draw_polyline(line, Color(earth.darkened(0.16), float(contact.compression_alpha)), 1.8 * scale_value, true)
	var variation := int(profile.get("variation", 0))
	for i in range(int(contact.dust_count)):
		var side := -1.0 if i % 2 == 0 else 1.0
		var distance := radius * (0.38 + float(i) * 0.10)
		var lift := float(contact.dust_lift) * (0.7 + float((i + variation) % 3) * 0.16) * scale_value
		var point := anchor + Vector2(side * distance, -lift - float(i % 2) * scale_value)
		var length := (1.8 + float(i % 2) * 0.7) * scale_value
		canvas.draw_line(point, point + Vector2(side * length, -0.5 * scale_value),
			Color(moss if i % 2 == 0 else earth, float(contact.dust_alpha)), 1.1 * scale_value, true)


static func _draw_fracture(canvas: CanvasItem, point: Vector2, direction: Vector2,
		progress: float, scale_value: float, color: Color, fade: float) -> void:
	var normal := direction.orthogonal()
	for side in [-1.0, 1.0]:
		var start: Vector2 = point + normal * float(side) * (3.0 + progress * 9.0) * scale_value
		var elbow: Vector2 = start + direction * (2.0 + progress * 3.0) * scale_value + normal * float(side) * 3.0 * scale_value
		var end: Vector2 = elbow - direction * 3.0 * scale_value + normal * float(side) * 4.0 * scale_value
		canvas.draw_polyline(PackedVector2Array([start, elbow, end]), Color(color.darkened(0.22), fade * 0.78), 1.6 * scale_value, true)
		canvas.draw_line(elbow, elbow + direction * 4.0 * scale_value, Color(color, fade * 0.54), scale_value, true)


static func _number(value: Variant, fallback: float) -> float:
	if not value is int and not value is float:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback
