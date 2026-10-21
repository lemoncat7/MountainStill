extends SceneTree
const Duel=preload("res://scripts/duel_timeline.gd")
var failures:=0
func _initialize():
 for species in ["moss_beast","cloud_crane"]:
  for boss in [false,true]:
   var d:=Duel.new();d.start({"hp":10000,"max_hp":10000,"attack":1,"defense":0,"active_skills":[],"weapon_art":{},"heart_method":{},"weapon_skill":{}},{"hp":10000,"max_hp":10000,"attack":1,"defense":1,"visual_type":species,"route_id":"cloud_slope" if species=="cloud_crane" else "bamboo_pass","boss":boss,"dodge_chance":0.,"guard_chance":0.},"mist","sword",77)
   var previous:Dictionary=d.pose().enemy;var maximum:=0.0;var label:=""
   for frame in range(1440):
    d.advance(1.0/60.0)
    var current:Dictionary=d.pose().enemy
    if float(current.reaction_amount)<.001 and float(previous.reaction_amount)<.001 and current.combat_phase!="stagger" and previous.combat_phase!="stagger":
     var step:=Vector2(current.visual_offset).distance_to(previous.get("visual_offset",Vector2.ZERO))
     if step>maximum:maximum=step;label="%s>%s/%s t=%.3f p=%.3f %s>%s"%[previous.combat_phase,current.combat_phase,current.move_family,d.elapsed,current.phase_progress,str(previous.visual_offset),str(current.visual_offset)]
    previous=current
   print("Monster root continuity %s boss%s max %.3f px/frame %s"%[species,boss,maximum,label])
   if maximum>12.0:failures+=1;push_error("Unmotivated monster root pop at 60Hz")
 print("Monster root continuity:4 scenarios,%d failures"%failures)
 quit(1 if failures else 0)
