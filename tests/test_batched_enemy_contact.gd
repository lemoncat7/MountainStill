extends SceneTree
## Exact (not approximate) parity against the unchanged scalar front API/path.
const Geometry=preload("res://scripts/melee_contact_geometry.gd")
const Duel=preload("res://scripts/duel_timeline.gd")
const ScalarDuel=preload("res://tests/fixtures/scalar_enemy_contact_duel.gd")
const Moves=preload("res://scripts/monster_move_library.gd")
const MonsterRig=preload("res://scripts/monster_pose_renderer.gd")
const BaseModule=preload("res://scripts/combat_modules/attack_module.gd")
const ROUTES=["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]
var checks:=0
var failures:=0
var valid_samples:=0
var invalid_samples:=0
class MutatingProvider extends RefCounted:
 var enemy:Dictionary
 var calls:=0
 var current:Dictionary={}
 var definition:Dictionary={}
 func pose_track(_motion:Dictionary,gather:float,extend:float,stance:float)->Dictionary:
  calls+=1
  enemy.visual_offset=Vector2(83,-17)
  if not current.is_empty():current.enemy={"pose_key":"attack","visual_offset":Vector2(41,-33)}
  if not definition.is_empty():definition.engagement_distance=97.0
  return BaseModule.standard_track(gather,extend,stance)
func _initialize()->void:
 var points:=PackedVector2Array([Vector2(10,-10000),Vector2(20,10000)])
 for y in range(-220,41,3):points.append(Vector2(y*.3,y))
 points.append(points[10]);points.append(points[0]) # repeated heights/order
 for route in ROUTES:
  for boss in [false,true]:
   var definition:={"route_id":route,"boss":boss,"engagement_distance":128.0,"feet_y_delta":0.0}
   for pose_key in ["idle","windup","attack","missing_pose","retract","settle"]:
    for rotation in [0.0,.00009,.0001,-.17,.23]:
     compare({"pose_key":pose_key,"visual_offset":Vector2(-13,7),"visual_rotation":rotation},definition,points)
   var families:Array=["moss_pounce","moss_rush","moss_slam"] if route=="bamboo_pass" else ["crane_peck","crane_sweep","crane_dive"]
   for family in families:
    for phase in ["idle","windup","strike","contact","recovery","stagger","defeated"]:
     for progress in [0.0,.5,1.0]:
      var motion:={"monster_pose":Moves.neutral_pose(),"move_family":family,"combat_phase":phase,"phase_progress":progress,
       "interrupted_phase":"strike","interrupted_progress":.5,"visual_offset":Vector2(progress*23,-progress*31),"visual_rotation":progress*.09}
      compare(motion,definition,points)
      motion.visual_offset=Vector2(71,-26);definition.feet_y_delta=12.0
      compare(motion,definition,points)
      definition.feet_y_delta=0.0
   # A defeated source can change between calls through the renderer's state.
   for previous in ["authored_crouch","authored_land","authored_peck"]:
    MonsterRig._last_pose[route+("_boss" if boss else "")]=previous
    compare({"monster_pose":{},"combat_phase":"defeated","defeat_amount":.01},definition,points)
 test_cold_sources(points)
 var count:=Geometry._source_records.size()
 expect(Geometry.body_fronts({}, {"route_id":"nonexistent_empty_batch"}, PackedVector2Array()).is_empty(),"empty batch")
 expect(Geometry._source_records.size()==count,"empty batch does not resolve source")
 test_provider_order()
 print("BATCHED_FRONT_MATRIX: ",checks," checks; valid=",valid_samples," invalid=",invalid_samples," failures=",failures)
 test_duel_traces()
 print("BATCHED_ENEMY_CONTACT: ",checks," checks, ",failures," failures")
 quit(1 if failures else 0)
func test_cold_sources(points:PackedVector2Array)->void:
 for motion in [{"pose_key":"missing_pose"},{"monster_pose":{},"combat_phase":"strike","move_family":"moss_pounce","phase_progress":.5,"visual_rotation":.12}]:
  var definition:={"route_id":"bamboo_pass","boss":true}
  clear_sources()
  var actual:=Geometry.body_fronts(motion,definition,points)
  clear_sources()
  var expected:Array[Dictionary]=[]
  for point in points:expected.append(Geometry.body_front(motion,definition,point.y))
  expect(actual==expected,"cold source/cache scalar equality")
func clear_sources()->void:
 Geometry._images.clear();Geometry._front_rows.clear();Geometry._source_records.clear()
 Geometry._deformed_fronts.clear();Geometry._deformed_front_bins.clear();Geometry._pixel_masks.clear()
func compare(motion:Dictionary,definition:Dictionary,points:PackedVector2Array)->void:
 var actual:=Geometry.body_fronts(motion,definition,points)
 expect(actual.size()==points.size(),"same sample count")
 for i in range(points.size()):
  var expected:=Geometry.body_front(motion,definition,points[i].y)
  expect(actual[i]==expected,"exact scalar front "+str(i)+" "+str(definition)+" "+str(motion))
  if expected.valid:valid_samples+=1
  else:invalid_samples+=1
func test_provider_order()->void:
 var motion:={"pose_key":"idle","visual_offset":Vector2.ZERO,"body_separation":3.0,"body_reservation":7.0}
 var provider:=MutatingProvider.new();provider.enemy=motion
 var current:={"hero":{"pose_provider":provider},"enemy":motion}
 var actual:=Duel.new();var scalar:=ScalarDuel.new()
 actual._enemy={"route_id":"bamboo_pass"};scalar._enemy=actual._enemy.duplicate()
 var action:={"strike_geometry":{"reach":24.0,"area":true}}
 var expected:Dictionary=scalar._measure_enemy_contact(action,current)
 expect(provider.calls==1,"scalar pose provider called once")
 motion.visual_offset=Vector2.ZERO;provider.calls=0
 expect(actual._measure_enemy_contact(action,current)==expected,"provider mutation precedes body snapshot")
 expect(provider.calls==1,"batch pose provider called once")
 # Replacing the dictionary (rather than just its fields) must also be seen.
 provider.current=current;provider.definition=actual._enemy
 actual._enemy.engagement_distance=128.0
 current.enemy=motion
 var replacement_actual:Dictionary=actual._measure_enemy_contact(action,current)
 provider.definition=scalar._enemy;scalar._enemy.engagement_distance=128.0
 current.enemy=motion
 var replacement_expected:Dictionary=scalar._measure_enemy_contact(action,current)
 expect(replacement_actual==replacement_expected,"provider replaces enemy and mutates definition before snapshot")
 provider.current={};provider.definition={};current.enemy=motion
 for offset in [Vector2(0,0),Vector2(13,-29),Vector2(-50,300)]:
  current.hero={};motion.visual_offset=offset
  expect(actual._measure_enemy_contact(action,current)==scalar._measure_enemy_contact(action,current),"fresh snapshot after enemy mutation")
func test_duel_traces()->void:
 for route in ROUTES:
  for boss in [false,true]:
   var actual:=Duel.new();var scalar:=ScalarDuel.new()
   var hero:={"hp":10000,"max_hp":10000,"attack":11,"defense":1}
   var enemy:={"hp":10000,"max_hp":10000,"attack":8,"defense":1,"route_id":route,"boss":boss}
   actual.start(hero,enemy,"mist","sword",377);scalar.start(hero,enemy,"mist","sword",377)
   for tick in range(360):
    expect(actual.advance(1.0/60.0)==scalar.advance(1.0/60.0),"exact events "+route+" tick="+str(tick))
    var a:=actual.pose();var b:=scalar.pose()
    # Provider bindings are independent instances; compare observable data.
    for actor in ["hero","enemy"]:
     for key in ["pose_provider","strike_provider","guard_provider"]:
      a[actor].erase(key);b[actor].erase(key)
    expect(a==b,"exact pose "+route+" tick="+str(tick))
   print("BATCHED_TRACE: ",route," boss=",boss," 360 ticks failures=",failures)
func expect(ok:bool,label:String)->void:
 checks+=1
 if not ok:
  failures+=1
  if failures<=20:push_error(label)
