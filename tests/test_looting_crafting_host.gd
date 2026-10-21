extends SceneTree
## Isolated host/UI regression. Capacity/crafting states are explicit unit fixtures.
## Native HP, attack, timing and damage are never changed.
const Plan=preload("res://tests/campaign_build_plan.gd")
const State=preload("res://scripts/cultivation_state.gd")
var scene
var checks:=0
var failures:=0
var save_path:="user://loot_host_ui_%d.json"%OS.get_process_id()
func check(value:bool,label:String):
 checks+=1
 if not value:failures+=1;printerr("FAIL: "+label)
func advance(seconds:float):
 for frame in range(ceili(seconds*60.0)):scene._process(1.0/60.0)
func until(predicate:Callable,seconds:float,label:String)->bool:
 for frame in range(ceili(seconds*60.0)):
  if predicate.call():check(true,label);return true
  scene._process(1.0/60.0)
 check(false,label+" phase="+str(scene.encounter_phase));return false
func press(key:String):
 var button=scene.buttons.get(key)
 check(is_instance_valid(button) and button is BaseButton,"Control exists: "+key)
 if not is_instance_valid(button):return
 check(not button.disabled,"Control enabled: "+key)
 if not button.disabled:button.pressed.emit()
func page(tab:String):
 scene.wardrobe_tab=tab
 if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
 scene._refresh_drawer()
func snapshot()->Dictionary:
 return {"materials":scene.state.materials.to_dict(),"gear":scene.state.gear.to_dict(),"herbs":scene.state.herbs,"dew":scene.state.dew,"victories":scene.state.total_victories,"kills":scene.state.stage_status().kills}
func fixture():
 scene._close_drawer();scene.drawer_alpha=0.0;scene._reset_presentation()
 scene.state.new_game();scene.state.save_path=save_path;scene.state.auto_advance=false
 scene.demo=true;scene.state._adventure_rng.seed=61;scene.state.gear.rng.seed=110
 Plan.configure(scene.state,"guard",0)
 scene.character_x=390.0;scene.character_y=230.0;scene.meditation_amount=0.0;scene.meditation_settle=0.0
 scene._start_encounter()
