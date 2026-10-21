extends SceneTree
## Independent QA: earn two legal native-HP boss checkpoints with one active.
const State = preload("res://scripts/cultivation_state.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
var output := "/tmp/continuous-combat-checkpoints"
var provenance: Array = []
var failed := false

func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 for target in ["bamboo_pass", "cloud_slope"]:
  prepare(target)
 var file := FileAccess.open(output.path_join("provenance.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify({"failed":failed,"metadata":Plan.measurement_metadata(),"cases":provenance}, "\t"))
 file.close()
 quit(1 if failed else 0)

func setup_target(s) -> Dictionary:
 var before := {"seconds":s.lifetime_seconds,"herbs":s.herbs,"dew":s.dew,"qi":s.qi,"heart":s.equipped_heart}
 Plan.study(s,"stillness",1)
 var quote: Dictionary = s.quote_heart_switch("stillness")
 if not quote.get("ok",false): fail("heart quote blocked"); return {}
 var cost: Dictionary = quote.get("cost",{})
 # The canonical guard plan learned stillness but spent down its herbs.
 # Gather the shortfall through the actual 8-second gathering loop, then
 # pay the published quote and wait the genuine saved switch timer.
 s.set_activity("gather")
 for tick in range(450):
  if s.herbs >= int(cost.get("herbs",0)) and s.dew >= int(cost.get("dew",0)): break
  s.step(8.0)
 s.set_activity("meditate")
 for tick in range(450):
  if s.qi >= float(cost.get("qi",0.0)): break
  s.step(8.0)
 if not Plan.choose_heart(s,"stillness"): fail("paid heart switch blocked"); return {}
 s.unequip_technique("mist", "weapon_art")
 for id in s.equipped_actives.duplicate(): s.unequip_technique(str(id), "active")
 s.equip_technique("barrier", "active")
 for id in s.equipped_passives.duplicate(): s.unequip_technique(str(id), "passive")
 var result := {"before":before,"after":{"seconds":s.lifetime_seconds,"herbs":s.herbs,"dew":s.dew,"qi":s.qi,"heart":s.equipped_heart},"quoted_cost":cost,"switch_seconds":quote.get("duration",0),"total_preparation_seconds":s.lifetime_seconds-float(before.seconds)}
 print("HEART_PREPARATION " + JSON.stringify(result))
 return result

func prepare(target: String) -> void:
 var s := State.new()
 s._adventure_rng.seed = 61
 s.gear.rng.seed = 110
 Plan.configure(s, "guard", 0)
 var records: Array = []
 var routes: Array = ["bamboo_pass", "creek_bridge", "bamboo_pass"] if target == "bamboo_pass" else ["bamboo_pass", "creek_bridge", "cloud_slope"]
 for chapter in range(routes.size()):
  var route: String = routes[chapter]
  var is_target := chapter == routes.size() - 1
  var target_preparation: Dictionary = {}
  if is_target:
   target_preparation = setup_target(s)
   if failed: return
  if not s.select_stage(route): fail("route locked " + route); return
  var started := s.start_stage()
  if not started.get("ok", false): fail("start blocked " + route); return
  var hp := int(s.stats().max_hp)
  for index in range(3):
   if index == 2:
    s.check_route_opportunity(int(started.run_id))
    if s.stage_status().opportunity_pending: s.choose_opportunity("gather_gift")
   var hero := s.stats().duplicate(true)
   hero.hp = hp
   hero.battle_resources = s.stage_battle_resources()
   var enemy := Plan.prepare_enemy(s.stage_status().next_monster, route)
   var seed_value := int(started.run_id) * 1337 + index * 79 + 17
   if is_target and index == 2:
    var snap := s._snapshot()
    snap.settings.paused = true
    var checkpoint := FileAccess.open(output.path_join(target + "-checkpoint.json"), FileAccess.WRITE)
    checkpoint.store_string(JSON.stringify(snap, "\t")); checkpoint.close()
    var setup := {"route":route,"run_id":started.run_id,"index":index,"hp":hp,"hero":hero,"enemy":enemy,"seed":seed_value,"weapon":s.gear.visual_loadout().get("weapon", ""),"heart":s.equipped_heart,"form":s.equipped_weapon_art,"actives":s.equipped_actives.duplicate(),"earned_victories":s.total_victories,"checkpoint_valid":s._valid_save(snap),"paid_heart_preparation":target_preparation}
    var setup_file := FileAccess.open(output.path_join(target + "-setup.json"), FileAccess.WRITE)
    setup_file.store_string(JSON.stringify(setup,"\t")); setup_file.close()
   var duel := Duel.new()
   duel.start(hero, enemy, s.technique, str(s.gear.visual_loadout().get("weapon", "")), seed_value)
   var events: Array = []
   while not duel.finished and duel.elapsed < 150.0:
    events.append_array(duel.advance(1.0 / 60.0)); s.step(1.0 / 60.0)
   var record := {"route":route,"index":index,"target":is_target and index==2,"hero":hero,"enemy":enemy,"seconds":duel.elapsed,"hp_end":duel.hero_hp,"victory":duel.victory,"events":events}
   records.append(record)
   print("EARNED_CONTINUOUS route=%s index=%d target=%s seconds=%.4f hp=%d victory=%s" % [route,index,is_target and index==2,duel.elapsed,duel.hero_hp,duel.victory])
   if not duel.victory: fail("lost " + route + ":" + str(index)); return
   s.update_stage_battle_resources(int(started.run_id), duel.battle_resource_snapshot())
   hp = duel.hero_hp
   var result := s.defeat_stage_monster(int(started.run_id),index)
   if not result.get("ok", false): fail("reward blocked"); return
   if index < 2:
    var stats := s.stats()
    s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)));s.step(9.0)
   elif result.get("chapter_reward",{}).get("item") is Dictionary:
    s.equip_item(int(result.chapter_reward.item.id))
  s.step(0.1)
  if not is_target: Plan.configure(s,"guard",chapter+1);Plan.buy_affordable_meridians(s)
 provenance.append({"target":target,"records":records,"earned_victories":s.total_victories,"final_state_valid":s._valid_save(s._snapshot())})

func fail(message: String) -> void:
 failed = true
 push_error(message)
