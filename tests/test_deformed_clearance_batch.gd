extends SceneTree
const G=preload("res://scripts/melee_contact_geometry.gd")
var checks:=0
var failures:=0
func oracle(probes:PackedVector2Array,data:Dictionary)->float:
 var result:=0.0
 for nose in probes:
  var front:=G._front_at_y(nose.y,data)
  if bool(front.valid):result=maxf(result,maxf(0.0,nose.x+3.0-Vector2(front.point).x))
 return result
func _initialize()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=782199
 for i in range(420):
  var route:String=["bamboo_pass","cloud_slope","creek_bridge"][i%3]
  var enemy:={"pose_key":"attack","move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","combat_phase":"strike","phase_progress":rng.randf(),"monster_pose":{"step_cycle":rng.randf_range(-1,1)},"visual_rotation":rng.randf_range(-.6,.6),"visual_offset":Vector2(rng.randf_range(-30,30),rng.randf_range(-30,30))}
  var data:=G._body_data(enemy,{"route_id":route,"boss":i%2==0,"engagement_distance":rng.randf_range(70,150)})
  var probes:=PackedVector2Array()
  for n in range(i%100):probes.append(Vector2(rng.randf_range(-150,150),rng.randf_range(-160,40)))
  for state in range(4):
   if state==0:G._deformed_fronts.clear();G._deformed_front_bins.clear()
   if state==2:
    data.origin+=Vector2(.000001,-.000001)
    data.motion.monster_pose.step_cycle+=.001
   if state==3:
    G._deformed_fronts.clear();G._deformed_front_bins.clear()
    for dummy in range(96):
     G._deformed_fronts[str(dummy)]=PackedVector2Array();G._deformed_front_bins[str(dummy)]={}
   var before_shapes:=G._deformed_fronts.duplicate(true)
   var before_bins:=G._deformed_front_bins.duplicate(true)
   var actual:=G._clearance_correction(probes,data,{})
   var after_shapes:=G._deformed_fronts.duplicate(true)
   var after_bins:=G._deformed_front_bins.duplicate(true)
   G._deformed_fronts=before_shapes.duplicate(true);G._deformed_front_bins=before_bins.duplicate(true)
   var expected:=oracle(probes,data)
   checks+=1
   if G._deformed_fronts!=after_shapes or G._deformed_front_bins!=after_bins:failures+=1;push_error("cache mismatch")
   if probes.is_empty():
    checks+=1
    if after_shapes!=before_shapes or after_bins!=before_bins:failures+=1
   checks+=1
   if actual!=expected:failures+=1;push_error(str([i,state,actual,expected]))
 # Bin boundaries, repeated points, invalid rows and exact scalar probe order.
 var data:=G._body_data({"move_family":"crane_dive","combat_phase":"strike","phase_progress":.4,"monster_pose":{"step_cycle":.5},"visual_rotation":.23},{"route_id":"cloud_slope","boss":true})
 for y in range(-160,60):
  for epsilon in [-.000001,0.0,.000001]:
   var point:=Vector2(80,y*4.0+epsilon)
   var probes:=PackedVector2Array([point,point,Vector2(-300,point.y),Vector2(500,point.y)])
   checks+=1
   if G._clearance_correction(probes,data,{})!=oracle(probes,data):failures+=1
 for rotation in [-.000100001,-.0001,-.000099999,.000099999,.0001,.000100001,.3]:
  for rows in [PackedInt32Array(),PackedInt32Array([-1]),PackedInt32Array([10]),PackedInt32Array([-1,-1,-1]),PackedInt32Array([20,22,21])]:
   var sample:=data.duplicate(true);sample.rotation=rotation;sample.front_rows=rows
   sample.key=str(data.key)+"_synthetic_"+str(rotation)+str(rows)
   var probes:=PackedVector2Array([Vector2(-1000000,-1000000),Vector2(1000000,1000000),Vector2(0,-40),Vector2(10,-40)])
   G._deformed_fronts.clear();G._deformed_front_bins.clear()
   var actual:=G._clearance_correction(probes,sample,{})
   G._deformed_fronts.clear();G._deformed_front_bins.clear()
   checks+=1
   if actual!=oracle(probes,sample):failures+=1;push_error("synthetic mismatch")
 # The legacy elastic articulated key uses the same scalar shape construction.
 var elastic:=data.duplicate(true);elastic.key="bamboo_pass_idle";elastic.rotation=.3
 var probes:=G.hero_body_fronts({"combat_phase":"contact","attack_style":"unarmed"})
 G._deformed_fronts.clear();G._deformed_front_bins.clear()
 var actual:=G._clearance_correction(probes,elastic,{})
 G._deformed_fronts.clear();G._deformed_front_bins.clear()
 checks+=1
 if actual!=oracle(probes,elastic):failures+=1;push_error("elastic mismatch")
 print("DEFORMED_CLEARANCE_BATCH ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
