extends "res://tests/test_battle_resource_host.gd"
## Paused return is a presentation-only request, not one unpaused simulation tick.
## Isolated state/timeline fixtures are not natural campaign or GUI evidence.
const Pages=preload("res://scripts/adventure_pages.gd")

func formal()->Dictionary:
	var result:Dictionary=scene.state._snapshot()
	result.erase("saved_at")
	return result

func live()->Array:
	return [scene.encounter_clock,scene.vitality,scene.enemy_hp,scene.duel.combat_report().duplicate(true),scene.duel._rng.state,scene.duel._enemy_rng.state,scene.battle_resources.duplicate(true),scene.state._adventure_rng.state,scene.state._journey_rng.state,scene.state.gear.rng.state]

func paper():
	scene.wardrobe_tab="expedition"
	if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
	scene._refresh_drawer()

func click_retreat():
	paper()
	check(is_instance_valid(scene.buttons.get("depart_stage")),"Actual expedition control exists")
	check(not scene.buttons.depart_stage.disabled,"Paused formal retreat control is enabled")
	scene.buttons.depart_stage.pressed.emit()

func paused_return(label:String):
	var before:Array=live()
	var distance:float=scene.route_distance
	click_retreat()
	check(scene.paused and bool(scene.state.settings.paused),label+": request keeps both global pause flags")
	check(scene.encounter_phase in ["teleport_return_out","teleport_home_in"],label+": request enters only homeward portal")
	check(not bool(scene.state.stage_status().active),label+": formal route stops before any animation")
	var after_request:Dictionary=formal()
	var after_live:Array=live()
	check(before==after_live,label+": request does not advance fight/resources/RNG")
	scene._update_encounter(.2)
	var age:float=scene.encounter_phase_age
	var phase:String=scene.encounter_phase
	for repeat in range(4):
		Pages._depart(scene,scene.encounter_run_id)
		scene._retreat_encounter()
	check(scene.encounter_phase==phase and scene.encounter_phase_age==age,label+": repeated requests never restart portal")
	check(formal()==after_request,label+": repeated requests never duplicate report/reward or change State")
	until(func():return not scene.encounter_active,4,label+": paused return reaches courtyard")
	check(scene.world_route.is_empty() and scene.encounter_phase=="idle" and scene.paused_retreat_run_id==-1,label+": settles and clears transient permission")
	check(live()==after_live and scene.route_distance==distance,label+": portal does not tick combat/HP/Qi/CD/distance/RNG")
	check(formal()==after_request,label+": cultivation/training/journey and all formal values stay frozen")
	advance(3)
	check(not scene.encounter_active and scene.paused and formal()==after_request,label+": no automatic restart or world progress at home")
	paper()
	check(scene.buttons.depart_stage.disabled,label+": global pause still blocks departure/continuation")
	var frozen:Dictionary=formal()
	Pages._depart(scene)
	check(formal()==frozen and not scene.encounter_active,label+": direct departure also remains blocked")

func run():
	save_path="user://paused_retreat_%d.json"%OS.get_process_id()
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path
	root.add_child(scene);await process_frame
	scene.set_process(false);scene.size=Vector2(1200,400)
	test_fight()
	await test_reload()
	test_travel()
	test_midroute_fight()
	test_corpses()
	test_opportunity()
	test_portal_matrix()
	test_rejection_guards()
	test_stale_run()
	test_finished_route()
	test_save_failure()
	test_practice_guards()
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Paused safe retreat: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)

func test_fight():
	fixture()
	begin_depleted_duel()
	scene.state.herbs=10000;scene.state.dew=10000
	check(bool(scene.state.upgrade_technique("mist").ok),"Actual training API creates a ticking task")
	check(bool(scene.state.start_journey("bamboo").ok),"Actual journey API creates a ticking journey")
	advance(.65)
	scene.demo=false
	scene._set_paused(true)
	var before:Array=live()
	var frozen:Dictionary=formal()
	advance(2)
	check(live()==before and formal()==frozen,"Space-style pause freezes active fight and formal world before click")
	paused_return("fight")
	check(scene.state.combat_reports.size()==1 and scene.state.combat_reports[0].outcome=="retreat","Exactly one retreat report from actual fight")
	check(is_equal_approx(float(scene.state.combat_reports[0].elapsed),float(before[3].elapsed)),"Retreat report records exact paused duel elapsed")
	check(resource_equal(scene.state.stage_battle_resources(),before[6]),"Resource flush preserves exact observed depleted qi/cooldowns")
	check(scene._save_current(),"Actual paused-home save succeeds")

