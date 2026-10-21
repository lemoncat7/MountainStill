extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"basic_fan_sweep": {"label": "展扇横拂", "windup": 0.43, "strike": 0.27, "hold": 0.13, "recovery": 0.36, "hits": [1.02], "gap": 0.0, "lunge": 12.0, "basic_range": 53.0, "trail_kind": "fan_sweep", "sound_kind": "fan_sweep"},
	"basic_fan_flick": {"label": "收扇点打", "windup": 0.34, "strike": 0.21, "hold": 0.10, "recovery": 0.39, "hits": [0.88], "gap": 0.0, "lunge": 17.0, "basic_range": 48.0, "trail_kind": "fan_flick", "sound_kind": "fan_flick"},
	"basic_fan_return": {"label": "回扇反拂", "windup": 0.46, "strike": 0.25, "hold": 0.12, "recovery": 0.38, "hits": [1.05], "gap": 0.0, "lunge": 11.0, "basic_range": 56.0, "trail_kind": "fan_return_basic", "sound_kind": "fan_return_basic"},
	"weapon_fan_return": {"label": "流云 · 回风扇", "windup": 0.48, "strike": 0.27, "hold": 0.13, "recovery": 0.43, "hits": [0.74, 0.86], "gap": 0.38, "lunge": 18.0, "basic_range": 64.0, "trail_kind": "fan_return", "sound_kind": "fan_return"},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "weapon.fan", "kind": "weapon", "action_kind": "weapon", "style": "fan", "moves": MOVES,
		"sequence": ["basic_fan_sweep", "basic_fan_flick", "basic_fan_return"], "default_move": "basic_fan_sweep",
		"weapon_move": "weapon_fan_return", "resources": {"qi_cost": 12.0, "cooldown": 10.0},
		"action_cues": {"source": "weapon", "contact": "melee"},
		"strike_geometry": {"kind": "fan_edge", "attachment": "active_grip", "weapon_key": "fan", "needs_grip": true, "range": 0.0}}
func pose_track(motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var move := str(motion.get("combat_move", "basic_fan_sweep"))
	if move == "weapon_fan_return":
		var art := standard_track(g, e, stance)
		art.merge({"upper": -0.38*g-1.12*e, "lower": -0.78*g-1.55*e, "hand": -0.95*g+0.42*e, "wrist_flex": -.24*g+.26*e,
			"fan_open": 1.0-0.82*g, "tilt": -0.06*g+0.04*e,
			"far_upper": -0.78*stance-0.16*e, "far_lower": -1.90*stance+0.25*e}, true)
		return art
	var requested := str(motion.get("basic_form", ""))
	if requested in ["basic_fan_sweep", "basic_fan_flick", "basic_fan_jab", "basic_fan_return"]:
		move = requested
	if move not in ["basic_fan_sweep", "basic_fan_flick", "basic_fan_jab", "basic_fan_return"]:
		move = "basic_fan_sweep"
	var result := basic_track(stance, move)
	result.merge({"upper": 0.12*g-0.86*e, "lower": -0.15*g-1.30*e, "hand": -0.72*g+0.20*e, "wrist_flex": -.22*g+.20*e,
		"tilt": -0.055*g+0.045*e, "shift_x": -8.0*g+2.0*e, "shift_y": 6.0*stance+5.0*g,
		"far_upper": -0.78*stance+0.14*e, "far_lower": -1.96*stance+0.20*e, "lead_stance": 7.0, "rear_stance": 17.0}, true)
	if move in ["basic_fan_jab", "basic_fan_flick"]:
		result.merge({"upper": 0.42*g-1.15*e, "lower": 0.30*g-1.48*e, "hand": 0.94*g+1.34*e, "wrist_flex": .20*g-.10*e,
			"fan_open": 1.0-0.88*maxf(g,e), "tilt": -0.035*g+0.075*e, "shift_y": 6.0*stance+3.0*e}, true)
	elif move == "basic_fan_return":
		result.merge({"upper": -0.64*g-0.72*e, "lower": -1.75*g-1.12*e, "hand": -1.02*g+0.56*e, "wrist_flex": -.24*g+.26*e,
			"fan_open": 1.0-0.72*g, "tilt": -0.06*g-0.015*e, "shift_x": -5.0*g-3.0*e}, true)
	if requested == "petal":
		result.shift_x -= 3.0*g
		result.lower -= 0.10*e
		result.hand -= 0.08*e
	result.far_hand = result.far_lower
	return result

# Painted fan rim converted once to the 48x40 displayed grip coordinates.
const FAN_RIM := [Vector2(-22.1,-10.02857142857143), Vector2(-18.575,-15.314285714285715), Vector2(-14.0,-19.1), Vector2(-6.8,-23.6), Vector2(-0.05,-24.385714285714286), Vector2(8.275,-21.814285714285717), Vector2(15.025,-17.67142857142857), Vector2(23.575,-8.457142857142859)]

func geometry_points(_motion: Dictionary, _rig_pose: Dictionary, grip: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var offset := Vector2(grip.get("offset", Vector2.ZERO))
	var angle := float(grip.get("rotation", 0.0))
	var spread := float(grip.get("fan_open", 1.0))
	for point in FAN_RIM:
		result.append(offset + Vector2(point.x * spread, point.y).rotated(angle))
	return result

func guard_track(motion:Dictionary)->Dictionary:
	if str(motion.get("action_kind","")) in ["spell","defense","utility"]:return super.guard_track(motion)
	var age:=float(motion.get("reaction_age",-1.0))
	var absorb:=0.0 if age<0.0 else sin(clampf(age/.16,0.0,1.0)*PI)
	return {"upper":-1.24+.10*absorb,"lower":-2.15-.10*absorb,"hand":.46-.07*absorb,
		"far_upper":-.98,"far_lower":-2.40,"far_hand":-2.40,
		"tilt":-.08-.035*absorb,"shift_x":-5.0-4.0*absorb,"shift_y":20.0+4.0*absorb,
		"lead_stance":18.0,"rear_stance":25.0,"fan_open":.16,"hand_form":"fist","wrist_flex":.22-.06*absorb}
