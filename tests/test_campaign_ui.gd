extends SceneTree
## Actual paper controls exercise the saved campaign; no production save is read.
const State=preload("res://scripts/cultivation_state.gd")
const Ink=preload("res://scripts/ink_pages.gd")
var checks:int=0
var failures:int=0
var scene
var save_path:String="user://campaign_ui_%d.json"%OS.get_process_id()

func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)

func press(key:String):
	var button=scene.buttons.get(key)
	check(is_instance_valid(button) and button is BaseButton,"Control exists: "+key)
	if not is_instance_valid(button):return
	check(not button.disabled,"Control enabled: "+key)
	if not button.disabled:button.pressed.emit()

func inspect_manual(id:String):
	press("tech_category_all")
	var rows:Array=scene.state.technique_rows()
	var index:int=0
	for i in range(rows.size()):
		if str(rows[i].id)==id:index=i;break
	for _i in range(index/Ink.MANUALS_PER_PAGE):press("tech_next")
	press("equip_"+id)

func complete_training():
	var seconds:float=0.0
	for job in scene.state.technique_training:seconds=maxf(seconds,float(job.remaining))
	scene.state.step(seconds+0.1);scene._refresh_drawer()

func open_page(id:String):
	if scene.drawer_name!=id:scene._toggle_drawer(id)
	scene._refresh_drawer()

func geometry(label:String):
	var paper:Rect2=scene._drawer_rect()
	check(paper.position.x>=0 and paper.end.x<=scene.size.x,"Paper fits 1000px: "+label)
	for child in scene.drawer.get_children():
		if child is BaseButton:
			var rect:Rect2=Rect2(child.position,child.size)
			check(paper.encloses(rect),"Control fits paper: "+label+" / "+child.text)

func cleanup():
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)

func _initialize():call_deferred("run")

