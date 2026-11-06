extends SceneTree
const G=preload("res://scripts/melee_contact_geometry.gd")
var sink:=0.0
func scalar(probes:PackedVector2Array,data:Dictionary)->float:
 var correction:=0.0
 for nose in probes:
  var front:=G._front_at_y(nose.y,data)
  if bool(front.valid):correction=maxf(correction,maxf(0.0,nose.x+3.0-Vector2(front.point).x))
 return correction
func block(candidate:bool,probes:PackedVector2Array,data:Dictionary)->int:
 var start:=Time.get_ticks_usec()
 for i in range(200):sink=G._clearance_correction(probes,data,{}) if candidate else scalar(probes,data)
 return Time.get_ticks_usec()-start
func _initialize()->void:
 for route in ["bamboo_pass","cloud_slope"]:
  var data:=G._body_data({"move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","combat_phase":"strike","phase_progress":.4,"monster_pose":{"step_cycle":.5},"visual_rotation":.23},{"route_id":route,"boss":true})
  var probes:=G.hero_body_fronts({"combat_phase":"strike","attack_style":"unarmed","phase_progress":.5,"attack_amount":1.0,"combat_stance":1.0})
  assert(scalar(probes,data)==G._clearance_correction(probes,data,{}))
  block(false,probes,data);block(true,probes,data)
  var rows:Array=[]
  for roundno in range(7):
   for candidate in [false,true,true,false]:rows.append({"round":roundno,"candidate":candidate,"us":block(candidate,probes,data)})
  print("DEFORMED_MICRO ",JSON.stringify({"route":route,"key":data.key,"probes":probes.size(),"iterations":200,"blocks":rows}))
 quit()
