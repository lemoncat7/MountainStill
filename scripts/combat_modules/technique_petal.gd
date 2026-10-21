extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"petal_step": {"label": "落英 · 游身", "windup": 0.42, "strike": 0.24, "hold": 0.13, "recovery": 0.34, "hits": [1.0], "gap": 0.0, "lunge": 15.0},
	"petal_counter": {"label": "落英 · 闪身回锋", "windup": 0.32, "strike": 0.22, "hold": 0.15, "recovery": 0.36, "hits": [1.42], "gap": 0.0, "lunge": 27.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.petal", "kind": "technique", "action_kind": "weapon_art", "style": "fan", "moves": MOVES,
		"sequence": ["petal_step", "petal_counter"], "default_move": "petal_step",
		"attack_scale": 0.92, "resources": {"qi_cost": 14.0, "cooldown": 8.0},
		"basic_modifiers": {"form": "petal", "recovery_scale": 0.92},
		"action_cues": {"trail_kind": "petal", "sound_kind": "petal"},
		"strike_geometry": {"kind": "active_grip", "attachment": "active_grip", "range": 0.0}}
func select_action(state: Dictionary = {}) -> Dictionary:
	var request := state.duplicate(true)
	request.move = "petal_counter" if bool(state.get("counter", false)) else "petal_step"
	return super.select_action(request)

func pose_track(motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": 0.35*g-0.93*e, "lower": 0.55*g-1.36*e,
		"hand": 0.18*e if str(motion.get("attack_style", "fan")) == "fan" else 1.20*g+1.10*e,
		"shift_x": -13.0*g+5.0*e, "tilt": -0.09*g+0.115*e, "shift_y": result.shift_y+7.0*g-3.0*e,
		"far_upper": -0.45*stance+0.40*e, "far_lower": -1.0*stance-0.55*e}, true)
	return result
