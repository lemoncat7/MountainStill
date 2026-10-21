extends SceneTree
## Real host controls with isolated unit fixtures. This does not prepare a demo
## save or change battle values, accepted body poses, portrait or scene framing.
const Ink=preload("res://scripts/ink_pages.gd")
const Adventure=preload("res://scripts/adventure_pages.gd")
var scene
var checks:int=0
var failures:int=0
var save_path:String="user://chapter_crafting_ui_%d.json"%OS.get_process_id()

func check(value:bool,label:String):
	checks+=1
	if not value:failures+=1;printerr("FAIL: "+label)

func press(key:String):
	var control=scene.buttons.get(key)
	check(is_instance_valid(control),"Control exists: "+key)
	if not is_instance_valid(control):return
	check(not control.disabled,"Control enabled: "+key)
	if not control.disabled:control.pressed.emit()

func geometry(label:String):
	var paper:Rect2=scene._drawer_rect()
	check(paper.position.x>=0 and paper.end.x<=scene.size.x,"Paper fits viewport: "+label)
	var children:Array=[]
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect:Rect2=Rect2(child.position,child.size)
			check(paper.encloses(rect),"Control fits: "+label+" / "+child.text)
			for other in children:
				check(not rect.intersects(Rect2(other.position,other.size)),"Controls do not overlap: "+label+" / "+child.text+" / "+other.text)
			children.append(child)

func page(tab:String):
	scene.wardrobe_tab=tab
	if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
	else:scene._refresh_drawer()

func unit_materials():
	scene.state.materials.inventory={}
	for id in scene.state.Materials.material_ids():scene.state.materials.inventory[id]=50

func snapshot()->Dictionary:
	return {"materials":scene.state.materials.to_dict(),"gear":scene.state.gear.to_dict(),"run":scene.state.stage_run.duplicate(true),"selected_stage":scene.state.selected_stage,"victories":scene.state.total_victories,"clears":scene.state.stage_clears.duplicate(true)}

func reset():
	scene._close_drawer();scene.drawer_alpha=0.0;scene._reset_presentation()
	scene.state.new_game();scene.state.save_path=save_path;scene.state.auto_advance=false
	scene.encounter_active=false;scene.paused=false;scene.demo=true
	scene.character_x=520.0;scene.character_y=230.0
	scene.set_meta("craft_recipe","refine_stone");scene.set_meta("craft_page",0);scene.set_meta("craft_receipt","")
	scene.set_meta("craft_material_refine_route","")
	scene.set_meta("ink_stage_id","bamboo_pass");scene.set_meta("ink_stage_page",0);scene.set_meta("expedition_view","route")
	scene.set_meta("bag_view","craft")

func _initialize():call_deferred("run")

