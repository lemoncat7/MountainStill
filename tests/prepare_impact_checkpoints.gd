extends SceneTree
## Creates review checkpoints through real deterministic duels and paid growth.
## Never injects HP, realms, resources, victories, items, or free skill levels.
const State=preload('res://scripts/cultivation_state.gd')
const Duel=preload('res://scripts/duel_timeline.gd')
const Plan=preload('res://tests/campaign_build_plan.gd')
var folder:='user://impact-proof'
var records:Array=[]
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--output='):folder=arg.trim_prefix('--output=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder))
 var state:=State.new();state._adventure_rng.seed=61;state.gear.rng.seed=110
 var initial:Dictionary=state.open_chest()
 if initial.get('item') is Dictionary:state.equip_item(int(initial.item.id))
 Plan.configure(state,'sword',0)
 # The early character has no sword yet. Use the normal loadout operation
 # rather than presenting a knowingly incompatible sword art in the slice.
 if str(state.gear.visual_loadout().get('weapon','')).is_empty():
  state.unequip_technique('mist','weapon_art')
 for chapter in range(3):
  var route:String=state.Content.CHAPTER_ORDER[chapter]
  if not state.select_stage(route):fail('locked '+route);return
  var started:Dictionary=state.start_stage()
  if not started.get('ok',false):fail('could not depart '+route);return
  var health:=int(state.stats().max_hp)
  for index in range(3):
   if index==2:
    state.check_route_opportunity(int(started.run_id))
    if state.stage_status().opportunity_pending:state.choose_opportunity('gather_gift')
   if (chapter==0 and index==1) or (chapter==2 and index==2):
    var checkpoint:Dictionary=state._snapshot()
    checkpoint.settings.paused=true
    var file:=FileAccess.open(folder+'/'+route+'-checkpoint.json',FileAccess.WRITE)
    if file==null:fail('checkpoint write');return
    file.store_string(JSON.stringify(checkpoint,'\t'));file.close()
    print('EARNED_CHECKPOINT '+route+' victories='+str(state.total_victories)+' realm='+str(state.realm))
   var hero:Dictionary=state.stats().duplicate(true);hero.hp=health;hero.battle_resources=state.stage_battle_resources()
   var enemy:Dictionary=Plan.prepare_enemy(state.stage_status().next_monster,route)
   var duel:=Duel.new();duel.start(hero,enemy,state.technique,str(state.gear.visual_loadout().get('weapon','')),int(started.run_id)*1337+index*79+17)
   while not duel.finished and duel.elapsed<150.0:duel.advance(.1);state.step(.1)
   if not duel.victory:fail('lost '+route+':'+str(index));return
   records.append({'route':route,'index':index,'hero':hero,'enemy':enemy,'seconds':duel.elapsed,'hp_end':duel.hero_hp,'victory':duel.victory})
   state.update_stage_battle_resources(int(started.run_id),duel.battle_resource_snapshot());health=duel.hero_hp
   var result:Dictionary=state.defeat_stage_monster(int(started.run_id),index)
   if not result.get('ok',false):fail('reward failed');return
   if index<2:
    var stats:Dictionary=state.stats()
    state.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(state.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)));state.step(9.0)
   elif result.get('chapter_reward',{}).get('item') is Dictionary:state.equip_item(int(result.chapter_reward.item.id))
  state.step(.1);Plan.configure(state,'sword',chapter+1);Plan.buy_affordable_meridians(state)
 var report:=FileAccess.open(folder+'/provenance.json',FileAccess.WRITE)
 report.store_string(JSON.stringify({'records':records,'sources':Plan.measurement_metadata(),'wins':state.total_victories,'adventure_seed':61,'starter_gear_seed':110,'early_incompatible_art_normally_unequipped':true},'\t'));report.close()
 print('CHECKPOINTS_READY actual_wins='+str(state.total_victories));quit()
func fail(reason:String):push_error(reason);quit(1)