func test_reload():
	var checkpoint:Dictionary=scene.state.stage_run.duplicate(true)
	var expected:Array=live()
	var restored=load("res://main.tscn").instantiate();restored.state.save_path=save_path
	root.add_child(restored);await process_frame;restored.set_process(false)
	check(restored.paused and bool(restored.state.settings.paused),"Fresh host reload restores global pause")
	check(not restored.encounter_active and restored.world_route.is_empty(),"Fresh host reload starts at home without encounter")
	check(restored.state.stage_run==checkpoint and bool(restored.state.stage_status().paused),"Fresh host reload retains exact inactive route checkpoint")
	check(resource_equal(restored.state.stage_battle_resources(),expected[6]),"Fresh host reload retains qi/cooldowns")
	var before:Dictionary=restored.state._snapshot();before.erase("saved_at")
	for i in range(30):restored._process(.1)
	var after:Dictionary=restored.state._snapshot();after.erase("saved_at")
	check(before==after and not restored.encounter_active,"Reload cannot restart or accumulate offline/world time while paused")
	restored.queue_free();await process_frame

func test_travel():
	fixture();advance(.4);scene._set_paused(true)
	paused_return("travel")
	check(scene.state.combat_reports.is_empty(),"Travel return cannot fabricate a combat report")

func test_midroute_fight():
	fixture();advance_state_enemy(0)
	scene._prepare_stage_monster();begin_depleted_duel();advance(.35)
	scene._set_paused(true);paused_return("second enemy after 1/3")
	check(int(scene.state.stage_run.kills)==1 and scene.state.total_victories==1,"Paused second-enemy return retains one-of-three earned checkpoint")
	check(scene.state.combat_reports.size()==1 and scene.state.combat_reports[0].outcome=="retreat","Only the actual second-enemy fight creates a retreat report")

func test_corpses():
	for capacity in [false,true]:
		fixture();begin_depleted_duel(1)
		until(func():return scene.encounter_phase=="pickup",15,"Actual victory creates an owned corpse")
		if capacity:scene.state.materials.inventory.spirit_shard=scene.state.Materials.MAX_STACK
		until(func():return scene.pickup_collect_started>=0,10,"Actual host reaches corpse search position")
		advance(2.3 if capacity else .45)
		var body:Dictionary=scene.state.stage_corpse_status().duplicate(true)
		check(not body.is_empty() and float(body.search_seconds)>0,"Corpse has real search progress")
		check(bool(body.search_ready)==capacity,"Partial and capacity-full search fixtures are distinct")
		if capacity:check(scene.pickup_block_reason=="material_full" and scene.pickup_claimed_at<0,"Capacity branch retains unclaimed ready corpse")
		var held:Dictionary=scene.get_meta("capacity_corpse_hold",{}).duplicate(true)
		var reports:Array=scene.state.combat_reports.duplicate(true)
		scene._set_paused(true);paused_return("capacity corpse" if capacity else "partial corpse")
		check(scene.state.stage_corpse_status()==body,"Return preserves exact corpse owner/reward/search seconds")
		check(scene.get_meta("capacity_corpse_hold",{})==held,"Return preserves capacity's explicit-claim token")
		check(scene.state.combat_reports==reports,"Pickup return adds no retreat report after victory")
		check(scene._save_current(),"Owned corpse paused-home save succeeds")
		var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
		# Runtime equality above is exact. Across disk, compare the same canonical
		# JSON representation used by the existing save serializer (decimal floats).
		check(JSON.stringify(loaded.stage_corpse_status())==JSON.stringify(body) and bool(loaded.settings.paused),"Reload preserves canonical saved corpse with global pause")

func advance_state_enemy(index:int):
	var id:int=scene.encounter_run_id
	check(bool(scene.state.begin_stage_corpse(id,index).get("ok",false)),"State fixture supplies actual defeat receipt index="+str(index))
	check(bool(scene.state.advance_stage_search(id,index,2).get("ok",false)),"State fixture completes actual search index="+str(index))
	return scene.state.complete_stage_search(id,index)