func run():
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame
	scene.set_process(false);scene.get_window().size=Vector2i(1200,320)
	test_recipe_pages()
	test_conversion_selection()
	test_locked_and_comparison()
	test_guides()
	test_live_guide_navigation()
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Chapter crafting UI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func test_recipe_pages():
	reset();unit_materials()
	var order:Array=scene.state.Materials.RECIPE_ORDER
	check(order.size()==7,"Finite catalog has seven recipes")
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);page("bag");Ink.inspect_craft(scene,"refine_stone")
		geometry("First craft leaf at %d"%width)
		check(scene.buttons.craft_prev.disabled and not scene.buttons.craft_next.disabled,"First recipe leaf has bounded previous")
		for i in range(order.size()):
			check(is_instance_valid(scene.buttons.get("craft_recipe_"+str(order[i])))==(i<4),"Only four first-leaf targets: "+str(order[i]))
		press("craft_next");geometry("Second craft leaf at %d"%width)
		check(str(scene.get_meta("craft_recipe"))=="carve_river_pin" and int(scene.get_meta("craft_page"))==1,"Next leaf selects a visible recipe")
		check(scene.buttons.craft_next.disabled and not scene.buttons.craft_prev.disabled,"Last recipe leaf is bounded")
		for i in range(order.size()):
			check(is_instance_valid(scene.buttons.get("craft_recipe_"+str(order[i])))==(i>=4),"Only three second-leaf targets: "+str(order[i]))
		for id in ["carve_river_pin","bind_cloud_fan","weave_moon_robe"]:
			press("craft_recipe_"+id)
			var quote:Dictionary=scene.state.crafting_quote(id)
			check(scene.buttons.craft_selected.disabled and scene.buttons.craft_selected.text=="尚待解锁","Locked recipe is readable but disabled: "+id)
			check(scene.buttons["craft_recipe_"+id].tooltip_text.contains(str(quote.unlock_text)),"Exact chapter unlock appears in row tooltip: "+id)
			check(Ink.SANS.get_string_size(Ink._craft_status(quote),HORIZONTAL_ALIGNMENT_LEFT,-1,9).x<=195,"Exact unlock fits recipe subtitle: "+id)
		press("craft_prev")
		check(str(scene.get_meta("craft_recipe"))=="refine_stone" and int(scene.get_meta("craft_page"))==0,"Previous leaf restores visible first selection")
		check(scene._scene_camera_transform()==Transform2D.IDENTITY and scene.character_x==520.0,"Craft navigation preserves world framing")
	scene.size=Vector2(1200,320)
	scene.set_meta("craft_recipe","not_a_recipe");page("bag")
	check(str(scene.get_meta("craft_recipe"))=="refine_stone","Invalid view metadata safely normalizes to first recipe")

func test_conversion_selection():
	reset()
	scene.state.materials.inventory={"moss_fiber":3,"river_ore":3,"spirit_jade":2}
	page("bag");press("craft_recipe_refine_route")
	check(str(Ink._craft_selected(scene).selected_material)=="moss_fiber","Initial explicit selection prefers mundane material")
	check(scene.buttons.craft_selected.tooltip_text.contains("青苔灵纤 3") and not scene.buttons.craft_selected.tooltip_text.contains("消耗：灵髓玉"),"Craft action states exact selected ingredient")
	geometry("Explicit material selector")
	press("craft_selected")
	check(scene.state.material_count("moss_fiber")==0 and scene.state.material_count("refinement_stone")==1,"One conversion consumes precisely shown mundane stack")
	check(scene.state.material_count("river_ore")==3 and scene.state.material_count("spirit_jade")==2,"First conversion preserves alternatives and rare jade")
	check(scene.buttons.craft_selected.disabled,"Depletion disables craft even while another stack could afford it")
	check(str(Ink._craft_selected(scene).selected_material)=="moss_fiber","Depletion never changes chosen material")
	var depleted:Dictionary=snapshot()
	scene.buttons.craft_selected.pressed.emit()
	check(snapshot()==depleted,"Repeated disabled signal cannot convert alternate stock")
	page("equipment");page("bag")
	check(str(Ink._craft_selected(scene).selected_material)=="moss_fiber" and scene.buttons.craft_selected.disabled,"Reopening retains depleted explicit selection")
	press("craft_material_next")
	check(str(Ink._craft_selected(scene).selected_material)=="river_ore","Cycle visibly changes to next ingredient")
	press("craft_selected")
	check(scene.state.material_count("river_ore")==0 and scene.state.material_count("refinement_stone")==2,"Explicit second ingredient matches actual cost")
	for i in range(5):press("craft_material_next")
	var rare:Dictionary=Ink._craft_selected(scene)
	check(str(rare.selected_material)=="spirit_jade" and int(rare.output_count)==3,"Rare jade requires deliberate selection and advertises three output")
	check(scene.buttons.craft_selected.tooltip_text.contains("灵髓玉 1"),"Rare conversion declares exact rare cost")
	press("craft_selected")
	check(scene.state.material_count("spirit_jade")==1 and scene.state.material_count("refinement_stone")==5,"Rare conversion charges one jade for three stones")
	check(str(scene.get_meta("craft_receipt")).contains("灵髓玉 1") and str(scene.get_meta("craft_receipt")).contains("×3"),"Receipt reflects exact chosen material and output")
	press("craft_material_next")
	check(str(Ink._craft_selected(scene).selected_material)=="moss_fiber","Ingredient cycling wraps to mundane material")
	reset();scene.state.materials.inventory={"spirit_jade":3};page("bag");press("craft_recipe_refine_route")
	check(str(Ink._craft_selected(scene).selected_material)!="spirit_jade" and scene.buttons.craft_selected.disabled,"Rare-only inventory is never implicitly consumed")

