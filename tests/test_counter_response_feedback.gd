extends SceneTree
const Duel=preload("res://scripts/duel_timeline.gd")
const Rig=preload("res://scripts/character_sidewalk.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Cues=preload("res://scripts/combat_response_cues.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:
 test_cues()
 test_poses()
 test_real_sources()
 print("Counter / barrier feedback: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func test_cues()->void:
 var event:Dictionary={"actor":"hero","target":"enemy","move":"arbitrary_new_module_attack","resolution":"hit","contact_id":"8:0","counter":true,"counter_source":"5:0","damage":6,"raw_damage":6}
 var saved:=event.duplicate(true)
 var hit:=Impact.describe(event)
 check(event==saved,"describing counter never mutates combat event")
 check(hit.response_cue.kind=="counter_hit" and hit.response_cue.counter_source=="5:0","new module gets linked counter cue without weapon/move branch")
 check(hit.hitstop>=.06 and not hit.poise_broken,"counter contact gets readable beat, never fabricated posture break")
 for result in ["whiff","dodge","guard"]:
  var miss:=event.duplicate(true);miss.resolution=result;miss.damage=0
  check(Cues.contact_cue(miss).get("kind","")!="counter_hit","no punish burst on unsuccessful counter: "+result)
 event.counter_source=""
 check(Cues.contact_cue(event).is_empty(),"no earned feedback without source contact")
 var guard:Dictionary={"actor":"enemy","target":"hero","contact_id":"5:0","resolution":"guard","damage":2,"counter_earned":true}
 check(Cues.contact_cue(guard).kind=="deflection","real guard gets redirected contact stroke")
 guard.poise_broken=true
 check(Cues.contact_cue(guard).is_empty(),"broken guard cannot show successful deflection")
 check(Cues.barrier_marks({}).is_empty(),"ordinary guard/idle cannot create protective field")
 var marks:=Cues.barrier_marks({"shield":9,"shield_remaining":2.3})
 check(marks.size()==2,"active barrier has two transparent open rim segments")
 for mark in marks:
  check(float(mark.alpha)<=.35,"sustained field stays softly lit")
  check(Vector2(mark.points[0]).distance_to(mark.points[-1])>10,"rim never closes into opaque enclosing paint")
  for point in mark.points:check(point.x>=-22.1 and point.x<=24.1 and point.y>=-77.1 and point.y<=1.1,"field fits body without dominating scene")
 check(Cues.barrier_status({"shield":9,"shield_remaining":2.3})=="护元 9 · 2.3s","shield identity amount and duration are readable")
 var shield:Dictionary={"contact_id":"9:0","resolution":"hit","shield_absorbed":6,"shield_after":0}
 var cue:=Cues.contact_cue(shield)
 check(cue.shield_depleted,"last real absorption authors depletion")
 shield.damage=2;shield.raw_damage=8
 check(float(Impact.describe(shield).duration)>=.32,"partially absorbed breaking hit retains the complete dissolve")
 var impacts:Array=[{"profile":{"response_cue":cue},"age":.08}]
 check(Cues.barrier_feedback(impacts).depleted,"depletion survives zero shield long enough for dissolve")
 impacts[0].age=.4
 check(Cues.barrier_feedback(impacts).is_empty(),"depletion effect expires without a persistent egg")
func test_poses()->void:
 for style in ["sword","fan","unarmed"]:
  var move:String={"sword":"basic_sword_cut","fan":"basic_fan_sweep","unarmed":"basic_unarmed_jab"}[style]
  var m:Dictionary={"combat_move":move,"action_kind":"basic","attack_style":style,"basic_style":style,"combat_stance":1.0,"attack_amount":1.0,"counter":true,"counter_source":"5:0"}
  m.combat_phase="windup";m.phase_progress=.7
  var loaded:=Rig.sample_pose(m)
  var ordinary:=m.duplicate(true);ordinary.counter=false
  check(Vector2(loaded.near_arm.elbow).distance_to(Rig.sample_pose(ordinary).near_arm.elbow)>3.0,"counter visibly chambers: "+style)
  for phase in ["contact","recovery"]:
   m.combat_phase=phase;m.phase_progress=.3
   ordinary=m.duplicate(true);ordinary.counter=false
   check(Rig.sample_pose(m)==Rig.sample_pose(ordinary),"counter leaves exact authored contact/recovery endpoint: "+style+"/"+phase)
 var m:Dictionary={"combat_phase":"idle","attack_amount":0.0,"search_amount":1.0,"search_phase":.5}
 var kneel:=Rig.sample_pose(m)
 m.search_amount=0.0
 var rest:=Rig.sample_pose(m)
 check(float(kneel.shift.y)-float(rest.shift.y)>45.0,"search visibly lowers hips into a crouch")
 for leg in [kneel.near_leg,kneel.far_leg]:
  check(absf(Vector2(leg.hip).distance_to(leg.knee)-Rig.UPPER_LENGTH)<.001,"search preserves thigh length")
  check(absf(Vector2(leg.knee).distance_to(leg.ankle)-Rig.LOWER_LENGTH)<.001,"search preserves shin length")
  check(absf(float(leg.ankle.y)-Rig.REST_ANKLE.y)<.001,"search soles stay planted")
 check(Rig.HEAD_SCALE==.86 and Rig.TORSO_WIDTH==1.30,"accepted head/body proportions unchanged")
 var deflected:=Cues.deflection_transform({"deflected_contact_id":"5:0","deflection_age":.08,"deflection_duration":.27})
 check(float(deflected.amount)>.8 and float(deflected.rotation)>.08,"real block visibly turns attacking follow-through")
 check(Cues.deflection_transform({"deflection_age":.08}).amount==0.0,"no attacker deflection without resolved source")
func test_real_sources()->void:
 var d=Duel.new()
 d.start({"hp":9999,"max_hp":9999,"attack":10,"defense":2},{"hp":9999,"max_hp":9999,"attack":8,"defense":1,"boss":true,"route_id":"bamboo_pass"},"stillness","sword",17)
 var seen:Dictionary={};var counter_hits:=0;var deflections:=0
 for tick in range(20*60):
  for event in d.advance(1.0/60.0):
   if event.type!="contact":continue
   seen[str(event.contact_id)]=event
   if bool(event.counter):
    check(seen.has(str(event.counter_source)),"actual counter contact carries existing causal contact ID")
    if seen.has(str(event.counter_source)):
     var source:Dictionary=seen[str(event.counter_source)]
     check(source.resolution=="guard" or bool(source.poise_broken),"actual counter cause is earned guard or posture break")
    if event.resolution=="hit" and event.damage>0:
     counter_hits+=1
     check(event.impact_profile.response_cue.kind=="counter_hit","successful real counter emits punish cue")
  var p:Dictionary=d.pose()
  if p.enemy.has("deflected_contact_id"):
   deflections+=1
   check(seen.has(str(p.enemy.deflected_contact_id)),"visible attacker redirect identifies a real resolved contact")
   check(p.enemy.combat_phase!="stagger" or bool(p.enemy.get("guard_broken",false)),"deflection does not assert enemy stagger")
 check(counter_hits>1 and deflections>5,"native timeline supplies repeated readable counter cycles")
