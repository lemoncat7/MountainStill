extends SceneTree
## Real controls; isolated state. Headless checks are not native visual proof.
const Ink=preload("res://scripts/ink_pages.gd")
const Supply=preload("res://scripts/craft_supply_pages.gd")
var scene
var checks:int=0
var failures:int=0
var save_path:String="user://craft_supply_%d.json"%OS.get_process_id()
func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)
func press(key:String):
	var b=scene.buttons.get(key)
	check(is_instance_valid(b),"Control exists "+key)
	if is_instance_valid(b):b.pressed.emit()
func snapshot()->Dictionary:
	return {"materials":scene.state.materials.to_dict(),"gear":scene.state.gear.to_dict(),"run":scene.state.stage_run.duplicate(true),"selected":scene.state.selected_stage,"clears":scene.state.stage_clears.duplicate(true),"herbs":scene.state.herbs,"dew":scene.state.dew,"qi":scene.state.qi}
func geometry(label:String):
	var paper:Rect2=scene._drawer_rect()
	var controls:Array=[]
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var r:Rect2=Rect2(child.position,child.size)
			check(paper.encloses(r),"fits "+label+" "+child.text)
			for other in controls:check(not r.intersects(Rect2(other.position,other.size)),"no overlap "+label+" "+child.text+"/"+other.text)
			controls.append(child)
func reset():
	scene._close_drawer();scene.state.new_game();scene.state.save_path=save_path
	scene.state.auto_advance=false;scene.encounter_active=false;scene.paused=false;scene.demo=true
	scene.wardrobe_tab="bag";scene.set_meta("bag_view","craft")
	scene._toggle_drawer("wardrobe");Ink.inspect_craft(scene,"forge_sword")
