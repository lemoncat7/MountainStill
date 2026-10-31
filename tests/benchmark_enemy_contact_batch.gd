extends SceneTree
## Paired CPU microbenchmark; not rendered FPS or a frame-latency guarantee.
const Duel=preload("res://scripts/duel_timeline.gd")
const ScalarDuel=preload("res://tests/fixtures/scalar_enemy_contact_duel.gd")
var sink:Dictionary={}
func _initialize()->void:
 var actual:=Duel.new();var scalar:=ScalarDuel.new()
 var action:={"strike_geometry":{"reach":24.0}}
 for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
  var definition:={"route_id":route,"boss":true,"engagement_distance":128.0}
  actual._enemy=definition;scalar._enemy=definition
  var current:={"hero":{},"enemy":{"monster_pose":{},"move_family":"moss_pounce" if route=="bamboo_pass" else "crane_peck","combat_phase":"strike","phase_progress":.5,"visual_offset":Vector2(3,-7)}}
  for i in range(100):
   sink=scalar._measure_enemy_contact(action,current);sink=actual._measure_enemy_contact(action,current)
  var old_times:Array=[];var new_times:Array=[]
  for trial in range(7):
   if trial%2==0:
    old_times.append(measure(scalar,action,current));new_times.append(measure(actual,action,current))
   else:
    new_times.append(measure(actual,action,current));old_times.append(measure(scalar,action,current))
  old_times.sort();new_times.sort()
  print("BATCH_CONTACT_BENCH route=",route," iterations=1000 scalar_us=",old_times," batch_us=",new_times," median_reduction_pct=",100.0*(1.0-float(new_times[3])/float(old_times[3])))
 quit()
func measure(duel:RefCounted,action:Dictionary,current:Dictionary)->int:
 var start:=Time.get_ticks_usec()
 for i in range(1000):sink=duel._measure_enemy_contact(action,current)
 return Time.get_ticks_usec()-start
