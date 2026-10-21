extends SceneTree
## Exact parity with the pre-cache source calculation; no gameplay tolerance.
const Geometry=preload("res://scripts/melee_contact_geometry.gd")
const Reference=preload("res://tests/geometry_source_reference.gd")
const Moves=preload("res://scripts/monster_move_library.gd")
var checks:=0
var failures:=0
func _initialize()->void:
 for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
  for boss in [false,true]:
   var definition:={"route_id":route,"boss":boss,"engagement_distance":128.0,"feet_y_delta":0.0}
   for pose_key in ["idle","windup","attack","missing_pose"]:
    compare({"pose_key":pose_key},definition)
   if route not in ["bamboo_pass","cloud_slope"]:continue
   var families:Array=["moss_pounce","moss_rush","moss_slam"] if route=="bamboo_pass" else ["crane_peck","crane_sweep","crane_dive"]
   for family in families:
    for phase_name in ["idle","windup","strike","contact","recovery","stagger"]:
     for progress in [0.0,.05,.3,.5,.8,1.0]:
      for reaction in ["ready","hit","guard","dodge"]:
       var motion:={"move_family":family,"combat_phase":phase_name,"phase_progress":progress,"strike_index":0,
        "monster_pose":Moves.neutral_pose(),"interrupted_phase":"strike","interrupted_progress":.5,
        "defense_action":reaction,"reaction_amount":.6 if reaction!="ready" else 0.0,
        "reaction_strength":.9,"guard_broken":reaction=="guard","impact_profile":{"kind":"heavy"},
        "visual_offset":Vector2(progress*7.0,-progress*13.0),"visual_rotation":progress*.035}
       compare(motion,definition)
       var changed:=definition.duplicate();changed.engagement_distance=91.0;changed.feet_y_delta=12.0
       compare(motion,changed)
 for source in Geometry._source_records.values():expect(source.is_read_only(),"source records are read-only")
 var count:=Geometry._source_records.size()
 for repeat in range(100):
  compare({"move_family":"moss_pounce","combat_phase":"contact","monster_pose":Moves.neutral_pose(),"visual_offset":Vector2(repeat,0)}, {"route_id":"bamboo_pass","boss":true,"engagement_distance":float(repeat)})
 expect(count==Geometry._source_records.size(),"changing world origins does not grow the immutable source cache")
 print("GEOMETRY_SOURCE_CACHE: ",checks," checks, ",failures," failures; ",Geometry._source_records.size()," source records")
 quit(1 if failures else 0)
func compare(motion:Dictionary,definition:Dictionary)->void:
 var actual:=Geometry._body_data(motion,definition)
 var expected:=Reference._body_data(motion,definition)
 for key in ["rect","skull","origin","rotation","key","front_rows","articulated","motion","registration"]:
  expect(actual[key]==expected[key],"cached field "+key+" matches reference for "+str(definition)+" "+str(motion.get("move_family",motion.get("pose_key",""))))
 expect(actual.image.get_size()==expected.image.get_size(),"image dimensions match")
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<20:push_error(label)
