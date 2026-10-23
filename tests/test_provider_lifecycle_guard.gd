extends SceneTree
## Self-contained external entry: only production res:// scripts are preloaded.
## Run through tools/qa_verify_provider_lifecycle.py: exit0/check counts alone
## are NOT a pass, because Godot can emit SCRIPT ERROR and then exit0.
const G=preload("res://scripts/melee_contact_geometry.gd")
const Fan=preload("res://scripts/combat_modules/weapon_fan.gd")
const Sword=preload("res://scripts/combat_modules/weapon_sword.gd")
const Unarmed=preload("res://scripts/combat_modules/weapon_unarmed.gd")
class CustomFan:
 extends "res://scripts/combat_modules/weapon_fan.gd"
 var geometry_calls:=0
 var pose_calls:=0
 func geometry_points(motion:Dictionary,rig_pose:Dictionary,grip:Dictionary)->PackedVector2Array:
  geometry_calls+=1
  return super.geometry_points(motion,rig_pose,grip)
 func pose_track(motion:Dictionary,g:float,e:float,stance:float)->Dictionary:
  pose_calls+=1
  return super.pose_track(motion,g,e,stance)
var checks:=0
var failures:=0
var cases:Array[String]=[]
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func done(label:String)->void:
 cases.append(label)
 print("PROVIDER_LIFECYCLE_CASE ",label)
func motion(provider:Variant,style:String="fan")->Dictionary:
 return {"pose_provider":provider,"strike_provider":provider,"attack_style":style,"basic_style":style,"combat_move":"basic_"+style+"_sweep","combat_phase":"contact","phase_progress":0.0,"attack_amount":1.0,"combat_stance":1.0}
func equal_fit(h:Dictionary,e:Dictionary,d:Dictionary,label:String)->Dictionary:
 var expected:=G.fit_approach(h,e,d,0.0,{},false)
 var samples:Dictionary={}
 var actual:=G.fit_approach(h,e,d,0.0,samples,true)
 check(var_to_bytes(expected)==var_to_bytes(actual),label+" trusted cold equals full bytes")
 check(var_to_bytes(expected)==var_to_bytes(G.fit_approach(h,e,d,0.0,samples,true)),label+" trusted warm equals full bytes")
 check(expected.size()==4 and expected.has_all(["cost","target","aim","crouch"]),label+" full result shape")
 return expected
func _initialize()->void:
 var dead:=Node.new()
 dead.free()
 check(typeof(dead)==TYPE_OBJECT,"actually freed object retains TYPE_OBJECT")
 check(not is_instance_valid(dead),"actually freed object is invalid")
 check(dead==null,"Godot 4.6.3 existing full path recognizes dead as null")
 check(not G._finite_fit_input(dead),"finite input rejects freed object")
 done("actual_freed_object")
 var e:={"pose_key":"idle"}
 var d:={"route_id":"cloud_slope","boss":true}
 var original:=motion(Fan.new())
 for pair in [[Fan,"fan"],[Sword,"sword"],[Unarmed,"unarmed"]]:
  var h:=motion(pair[0].new(),pair[1])
  check(G._fit_pruning_safe(h,e,d,0.0),"builtin guard accepted "+pair[1])
  equal_fit(h,e,d,pair[1])
  done("builtin_"+pair[1])
 for key in ["pose_provider","strike_provider"]:
  for invalid in [null,7,RefCounted.new()]:
   var h:=original.duplicate();h[key]=invalid
   check(not G._fit_pruning_safe(h,e,d,0.0),"reject malformed "+key)
   var kind:="null" if invalid==null else ("scalar" if typeof(invalid)==TYPE_INT else "live_unknown")
   if invalid==null:equal_fit(h,e,d,"null "+key)
   done(kind+"_"+key)
 for role in ["pose","strike","both"]:
  var h:=original.duplicate();var null_h:=original.duplicate()
  if role in ["pose","both"]:h.pose_provider=dead;null_h.pose_provider=null
  if role in ["strike","both"]:h.strike_provider=dead;null_h.strike_provider=null
  check(not G._fit_pruning_safe(h,e,d,0.0),"actual dead "+role+" guard false")
  var result:=equal_fit(h,e,d,"dead "+role)
  check(var_to_bytes(result)==var_to_bytes(G.fit_approach(null_h,e,d,0.0,{},false)),"dead "+role+" equals corresponding null full bytes")
  done("dead_"+role)
 for location in ["hero","enemy","definition"]:
  var h:=original.duplicate();var en:=e.duplicate();var definition:=d.duplicate()
  var nested:={"not_used_by_geometry":[{"dead":dead}]}
  check(not G._finite_fit_input(nested),"reject nested dead "+location)
  if location=="hero":h.extra=nested
  elif location=="enemy":en.extra=nested
  else:definition.extra=nested
  check(not G._fit_pruning_safe(h,en,definition,0.0),"nested dead guard false "+location)
  equal_fit(h,en,definition,"nested dead "+location)
  done("nested_dead_"+location)
 var custom_a:=CustomFan.new();var custom_b:=CustomFan.new()
 var custom_h:=motion(custom_a);var custom_other:=motion(custom_b)
 check(not G._fit_pruning_safe(custom_h,e,d,0.0),"live custom subclass not trusted")
 var custom_full:=G.fit_approach(custom_h,e,d,0.0,{},false)
 var custom_trusted:=G.fit_approach(custom_other,e,d,0.0,{},true)
 check(var_to_bytes(custom_full)==var_to_bytes(custom_trusted),"custom trusted equals full bytes")
 check(custom_a.geometry_calls==custom_b.geometry_calls and custom_a.geometry_calls>0,"custom geometry callbacks not pruned")
 check(custom_a.pose_calls==custom_b.pose_calls and custom_a.pose_calls>0,"custom pose callbacks not pruned")
 done("live_custom")
 print("PROVIDER_LIFECYCLE_RESULT ",JSON.stringify({"schema":1,"checks":checks,"failures":failures,"cases":cases,"engine":Engine.get_version_info().string}))
 quit(1 if failures else 0)
