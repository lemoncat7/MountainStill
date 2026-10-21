extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"ember_palm": {"label": "照炉 · 吐焰掌", "windup": 0.68, "strike": 0.23, "hold": 0.16, "recovery": 0.40, "hits": [1.03], "gap": 0.0, "lunge": 12.0},
	"ember_pulse": {"label": "照炉 · 双重炎息", "windup": 0.61, "strike": 0.24, "hold": 0.12, "recovery": 0.36, "hits": [0.66, 0.64], "gap": 0.30, "lunge": 16.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.ember", "kind": "technique", "action_kind": "spell", "style": "unarmed", "moves": MOVES,
		"sequence": ["ember_palm", "ember_pulse"], "default_move": "ember_palm",
		"attack_scale": 1.13, "resources": {"qi_cost": 18.0, "cooldown": 7.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "ember", "sound_kind": "ember"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.34*g-1.02*e, "lower": -1.0*g-1.38*e, "hand": -0.22*g-0.18*e,
		"hand_form": "palm", "tilt": -0.065*g+0.105*e, "shift_y": result.shift_y+8.0*g+4.0*e,
		"far_upper": -0.38*stance-0.18*g-0.62*e, "far_lower": -1.0*stance-0.20*g-0.42*e}, true)
	return result
