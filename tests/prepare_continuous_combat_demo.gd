extends SceneTree
## Independent QA: earn two legal native-HP boss checkpoints with one active.
const State = preload("res://scripts/cultivation_state.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
var output := "/tmp/continuous-combat-checkpoints"
var provenance: Array = []
var failed := false
var growth: Array = []

func _initialize() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 for target in ["bamboo_pass", "cloud_slope"]:
  prepare(target)
  if failed: break
 var file := FileAccess.open(output.path_join("provenance.json"), FileAccess.WRITE)
 file.store_string(JSON.stringify({"failed":failed,"metadata":Plan.measurement_metadata(),"cases":provenance,"manual_growth":growth,"method":"Paid manual breakthroughs and real corpse search; checkpoint preparation is not continuous UI play."}, "\t"))
 file.close()
 quit(1 if failed else 0)

func setup_target(s) -> Dictionary:
 var before := {"seconds":s.lifetime_seconds,"herbs":s.herbs,"dew":s.dew,"qi":s.qi,"heart":s.equipped_heart}
 Plan.study(s,"stillness",1)
 var quote: Dictionary = s.quote_heart_switch("stillness")
 var already_equipped:bool=s.equipped_heart=="stillness"
 if not quote.get("ok",false) and not already_equipped: fail("heart quote blocked: "+str(quote.get("reason",""))); return {}
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
 var result := {"before":before,"after":{"seconds":s.lifetime_seconds,"herbs":s.herbs,"dew":s.dew,"qi":s.qi,"heart":s.equipped_heart},"already_equipped":already_equipped,"quoted_cost":cost,"switch_seconds":quote.get("duration",0),"total_preparation_seconds":s.lifetime_seconds-float(before.seconds)}
 print("HEART_PREPARATION " + JSON.stringify(result))
 return result

func grow_to(s, target: int, case_target: String, route: String) -> bool:
 while s.realm < target:
  var start_seconds:float=s.lifetime_seconds
  var cost_qi:float=s.Content.QI_COSTS[s.realm]
  var cost_herbs:int=s.Content.HERB_COSTS[s.realm]
  for tick in range(450):
   if s.herbs>=cost_herbs and s.qi>=cost_qi:break
   s.set_activity("gather" if s.herbs<cost_herbs else "meditate")
   s.step(8.0)
  s.set_activity("meditate")
  var before:Dictionary={"realm":s.realm,"qi":s.qi,"herbs":s.herbs}
  if not s.breakthrough():fail("manual breakthrough budget unavailable");return false
  if s.realm!=int(before.realm)+1 or s.herbs!=int(before.herbs)-cost_herbs or absf(s.qi-(float(before.qi)-cost_qi))>.00001:
   fail("manual breakthrough cost mismatch");return false
  growth.append({"case_target":case_target,"route":route,"before":before,"after":{"realm":s.realm,"qi":s.qi,"herbs":s.herbs},"qi_cost":cost_qi,"herb_cost":cost_herbs,"gather_or_meditate_seconds":s.lifetime_seconds-start_seconds})
 return true

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
  # A fresh player remains manual; rewards never perform this choice for them.
  # The target stillness build also needs realm three before its paid lessons.
  if not grow_to(s,maxi(int(s.Content.STAGES[route].unlock_realm),3 if is_target else 0),target,route):return
  if chapter>0:Plan.configure(s,"guard",chapter);Plan.buy_affordable_meridians(s)
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
   if not s.begin_stage_corpse(int(started.run_id),index).get("ok",false):fail("corpse blocked");return
   if s.complete_stage_search(int(started.run_id),index).get("ok",false):fail("premature search reward");return
   for tick in range(120):
    s.advance_stage_search(int(started.run_id),index,1.0/60.0)
    var resting:Dictionary=s.stats()
    s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),1.0/60.0,float(resting.combat_qi_max),float(resting.combat_qi_regen)))
    s.step(1.0/60.0)
   var result := s.complete_stage_search(int(started.run_id),index)
   if not result.get("ok", false): fail("reward blocked"); return
   if s.complete_stage_search(int(started.run_id),index).get("ok",false):fail("duplicate search reward");return
   if index < 2:
    var stats := s.stats()
    s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)));s.step(9.0)
   elif result.get("chapter_reward",{}).get("item") is Dictionary:
    s.equip_item(int(result.chapter_reward.item.id))
  s.step(0.1)
 provenance.append({"target":target,"records":records,"earned_victories":s.total_victories,"final_state_valid":s._valid_save(s._snapshot())})

func fail(message: String) -> void:
 failed = true
 push_error(message)