func test_opportunity():
	fixture()
	advance_state_enemy(0);advance_state_enemy(1)
	# Fixed RNG seed is an explicit fixture, not a claim about natural odds.
	var chance_rng=RandomNumberGenerator.new()
	for seed_value in range(100):
		chance_rng.seed=seed_value
		if chance_rng.randf()<scene.state.Content.OPPORTUNITY_CHANCE:
			scene.state._adventure_rng.seed=seed_value;break
	var result:Dictionary=scene.state.check_route_opportunity(scene.encounter_run_id)
	check(bool(result.get("opportunity_pending",false)),"Seeded actual checkpoint creates pending opportunity")
	scene.encounter_index=2;scene.encounter_phase="opportunity"
	var token:Dictionary=scene.state.pending_opportunity.duplicate(true)
	scene._set_paused(true);paused_return("opportunity")
	check(scene.state.pending_opportunity==token,"Pending opportunity token/choice remains exact and unconsumed")
	check(scene._save_current(),"Pending opportunity save succeeds")
	var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
	check(loaded.pending_opportunity==token and bool(loaded.settings.paused),"Pending opportunity reload remains paused and unchosen")

func test_portal_matrix():
	for phase in ["prepare_portal","teleport_out","teleport_arrive","teleport_return_out","teleport_home_in"]:
		fixture()
		scene.encounter_phase=phase;scene.encounter_phase_age=.4
		if phase in ["prepare_portal","teleport_out","teleport_home_in"]:scene.world_route=""
		if phase in ["prepare_portal","teleport_out"]:scene.meditation_amount=1.0
		if phase in ["teleport_return_out","teleport_home_in"]:scene.state.pause_stage(scene.encounter_run_id)
		scene._set_paused(true)
		var before:Dictionary=formal()
		advance(2)
		check(scene.encounter_phase==phase and scene.encounter_phase_age==.4,phase+": ordinary pause freezes every portal without explicit request")
		check(formal()==before,phase+": ordinary paused portal never progresses State")
		paused_return(phase)
		check(scene.state.combat_reports.is_empty(),phase+": portal return adds no report")
	# Resuming global time consumes the special permission; pausing again is ordinary.
	fixture();scene._set_paused(true);scene._retreat_encounter();scene._update_encounter(.2)
	scene._set_paused(false);scene._set_paused(true)
	var age:float=scene.encounter_phase_age
	advance(.3)
	check(scene.paused_retreat_run_id==-1 and scene.encounter_phase_age==age,"Explicit global resume invalidates old paused-return permission")
	scene._reset_presentation();check(scene.paused_retreat_run_id==-1,"Reset clears transient return permission")

func test_rejection_guards():
	for guard in ["closing","update_transaction","tree"]:
		fixture();begin_depleted_duel();scene._set_paused(true)
		scene.demo=false;check(scene._save_current(),guard+": precondition disk save")
		var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save_path)
		if guard=="closing":scene.closing=true
		elif guard=="update_transaction":scene.set_meta("update_transaction",true)
		else:paused=true
		var before:Dictionary=formal();var observed:Array=live()
		check(not scene._can_retreat_encounter(),guard+": host rejects unsafe request")
		scene._retreat_encounter();Pages._depart(scene)
		check(formal()==before and live()==observed and scene.encounter_phase=="fight",guard+": host and direct page calls are formal no-ops")
		check(FileAccess.get_file_as_bytes(save_path)==bytes,guard+": no disk overwrite")
		check(scene.paused_retreat_run_id==-1,guard+": cannot authorize portal")
		scene.closing=false;scene.set_meta("update_transaction",false);paused=false
		# Existing permission also cannot animate through a transaction freeze.
		scene._retreat_encounter();var age:float=scene.encounter_phase_age
		if guard=="closing":scene.closing=true
		elif guard=="update_transaction":scene.set_meta("update_transaction",true)
		else:paused=true
		scene._update_encounter(.5)
		check(scene.encounter_phase_age==age,guard+": no previously-authorized portal progress while frozen")
		scene.closing=false;scene.set_meta("update_transaction",false);paused=false

func test_stale_run():
	fixture();begin_depleted_duel();scene._set_paused(true)
	var real_id:int=scene.encounter_run_id
	scene.encounter_run_id+=1
	var before:Dictionary=formal();var observed:Array=live()
	scene._retreat_encounter();Pages._depart(scene)
	check(formal()==before and live()==observed and scene.encounter_phase=="fight","Wrong host run never records report/cancels duel/pauses newer run")
	scene.encounter_run_id=real_id
	Pages._depart(scene,real_id-1)
	check(formal()==before and live()==observed,"Old control's captured run cannot affect current formal encounter")
	paper();var old_button=scene.buttons.depart_stage
	scene._refresh_drawer();old_button.pressed.emit()
	check(formal()==before and live()==observed,"Detached old button signal cannot retreat an encounter")
	scene._retreat_encounter();scene._update_encounter(.2)
	scene.state.stage_run.run_id+=1
	var age:float=scene.encounter_phase_age
	scene._update_encounter(.5)
	check(scene.encounter_phase_age==age,"Transient permit cannot advance a different State run")
	scene._reset_presentation();scene.state.new_game();scene._set_paused(true)
	before=formal();scene._retreat_encounter();Pages._depart(scene)
	check(formal()==before and not scene.encounter_active,"Idle paused direct callbacks are no-ops")

