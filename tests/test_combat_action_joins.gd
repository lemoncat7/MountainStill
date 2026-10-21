extends SceneTree
## Visual joins use actual outgoing motion; counter metadata names its real cause.
const Duel=preload("res://scripts/duel_timeline.gd")
const Rig=preload("res://scripts/character_sidewalk.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:
 for tech in ["mist","stillness","petal"]:
  var d=Duel.new()
  d.start({"hp":9999,"max_hp":9999,"attack":10,"defense":2},{"hp":9999,"max_hp":9999,"attack":8,"defense":1,"boss":true,"route_id":"bamboo_pass"},tech,"fan" if tech=="petal" else "sword",17)
  var contacts:Dictionary={}
  var joins:=0;var counters:=0
  for tick in range(18*60):
   for event in d.advance(1.0/60.0):
    if event.type=="contact":contacts[str(event.contact_id)]=event
    if event.type=="turn_started" and event.actor=="hero":
     if event.counter:
      counters+=1
      check(contacts.has(str(event.counter_source)),"counter refers to an already resolved physical contact")
      check(float(event.counter_earned_at)<=float(event.time),"counter cannot predate its defensive result")
      if contacts.has(str(event.counter_source)):
       var cause:Dictionary=contacts[str(event.counter_source)]
       check(cause.resolution not in ["whiff","support"],"whiff/support cannot manufacture counter")
       check(cause.resolution=="guard" if event.counter_kind=="deflect_counter" else (cause.resolution=="dodge" if event.counter_kind=="dodge_chase" else cause.poise_broken),"counter kind matches its actual cause")
   var motion:Dictionary=d.pose().hero
   var entry:Dictionary=motion.get("entry_pose",{})
   if not entry.is_empty() and float(motion.get("entry_blend",1))<1:
    joins+=1
    var pose:=Rig.sample_pose(motion)
    check(is_finite(float(pose.body_angle)),"joined body stays finite")
    for arm in [pose.near_arm,pose.far_arm]:
     check(absf(Vector2(arm.shoulder).distance_to(arm.elbow)-42.0)<.001,"join preserves upper arm length")
   if str(motion.combat_phase) in ["strike","contact"]:
    check(float(motion.get("entry_blend",1))==1,"entry interpolation ends before committed contact")
  check(joins>10,"consecutive actions share an outgoing pose: "+tech)
  check(counters>0,"real defensive/offensive opportunity observed: "+tech)
 print("Combat action joins: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