func run():
	cleanup()
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.get_window().size=Vector2i(1000,320)
	scene.size=Vector2(1000,320)
	scene.state.new_game()
	scene.set_meta("ink_journal_tab","practice")
	scene.state.auto_advance=false

	# Ten books are paged by overlapping tags; inspection never equips a slot.
	open_page("wardrobe");press("wardrobe_technique");geometry("Manual categories")
	for category in Ink.MANUAL_FILTERS:check(is_instance_valid(scene.buttons.get("tech_category_"+str(category))),"Manual filter present: "+str(category))
	inspect_manual("petal")
	check(scene.state.equipped_weapon_art=="mist","Locked book does not replace active weapon form")
	check(scene.buttons.train_technique.disabled,"Locked technique cannot be trained")
	scene.state.realm=State.MAX_REALM;scene.state.herbs=10000;scene.state.dew=10000;scene._refresh_drawer()
	inspect_manual("petal")
	check(scene.state.equipped_weapon_art=="mist","Untrained inspection leaves form unchanged")
	press("train_technique")
	check(scene.state.technique_levels.petal==0 and not scene.state.technique_training.is_empty(),"First lesson has a real timer")
	complete_training()
	check(scene.state.technique_levels.petal==1 and scene.state.equipped_weapon_art=="mist","Finished lesson learns without auto-equipping")
	press("manual_slot_weapon_art")
	check(scene.state.equipped_weapon_art=="petal" and scene.state.gather_multiplier()>1,"Explicit petal form retains gathering utility")
	inspect_manual("mist");press("manual_slot_weapon_art")
	check(is_equal_approx(scene.state.gather_multiplier(),1),"Replacing form removes prior utility if absent elsewhere")
	for id in ["petal","ember","stillness"]:
		inspect_manual(id)
		for _rank in range(int(scene.state.Content.TECHNIQUES[id].max_level)):
			if int(scene.state.technique_levels[id])>=int(scene.state.Content.TECHNIQUES[id].max_level):break
			if scene.buttons.train_technique.disabled:check(false,"Expected available training: "+id);break
			press("train_technique");complete_training()
		check(scene.buttons.train_technique.disabled,"Per-book max level disables training: "+id)
		check(int(scene.state.technique_levels[id])==int(scene.state.Content.TECHNIQUES[id].max_level),"Distinct rank cap reached: "+id)
	inspect_manual("ember");press("manual_slot_active")
	check(scene.state.equipped_actives.has("ember") and scene.state.brew_multiplier()>1,"Explicit active spell retains alchemy utility")
	check(not scene.encounter_active and not scene.state.expedition_auto,"Training never starts battle")

	scene.state.realm=4
	# Inspect, equip, enhance and remove a concrete owned instance.
	press("wardrobe_equipment");press("first_chest");press("item_0")
	var item_id:int=scene.selected_item
	var item:Dictionary=scene.state.gear.get_item(item_id)
	press("equip_selected")
	var before_cost:Dictionary=scene.state.gear.enhancement_cost(item_id)
	var herbs_before:int=scene.state.herbs
	var dew_before:int=scene.state.dew
	press("enhance_item")
	check(scene.state.gear.get_item(item_id).enhancement==1,"Enhancement control modifies selected owned item")
	check(scene.state.herbs==herbs_before-int(before_cost.herbs) and scene.state.dew==dew_before-int(before_cost.dew),"Enhancement pays exact shown materials")
	check(int(scene.state.gear.equipped.get(item.slot,-1))==item_id,"Enhancement retains equipped identity")
	for _i in range(4):press("enhance_item")
	check(scene.buttons.enhance_item.disabled,"Maximum enhancement disables action")
	press("unequip_slot")
	check(scene.state.gear.equipped_item(item.slot).is_empty(),"Enhanced item can be unequipped")
	geometry("Equipment enhancement")

	# Journey choices are inspectable while locked; repeat is deliberate.
	press("wardrobe_adventure");geometry("Journeys")
	scene.state.realm=0;scene._refresh_drawer()
	press("journey_ridge")
	check(scene.buttons.journey_dispatch.disabled,"Locked journey cannot dispatch")
	press("journey_bamboo");press("journey_dispatch")
	check(bool(scene.state.journey_status().active),"Dispatch starts actual journey")
	check(scene.buttons.journey_dispatch.disabled,"Active journey cannot be duplicated")
	check(not scene.encounter_active and not scene.state.expedition_auto,"Journey leaves combat opt-in")
	var signature_before:String=Ink.state_signature(scene)
	scene.state.step(300);scene._refresh_drawer()
	check(scene.state.journey_completed==1 and not bool(scene.state.journey_status().active),"One-off journey returns exactly once")
	check(scene.state.journey_bond>0 and not scene.state.journey_last_result.is_empty(),"Return credits bond and actual outcome")
	check(Ink.state_signature(scene)!=signature_before,"Return changes button refresh signature")
	press("journey_repeat");press("journey_dispatch")
	scene.state.step(300);scene._refresh_drawer()
	check(scene.state.journey_completed==2 and bool(scene.state.journey_status().active),"Opt-in repeat dispatches same journey after return")
	press("journey_repeat")
	scene.state.step(300);scene._refresh_drawer()
	check(scene.state.journey_completed==3 and not bool(scene.state.journey_status().active),"Turning repeat off lets current trip finish once")
	check(scene.state.chest_count>=1,"Three journeys award an unopened chest")

	# Three recipe buttons, real brewing and permanent/timed pill effects.
	scene.state.realm=4;scene.state.herbs=5000;scene.state.dew=2000
	open_page("alchemy");geometry("Alchemy")
	for id in ["qi","spring","clarity"]:
		press("recipe_"+id)
		check(scene.state.recipe==id,"Recipe selection reaches state: "+id)
		press("start_brew")
		check(scene.state.activity=="brew" and not scene.state.auto_advance,"Brew is a deliberate activity")
		scene.state.step(50);scene._refresh_drawer()
		check(int(scene.state.pill_stocks[id])>=1,"Selected recipe produces its own pill: "+id)
		var count_before:int=int(scene.state.pill_stocks[id])
		press("use_pill")
		check(int(scene.state.pill_stocks[id])==count_before-1,"Use consumes one selected pill: "+id)
	check(scene.state.buff_rows().size()==2,"Both timed buff types can coexist")
	check(scene.state.qi>0,"Instant pill adds real qi")

	# Current guidance, rewards, history, collections and finite ending.
	open_page("practice");geometry("Cultivation")
	check(not scene.buttons.practice_claim.disabled,"Current guidance is reachable")
	check(bool(scene.state.quest_rows()[0].ready),"First guidance tracks actual simulated time")
	var guidance_before:Dictionary=scene.state.quest_claimed.duplicate()
	press("practice_claim")
	check(scene.state.quest_claimed==guidance_before,"Journey action only navigates; it never silently claims a quest")
	scene.JournalPages.Journey.navigate(scene,"quest",str(scene.state.quest_rows()[0].id))
	press("quest_claim_"+str(scene.state.quest_rows()[0].id))
	check(bool(scene.state.quest_rows()[0].claimed),"Explicit journal reward claims through actual UI")
	press("journal_journal");geometry("Quest journal")
	press("journal_next");press("journal_prev")
	press("journal_events");geometry("Persistent event journal")
	check(scene.state.journal_rows().size()>0,"History is backed by saved significant events")
	press("journal_collection")
	for category in ["realms","items","discoveries","techniques","recipes"]:
		press("collection_"+category);geometry("Collection "+category)
	press("collection_realms");press("collection_next");press("collection_next")
	check(scene.buttons.collection_next.disabled,"Last realm collection page is bounded")
	press("collection_prev")
	scene.state.realm=State.MAX_REALM;scene.state.merit+=scene.state.qi;scene.state.qi=0.0
	press("journal_practice")
	check(scene.buttons.breakthrough.disabled,"Completed final realm has no false breakthrough action")
	check(bool(scene.state.completion_status().complete),"Finite ending is exposed to journal")
	geometry("Final realm")
	var reloaded=State.new();reloaded.save_path=save_path
	scene._save_loadout();reloaded.load_game()
	check(reloaded.realm==State.MAX_REALM,"Ending state persists")
	check(reloaded.journey_completed==scene.state.journey_completed,"Journey progress persists")
	check(reloaded.journal_rows().size()>0,"Journal persists")
	check(reloaded.gear.get_item(item_id).enhancement==5,"Enhanced instance persists")
	check(reloaded.technique_levels==scene.state.technique_levels,"Technique progress persists")
	check(not scene.encounter_active and not scene.state.expedition_auto,"Entire quiet campaign remains combat optional")
	cleanup()
	scene.queue_free();await process_frame;await process_frame
	print("Campaign UI: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
