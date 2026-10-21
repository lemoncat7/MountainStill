extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"frost_seal": {"label": "凝霜 · 缓行印", "windup": 0.64, "strike": 0.23, "hold": 0.17, "recovery": 0.41, "hits": [1.10], "gap": 0.0, "lunge": 8.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.frost", "kind": "technique", "action_kind": "spell", "style": "unarmed", "moves": MOVES,
		"sequence": ["frost_seal"], "default_move": "frost_seal",
		"attack_scale": 1.0, "resources": {"qi_cost": 16.0, "cooldown": 10.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "frost", "sound_kind": "frost"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.58*g-0.60*e, "lower": -1.65*g-0.55*e, "hand": 0.45*g+0.16*e,
		"tilt": -0.035*g+0.04*e, "shift_y": result.shift_y+11.0*e,
		"far_upper": -0.76*stance-0.12*g, "far_lower": -1.92*stance+0.35*e, "hand_form": "palm"}, true)
	return result