func _initialize():call_deferred("run")
func run():
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame;scene.set_process(false)
	for width in [960,1000,1200,1360]:
		reset();scene.size=Vector2(width,320);scene._refresh_drawer()
		var before:Dictionary=snapshot()
		press("craft_supply_open");geometry("supplies %d"%width)
		var entries:Array=Supply.rows(scene)
		check(entries.size()==2,"Both ingredient requirements shown")
		check(entries[0].missing==2 and entries[1].missing==2,"Exact shortfalls")
		check(entries[0].target=="bamboo_pass","Moss source matches actual route")
		check(entries[1].target=="refine_stone","Stones link to synthesis")
		var stale=scene.buttons.craft_supply_moss_fiber
		press("craft_supply_moss_fiber");geometry("route %d"%width)
		check(scene.wardrobe_tab=="expedition" and str(scene.get_meta("ink_stage_id"))=="bamboo_pass","Only opens chapter")
		stale.pressed.emit();check(scene.wardrobe_tab=="expedition","Repeated detached click ignored")
		press("craft_supply_return");geometry("returned %d"%width)
		check(Supply.is_open(scene) and str(scene.get_meta("craft_recipe"))=="forge_sword","Exact source recipe restored")
		press("craft_supply_refinement_stone");geometry("refine %d"%width)
		check(str(scene.get_meta("craft_recipe"))=="refine_stone" and not Supply.is_open(scene),"Synthesis inspected, not performed")
		press("craft_supply_open");press("craft_supply_spirit_shard")
		press("craft_supply_return");check(str(scene.get_meta("craft_recipe"))=="refine_stone","Nested return restores synthesis")
		press("craft_supply_return");check(str(scene.get_meta("craft_recipe"))=="forge_sword","Nested return restores original recipe")
		press("craft_supply_close");check(not Supply.is_open(scene),"Back returns to ordinary craft controls")
		check(snapshot()==before,"All browsing preserves full gameplay snapshot")
	reset()
	for id in scene.state.Materials.RECIPE_ORDER:
		Ink.inspect_craft(scene,str(id));press("craft_supply_open")
		check(Supply.rows(scene).size()==scene.state.crafting_quote(str(id)).costs.size(),"Every recipe cost covered "+str(id))
		geometry(str(id))
	Ink.inspect_craft(scene,"weave_moon_robe");press("craft_supply_open")
	var before:Dictionary=snapshot()
	var moon:Dictionary=Supply.rows(scene)[0]
	check(moon.target=="moon_marsh" and moon.gate.contains("需达") and moon.gate.contains("先通"),"Locked source retains both real gates")
	press("craft_supply_moon_thread")
	check(scene.buttons.depart_stage.disabled,"Locked chapter cannot depart")
	press("craft_supply_return");press("craft_supply_close")
	check(int(scene.get_meta("craft_page"))==1,"Second recipe page restored")
	check(snapshot()==before,"Locked route browsing has no mutation")
	for material in scene.state.Materials.recipe("refine_route").alternatives:
		Ink.inspect_craft(scene,"refine_route")
		scene.set_meta("craft_material_refine_route",str(material));scene._refresh_drawer()
		var source:Dictionary=Supply.rows(scene)[0]
		if str(material)!="spirit_jade":
			check(scene.state._base_corpse_materials(str(source.target),0).has(material),"Advertised route actually supplies "+str(material))
		else:check(source.source.contains("1%"),"Rare source remains probabilistic")
	Ink.inspect_craft(scene,"refine_route")
	scene.set_meta("craft_material_refine_route","spirit_jade");scene._refresh_drawer();press("craft_supply_open")
	check(Supply.rows(scene)[0].source.contains("1%") and Supply.rows(scene)[0].source.contains("无保底"),"Rare chance not a guaranteed promise")
	press("craft_supply_spirit_jade");press("craft_supply_return")
	check(str(scene.get_meta("craft_material_refine_route"))=="spirit_jade","Explicit rare ingredient preserved, not replaced")
	press("craft_supply_close")
	scene.state.materials.inventory={"spirit_jade":1};press("craft_supply_open")
	check(Supply.rows(scene)[0].missing==0,"Enough ingredients never show negative shortage")
	var old=scene.buttons.craft_supply_spirit_jade
	press("wardrobe_equipment");old.pressed.emit()
	check(scene.wardrobe_tab=="equipment" and not Supply.has_return(scene),"New sidebar navigation invalidates source links")
	reset();press("craft_supply_open");press("craft_supply_moss_fiber")
	var old_return=scene.buttons.craft_supply_return
	scene._close_drawer();old_return.pressed.emit()
	check(scene.drawer_name.is_empty() and not Supply.has_return(scene) and not Supply.is_open(scene),"Close clears detour; old return cannot reopen")
	for destination in ["settings","alchemy","practice"]:
		reset();press("craft_supply_open");press("craft_supply_moss_fiber")
		scene._toggle_drawer(destination)
		check(not Supply.has_return(scene) and not Supply.is_open(scene),"Unrelated book clears detour "+destination)
		scene._toggle_drawer("wardrobe")
		check(not is_instance_valid(scene.buttons.get("craft_supply_return")),"No stale return on reopened wardrobe "+destination)
	reset();press("craft_supply_open");press("craft_supply_moss_fiber");press("expedition_meridian")
	check(not Supply.has_return(scene),"Meridian shortcut clears detour")
	for tab in ["materials","supplies"]:
		reset();press("craft_supply_open");press("craft_supply_refinement_stone");press("bag_view_"+tab)
		check(not Supply.has_return(scene) and not Supply.is_open(scene),"Bag tab clears detour "+tab)
	reset();press("craft_supply_open");press("craft_supply_moss_fiber")
	Ink.inspect_craft(scene,"bind_cloud_fan")
	check(not Supply.has_return(scene) and not Supply.is_open(scene),"Independent recipe link supersedes detour")
	# Saved incomplete route must survive browsing even a different source.
	reset();scene.state.select_stage("bamboo_pass");scene.state.start_stage();scene.state.pause_stage()
	before=snapshot();Ink.inspect_craft(scene,"weave_moon_robe");press("craft_supply_open");press("craft_supply_moon_thread");press("craft_supply_return")
	check(snapshot()==before,"Paused checkpoint and chosen route remain unchanged")
	# An earlier abandon confirmation cannot stay armed after a source detour.
	scene.state.realm=scene.state.MAX_REALM
	for stage in scene.state.stage_rows():scene.state.stage_clears[str(stage.id)]=1
	scene.wardrobe_tab="expedition";scene.set_meta("ink_stage_id","moon_marsh");scene._refresh_drawer()
	press("abandon_stage")
	check(scene.buttons.abandon_stage.text.begins_with("确认放下"),"First deliberate click arms old confirmation")
	press("wardrobe_bag");scene.set_meta("bag_view","craft");Ink.inspect_craft(scene,"weave_moon_robe")
	press("craft_supply_open");press("craft_supply_moon_thread")
	check(str(scene.get_meta("ink_abandon_confirm","" )).is_empty(),"Source route clears unrelated abandon confirmation")
	check(bool(scene.state.stage_status().paused),"Clearing confirmation never abandons checkpoint")
	check(not scene.buttons.abandon_stage.text.begins_with("确认放下"),"Source entry requires fresh first click")
	press("abandon_stage")
	check(bool(scene.state.stage_status().paused) and scene.buttons.abandon_stage.text.begins_with("确认放下"),"Fresh first click only arms confirmation")
	press("abandon_stage")
	check(not bool(scene.state.stage_status().paused),"Only second fresh deliberate click abandons")

	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Craft supply UI: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
