extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"stillness_palm": {"label": "止水 · 沉息掌", "windup": 0.63, "strike": 0.25, "hold": 0.16, "recovery": 0.38, "hits": [1.0], "gap": 0.0, "lunge": 10.0},
	"stillness_push": {"label": "止水 · 回澜推掌", "windup": 0.71, "strike": 0.25, "hold": 0.16, "recovery": 0.40, "hits": [1.16], "gap": 0.0, "lunge": 13.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.stillness", "kind": "technique", "action_kind": "spell", "style": "unarmed", "moves": MOVES,
		"sequence": ["stillness_palm", "stillness_push"], "default_move": "stillness_palm",
		"attack_scale": 0.98, "resources": {"qi_cost": 16.0, "cooldown": 9.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "stillness", "sound_kind": "stillness"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.34*g-1.02*e, "lower": -1.0*g-1.38*e, "hand": -0.22*g-0.18*e,
		"hand_form": "palm", "tilt": -0.025*g+0.065*e, "shift_y": result.shift_y+8.0*g+4.0*e+7.0*stance,
		"far_upper": -0.55*stance-0.12*g, "far_lower": -1.55*stance-0.20*g}, true)
	return result
