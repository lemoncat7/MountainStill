extends SceneTree
## Untimed, explicitly scoped gameplay trace; never used for performance timing.
const Duel = preload("res://scripts/duel_timeline.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
const FIELDS = ["hero_hp", "hero_max_hp", "enemy_hp", "enemy_max_hp", "finished", "victory", "cancelled", "technique", "weapon_style", "turn_index", "elapsed", "_hero", "_enemy", "_profile", "_enemy_history", "_enemy_stamina_base", "_enemy_stamina_anchor", "_lanes", "_pending", "_hero_turns", "_enemy_turns", "_counter_ready", "_counter_kind", "_counter_source", "_counter_earned_at", "_last_contact", "_reactions", "_defense_releases", "_pressure", "_pressure_time", "_break_immunity", "_chase", "_finish_at", "_finish_started", "_finish_approach", "_hero_stance", "_started", "_qi_max", "_qi_regen", "_qi_base", "_qi_anchor", "_skill_lanes", "_skills", "_cooldowns", "_heart", "_weapon_art_form", "_passive_methods", "_skill_uses", "_enemy_slow_until", "_hero_slow_until", "_slow_fractions", "_shield", "_shield_until", "_cost_reduction", "_cooldown_reduction", "_basic_turns", "_technique_uses", "_must_basic", "_next_skill_index", "_enemy_module_definition", "_module_definitions", "_module_ids", "_hero_join", "_action_timing"]
var route := "bamboo_pass"
var weapon := "sword"
var report_path := ""
var trace_prefix := ""
# Dictionaries become ordered entry lists with original key types/order intact.
# Every value is type-tagged; var_to_bytes retains numeric representation.
func canonical(value: Variant) -> Variant:
 var kind := typeof(value)
 if value is Dictionary:
  var entries: Array = []
  for key in value: entries.append([canonical(key), canonical(value[key])])
  return [kind, entries]
 if value is Array:
  var items: Array = []
  for item in value: items.append(canonical(item))
  return [kind, items]
 if value is Object:
  if value == null: return [kind, null]
  var script = value.get_script()
  return [kind, value.get_class(), script.resource_path if script else ""]
 return [kind, value]
func module_state(module: Variant) -> Variant:
 if module == null: return null
 return {"script":module.get_script().resource_path,"selection_count":module.selection_count,"context":module._context,"definition":module._definition}
func digest(bytes: PackedByteArray) -> String:
 var h := HashingContext.new()
 h.start(HashingContext.HASH_SHA256)
 h.update(bytes)
 return h.finish().hex_encode()
func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--route="): route = arg.trim_prefix("--route=")
  elif arg.begins_with("--weapon="): weapon = arg.trim_prefix("--weapon=")
  elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
  elif arg.begins_with("--trace-prefix="): trace_prefix = arg.trim_prefix("--trace-prefix=")
 if report_path.is_empty() or not ((route == "bamboo_pass" and weapon == "sword") or (route == "cloud_slope" and weapon in ["unarmed", "fan"])):
  push_error("Required report path and fixed case missing"); quit(2); return
 var trials: Array = []
 for trial in range(2):
  var d := Duel.new()
  d.start({"hp":420,"max_hp":420,"attack":11,"defense":1},{"hp":780,"max_hp":780,"attack":8,"defense":1,"boss":true,"route_id":route,"dodge_chance":0.0,"guard_chance":0.0},"mist",weapon,377)
  var rows: Array = []
  var event_rows: Array = []
  var tick_hashes: Array = []
  for tick in range(480):
   var events := d.advance(1.0 / 60.0)
   var pose := d.pose()
   var rig := Rig.sample_pose(pose.hero)
   var fields: Dictionary = {}
   for field in FIELDS: fields[field] = d.get(field)
   var modules: Array = []
   for role in ["_base_module", "_form_module", "_enemy_module"]:
    var module = d.get(role)
    modules.append({"role":role,"value":module_state(module)})
   for key in d._skill_modules:
    modules.append({"role":"_skill_modules","key":key,"value":module_state(d._skill_modules[key])})
   var row = canonical({"tick":tick,"events":events,"pose":pose,"rig":rig,"duel":fields,"rng":d._rng.state,"enemy_rng":d._enemy_rng.state,"modules":modules,"report":{"values":d._report._values,"actions":d._report._actions,"contacts":d._report._contacts}})
   rows.append(row)
   event_rows.append(canonical(events))
   tick_hashes.append({"tick":tick,"state_sha256":digest(var_to_bytes(row)),"event_sha256":digest(var_to_bytes(canonical(events)))})
  var bytes := var_to_bytes(rows)
  var record := {"trial":trial,"cache_phase":"cold_process" if trial == 0 else "warm_process","ticks":480,"trace_sha256":digest(bytes),"events_sha256":digest(var_to_bytes(event_rows)),"tick_hashes":tick_hashes,"trace_bytes":bytes.size()}
  if not trace_prefix.is_empty():
   var output := FileAccess.open(trace_prefix + "-" + str(trial) + ".bin", FileAccess.WRITE)
   if output == null: push_error("Cannot write trace"); quit(2); return
   output.store_buffer(bytes); output.close()
  trials.append(record)
 var report := {"schema":"mountainstill.gameplay-trace.v1","engine":Engine.get_version_info(),"os":OS.get_name(),"architecture":Engine.get_architecture_name(),"route":route,"weapon":weapon,"technique":"mist","seed":377,"ticks":480,"dt":1.0/60.0,"duel_fields":FIELDS,"trials":trials,"source_sha256":{"duel":FileAccess.get_sha256("res://scripts/duel_timeline.gd"),"geometry":FileAccess.get_sha256("res://scripts/melee_contact_geometry.gd")}}
 var file := FileAccess.open(report_path,FileAccess.WRITE)
 if file == null: push_error("Cannot write trace report"); quit(2); return
 file.store_string(JSON.stringify(report,"\t"));file.close()
 print("TRACE_REPORT ",report_path);quit(0)
