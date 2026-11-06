extends SceneTree
## Exact reduction microbenchmark; not native frame/GPU evidence.
const Geometry=preload("res://scripts/melee_contact_geometry.gd")
var sink:=0.0
func reference(probes:PackedVector2Array,data:Dictionary)->float:
 var clearance:=INF
 for nose in probes:
  var front:=Geometry._front_at_y(nose.y,data)
  if bool(front.valid):clearance=minf(clearance,Vector2(front.point).x-nose.x)
 return clearance
func block(candidate:bool,probes:PackedVector2Array,data:Dictionary)->int:
 var start:=Time.get_ticks_usec()
 for i in range(500):sink=Geometry._body_clearance(probes,data) if candidate else reference(probes,data)
 return Time.get_ticks_usec()-start
func _initialize()->void:
 for route in ["bamboo_pass","cloud_slope","creek_bridge"]:
  var motion:={"pose_key":"attack","move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","combat_phase":"contact","phase_progress":.5,"monster_pose":{"step_cycle":.4},"visual_offset":Vector2(3,-7)}
  var data:=Geometry._body_data(motion,{"route_id":route,"boss":true,"engagement_distance":128.0})
  var probes:=Geometry.hero_body_fronts({"combat_phase":"strike","attack_style":"unarmed","phase_progress":.5,"attack_amount":1.0,"combat_stance":1.0})
  assert(reference(probes,data)==Geometry._body_clearance(probes,data))
  block(false,probes,data);block(true,probes,data)
  var rows:Array=[]
  for roundno in range(7):
   for candidate in [false,true,true,false]:rows.append({"round":roundno,"candidate":candidate,"us":block(candidate,probes,data)})
  print("CLEARANCE_MICRO ",JSON.stringify({"route":route,"key":data.key,"probes":probes.size(),"iterations_per_block":500,"blocks":rows}))
 quit()
