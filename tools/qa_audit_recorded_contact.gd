extends SceneTree
const Geometry = preload("res://scripts/melee_contact_geometry.gd")
const Monster = preload("res://scripts/monster_pose_renderer.gd")
var path := ""
var output := ""
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--events="):path=arg.trim_prefix("--events=")
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 var definition: Dictionary=restore(data.bouts[1].loaded_enemy)
 var rows: Array=[]
 var worst:=INF
 var worst_head:=INF
 var tolerance_error:=0.0
 for frame in data.frames:
  if float(frame.time)<18.30 or float(frame.time)>19.30:continue
  var hero:Dictionary=restore(frame.hero)
  var enemy:Dictionary=restore(frame.enemy)
  var points:=Geometry.hero_body_fronts(hero)
  var first_count:=points.size()
  if float(hero.get("reaction_amount",0.0))>0.0:
   var planted:=hero.duplicate();planted.reaction_amount=0.0;planted.defense_action="ready";planted.guard_broken=false
   points.append_array(Geometry.hero_body_fronts(planted))
  var minimum:=INF
  var head_minimum:=INF
  var nearest:Dictionary={}
  for i in range(points.size()):
   var h:Vector2=points[i]
   var front:=Geometry.body_front(enemy,definition,h.y)
   if not front.valid:continue
   var gap:=Vector2(front.point).x-h.x
   if gap<minimum:minimum=gap;nearest={"hero_front":h,"enemy_front":front.point}
   if i<Geometry._hero_head_outline.size() or (i>=first_count and i<first_count+Geometry._hero_head_outline.size()):head_minimum=minf(head_minimum,gap)
  worst=minf(worst,minimum);worst_head=minf(worst_head,head_minimum)
  tolerance_error=maxf(tolerance_error,absf(minimum-float(enemy.get("body_clearance",minimum))))
  rows.append({"time":frame.time,"duel_time":frame.duel_time,"hero_phase":hero.get("combat_phase"),"enemy_phase":enemy.get("combat_phase"),"enemy_progress":enemy.get("phase_progress"),"enemy_pose":Monster.source_pose("cloud_slope_boss",enemy),"body_gap":minimum,"solid_head_gap":head_minimum,"nearest":nearest})
 var result:={"sample_start":18.30,"sample_end":19.30,"frames":rows.size(),"min_body_gap_px":worst,"min_solid_head_gap_px":worst_head,"max_difference_from_recorded_gap_px":tolerance_error,"pass":worst>=2.99 and worst_head>=2.99 and tolerance_error<.01,"rows":rows,"notes":"Reconstructed with authoritative painted-body and hero solid-head outline. Decorative hair/bun excluded by existing body mask. Does not claim sprite silhouettes never visually overlap."}
 var file:=FileAccess.open(output,FileAccess.WRITE);file.store_string(JSON.stringify(result,"\t"));file.close()
 print("CONTACT_AUDIT "+JSON.stringify({"pass":result.pass,"frames":rows.size(),"min_body_gap_px":worst,"min_head_gap_px":worst_head,"max_record_error":tolerance_error}))
 quit(0 if result.pass else 1)
func restore(value:Variant)->Variant:
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:result[key]=restore(value[key])
  return result
 if value is Array:
  var result:Array=[]
  for item in value:result.append(restore(item))
  return result
 if value is String and value.begins_with("(") and value.ends_with(")"):
  var components:PackedStringArray=value.trim_prefix("(").trim_suffix(")").split(",")
  if components.size()==2 and components[0].strip_edges().is_valid_float() and components[1].strip_edges().is_valid_float():
   return Vector2(float(components[0]),float(components[1]))
 return value