func test_locked_and_comparison():
	reset();unit_materials();page("bag");press("craft_next");press("craft_recipe_bind_cloud_fan")
	var before:Dictionary=snapshot()
	scene.buttons.craft_selected.pressed.emit()
	check(snapshot()==before,"Locked control cannot spend materials or grant equipment")
	scene.state.stage_clears.cloud_slope=1;scene._refresh_drawer()
	check(not scene.buttons.craft_selected.disabled,"Actual chapter clear unlocks the same visible recipe")
	# A chapter prerequisite changed after the button was built: click-time
	# requote still prevents the stale enabled control from manufacturing.
	scene.state.stage_clears.cloud_slope=0;before=snapshot()
	press("craft_selected")
	check(snapshot()==before and scene.buttons.craft_selected.disabled,"Fresh quote guards a stale enabled recipe")
	scene.state.stage_clears.cloud_slope=1;scene._refresh_drawer()
	var quote:Dictionary=Ink._craft_selected(scene)
	check(scene.buttons.craft_selected.tooltip_text.contains("未穿戴 → "+str(quote.output_name)),"Preview names currently equipped item and proposed output")
	check(scene.buttons.craft_selected.tooltip_text.contains(Ink._craft_comparison(quote)),"Action exposes exact signed live equipment deltas")
	var worn:Dictionary=scene.state.gear.equipped.duplicate()
	press("craft_selected")
	var made:int=scene.selected_item
	check(scene.state.gear.equipped==worn and not made in scene.state.gear.equipped.values(),"Manufacturing never auto-equips or changes portrait loadout")
	press("craft_to_equipment");press("equip_selected");page("bag")
	quote=Ink._craft_selected(scene)
	check(str(quote.comparison.equipped_name)==str(quote.output_name) and int(quote.comparison.attack_delta)==0,"Comparison recomputes against explicitly equipped crafted item")
	check(Ink._craft_comparison(quote).contains("攻 +0"),"Zero-difference comparison remains explicit")
	geometry("Post-equip comparison")

