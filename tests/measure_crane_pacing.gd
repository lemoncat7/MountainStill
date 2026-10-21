extends SceneTree
## Matched chapter-three diagnostic from genuinely earned campaign snapshots.
## This is not a replacement for the complete lawful campaign balance suite.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
func _initialize() -> void:
 var input_path := "res://docs/qa/campaign-pacing-revision/before.json"
 var report_path := "user://crane-paired-sensitivity.json"
 var seed_count := 32
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--input="):input_path = arg.trim_prefix("--input=")
  elif arg.begins_with("--report="):report_path = arg.trim_prefix("--report=")
  elif arg.begins_with("--seed-count="):seed_count = maxi(1,int(arg.trim_prefix("--seed-count=")))
 var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
 if not data is Dictionary or not data.get("encounters") is Array:
  push_error("Readable earned encounter input is required")
  quit(1)
  return
 var rows: Array = data.encounters
 var outputs: Array = []
 var revised_hp := int(Content.STAGES.cloud_slope.monsters[2].hp)
 for build in Plan.BUILDS:
  var profiles := rows.filter(func(r): return r.build == build and r.chapter == 3 and r.rng_seed == 61)
  if profiles.size() != 3:
   push_error("Expected all three earned crane-route profiles for " + build)
   quit(1)
   return
  for seed_index in range(seed_count):
   var health := int(profiles[0].hero_stats.max_hp)
   var resources: Dictionary = profiles[0].hero_stats.battle_resources.duplicate(true)
   var normals: Array = []
   var route_ok := true
   for index in range(2):
    var row: Dictionary = profiles[index]
    var hero: Dictionary = row.hero_stats.duplicate(true)
    hero.hp = health
    hero.battle_resources = resources.duplicate(true)
    var enemy := Plan.prepare_enemy(Content.STAGES.cloud_slope.monsters[index], "cloud_slope")
    var duel := Duel.new()
    duel.start(hero,enemy,row.technique,row.equipment.get("weapon",""),int(row.duel_seed)+seed_index*10007)
    duel.advance(120.0)
    health = duel.hero_hp
    resources = duel.battle_resource_snapshot()
    normals.append({"index":index,"seconds":duel.elapsed,"victory":duel.victory,"remaining_hp":health})
    if not duel.victory:
     route_ok = false
     break
    resources = Duel.rest_resource_snapshot(resources,9.0,float(hero.combat_qi_max),float(hero.combat_qi_regen))
   if not route_ok:
    outputs.append({"build":build,"seed_index":seed_index,"normals":normals,"bosses":[]})
    continue
   var bosses: Array = []
   for hp in [550,revised_hp]:
    var row: Dictionary = profiles[2]
    var hero: Dictionary = row.hero_stats.duplicate(true)
    hero.hp = health
    hero.battle_resources = resources.duplicate(true)
    var enemy := Plan.prepare_enemy(Content.STAGES.cloud_slope.monsters[2],"cloud_slope")
    enemy.hp = hp
    var duel := Duel.new()
    duel.start(hero,enemy,row.technique,row.equipment.get("weapon",""),int(row.duel_seed)+seed_index*10007)
    var events := duel.advance(120.0)
    var whiffs := 0
    var dodges := 0
    var guards := 0
    var contacts := 0
    for event in events:
     if event.type == "contact" and event.actor == "hero":
      contacts += 1
      if event.resolution == "whiff":whiffs += 1
      if event.resolution == "dodge":dodges += 1
      if event.resolution == "guard":guards += 1
    bosses.append({"hp":hp,"seconds":duel.elapsed,"victory":duel.victory,"remaining_hp":duel.hero_hp,"hero_contacts":contacts,"hero_whiffs":whiffs,"enemy_dodges":dodges,"enemy_guards":guards,"end_resources":duel.battle_resource_snapshot()})
   outputs.append({"build":build,"seed_index":seed_index,"normals":normals,"bosses":bosses})
  print("CRANE PAIRED SENSITIVITY ",build," complete")
 var file := FileAccess.open(report_path,FileAccess.WRITE)
 if file == null:
  push_error("Cannot write crane diagnostic report")
  quit(1)
  return
 file.store_string(JSON.stringify({"seed_count":seed_count,"boss_hp_before":550,"boss_hp_after":revised_hp,"source_snapshot_sha256":FileAccess.get_sha256(input_path),"source_metadata":data.metadata,"method":"Same genuinely earned chapter-three checkpoints; actual HP/qi/cooldowns carried across normals with 9s travel; paired bosses change only vitality; canonical seed + index * 10007. Diagnostic, not a complete earned-state campaign rerun.","samples":outputs},"\t"))
 file.close()
 quit()
