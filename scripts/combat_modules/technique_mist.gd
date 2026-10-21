extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"mist_thrust": {"label": "云起 · 直刺", "windup": 0.48, "strike": 0.22, "hold": 0.13, "recovery": 0.36, "hits": [1.0], "gap": 0.0, "lunge": 19.0},
	"mist_lift": {"label": "岚回 · 挑锋", "windup": 0.57, "strike": 0.25, "hold": 0.14, "recovery": 0.34, "hits": [1.12], "gap": 0.0, "lunge": 14.0},
	"mist_combo": {"label": "云岚 · 三叠", "windup": 0.40, "strike": 0.20, "hold": 0.09, "recovery": 0.29, "hits": [0.43, 0.43, 0.52], "gap": 0.24, "lunge": 22.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.mist", "kind": "technique", "action_kind": "weapon_art", "style": "sword", "moves": MOVES,
		"sequence": ["mist_thrust", "mist_lift", "mist_combo"], "default_move": "mist_thrust",
		"attack_scale": 1.0, "resources": {"qi_cost": 12.0, "cooldown": 6.0},
		"basic_modifiers": {"form": "mist", "strike_scale": 0.94},
		"action_cues": {"trail_kind": "mist", "sound_kind": "mist"},
		"strike_geometry": {"kind": "active_grip", "attachment": "active_grip", "range": 0.0}}
func pose_track(motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	var move := str(motion.get("combat_move", "mist_thrust"))
	if move == "mist_lift":
		result.merge({"upper": -0.20*g-1.35*e, "lower": -0.18*g-1.70*e, "hand": 1.20*g+0.46*e,
			"tilt": -0.045*g-0.055*e, "shift_y": result.shift_y-3.0*e}, true)
	elif move == "mist_combo":
		var t := clampf(float(motion.get("attack_phase", 0.0)), 0.0, 1.0)
		var flourish := sin(clampf((t-0.22)/0.58, 0.0, 1.0)*TAU)
		if motion.has("combat_phase"):
			var index := int(motion.get("strike_index", 0))
			var previous := maxi(0, index-1)
			var progress := clampf(float(motion.get("phase_progress", 0.0)), 0.0, 1.0)
			flourish = lerpf(sin(previous*PI*0.70), sin(index*PI*0.70), smoothstep(0.0, 1.0, progress)) if str(motion.get("combat_phase", "")) == "strike" else sin(index*PI*0.70)
		result.merge({"upper": 0.30*g-(1.10+0.48*flourish)*e, "lower": 0.64*g-(1.35+0.42*flourish)*e,
			"hand": 1.20*g+(1.0-0.85*flourish)*e, "tilt": -0.055*g+(0.075-0.06*flourish)*e,
			"shift_y": result.shift_y+3.0*absf(flourish)*e, "far_upper": result.far_upper-0.12*flourish*e}, true)
	else:
		result.merge({"upper": 0.44*g-1.25*e, "lower": 0.67*g-1.50*e, "hand": 1.20*g+1.34*e,
			"tilt": -0.065*g+0.125*e, "shift_y": result.shift_y+4.0*e}, true)
	return result
