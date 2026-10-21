extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"basic_unarmed_jab": {"label": "探身冲拳", "windup": 0.30, "strike": 0.16, "hold": 0.09, "recovery": 0.38, "hits": [0.82], "gap": 0.0, "lunge": 25.0, "basic_range": 36.0, "trail_kind": "unarmed_jab", "sound_kind": "unarmed_jab"},
	"basic_unarmed_palm": {"label": "沉肩推掌", "windup": 0.46, "strike": 0.22, "hold": 0.13, "recovery": 0.41, "hits": [1.06], "gap": 0.0, "lunge": 22.0, "basic_range": 39.0, "trail_kind": "unarmed_palm", "sound_kind": "unarmed_palm"},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "weapon.unarmed", "kind": "weapon", "action_kind": "weapon", "style": "unarmed", "moves": MOVES,
		"sequence": ["basic_unarmed_jab", "basic_unarmed_palm"], "default_move": "basic_unarmed_palm",
		"weapon_move": "", "resources": {},
		"action_cues": {"source": "weapon", "contact": "melee"},
		"strike_geometry": {"kind": "active_hand", "attachment": "active_grip", "weapon_key": "unarmed", "needs_grip": false, "range": 0.0}}
func pose_track(motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var move := str(motion.get("combat_move", "basic_unarmed_palm"))
	var requested := str(motion.get("basic_form", ""))
	if requested in ["basic_unarmed_jab", "basic_unarmed_knuckle", "basic_unarmed_palm"]:
		move = requested
	if move not in ["basic_unarmed_jab", "basic_unarmed_knuckle", "basic_unarmed_palm"]:
		move = "basic_unarmed_palm"
	var result := basic_track(stance, move)
	result.merge({"upper": -0.20*g-1.17*e, "lower": -1.10*g-1.43*e, "hand": -0.30*g-0.16*e,
		"hand_form": "palm", "tilt": -0.045*g-0.070*e, "shift_x": -3.0*g, "shift_y": 12.0*stance+5.0*g+3.0*e,
		"far_upper": -0.60*stance-0.16*g, "far_lower": -1.70*stance-0.10*g, "lead_stance": 17.0, "rear_stance": 15.0}, true)
	if move in ["basic_unarmed_jab", "basic_unarmed_knuckle"]:
		result.merge({"upper": -0.24*g-0.10*e, "lower": -0.68*g-0.58*e, "hand": -0.28*g-0.40*e,
			"far_upper": -0.64*stance+0.16*g-0.55*e, "far_lower": -1.70*stance+0.75*g+0.18*e,
			"attack_hand": "far", "hand_form": "fist", "tilt": -0.03*g-0.070*e,
			"shift_y": 12.0*stance+2.0*g+1.0*e, "lead_stance": 13.0, "rear_stance": 18.0}, true)
	result.far_hand = result.far_lower
	return result

func geometry_points(motion: Dictionary, rig_pose: Dictionary, _grip: Dictionary) -> PackedVector2Array:
	var arm: Dictionary = rig_pose.far_arm if str(rig_pose.combat.attack_hand) == "far" else rig_pose.near_arm
	var length := 16.0 if str(arm.hand_form) == "palm" else 10.0
	var scale_value := float(motion.get("rig_pixel_scale", 132.0 / 488.0))
	var tip := (Vector2(arm.wrist) + Vector2(0, length).rotated(float(arm.hand_angle))) * scale_value
	return PackedVector2Array([tip, tip + Vector2(1.7, 0), tip + Vector2(0, -1.7), tip + Vector2(0, 1.7)])
