extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"barrier_guard": {"label": "护元 · 结障", "windup": 0.56, "strike": 0.20, "hold": 0.18, "recovery": 0.34, "hits": [0.0], "gap": 0.0, "lunge": 0.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.barrier", "kind": "technique", "action_kind": "defense", "style": "unarmed", "moves": MOVES,
		"sequence": ["barrier_guard"], "default_move": "barrier_guard",
		"attack_scale": 1.0, "resources": {"qi_cost": 16.0, "cooldown": 12.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "barrier", "sound_kind": "barrier"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.42*g-0.70*e, "lower": -1.35*g-1.91*e, "hand": -0.22*g-0.16*e,
		"far_upper": -0.58*stance-0.25*e, "far_lower": -1.70*stance-0.30*e,
		"tilt": -0.018*g-0.025*e, "shift_y": result.shift_y+9.0*e, "hand_form": "palm"}, true)
	return result
