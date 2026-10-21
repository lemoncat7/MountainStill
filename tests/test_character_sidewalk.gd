extends SceneTree
const Walk=preload("res://scripts/character_sidewalk.gd")
var checks:=0
var failures:=0
func _initialize()->void:
	var rig=Walk.new()
	var rig2=Walk.new()
	for i in range(60):rig.update_motion(1.0/60.0,55.0)
	for i in range(120):rig2.update_motion(1.0/120.0,55.0)
	_check(is_equal_approx(rig.phase,rig2.phase),"distance clock is frame-rate invariant")
	for i in range(101):
		var pose=Walk.sample_pose({"phase":float(i)/100.0,"blend":1.0,"facing":1.0})
		for key in ["near_leg","far_leg"]:
			var leg:Dictionary=pose[key]
			_check(absf(Vector2(leg.knee).distance_to(leg.hip)-Walk.UPPER_LENGTH)<0.001,"fixed upper length")
			_check(absf(Vector2(leg.ankle).distance_to(leg.knee)-Walk.LOWER_LENGTH)<0.001,"fixed lower length")
			if leg.planted:
				_check(absf(float(leg.ankle.y)-Walk.REST_ANKLE.y)<0.001,"grounded contact")
		_check(pose.near_leg.planted or pose.far_leg.planted,"at least one foot bears weight")
	var a=Walk.sample_pose({"phase":0.15,"blend":1.0})
	var b=Walk.sample_pose({"phase":0.15+0.001/Walk.CYCLE_DISTANCE,"blend":1.0})
	_check(absf((float(b.near_leg.ankle.x)-float(a.near_leg.ankle.x))*Walk.PIXEL_SCALE+0.001)<0.0001,"planted foot cancels exact world displacement")
	var motion={"phase":0.8,"blend":1.0,"facing":1.0}
	var hand=Walk.attachment_offset(Vector2.ZERO,motion)
	motion.facing=-1.0
	_check(Walk.attachment_offset(Vector2.ZERO,motion).is_equal_approx(hand*Vector2(-1,1)),"weapon attachment mirrors with body")
	_check(rig.assets.has("head") and rig.assets.has("leg"),"real side profile textures load")
	for key in ["head_pin","head_crown","chest_blue","chest_jade","sleeve_blue","sleeve_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
		_check(rig.assets.has(key),"independent side gear loads: "+key)
	for move in ["mist_thrust","mist_lift","mist_combo","petal_step","petal_counter","ember_palm","ember_pulse","stillness_palm","stillness_push"]:
		for progress in [0.0,0.25,0.75,1.0]:
			var combat=Walk._combat({"attack_amount":1.0,"combat_move":move,"combat_phase":"contact","phase_progress":progress})
			_check(is_equal_approx(combat.reach,1.0),"visual contact holds exact damage phase")
		var finish=Walk._combat({"attack_amount":1.0,"combat_move":move,"combat_phase":"recovery","phase_progress":1.0})
		_check(is_equal_approx(finish.amount,0.0),"recovery returns to same side idle")
	var contact=Walk._combat({"combat_move":"mist_thrust","combat_phase":"contact","phase_progress":1.0,"strike_index":0})
	var repeated=Walk._combat({"combat_move":"mist_thrust","combat_phase":"strike","phase_progress":0.0,"strike_index":1})
	_check(is_equal_approx(contact.reach,repeated.reach) and is_equal_approx(contact.upper,repeated.upper),"multi-hit contact to repeated strike has no pose pop")
	for lunge in [0.0,5.0,10.0,19.0,27.0]:
		for phase_name in ["windup","strike","contact","recovery"]:
			var pose=Walk.sample_pose({"blend":0.0,"actor_lunge":lunge,"combat_phase":phase_name,"phase_progress":0.5,"attack_amount":1.0})
			_check(is_equal_approx(pose.far_leg.ankle.x,Walk.REST_ANKLE.x-7.0),"rear foot stays planted during lunge")
			_check(is_equal_approx(pose.far_leg.ankle.y,Walk.REST_ANKLE.y),"rear foot ground height during lunge")
			for key in ["near_leg","far_leg"]:
				_check(absf(Vector2(pose[key].knee).distance_to(pose[key].hip)-Walk.UPPER_LENGTH)<0.001,"lunge retains upper bone length")
				_check(absf(Vector2(pose[key].ankle).distance_to(pose[key].knee)-Walk.LOWER_LENGTH)<0.001,"lunge retains lower bone length")
	for technique in ["ember","stillness"]:
		var pose=Walk.weapon_pose({"technique":technique,"facing":1.0})
		_check(pose.stowed and pose.draw_behind,"palm technique visibly stows equipped sword")
	var active=Walk.weapon_pose({"technique":"mist","facing":1.0})
	_check(not active.stowed and not active.draw_behind,"sword technique keeps active grip")
	for reaction in [0.0,0.25,0.5,0.75,1.0]:
		var dodge=Walk.sample_pose({"blend":0.0,"defense_action":"dodge","reaction_amount":reaction})
		_check(is_equal_approx(float(dodge.shift.x),-36.0*reaction),"dodge visibly shifts hips back")
		_check(absf(float(dodge.body_angle))<=0.14001,"dodge restrains large-head tilt")
		for key in ["near_leg","far_leg"]:
			var leg:Dictionary=dodge[key]
			_check(leg.ankle.y<=Walk.REST_ANKLE.y+.001,"dodge feet never fall below ground")
			_check(absf(Vector2(leg.knee).distance_to(leg.hip)-Walk.UPPER_LENGTH)<0.001,"dodge retains upper bone length")
			_check(absf(Vector2(leg.ankle).distance_to(leg.knee)-Walk.LOWER_LENGTH)<0.001,"dodge retains lower bone length")
	print("Sidewalk rig: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
func _check(ok:bool,label:String)->void:
	checks+=1
	if not ok:failures+=1;push_error(label)
