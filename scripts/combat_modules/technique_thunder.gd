extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"thunder_strike": {"label": "惊雷 · 破势指", "windup": 0.78, "strike": 0.17, "hold": 0.13, "recovery": 0.44, "hits": [1.48], "gap": 0.0, "lunge": 11.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.thunder", "kind": "technique", "action_kind": "spell", "style": "unarmed", "moves": MOVES,
		"sequence": ["thunder_strike"], "default_move": "thunder_strike",
		"attack_scale": 1.0, "resources": {"qi_cost": 20.0, "cooldown": 12.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "thunder", "sound_kind": "thunder"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.52*g-0.95*e, "lower": -1.25*g-1.95*e, "hand": -1.08*g-2.40*e,
		"tilt": -0.035*g-0.018*e, "shift_y": result.shift_y-2.0*e,
		"far_upper": -0.55*stance-0.18*g, "far_lower": -1.72*stance-0.16*e, "hand_form": "finger"}, true)
	return result
