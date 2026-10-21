extends "res://scripts/combat_modules/attack_module.gd"
const MOVES := {
	"basic_sword_cut": {"label": "平斩", "windup": 0.38, "strike": 0.20, "hold": 0.11, "recovery": 0.40, "hits": [0.96], "gap": 0.0, "lunge": 17.0, "basic_range": 62.0, "trail_kind": "sword_cut", "sound_kind": "sword_cut"},
	"basic_sword_thrust": {"label": "直刺", "windup": 0.43, "strike": 0.18, "hold": 0.10, "recovery": 0.38, "hits": [1.0], "gap": 0.0, "lunge": 23.0, "basic_range": 70.0, "trail_kind": "sword_thrust", "sound_kind": "sword_thrust"},
	"basic_sword_lift": {"label": "回腕挑锋", "windup": 0.47, "strike": 0.23, "hold": 0.12, "recovery": 0.35, "hits": [1.04], "gap": 0.0, "lunge": 18.0, "basic_range": 58.0, "trail_kind": "sword_lift", "sound_kind": "sword_lift"},
	"weapon_sword_pierce": {"label": "青锋 · 破风刺", "windup": 0.53, "strike": 0.20, "hold": 0.16, "recovery": 0.46, "hits": [1.58], "gap": 0.0, "lunge": 30.0, "basic_range": 78.0, "trail_kind": "sword_pierce", "sound_kind": "sword_pierce", "armor_factor": 0.55},
}

func _build_definition(_loadout: Dictionary) -> Dictionary:
	return {"id": "weapon.sword", "kind": "weapon", "action_kind": "weapon", "style": "sword", "moves": MOVES,
		"sequence": ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"], "default_move": "basic_sword_thrust",
		"weapon_move": "weapon_sword_pierce", "resources": {"qi_cost": 10.0, "cooldown": 9.0},
		"action_cues": {"source": "weapon", "contact": "melee"},
		"strike_geometry": {"kind": "blade_segment", "attachment": "active_grip", "weapon_key": "sword", "needs_grip": true, "range": 0.0}}
func pose_track(motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
	var move := str(motion.get("combat_move", "basic_sword_thrust"))
	if move == "weapon_sword_pierce":
		var art := standard_track(g, e, stance)
		art.merge({"upper": 0.46*g-1.31*e, "lower": 0.64*g-1.52*e, "hand": 1.28*g+1.34*e, "wrist_flex": .18*g-.10*e,
			"tilt": -0.055*g+0.105*e, "shift_y": 7.0*stance+5.0*g+5.0*e}, true)
		return art
	var requested := str(motion.get("basic_form", ""))
	if requested in ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"]:
		move = requested
	if move not in ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"]:
		move = "basic_sword_thrust"
	var result := basic_track(stance, move)
	result.merge({"upper": 0.34*g-1.22*e, "lower": 0.50*g-1.48*e, "hand": 1.15*g+1.32*e, "wrist_flex": .22*g-.12*e,
		"tilt": -0.070*g+0.105*e, "shift_x": -13.0*g, "shift_y": 7.0*stance+9.0*g+3.0*e,
		"far_upper": -0.54*stance-0.28*g+0.22*e, "far_lower": -1.34*stance-0.26*g+0.21*e}, true)
	if move == "basic_sword_lift":
		result.merge({"upper": -0.08*g-1.27*e, "lower": 0.22*g-1.70*e, "hand": 1.40*g+0.48*e, "wrist_flex": -.26*g+.26*e,
			"tilt": -0.060*g-0.035*e, "shift_y": 7.0*stance+10.0*g-2.0*e}, true)
	elif move == "basic_sword_cut":
		result.merge({"upper": -0.44*g-0.88*e, "lower": -1.28*g-1.10*e, "hand": 0.28*g+1.83*e, "wrist_flex": .16*g-.20*e,
			"tilt": -0.055*g+0.095*e, "shift_y": 7.0*stance+7.0*g+6.0*e}, true)
	if requested == "mist":
		result.upper -= 0.08*g
		result.lower -= 0.16*g
		result.hand += 0.08*e
		result.tilt -= 0.012*g
	result.far_hand = result.far_lower
	return result

# Authored blade segment in grip space, prepared once rather than rebuilding
# the interpolation for every contact probe.
const BLADE_POINTS := [Vector2(0,-12.0), Vector2(0,-15.776), Vector2(0,-19.552), Vector2(0,-23.328), Vector2(0,-27.104), Vector2(0,-30.88), Vector2(0,-34.656), Vector2(0,-38.432), Vector2(0,-42.208), Vector2(0,-45.984), Vector2(0,-49.76)]

func geometry_points(_motion: Dictionary, _rig_pose: Dictionary, grip: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	var offset := Vector2(grip.get("offset", Vector2.ZERO))
	var angle := float(grip.get("rotation", 0.0)) + 0.22
	for point in BLADE_POINTS:
		result.append(offset + point.rotated(angle))
	return result

func guard_track(motion:Dictionary)->Dictionary:
	if str(motion.get("action_kind","")) in ["spell","defense","utility"]:return super.guard_track(motion)
	var age:=float(motion.get("reaction_age",-1.0))
	var absorb:=0.0 if age<0.0 else sin(clampf(age/.16,0.0,1.0)*PI)
	var release:=0.0 if age<0.0 else smoothstep(.13,.30,age)
	# An inclined vertical blade closes the incoming line in front of the
	# face/chest, rather than repeating the forward-thrust silhouette. The
	# trailing hand cups below the hilt; both elbows remain visibly bent.
	var result:={"upper":-.85+.11*absorb-.10*release,"lower":-2.18-.09*absorb+.18*release,"hand":.58-.03*absorb+.08*release,
		"far_upper":-.75+.10*absorb,"far_lower":-2.00-.10*absorb,"far_hand":-2.00-.10*absorb,
		"tilt":-.09-.035*absorb,"shift_x":-7.0-5.0*absorb,"shift_y":21.0+4.0*absorb,
		"shoulder_forward":0.0,"lead_stance":22.0,"rear_stance":22.0,"fan_open":1.0,"hand_form":"fist","wrist_flex":.28-.08*absorb}
	var profile:Dictionary=motion.get("impact_profile",{})
	var valid:=bool(profile.get("contact_point_valid",false)) or bool(motion.get("guard_contact_valid",false))
	if valid:
		var point:Vector2=motion.get("guard_contact_point",profile.get("contact_point",Vector2.ZERO))
		# A low horn/body rush needs a low angled parry, not a blade above the
		# actual incoming line. The middle of the real sword meets the measured
		# contact; the hilt remains in front of the chest, away from the face.
		var low:=smoothstep(-46.0,-37.0,point.y)
		# At impact this is the exact incoming line. After contact the edge
		# rolls outward while the shoulder yields. Hold that roll until the
		# brace releases; reversing it with the shoulder's absorption wave
		# pulled steel back across the face during the next windup.
		var edge_roll:=smoothstep(0.0,.08,maxf(age,0.0))
		result.guard_catch={"point":point+Vector2(3.6*edge_roll,0),"angle":lerpf(.10,1.50,low)-.06*absorb,"distance":lerpf(32.0,20.0,low),"weight":1.0}
	return result