func test_guides():
	reset()
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);page("expedition")
		var before:Dictionary=snapshot()
		press("chapter_guide");geometry("Chapter field guide at %d"%width)
		check(str(scene.get_meta("expedition_view"))=="guide" and snapshot()==before,"Guide opening changes presentation only")
		check(is_instance_valid(scene.buttons.depart_stage) and is_instance_valid(scene.buttons.expedition_gear) and is_instance_valid(scene.buttons.expedition_meridian),"Guide preserves departure and bottom preparation actions")
		press("stage_creek_bridge")
		var guide:Dictionary=scene.state.chapter_field_guide("creek_bridge")
		check(str(scene.get_meta("expedition_view"))=="guide" and scene.buttons.chapter_guide.tooltip_text.contains(str(guide.monster_name)),"Changing inspected chapter refreshes guide identity in-place")
		check(scene.buttons.depart_stage.disabled,"Locked chapter guide keeps locked departure disabled")
		check(scene.buttons.chapter_guide.tooltip_text.contains(str(guide.preparation)) and scene.buttons.chapter_guide.tooltip_text.contains(str(guide.crafting_goal)),"Guide exposes complete real preparation and crafting goal")
		before=snapshot();press("chapter_recipe");geometry("Guide links to recipe at %d"%width)
		check(scene.wardrobe_tab=="bag" and str(scene.get_meta("bag_view"))=="craft","Guide link opens crafting book")
		check(str(scene.get_meta("craft_recipe"))==str(guide.recipe_id) and int(scene.get_meta("craft_page"))==1,"Guide link selects exact recipe on its visible leaf")
		check(snapshot()==before and not scene.encounter_active,"Guide recipe link never starts or selects a different stage")
		page("expedition");press("chapter_guide")
		check(str(scene.get_meta("expedition_view"))=="route","Guide toggle returns to chapter story")
		scene.set_meta("ink_stage_id","bamboo_pass");scene.set_meta("ink_stage_page",0)
	scene.size=Vector2(1200,320);page("expedition")
	# Every catalog chapter provides readable guide copy and a real recipe.
	for row in scene.state.stage_rows():
		scene.set_meta("ink_stage_id",str(row.id));scene.set_meta("ink_stage_page",(int(row.chapter)-1)/3);scene.set_meta("expedition_view","guide");scene._refresh_drawer()
		var guide:Dictionary=scene.state.chapter_field_guide(str(row.id))
		check(not guide.is_empty(),"Every chapter has finite guide data: "+str(row.id))
		geometry("Guide "+str(row.id))
		for pair in [["identity",2],["preparation",2]]:
			var text:String=("备行 · " if pair[0]=="preparation" else "")+str(guide.get(pair[0],""))
			var lines:Array[String]=Ink._wrapped_lines(text,371,10,int(pair[1]))
			check(not lines.is_empty() and not lines[-1].ends_with("…"),"Guide copy fits without truncation: "+str(row.id)+" / "+str(pair[0]))
		var goal:String=str(guide.material_name)+" → "+str(guide.crafting_goal)
		check(Ink.SANS.get_string_size(goal,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x<=371,"Material and craft goal fit one line: "+str(row.id))
		if str(guide.recipe_id)=="refine_route":
			var before:Dictionary=snapshot();press("chapter_recipe")
			check(str(Ink._craft_selected(scene).selected_material)==str(guide.material_id),"Chapter conversion link previews this chapter's exact mundane material: "+str(row.id))
			check(snapshot()==before,"Chapter material preselection consumes nothing: "+str(row.id))
			page("expedition")

func test_live_guide_navigation():
	reset();scene.state.realm=scene.state.MAX_REALM
	for row in scene.state.stage_rows():scene.state.stage_clears[str(row.id)]=1
	scene.state.start_stage()
	var active:Dictionary=snapshot();page("expedition");press("chapter_guide");press("stage_cloud_slope")
	check(snapshot()==active,"Live-stage chapter guide inspection cannot switch active chapter or checkpoint")
	press("chapter_recipe")
	check(snapshot()==active and str(scene.get_meta("craft_recipe"))=="bind_cloud_fan","Live-stage recipe navigation is strictly read-only")
	scene.state.pause_stage(int(scene.state.stage_run.run_id))
	var paused:Dictionary=snapshot();page("expedition");press("stage_creek_bridge");press("chapter_recipe")
	check(snapshot()==paused,"Paused checkpoint survives guide switching and recipe link exactly")
	page("expedition");scene.set_meta("expedition_view","guide");scene._refresh_drawer()
	scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":"bamboo_pass","run_id":int(scene.state.stage_run.run_id)}
	scene.set_meta("ink_stage_id","bamboo_pass");scene._refresh_drawer()
	press("expedition_opportunity");geometry("Opportunity remains separate from guide")
	check(not is_instance_valid(scene.buttons.get("chapter_guide")) and not is_instance_valid(scene.buttons.get("chapter_recipe")),"Opportunity text and choices never overlap guide controls")
	press("opportunity_back")
	check(is_instance_valid(scene.buttons.get("chapter_guide")) and str(scene.get_meta("expedition_view"))=="route","Returning from opportunity restores normal guide access")
