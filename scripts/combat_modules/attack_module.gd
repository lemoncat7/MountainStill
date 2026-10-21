extends RefCounted
## Finite, trusted combat-module contract. The simulator owns all outcomes.
## A registry creates one instance per equipped combat slot. Do not put HP, qi,
## cooldowns, RNGs, Nodes, or a reference to the simulator inside a module.
var _context: Dictionary = {}
var _definition: Dictionary = {}
var selection_count: int = 0

func configure(context: Dictionary = {}) -> void:
	_context = context.duplicate(true)
	_definition = _build_definition(_context).duplicate(true)
	selection_count = 0

func definition(context: Dictionary = {}) -> Dictionary:
	if not context.is_empty():
		return _build_definition(context.duplicate(true)).duplicate(true)
	if _definition.is_empty():
		_definition = _build_definition(_context).duplicate(true)
	return _definition.duplicate(true)

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "", "kind": "none", "style": "unarmed", "moves": {}, "sequence": [], "default_move": "", "resources": {}, "action_cues": {}, "strike_geometry": {}}

func select_action(state: Dictionary = {}) -> Dictionary:
	if _definition.is_empty():
		_definition = _build_definition(_context).duplicate(true)
	var sequence: Array = _definition.get("sequence", [])
	var moves: Dictionary = _definition.get("moves", {})
	if sequence.is_empty():
		return {}
	var index := maxi(0, int(state.get("use_count", selection_count))) % sequence.size()
	var move := str(state.get("move", sequence[index]))
	if str(state.get("kind", "basic")) == "weapon":
		move = str(_definition.get("weapon_move", move))
	if not moves.has(move):
		move = str(sequence[index])
	var result: Dictionary = moves[move].duplicate(true)
	result.move = move
	result.module_id = str(_definition.id)
	result.attack_scale = float(_definition.get("attack_scale", 1.0))
	var cues: Dictionary = _definition.get("action_cues", {})
	result.trail_kind = str(result.get("trail_kind", cues.get("trail_kind", "")))
	result.sound_kind = str(result.get("sound_kind", cues.get("sound_kind", "")))
	result.strike_geometry = _definition.get("strike_geometry", {}).duplicate(true)
	result.strike_geometry.range = float(result.get("basic_range", result.strike_geometry.get("range", 0.0)))
	selection_count += 1
	return result

func modify_basic(action: Dictionary, _loadout: Dictionary = {}) -> Dictionary:
	var result := action.duplicate(true)
	var modifiers: Dictionary = definition().get("basic_modifiers", {})
	if modifiers.has("form"):
		result.basic_form = str(modifiers.form)
	for phase in ["windup", "strike", "hold", "recovery"]:
		result[phase] = float(result.get(phase, 0.0)) * float(modifiers.get(phase + "_scale", 1.0))
	return result

func pose_track(_motion: Dictionary, gather: float, extend: float, stance: float) -> Dictionary:
	return standard_track(gather, extend, stance)

static func standard_track(g: float, e: float, stance: float) -> Dictionary:
	return {"upper": 0.24*g-0.87*e, "lower": 0.56*g-1.24*e, "hand": 1.20*g+1.12*e, "wrist_flex": -.12*g+.12*e,
		"tilt": -0.035*g+0.075*e, "shift_x": -5.0*g, "shift_y": 7.0*stance+5.0*g,
		"far_upper": -0.52*stance-0.25*g+0.30*e, "far_lower": -1.18*stance-0.35*g+0.24*e,
		"far_hand": -1.18*stance-0.35*g+0.24*e, "attack_hand": "near", "hand_form": "fist",
		"fan_open": 1.0, "lead_stance": 12.0, "rear_stance": 12.0, "form": ""}

static func basic_track(stance: float, form: String) -> Dictionary:
	return {"upper": 0.0, "lower": 0.0, "hand": 0.0, "wrist_flex": 0.0, "tilt": 0.0, "shift_x": 0.0, "shift_y": 7.0*stance,
		"far_upper": -0.60*stance, "far_lower": -1.55*stance, "far_hand": -1.55*stance,
		"attack_hand": "near", "hand_form": "fist", "fan_open": 1.0, "lead_stance": 12.0, "rear_stance": 12.0, "form": form}

func geometry_points(_motion: Dictionary, _rig_pose: Dictionary, _grip: Dictionary) -> PackedVector2Array:
	return PackedVector2Array()

# Pure defensive staging. The timeline supplies the actual outcome and age;
# this provider cannot create guards, counters, damage, or persistent state.
func guard_track(motion:Dictionary)->Dictionary:
	var age:=float(motion.get("reaction_age",-1.0))
	var absorb:=0.0 if age<0.0 else sin(clampf(age/.16,0.0,1.0)*PI)
	var release:=0.0 if age<0.0 else smoothstep(.13,.30,age)
	return {"upper":-1.02+.10*absorb,"lower":-2.22-.10*absorb,"hand":-2.22,
		"far_upper":-.86,"far_lower":-2.40,"far_hand":-2.40,
		"tilt":-.09-.035*absorb,"shift_x":-6.0-5.0*absorb,"shift_y":21.0+4.0*absorb,
		"lead_stance":21.0,"rear_stance":22.0,"fan_open":1.0,"hand_form":"fist","wrist_flex":.20-.06*absorb,"release":release}
