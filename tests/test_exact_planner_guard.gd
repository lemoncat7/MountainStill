extends SceneTree
## Runs against shipped res:// runtime; sibling fixture is loaded externally.
const G=preload("res://scripts/melee_contact_geometry.gd")
const Rig=preload("res://scripts/character_sidewalk.gd")
const Fan=preload("res://scripts/combat_modules/weapon_fan.gd")
const Sword=preload("res://scripts/combat_modules/weapon_sword.gd")
const Unarmed=preload("res://scripts/combat_modules/weapon_unarmed.gd")
var checks:=0
var failures:=0
var early_returns:=0
var equal_costs:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
# Full ordered oracle uses PRODUCT public geometry, never a substituted runtime.
# Same legacy floating-point operation order, strict < tie retention and neutral early return.
func full(hero:Dictionary,enemy:Dictionary,definition:Dictionary,origin:float,samples:Dictionary)->Dictionary:
 var sources:Array=G._clearance_sources(enemy,definition)
 var best:={"cost":INF,"target":origin,"aim":0.0,"crouch":0.0}
 for crouch in [0.0,5.0,10.0]:
  for ai in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6]:
   var candidate:=hero.duplicate();candidate.strike_aim=float(ai)*0.2;candidate.aim_crouch=crouch
   var measured:Dictionary=G.measure(candidate,enemy,definition,samples)
   if not bool(measured.vertical_valid):continue
   var target:=clampf(float(measured.gap)+0.5,-70.0,110.0)
   candidate.approach_origin=target
   var final_enemy:Dictionary=G.separate(enemy,candidate,definition,sources,samples,false)
   var final:Dictionary=G.measure(candidate,final_enemy,definition,samples)
   var residual:=absf(float(final.gap)) if bool(final.vertical_valid) else 100.0
   var cost:float=maxf(0.0,residual-2.0)*20.0+absf(float(ai))*0.45+crouch*0.16+absf(target-origin)*0.015
   if bool(final.contact):
    cost-=5.0
    if ai==0 and crouch==0.0:
     early_returns+=1
     return {"cost":cost,"target":target,"aim":0.0,"crouch":0.0}
   if is_finite(cost) and cost==float(best.cost):equal_costs+=1
   if cost<float(best.cost):best={"cost":cost,"target":target,"aim":candidate.strike_aim,"crouch":crouch}
 return best
func motion(provider:Object,style:String)->Dictionary:
 return {"pose_provider":provider,"strike_provider":provider,"attack_style":style,"basic_style":style,"action_kind":"basic","combat_phase":"contact","phase_progress":0.0,"strike_progress":1.0,"approach_origin":0.0}
func compare(h:Dictionary,e:Dictionary,d:Dictionary,o:float,cache:Dictionary={})->void:
 var a:=cache.duplicate(true);var b:=cache.duplicate(true);var c:=cache.duplicate(true)
 var expected:=full(h,e,d,o,a)
 check(var_to_bytes(expected)==var_to_bytes(G.fit_approach(h,e,d,o,b)),"default legacy result exact")
 check(var_to_bytes(a)==var_to_bytes(b),"default false preserves full cache evaluation")
 check(var_to_bytes(expected)==var_to_bytes(G.fit_approach(h,e,d,o,c,false)),"explicit false result exact")
 check(var_to_bytes(b)==var_to_bytes(c),"default equals explicit false cache")
 if cache.is_empty():
  var owned:Dictionary={}
  check(var_to_bytes(expected)==var_to_bytes(G.fit_approach(h,e,d,o,owned,true)),"trusted cold exact result")
  check(var_to_bytes(expected)==var_to_bytes(G.fit_approach(h,e,d,o,owned,true)),"trusted warm exact result")
