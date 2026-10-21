extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"mending_bloom": {"label": "回春 · 清息", "windup": 0.66, "strike": 0.22, "hold": 0.19, "recovery": 0.36, "hits": [0.0], "gap": 0.0, "lunge": 0.0},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "technique.mending", "kind": "technique", "action_kind": "utility", "style": "unarmed", "moves": MOVES,
		"sequence": ["mending_bloom"], "default_move": "mending_bloom",
		"attack_scale": 1.0, "resources": {"qi_cost": 18.0, "cooldown": 14.0},
		"basic_modifiers": {},
		"action_cues": {"trail_kind": "mending", "sound_kind": "mending"},
		"strike_geometry": {"kind": "cast_contact", "attachment": "active_grip", "range": 0.0}}
func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var result := standard_track(g, e, stance)
	result.merge({"upper": -0.58*g-0.56*e, "lower": -1.85*g-1.20*e, "hand": 0.55*g+0.72*e,
		"far_upper": -0.65*stance-0.18*g+0.08*e, "far_lower": -1.85*stance-0.20*g+0.52*e,
		"tilt": -0.025*g+0.012*e, "shift_y": result.shift_y+3.0*g, "hand_form": "palm"}, true)
	return result