func test_finished_route():
	for ending_phase in ["pickup","teleport_return_out","teleport_home_in"]:
		fixture();advance_state_enemy(0);advance_state_enemy(1)
		var opportunity:Dictionary=scene.state.check_route_opportunity(scene.encounter_run_id)
		if bool(opportunity.get("opportunity_pending",false)):scene.state.choose_opportunity("gather_gift")
		scene.encounter_index=2;scene.encounter_phase="pickup";scene.encounter_phase_age=2.5
		check(bool(scene.state.begin_stage_corpse(scene.encounter_run_id,2).get("ok",false)),"Final fixture creates real owned boss corpse")
		scene.state.advance_stage_search(scene.encounter_run_id,2,2)
		scene._claim_searched_corpse()
		check(scene.state.stage_run.is_empty() and bool(scene.encounter_reward.get("stage_finished",false)),"Final host claim atomically clears run and owns final receipt")
		check(scene.encounter_first_clear,"Final fixture is actual first chapter clear")
		if ending_phase!="pickup":scene.encounter_complete=true;scene.encounter_phase=ending_phase
		if ending_phase=="teleport_home_in":scene.world_route=""
		var claimed:Dictionary=scene.state.chapter_reward_claimed.duplicate(true)
		scene._set_paused(true);paused_return("finished "+ending_phase)
		check(scene.encounter_complete and scene.encounter_first_clear,"Final paused return retains completion semantics")
		check(scene.state.chapter_reward_claimed==claimed and scene.state.stage_run.is_empty(),"Final paused return cannot duplicate reward or recreate stage run")
		check(scene.toast.contains("此章已解"),"Final home arrival still presents chapter-clear notice")

func test_save_failure():
	fixture();begin_depleted_duel();scene._set_paused(true)
	scene.demo=false;scene.state.save_path="user://absent_paused_retreat_%d/save.json"%OS.get_process_id()
	click_retreat()
	check(scene.toast.contains("无法写入"),"Request save failure is visible, never overwritten by return success")
	var warning:String=scene.toast
	scene._retreat_encounter()
	check(scene.toast==warning,"Repeat return does not overwrite a pending save warning")
	until(func():return not scene.encounter_active,4,"Even failed save does not require unpausing to reach home")
	check(scene.toast.contains("无法写入") and scene.paused and bool(scene.state.settings.paused),"Home final save failure remains visible and paused")
	scene.state.save_path=save_path
	check(scene._save_current(),"Explicit normal save can recover after write access returns")

func test_practice_guards():
	for trial in ["running","paused","finished"]:
		scene._close_drawer();scene._reset_presentation();scene.state.new_game();scene.state.save_path=save_path;scene.demo=false
		scene._set_paused(true)
		check(scene.start_practice("bamboo_sprite"),"Trial fixture starts: "+trial)
		if trial=="paused":scene.toggle_practice_pause()
		elif trial=="finished":
			for i in range(1300):scene._process(.1)
			check(bool(scene.practice_session.status().finished),"Actual trial reaches result")
		var before:Dictionary=formal();var observed:Array=live();var bytes:PackedByteArray=FileAccess.get_file_as_bytes(save_path)
		var trial_status:Dictionary=scene.practice_session.status().duplicate(true)
		check(not scene._can_retreat_encounter(),"Trial cannot claim formal return authority: "+trial)
		scene._retreat_encounter();Pages._depart(scene)
		check(formal()==before and live()==observed,"Trial callback leaves complete formal snapshot and both RNGs exact: "+trial)
		check(scene.practice_session.status()==trial_status and scene.practice_session!=null,"Formal retreat cannot cancel/advance trial: "+trial)
		check(FileAccess.get_file_as_bytes(save_path)==bytes,"Trial callback cannot write formal disk: "+trial)
		scene.end_practice()