func test_tie(enemy:Dictionary,definition:Dictionary)->void:
 var h:=motion(Unarmed.new(),"unarmed")
 var normal:Dictionary=Rig.sample_contact_pose(h)
 var samples:Dictionary={}
 for crouch in [0.0,5.0,10.0]:
  for ai in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6]:
   var candidate:=h.duplicate();candidate.strike_aim=float(ai)*0.2;candidate.aim_crouch=crouch
   var pose:=normal.duplicate(true)
   if ai==0:
    pose.near_arm.wrist=Vector2(0,100000);pose.far_arm.wrist=Vector2(0,100000)
   samples[candidate.duplicate(true)]=pose
   var measured:Dictionary=G.measure(candidate,enemy,definition,samples)
   candidate.approach_origin=clampf(float(measured.gap)+0.5,-70.0,110.0)
   samples[candidate.duplicate(true)]=pose.duplicate(true)
 var before:=equal_costs
 var result:=full(h,enemy,definition,0.0,samples.duplicate(true))
 check(equal_costs>before,"finite equal-cost real geometry fixture exercised")
 check(float(result.aim)==-0.2 and float(result.crouch)==0.0,"ordered tie retains negative aim first")
 compare(h,enemy,definition,0.0,samples)
func _initialize()->void:
 var definition:={"route_id":"bamboo_pass","boss":false,"engagement_distance":88.0}
 var enemy:={"pose_key":"idle"}
 test_tie(enemy,definition)
 for pair in [[Fan,"fan"],[Sword,"sword"],[Unarmed,"unarmed"]]:
  var h:=motion(pair[0].new(),pair[1])
  check(G._fit_pruning_safe(h,enemy,definition,0.0),"exact builtin accepted "+pair[1])
  for distance in [40.0,88.0,120.0]:
   var d:=definition.duplicate();d.engagement_distance=distance
   for origin in [0.0,-0.0,20.0]:compare(h,enemy,d,origin)
 var h:=motion(Fan.new(),"fan")
 for origin in [NAN,INF,-INF]:
  check(not G._fit_pruning_safe(h,enemy,definition,origin),"nonfinite origin fail open")
  compare(h,enemy,definition,origin)
 for key in ["pose_provider","strike_provider"]:
  for invalid in [null,7,RefCounted.new()]:
   var bad:=h.duplicate();bad[key]=invalid
   check(not G._fit_pruning_safe(bad,enemy,definition,0.0),"reject nonexact provider "+key)
 var custom_script=load(get_script().resource_path.get_base_dir().path_join("exact_planner_custom_fan.gd"))
 var pa=custom_script.new();var pb=custom_script.new()
 var ha:=motion(pa,"fan");var hb:=motion(pb,"fan")
 check(not G._fit_pruning_safe(ha,enemy,definition,0.0),"subclass not exact builtin")
 var a:=G.fit_approach(ha,enemy,definition,0.0,{},false)
 var b:=G.fit_approach(hb,enemy,definition,0.0,{},true)
 check(var_to_bytes(a)==var_to_bytes(b),"stateful custom fallback result")
 check(pa.geometry_calls==pb.geometry_calls and pa.pose_calls==pb.pose_calls and pa.geometry_calls>0,"custom callbacks not pruned")
 var key:=h.duplicate();key.strike_aim=0.0;key.aim_crouch=0.0
 var pose:Dictionary=Rig.sample_contact_pose(key);pose.shift=Vector2(pose.shift)+Vector2(7.0,2.0)
 var polluted:Dictionary={key.duplicate(true):pose.duplicate(true)}
 compare(h,enemy,definition,0.0,polluted)
 var bad:=h.duplicate();bad.unused=Vector2(NAN,0)
 check(not G._fit_pruning_safe(bad,enemy,definition,0.0),"nonfinite unused field fail open")
 compare(bad,enemy,definition,0.0)
 var deep:Dictionary={};var cursor:=deep
 for i in range(18):cursor.next={};cursor=cursor.next
 check(not G._finite_fit_input(deep),"deep input fail open")
 var cycle:Dictionary={};cycle.self=cycle
 check(not G._finite_fit_input(cycle),"cycle fail open");cycle.clear()
 check(not G._finite_fit_input({"object":RefCounted.new()}),"unknown nested object fail open")
 var dead:=Node.new();dead.free()
 check(not G._finite_fit_input(dead),"freed object fail open")
 check(early_returns>0,"actual geometry exercises neutral early return")
 print("Exact planner guard: %d checks, %d failures; neutral early returns=%d, exact ties=%d"%[checks,failures,early_returns,equal_costs])
 quit(1 if failures else 0)
