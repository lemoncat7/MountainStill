extends SceneTree
## Pointer-level integration: current production hit regions, not pressed.emit.
## Fresh play and reload use an isolated save. Later pages are inspected only;
## no materials, progression, wins, equipment or manual ranks are injected.
const Journey = preload("res://scripts/player_journey_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://player_journey_pointer_%d.json" % OS.get_process_id()
var pointer_actions: Array[Dictionary] = []
var capture_dir := ""

func _initialize():call_deferred("run")

func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;push_error("FAIL: "+label)

func snapshot()->Dictionary:
	return {"realm":scene.state.realm,"qi":scene.state.qi,"herbs":scene.state.herbs,"dew":scene.state.dew,"chests":scene.state.chest_count,"gear":scene.state.gear.to_dict(),"materials":scene.state.materials.to_dict(),"manuals":scene.state.technique_levels.duplicate(),"training":scene.state.technique_training.duplicate(true),"meridians":scene.state.meridian_rows(),"route":scene.state.stage_run.duplicate(true),"selected_stage":scene.state.selected_stage,"clears":scene.state.stage_clears.duplicate(),"quest_claimed":scene.state.quest_claimed.duplicate(),"auto":scene.state.auto_advance}

func settle(seconds:float=.34):
	await create_timer(seconds).timeout
	if is_instance_valid(scene):scene._sync_drawer_visuals();scene._update_hotspots()

func click(key:String):
	await settle()
	var control=scene.buttons.get(key)
	for _wait in range(20):
		if not is_instance_valid(control) or control.mouse_filter!=Control.MOUSE_FILTER_IGNORE:break
		await settle(.1);control=scene.buttons.get(key)
	check(is_instance_valid(control),"Pointer target exists: "+key)
	if not is_instance_valid(control):return
	check(control.is_visible_in_tree() and not control.disabled,"Pointer target visible and enabled: "+key)
	check(control.mouse_filter!=Control.MOUSE_FILTER_IGNORE,"Pointer target accepts input: "+key)
	if control.disabled or not control.is_visible_in_tree():return
	var rect:Rect2=control.get_global_rect()
	var at:Vector2=rect.get_center()
	check(root.get_visible_rect().has_point(at),"Pointer target inside viewport: "+key)
	var serial:int=scene.interaction_serial
	var motion:=InputEventMouseMotion.new();motion.position=at;motion.global_position=at
	root.push_input(motion,true)
	var down:=InputEventMouseButton.new();down.position=at;down.global_position=at;down.button_index=MOUSE_BUTTON_LEFT;down.button_mask=MOUSE_BUTTON_MASK_LEFT;down.pressed=true
	root.push_input(down,true)
	var up:=InputEventMouseButton.new();up.position=at;up.global_position=at;up.button_index=MOUSE_BUTTON_LEFT;up.pressed=false
	root.push_input(up,true)
	await process_frame
	pointer_actions.append({"button":key,"x":at.x,"y":at.y})
	if key not in ["practice","wardrobe","settings","garden","alchemy","companion"]:check(scene.interaction_serial==serial+1,"One pointer click invokes one production action: "+key)

func simulate(seconds:float):
	# Test-only waiting advances the unchanged production loop in 1/60s ticks.
	# It never edits resource balances, rank, rates, HP, drops or clock settings.
	for _tick in range(ceili(seconds*60.0)):scene._process(1.0/60.0)

func geometry(label:String):
	var paper:Rect2=scene._drawer_rect()
	var prior:Array=[]
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect:=Rect2(child.position,child.size)
			check(paper.encloses(rect),"Target stays on paper: "+label+" / "+child.text)
			for other in prior:check(not rect.intersects(Rect2(other.position,other.size)),"No target overlap: "+label+" / "+child.text)
			prior.append(child)

func capture(name:String):
	if capture_dir.is_empty() or DisplayServer.get_name()=="headless":return
	await settle(.8);scene.queue_redraw();await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(capture_dir.path_join(name+".png"))

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--captures="):capture_dir=arg.trim_prefix("--captures=");DirAccess.make_dir_recursive_absolute(capture_dir)
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame
	scene.set_process(false);scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
	scene._build_nav();scene._update_hotspots()
	check(not scene.state.auto_advance and scene.state.realm==0 and scene.state.gear.inventory.is_empty(),"Fresh run starts manual with actual empty inventory")
	await click("practice");await settle(.8)
	check(scene.drawer_name=="practice","Stone pointer opens actual journal")
	await click("journal_guide")
	check(Journey.rows(scene).size()==8,"Eight-phase finite roadmap replaces five-minute-only guide")
	var before:Dictionary=snapshot()
	await capture("first-arrival-guide")
	var first_goal:String=str(Journey.status(scene).id)
	var old_skip=scene.buttons.get("guide_journey_skip")
	await click("guide_journey_skip")
	check(snapshot()==before and str(Journey.status(scene).id)!=first_goal,"Skipping optional advice changes no earned state and creates no hard gate")
	var skipped:Dictionary=scene.state.journey_skipped.duplicate()
	if is_instance_valid(old_skip):old_skip.pressed.emit()
	check(scene.state.journey_skipped==skipped,"Stale skip callback cannot dismiss another live suggestion")
	await click("guide_restart")
	check(scene.state.journey_skipped.is_empty() and str(Journey.status(scene).id)==first_goal and snapshot()==before,"Re-reading guide restores advice without resetting progress")
	for i in range(8):
		await click("guide_step_%d"%i);geometry("Roadmap %d"%i)
	check(snapshot()==before,"Browsing all roadmap phases is read-only")
	await click("guide_recommend");await click("guide_action")
	check(scene.drawer_name=="wardrobe" and scene.wardrobe_tab=="equipment","Live first recommendation opens true equipment page")
	check(snapshot()==before,"First recommendation neither opens chest nor equips")
	await click("first_chest")
	check(scene.state.gear.inventory.size()==1 and scene.state.chest_count==0,"First chest pointer creates one actual owned item")
	var item:int=scene.selected_item
	await click("equip_selected")
	check(item in scene.state.gear.equipped.values(),"Separate equip pointer wears actual starter item")
	await capture("earned-starter-equipped")
	await settle()
	var method_button:Button=scene.buttons.enhancement_method
	check(is_equal_approx(method_button.size.y,14.0),"Transparent enhancement-material hit region keeps its exact authored 14px height")
	check(not method_button.get_global_rect().intersects(scene.buttons.enhance_item.get_global_rect()),"Material selector never overlaps the enhancement action")
	before=snapshot()
	await click("enhancement_method")
	check(str(scene.get_meta("enhancement_method","herbs"))=="materials" and snapshot()==before,"Centered real pointer switches to materials without performing an enhancement")
	await click("enhancement_method")
	check(str(scene.get_meta("enhancement_method","herbs"))=="herbs" and snapshot()==before,"Repeated centered pointer switches back to herbs without spending")
	before=snapshot()
	await click("drawer_close");await settle(.8);await click("practice");await settle(.8);await click("journal_guide")
	check(snapshot()==before,"Closing and reopening guide preserves earned state")
	await click("guide_idle")
	check(str(scene.get_meta("ink_journal_tab"))=="practice" and not scene.state.auto_advance,"Peaceful route link opens practice without secretly toggling automatic growth")
	check(scene.buttons.breakthrough.text.contains(scene.state.next_realm_name()),"Actual breakthrough names the destination realm")
	check(scene.buttons.breakthrough.tooltip_text.contains("突破后"),"Actual breakthrough previews its unlocks")
	await capture("first-practice-next-step")
	await click("practice_auto");check(scene.state.auto_advance,"Actual opt-in enables peaceful automation")
	await click("practice_auto");check(not scene.state.auto_advance,"Repeated opt-in toggle remains reversible")
	Journey.navigate(scene,"technique","breath");await settle(.8)
	before=snapshot();check(str(scene.get_meta("ink_technique_id"))=="breath","Manual link selects exact real manual")
	check(scene.state.equipped_heart.is_empty(),"Reading breath leaves the heart slot untouched")
	await click("manual_slot_heart");check(scene.state.equipped_heart.is_empty(),"Heart pointer first previews actual first-use quote")
	await capture("first-heart-confirmation")
	await click("confirm_heart_switch");check(scene.state.equipped_heart=="breath","Separate confirm installs actual first free heart")
	# Earn the first paid lesson's inputs through the real gathering activity.
	Journey.navigate(scene,"practice");await settle(.8);await click("activity_gather")
	simulate(50.0)
	check(scene.state.herbs>=9 and scene.state.dew>=3,"Normal gathering ticks earn lesson and first meridian materials")
	Journey.navigate(scene,"technique","mist");await settle(.8)
	var herbs_before:int=scene.state.herbs
	var dew_before:int=scene.state.dew
	var old_train=scene.buttons.train_technique
	await click("train_technique")
	check(scene.state.herbs==herbs_before-6 and scene.state.dew==dew_before-2,"Paid first lesson charges its actual displayed six grass and two dew")
	check(scene.state.technique_levels.mist==1 and scene.state.technique_training.size()==1,"Paid lesson starts a real timer without granting rank early")
	simulate(3.0)
	var remaining:float=float(scene.state.technique_training[0].remaining)
	var charged_herbs:int=scene.state.herbs
	var charged_dew:int=scene.state.dew
	check(scene.state.save_game(),"Interrupted paid lesson saves")
	if is_instance_valid(old_train):old_train.pressed.emit()
	check(scene.state.herbs==charged_herbs and scene.state.dew==charged_dew,"Stale training button cannot charge a second time")
	scene.queue_free();await process_frame;await process_frame
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene);await process_frame
	scene.set_process(false);scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
	check(scene.state.technique_training.size()==1 and scene.state.technique_levels.mist==1,"Reload keeps the paid lesson in progress")
	if scene.state.technique_training.size()==1:
		check(float(scene.state.technique_training[0].remaining)<=remaining+.1,"Reload does not restart the paid timer from its full duration")
		simulate(float(scene.state.technique_training[0].remaining)+.1)
	check(scene.state.technique_levels.mist==2 and int(scene.state.counters.techniques_trained)==1,"Resumed production timer completes precisely one learned rank")
	Journey.navigate(scene,"practice");await settle(.8);await click("activity_meditate")
	simulate(maxf(0.0,(30.0-scene.state.qi)/scene.state.qi_rate())+.1)
	var quote_before:Dictionary=snapshot()
	Journey.navigate(scene,"meridian","qihai");await settle(.8);geometry("Exact meridian link")
	check(str(scene.get_meta("meridian_id"))=="qihai" and snapshot()==quote_before,"Meridian link is exact and never purchases")
	var qi_before:float=scene.state.qi
	herbs_before=scene.state.herbs;dew_before=scene.state.dew
	await click("unlock_meridian")
	check(scene.state.meridian_count==1 and absf(scene.state.qi-(qi_before-30.0))<.01 and scene.state.herbs==herbs_before-3 and scene.state.dew==dew_before-1,"First actual meridian control charges exactly its earned resources")
	Journey.navigate(scene,"practice");await settle(.8);await click("activity_gather")
	simulate(48.1)
	await click("activity_meditate")
	simulate(maxf(0.0,(float(scene.state.stats().need_qi)-scene.state.qi)/scene.state.qi_rate())+.1)
	check(scene.state.realm==0 and not scene.buttons.breakthrough.disabled,"Ready first breakthrough waits for the player's real control")
	qi_before=scene.state.qi;herbs_before=scene.state.herbs
	await capture("paid-growth-before-breakthrough")
	await click("breakthrough")
	check(scene.state.realm==1 and absf(scene.state.qi-(qi_before-120.0))<.01 and scene.state.herbs==herbs_before-6,"First breakthrough pointer spends published cost and advances one realm")
	check(scene.state.technique_levels.mist==2 and scene.state.meridian_count==1,"Breakthrough preserves genuinely learned manual and meridian")
	quote_before=snapshot()
	Journey.navigate(scene,"crafting","bind_cloud_fan");await settle(.8);geometry("Exact locked recipe")
	check(str(scene.get_meta("craft_recipe"))=="bind_cloud_fan" and scene.buttons.craft_selected.disabled,"Late recipe link opens actual locked second-leaf recipe")
	check(snapshot()==quote_before,"Reading recipe never manufactures or unlocks it")
	await capture("future-recipe-readable")
	Journey.navigate(scene,"route","creek_bridge");await settle(.8);geometry("Locked chapter link")
	check(scene.buttons.depart_stage.disabled and not scene.encounter_active,"Locked chapter link remains an explicit gated departure")
	check(snapshot()==quote_before,"Chapter inspection never selects state route or starts it")
	Journey.navigate(scene,"route","bamboo_pass");await settle(.8)
	await click("depart_stage")
	check(scene.encounter_active and bool(scene.state.stage_status().active),"Manual pointer alone starts first stage")
	# A deliberate return before travel is an authentic unfinished checkpoint.
	if scene.drawer_name.is_empty():Journey.navigate(scene,"route","bamboo_pass");await settle(.8)
	await click("depart_stage")
	scene.set_process(true);await settle(3.0);scene.set_process(false)
	check(not scene.encounter_active and bool(scene.state.stage_status().paused),"Same route control explicitly returns with a checkpoint")
	before=snapshot();check(scene.state.save_game(),"Interrupted state saves")
	var run_id:int=int(scene.state.stage_status().run_id)
	scene.queue_free();await process_frame;await process_frame
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene);await process_frame
	scene.set_process(false);scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
	check(not scene.encounter_active and bool(scene.state.stage_status().paused) and int(scene.state.stage_status().run_id)==run_id,"Reload remains at home with same unpaid continuation token")
	check(item in scene.state.gear.equipped.values() and scene.state.equipped_heart=="breath","Reload preserves explicitly equipped starter and heart")
	Journey.navigate(scene,"route","bamboo_pass");await settle(.8)
	check(scene.buttons.depart_stage.text=="继续此程","Reload exposes concrete manual continuation")
	await capture("saved-manual-continuation")
	await click("depart_stage")
	check(scene.encounter_active and int(scene.state.stage_status().run_id)==run_id,"Continuation pointer resumes same run exactly once")
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);scene.get_window().size=Vector2i(width,320)
		scene.set_meta("ink_journal_tab","guide");scene.set_meta("ink_guide_follow_current",true)
		if scene.drawer_name=="practice":scene._refresh_drawer()
		else:scene._toggle_drawer("practice")
		await settle(.8);geometry("Guide width %d"%width)
		await click("guide_recommend")
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Player journey pointer audit: %d checks, %d failures; %d actual pointer targets"%[checks,failures,pointer_actions.size()])
	quit(1 if failures else 0)
