extends SceneTree
## Boss painted recovery contract; isolated sampling and actual alpha geometry.
const Module = preload("res://scripts/combat_modules/enemy_attack_module.gd")
const Geometry = preload("res://scripts/melee_contact_geometry.gd")
const Beast = preload("res://scripts/beast_presentation.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const KEY = "creek_bridge_boss_settle"
var checks := 0
var failures := 0
class Probe:
 extends RefCounted
 var point := Vector2.ZERO
 func geometry_points(_motion:Dictionary,_pose:Dictionary,_grip:Dictionary)->PackedVector2Array:
  return PackedVector2Array([point])
func check(ok:bool,label:String)->void:
 checks += 1
 if not ok:
  failures += 1
  printerr("FAIL: "+label)
func module(species:String,boss:bool):
 var value = Module.new()
 value.configure({"module_id":"enemy."+species,"enemy":{"boss":boss,"route_id":"creek_bridge"}})
 return value
func sample(value,kind:String,p:float,phase:String="recovery",state:Dictionary={},action_override:Dictionary={})->Dictionary:
 var action:Dictionary = value.definition().moves[kind].duplicate(true)
 action.kind = kind
 action.merge(action_override,true)
 return value.sample_enemy_motion(action,{"name":phase,"progress":p,"index":0},22.0,state)
func _initialize():
 prewarm_checks()
 var stone = module("river_stone",true)
 for kind in ["charge","sweep","burst"]:
  for p in [-1.0,0.0,.199,.2,.339999,.34,.340001,.5,.779999,.78,.780001,.92,1.0,2.0]:
   var motion := sample(stone,kind,p)
   var expected := "attack" if p < .34 else ("settle" if p < .78 else "idle")
   check(motion.pose_key == expected,"boss %s %.6f pose"%[kind,p])
   check(is_equal_approx(float(motion.clearance_weights[expected]),1.0),"visible key full clearance")
   check(motion.visual_scale == Vector2.ONE,"no anatomy scaling")
  for phase in ["idle","windup","strike","contact","stagger","death"]:
   check(sample(stone,kind,.5,phase).pose_key != "settle","not enabled in "+phase)
  check(sample(stone,kind,.5,"recovery",{"finished":true}).pose_key == "idle","finished/dead settles to idle")
  var interrupted := {"interrupted":true,"frozen_phase":{"name":"strike","index":0},"frozen_pose_key":"attack"}
  check(sample(stone,kind,.5,"stagger",{},interrupted).pose_key == "idle","stagger does not enter settle")
  check(sample(stone,kind,.1,"stagger",{},interrupted).pose_key == "attack","stagger preserves frozen attack")
  interrupted.frozen_pose_key = "settle"
  check(sample(stone,kind,.1,"stagger",{},interrupted).pose_key == "settle","interrupt may retain genuine frozen settle")
  check(sample(stone,kind,.5,"stagger",{},interrupted).pose_key == "idle","frozen settle exits")
  check(sample(stone,kind,.5,"recovery",{"motion":{"defense_action":"guard","reaction_amount":1.0}}).pose_key == "windup","guard overrides recovery")
 for species in ["river_stone","moss_beast","cloud_crane","ember_guardian","moon_wisp","summit_keeper"]:
  for boss in [false,true]:
   if species == "river_stone" and boss: continue
   var other = module(species,boss)
   for kind in ["charge","sweep","burst"]:
    for p in [.339999,.34,.5,.779999,.78,1.0]:
     var motion := sample(other,kind,p)
     check(motion.pose_key == ("attack" if p < .34 else "idle"),"other species/normal unchanged")
     check(not motion.clearance_weights.has("settle"),"no other settle clearance")
 var action:Dictionary = stone.definition().moves.charge.duplicate(true)
 action.kind = "charge"
 var phase := {"name":"recovery","progress":.5,"index":0}
 var state := {"motion":{"actor_lunge":4.0,"nested":{"sentinel":[1,2]}},"hero_lunge":2.0}
 var before := [action.duplicate(true),phase.duplicate(true),state.duplicate(true)]
 var a:Dictionary = stone.sample_enemy_motion(action,phase,10.,state)
 var b:Dictionary = stone.sample_enemy_motion(action,phase,10000.,state)
 check(action == before[0] and phase == before[1] and state == before[2],"sampling is input-pure")
 check(a == b,"no independent animation clock")
 var empty:Dictionary = stone.sample_enemy_motion({},phase,10.,{})
 check(empty.pose_key == "idle" and not empty.clearance_weights.has("settle"),"empty action cannot enable settle")
 geometry_checks(a)
 var rotated := a.duplicate(true)
 rotated.visual_rotation = -.045
 rotated.visual_offset = Vector2(-17.,2.)
 geometry_checks(rotated)
 terminal_checks()
 print("Stone recovery contract: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func geometry_checks(motion:Dictionary)->void:
 var definition := {"route_id":"creek_bridge","boss":true,"engagement_distance":128.,"feet_y_delta":3.}
 var data:Dictionary = Geometry._body_data(motion,definition)
 check(data.key == KEY,"geometry uses actual settle image, not idle fallback")
 var expected:Rect2 = Beast.draw_rect(KEY,Vector2(256,256),174.)
 check(data.rect == expected,"renderer/geometry rect identical")
 var anchor:Array = Beast.landmarks(KEY).ground_anchor
 check(float(anchor[0]) == 121.0 and float(anchor[1]) == 232.0,"reviewed sole registration")
 check(data.rect.position.is_equal_approx(-Vector2(121,232)*174./256.),"registration applied exactly")
 check(not data.articulated,"single painted source not mesh")
 check(data.pixel_mask_key == KEY+"|alpha","separate source mask identity")
 var idle:Dictionary = Geometry._body_data({"pose_key":"idle"},definition)
 check(idle.key != data.key and idle.pixel_mask_key != data.pixel_mask_key,"idle/settle caches cannot alias")
 var again:Dictionary = Geometry._body_data(motion,definition)
 check(is_same(data.image,again.image),"immutable image cache reused")
 check(data.image.get_size() == Vector2i(256,256),"runtime PNG dimensions")
 var source:Image = data.image
 var skull:Array = data.skull
 var probe := Probe.new()
 var found := false
 for y in range(0,256,3):
  for x in range(0,256,3):
   var pixel := Vector2(x+.5,y+.5)
   var world:Vector2 = data.origin+(data.rect.position+pixel*174./256.).rotated(float(data.rotation))
   var solid:bool = x >= int(skull[0])-3 and y >= int(skull[1])-2 and source.get_pixel(x,y).a >= .65
   check(Geometry._opaque(world,data) == solid,"painted source alpha collision")
   if solid and not found:
    probe.point = world
    var measured:Dictionary = Geometry.measure({"strike_provider":probe},motion,definition)
    check(measured.contact and measured.enemy_pose == KEY,"real contact measure hits settle source")
    found = true
 check(found,"settle has hittable source pixels")
 var sources:Array = Geometry._clearance_sources(motion,definition)
 var current := false
 for item in sources:
  if item.data.key == KEY:
   current = true
   check(is_equal_approx(item.weight,1.0),"actual visible geometry fully reserved")
 check(current,"clearance includes actual settle source")

func terminal_checks()->void:
 for defeated in ["hero","enemy"]:
  var duel = Duel.new()
  var hero := {"hp":10000,"max_hp":10000,"attack":2,"defense":1,"battle_resources":{"qi":0.0},"active_skills":[],"passive_methods":[],"weapon_skill":{}}
  var enemy := {"hp":10000,"max_hp":10000,"attack":2,"defense":1,"boss":true,"route_id":"creek_bridge","engagement_distance":120.0,"dodge_chance":0.0,"guard_chance":0.0}
  duel.start(hero,enemy,"mist","unarmed",377)
  var saw_settle := false
  for frame in range(1200):
   duel.advance(.025)
   if duel.pose().enemy.get("pose_key","") == "settle":
    saw_settle = true
    break
  check(saw_settle,"real timeline reaches reviewed settle before terminal test")
  # Force only HP for a deterministic terminal boundary; normal advance owns
  # completion and normal pose sampling must suppress the active recovery.
  if defeated == "hero": duel.hero_hp = 0
  else: duel.enemy_hp = 0
  duel.advance(3.0)
  check(duel.finished,"real timeline processes "+defeated+" death")
  check(duel.pose().enemy.pose_key != "settle","finished real timeline cannot start/retain recovery")

func prewarm_checks()->void:
 # Run first, so another contact test cannot satisfy a missing prewarm.
 check(not Geometry._source_records.has(KEY+"|sprite"),"settle source initially cold")
 var normal := {"route_id":"creek_bridge","boss":false,"engagement_distance":88.}
 var normal_before := normal.duplicate(true)
 Geometry.prewarm(normal)
 check(normal == normal_before,"normal prewarm preserves definition")
 check(not Geometry._source_records.has(KEY+"|sprite"),"normal prewarm does not introduce boss settle")
 check(not Geometry._source_records.has("creek_bridge_settle|sprite"),"normal prewarm does not request absent normal settle")
 check(not Geometry._images.has(KEY),"normal prewarm does not load boss settle image")
 var boss := {"route_id":"creek_bridge","boss":true,"engagement_distance":128.}
 var before := boss.duplicate(true)
 Geometry.prewarm(boss)
 check(boss == before,"boss prewarm preserves definition")
 check(Geometry._source_records.has(KEY+"|sprite"),"boss prewarm compiles settle source")
 check(Geometry._images.has(KEY),"boss prewarm caches settle image")
 check(Geometry._front_rows.has(KEY),"boss prewarm compiles settle alpha rows")
 check(Geometry._source_records[KEY+"|sprite"].key == KEY,"prewarmed key is real settle not fallback")
 var count := Geometry._source_records.size()
 Geometry.prewarm(boss)
 check(Geometry._source_records.size() == count,"repeat prewarm reuses immutable source")