func _initialize():call_deferred("run")
func run():
 scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
 await process_frame
 scene.set_process(false);scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
 fixture()
 until(func():return scene.encounter_phase=="fight",20.0,"Native route reaches first fight")
 var native_hp:float=scene.enemy_hp
 check(native_hp==float(scene.state.Content.STAGES.bamboo_pass.monsters[0].hp),"Enemy native HP is unchanged")
 var before:Dictionary=snapshot()
 until(func():return scene.encounter_phase=="pickup",90.0,"Native victory creates body")
 check(scene.enemy_hp==0.0 and scene.pickup_claimed_at<0.0,"Victory has defeated body without claimed receipt")
 check(snapshot()==before,"Victory alone grants no materials, equipment or checkpoint")
 var body:Dictionary=scene.state.stage_corpse_status().duplicate(true)
 check(bool(body.get("pending",false)) and float(body.search_seconds)==0.0,"Body keeps immutable rolled rewards and zero search progress")
 advance(.70)
 check(float(scene.state.stage_corpse_status().search_seconds)==0.0 and scene.pickup_collect_started<0.0,"Collapse interval cannot silently collect loot")
 until(func():return scene.pickup_collect_started>=0.0,8.0,"Hero walks within actual corpse search range")
 check(absf(scene.encounter_enemy_x-scene.character_x)<=36.0,"Search begins only at close body distance")
 advance(.45)
 var progress:float=scene.state.stage_corpse_status().search_seconds
 check(progress>0.0 and progress<2.0,"Actual host search advances partial two-second timer")
 scene._set_paused(true);advance(3.0)
 check(is_equal_approx(progress,float(scene.state.stage_corpse_status().search_seconds)),"Pause preserves search timer without payout")
 check(snapshot()==before,"Paused body cannot grant reward")
 scene._set_paused(false);check(scene._save_current(),"Host saves interrupted search")
 var loaded=State.new();loaded.save_path=save_path;var report:Dictionary=loaded.load_game()
 check(bool(report.get("loaded",false)),"Saved body readback succeeds")
 check(not bool(loaded.stage_status().active),"Readback remains inactive until manual continuation")
 check(is_equal_approx(float(loaded.stage_corpse_status().search_seconds),progress),"Readback retains exact partial search seconds")
 check(loaded.stage_corpse_status().rewards==body.rewards,"Readback does not reroll corpse reward")
 scene._reset_presentation();scene.state=loaded;scene.state.settings.paused=false;scene.paused=false
 advance(4.0)
 check(not scene.encounter_active and scene.state.total_victories==before.victories,"Idle readback does not auto-start or auto-claim")
 scene._start_encounter()
 until(func():return scene.encounter_phase=="pickup",6.0,"Manual resume reaches retained body without fighting again")
 check(scene.enemy_defeat==1.0 and scene.enemy_hp==0.0,"Resumed body remains visibly defeated")
 until(func():return scene.pickup_claimed_at>=0.0,8.0,"Remaining close-range search pays real reward")
 check(scene.state.total_victories==int(before.victories)+1 and int(scene.state.stage_status().kills)==1,"Claim advances exactly one victory and checkpoint")
 check(scene.state.material_count("moss_fiber")==2 and scene.state.material_count("spirit_shard")==1,"Actual searched first body awards catalog materials")
 var after:Dictionary=snapshot()
 for repeated in range(5):scene._claim_searched_corpse()
 check(snapshot()==after,"Repeated real host completion cannot duplicate any reward")
 test_capacity()
 test_craft_controls()
 scene.queue_free();await process_frame;await process_frame
 for suffix in ["",".bak",".tmp"]:
  if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
 print("Loot host/UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
func test_capacity():
 fixture()
 until(func():return scene.encounter_phase=="pickup",100.0,"Capacity case earns native victory")
 scene.state.materials.inventory.spirit_shard=scene.state.Materials.MAX_STACK
 var before:Dictionary=snapshot()
 until(func():return bool(scene.state.stage_corpse_status().get("search_ready",false)),12.0,"Full-stack body finishes actual search")
 advance(.4)
 check(scene.pickup_claimed_at<0.0 and snapshot()==before,"Full material bag atomically blocks all reward and retains body")
 check(str(scene.pickup_block_reason)=="material_full","Host exposes precise full-stack blocker")
 scene._retreat_encounter()
 until(func():return not scene.encounter_active,6.0,"Full bag can retreat safely")
 check(bool(scene.state.stage_corpse_status().get("pending",false)) and bool(scene.state.stage_corpse_status().get("search_ready",false)),"Retreat retains ready body")
 scene.state.materials.inventory.spirit_shard=0
 scene._start_encounter()
 until(func():return scene.pickup_claimed_at>=0.0,12.0,"Explicit continuation can claim after room is freed")
 check(scene.state.material_count("spirit_shard")==1 and scene.state.material_count("moss_fiber")==2,"Ready body resumes once with original complete payout")
func test_craft_controls():
 scene._retreat_encounter();until(func():return not scene.encounter_active,6.0,"Return home for controls")
 # Explicit UI fixture seeds mundane materials only, never treasure or film inventory.
 scene.state.materials.inventory={"spirit_shard":9,"moss_fiber":5}
 page("bag");press("bag_view_craft");press("craft_recipe_refine_stone")
 for count in range(3):press("craft_selected")
 check(scene.state.material_count("refinement_stone")==3 and scene.state.material_count("spirit_shard")==0,"Three actual combine clicks pay full costs and create stones")
 check(scene.buttons.craft_selected.disabled,"Insufficient materials disables repeated combine")
 var depleted:Dictionary=scene.state.materials.to_dict();scene.buttons.craft_selected.pressed.emit()
 check(scene.state.materials.to_dict()==depleted,"Even a stale disabled signal cannot overspend materials")
 press("craft_recipe_forge_sword")
 var count_before:int=scene.state.inventory.size();press("craft_selected")
 var made:int=scene.selected_item
 check(scene.state.inventory.size()==count_before+1 and not scene.state.gear.get_item(made).is_empty(),"Forge creates real owned equipment and selects its identity")
 check(scene.state.material_count("refinement_stone")==1 and scene.state.material_count("moss_fiber")==3,"Forge consumes shown exact materials")
 check(not made in scene.state.gear.equipped.values(),"Crafting does not auto-equip")
 press("craft_to_equipment");press("equip_selected")
 check(int(scene.state.gear.equipped.weapon)==made and scene.state.gear.visual_loadout().weapon=="weapon_sword","Explicit equipment click changes owned visible weapon")
 var before:Dictionary=scene.state.gear.get_item(made).duplicate(true)
 var quote:Dictionary=scene.state.enhancement_quote(made,"materials")
 check(bool(quote.can_enhance) and int(quote.after.attack)>int(quote.before.attack),"Material enhancement preview shows a real stat increase")
 press("enhance_item")
 var upgraded:Dictionary=scene.state.gear.get_item(made)
 check(int(upgraded.id)==made and int(upgraded.enhancement)==1 and int(upgraded.attack)>int(before.attack),"Enhancement retains exact instance and increases live stats")
 check(scene.state.material_count("refinement_stone")==0 and int(scene.state.gear.equipped.weapon)==made,"Enhancement spends material once and keeps item equipped")
 check(scene.buttons.enhance_item.disabled,"Insufficient next-rank stones disables enhancement")
 var paper:Rect2=scene._drawer_rect()
 for child in scene.drawer.get_children():
  if child is BaseButton:check(paper.encloses(Rect2(child.position,child.size)),"Equipment control fits paper: "+child.name)
 page("bag");press("bag_view_craft")
 for child in scene.drawer.get_children():
  if child is BaseButton:check(paper.encloses(Rect2(child.position,child.size)),"Craft control fits paper: "+child.name)
