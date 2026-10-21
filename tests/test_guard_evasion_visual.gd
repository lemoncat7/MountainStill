extends SceneTree
## No painted shield can stand in for steel contact or a real rear-foot evade.
const Rig=preload("res://scripts/character_sidewalk.gd")
var checks:=0
var failures:=0
func _initialize()->void:
 _trace_follows_real_tip()
 _guard_uses_arm_chain()
 _evasion_steps_and_recovers()
 print("Guard/evasion visuals: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func motion()->Dictionary:
 return {"action_kind":"basic","basic_style":"sword","attack_style":"sword","combat_move":"basic_sword_cut","combat_phase":"idle","phase_progress":0.0,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0}
func _trace_follows_real_tip()->void:
 for move in ["basic_sword_cut","basic_sword_thrust","basic_sword_lift","mist_combo"]:
  for phase_name in ["windup","strike","contact","recovery"]:
   for facing in [-1.0,1.0]:
    for i in range(51):
     var m:=motion();m.combat_move=move;m.combat_phase=phase_name;m.phase_progress=float(i)/50.0;m.facing=facing
     var path:=Rig.sword_edge_trace(m)
     if phase_name not in ["strike","contact"]:
      check(path.is_empty(),"no static ribbon remains in windup/recovery")
      continue
     var distance:=0.0
     for j in range(path.size()):
      check(path[j].is_finite(),"every edge sample is finite")
      if j>0:distance+=path[j].distance_to(path[j-1])
     check(distance<=14.001,"steel trace cannot become a large crescent")
     if not path.is_empty():
      var grip:=Rig.weapon_pose(m)
      var tip:=Vector2(grip.offset)+Vector2(0,-49.76).rotated(float(grip.rotation)+.22)*Vector2(facing,1)
      check(path[-1].distance_to(tip)<.001,"short history terminates on actual painted tip")
 var source:=FileAccess.get_file_as_string("res://scripts/cultivation.gd")
 var block:=source.substr(source.find("var response:=str(hero.get(\"defense_action\""))
 block=block.left(block.find("func _draw_enemy_telegraph"))
 check(not "_ink_trail" in block and not "draw_arc" in block,"ordinary guard draws no curved shield")
func _guard_uses_arm_chain()->void:
 var m:=motion()
 var ready:=Rig.sample_pose(m)
 m.defense_action="guard";m.reaction_amount=1.0
 var guard:=Rig.sample_pose(m)
 for arm_key in ["near_arm","far_arm"]:
  var arm:Dictionary=guard[arm_key]
  check(absf(arm.shoulder.distance_to(arm.elbow)-42.0)<.001,"guard keeps upper bone length")
  check(absf(arm.elbow.distance_to(arm.wrist)-Vector2(10,36).length())<.001,"guard keeps forearm bone length")
  check(arm.elbow.distance_to(ready[arm_key].elbow)>5.0,"both elbows actively brace")
  check(absf(angle_difference(arm.lower_angle,arm.hand_angle))<=.421,"sword guard wrist stays anatomical")
 var weapon:=Rig.weapon_pose(m)
 check(not weapon.stowed,"ordinary sword guard retains actual sword")
 check(Vector2(weapon.offset).distance_to(Vector2(guard.near_arm.wrist)*Rig.PIXEL_SCALE)<.001,"guard hilt stays at the original painted fist joint")
 check(float(weapon.rotation)>.3 and float(weapon.rotation)<.7,"guard closes the incoming line with an inclined upright blade")
 check(float(guard.body_angle)<float(ready.body_angle),"shoulder/torso absorbs contact backward")
 m.impact_profile={"reaction_magnitude":1.7,"knockback":2.0}
 var loaded:=Rig.sample_pose(m)
 check(float(loaded.shift.x)<float(guard.shift.x),"contact weight loads rear stance")
func _evasion_steps_and_recovers()->void:
 var m:=motion();m.defense_action="dodge"
 var base:=Rig.sample_pose(m)
 var last:Dictionary={}
 for i in range(101):
  var amount:=float(i)/100.0;m.reaction_amount=amount
  var p:=Rig.sample_pose(m)
  check(absf(p.near_leg.ankle.y-base.near_leg.ankle.y)<.001,"evasion lead sole stays grounded")
  check(p.far_leg.ankle.y<=base.far_leg.ankle.y+.001,"rear step never passes through ground")
  for leg_key in ["near_leg","far_leg"]:
   var leg:Dictionary=p[leg_key]
   check(absf(leg.hip.distance_to(leg.knee)-Rig.UPPER_LENGTH)<.001,"evade upper leg never stretches")
   check(absf(leg.knee.distance_to(leg.ankle)-Rig.LOWER_LENGTH)<.001,"evade lower leg never stretches")
  if not last.is_empty():
   check(p.far_leg.ankle.distance_to(last.far_leg.ankle)<1.0,"evasion step has continuous landing/release")
  last=p
 m.reaction_amount=.5
 var transit:=Rig.sample_pose(m)
 check(transit.far_leg.ankle.y<base.far_leg.ankle.y-8.0,"rear foot visibly lifts during backstep")
 m.reaction_amount=1.0
 var contact:=Rig.sample_pose(m)
 check(contact.far_leg.ankle.x<base.far_leg.ankle.x-30.0,"rear foot lands behind its ready position")
 check(absf(contact.far_leg.ankle.y-base.far_leg.ankle.y)<.001,"rear sole lands for dodge contact")
 check((base.shift.x-contact.shift.x)*Rig.PIXEL_SCALE>9.0,"torso actually slips away from contact")
 m.reaction_amount=0.0
 check(Rig.sample_pose(m)==base,"release returns exactly to ready stance")
