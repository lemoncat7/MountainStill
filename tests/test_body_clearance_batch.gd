extends SceneTree
const Geometry=preload("res://scripts/melee_contact_geometry.gd")
var checks:=0
var failures:=0
func reference(probes:PackedVector2Array,data:Dictionary)->float:
 var clearance:=INF
 for nose in probes:
  var front:=Geometry._front_at_y(nose.y,data)
  if bool(front.valid):clearance=minf(clearance,Vector2(front.point).x-nose.x)
 return clearance
func verify(probes:PackedVector2Array,data:Dictionary,label:String)->void:
 checks+=1
 var actual:=Geometry._body_clearance(probes,data)
 var expected:=reference(probes,data)
 if actual!=expected and not (is_nan(actual) and is_nan(expected)):
  failures+=1
  if failures<10:push_error(label+" "+str([actual,expected]))
func _initialize()->void:
 var rng:=RandomNumberGenerator.new();rng.seed=773903
 for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
  for boss in [false,true]:
   for i in range(90):
    var definition:={"route_id":route,"boss":boss,"engagement_distance":rng.randf_range(-180,260),"feet_y_delta":rng.randf_range(-70,70)}
    var motion:={"pose_key":["idle","windup","attack"][i%3],"move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","combat_phase":["windup","strike","contact","recovery"][i%4],"phase_progress":rng.randf(),"visual_offset":Vector2(rng.randf_range(-100,100),rng.randf_range(-50,50)),"visual_rotation":[0.0,.000099,-.0001,.25][i%4]}
    if i%2==0:motion.monster_pose={"step_cycle":rng.randf_range(-1,1)}
    var data:=Geometry._body_data(motion,definition)
    var points:=PackedVector2Array()
    verify(points,data,"empty")
    for j in range(100):points.append(Vector2(rng.randf_range(-250,300),rng.randf_range(-250,100)))
    verify(points,data,"random "+route)
    var hero:={"combat_phase":"contact","attack_amount":1.0,"combat_stance":1.0,"reaction_amount":rng.randf(),"defense_action":["hit","dodge","guard"][i%3],"approach_origin":rng.randf_range(-70,110),"strike_aim":rng.randf_range(-1.2,1.2),"aim_crouch":rng.randf_range(0,10)}
    verify(Geometry.hero_body_fronts(hero),data,"moving outline "+route)
    if "_authored_" in str(data.key):
     var rect:Rect2=data.rect;var scale:=rect.size.y/256.0
     var origin:Vector2=data.origin;origin+=Vector2(data.registration)*scale
     points.clear()
     for row in range(-1,258):
      for epsilon in [-.00001,0.0,.00001]:
       points.append(Vector2(rng.randf_range(-100,200),origin.y+rect.position.y+(float(row)+.5)*scale+epsilon))
     verify(points,data,"row boundaries "+route)
 # Synthetic row validity and nonfinite X do not enter integer conversion.
 # Nonfinite Y/scale are outside this API's source-data contract; do not claim
 # to repair the scalar baseline's invalid float-to-row behavior.
 for rows in [PackedInt32Array(),PackedInt32Array([-1,-1,-1]),PackedInt32Array([0,10,20])]:
  var data:={"key":"synthetic_authored_body","rect":Rect2(-15,-3,256,256),"origin":Vector2(.25,-.5),"registration":Vector2(2.5,1.25),"rotation":0.0,"front_rows":rows}
  for x in [-INF,INF,NAN,0.0]:
   verify(PackedVector2Array([Vector2(x,-2),Vector2(10,-1),Vector2(-3,0)]),data,"synthetic rows / nonfinite x")
 print("BODY_CLEARANCE_BATCH ",checks," checks ",failures," failures")
 quit(1 if failures else 0)
