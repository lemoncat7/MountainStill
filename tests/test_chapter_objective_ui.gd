extends SceneTree
## Isolated seeded UI fixtures, not naturally earned player progress.
const Adventure=preload("res://scripts/adventure_pages.gd")
const Ink=preload("res://scripts/ink_pages.gd")
var scene
var checks:=0
var failures:=0
var save_path:="user://chapter_objective_%d.json"%OS.get_process_id()

func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func snapshot()->String:
	var data:Dictionary=scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)
func mark()->Dictionary:
	var data:=snapshot()
	return {"data":data,"clock":scene.state._clock_high_water}
func unchanged(before:Dictionary,label:String):
	check(scene.state._clock_high_water==before.clock,label+" clock unchanged")
	check(snapshot()==before.data,label+" formal state/RNG unchanged")
func fresh():
	scene._reset_presentation();scene.state.new_game();scene.state.save_path=save_path
	scene.state.auto_advance=false;scene.demo=true;scene.paused=false
	scene.encounter_active=false;scene.world_route=""
	scene.set_meta("combat_insight_open",false)
	scene.set_meta("equipment_comparison_open",false)
func clear_through(count:int,claimed:bool=true):
	for i in range(count):
		var id:String=scene.state.Content.CHAPTER_ORDER[i]
		scene.state.stage_clears[id]=1
		scene.state.chapter_reward_claimed[id]=claimed
func row(id:String)->Dictionary:
	for entry in scene.state.stage_rows():
		if str(entry.id)==id:return entry
	return {}
func objective(id:String)->String:
	var status:Dictionary=scene.state.stage_status()
	var chosen:=row(id)
	var before:=mark()
	var result:String=Adventure._chapter_objective(scene,chosen,status)
	for _repeat in range(3):check(Adventure._chapter_objective(scene,chosen,status)==result,"repeated objective stable "+id)
	unchanged(before,"objective "+id)
	var lines:Array[String]=Ink._wrapped_lines(result,371,11,1)
	check(lines.size()==1 and lines[0]==result,"entire objective fits existing single line: "+result)
	return result
func open_chapter(id:String):
	scene.wardrobe_tab="expedition"
	scene.set_meta("ink_stage_id",id)
	scene.set_meta("ink_stage_page",scene.state.Content.CHAPTER_ORDER.find(id)/3)
	scene.set_meta("expedition_view","route")
	if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
	else:scene._refresh_drawer()
func ui_matches(id:String):
	# Warm the existing status snapshot before testing read-only presentation.
	scene.state.stage_status()
	var before:=mark()
	open_chapter(id)
	var text:String=Adventure._chapter_objective(scene,row(id),scene.state.stage_status())
	check(is_instance_valid(scene.buttons.get("stage_"+id)),"chapter control present "+id)
	check(scene.buttons["stage_"+id].tooltip_text.contains(text),"tooltip uses the same live objective "+id)
	unchanged(before,"paper refresh "+id)
	check(not scene.encounter_active,"paper does not depart "+id)

func test_live_gate_matrix():
	fresh()
	check(objective("bamboo_pass").begins_with("本章目标"),"fresh route keeps current objective")
	check(objective("creek_bridge").contains("需达 炼气中期") and objective("creek_bridge").contains("先通 青竹关"),"locked route lists actual gates")
	# Every reached chapter, and every earlier reread, across future realm gates.
	for cleared in range(1,6):
		for realm in range(int(scene.state.Content.STAGES[scene.state.Content.CHAPTER_ORDER[cleared-1]].unlock_realm),scene.state.MAX_REALM+1):
			fresh();clear_through(cleared);scene.state.realm=realm
			var next_id:String=scene.state.Content.CHAPTER_ORDER[cleared]
			var next_row:=row(next_id)
			var expected:String="后续目标 · "+str(scene.state.chapter_status().next_objective)
			for previous in range(cleared):
				var id:String=scene.state.Content.CHAPTER_ORDER[previous]
				var text:=objective(id)
				check(text==expected,"reread resolves real first unfinished target "+id)
				check(text.contains(str(next_row.name)),"objective names actual next chapter")
				if bool(next_row.unlocked):check(not text.contains("突破") and not text.contains("需达到"),"already satisfied realm never requested again")
				else:check(text.contains(str(scene.state.REALM_NAMES[int(next_row.unlock_realm)])),"unmet next realm remains truthful")
	# Reproduction: realm reached before first clear. No automatic navigation.
	fresh();scene.state.realm=1;clear_through(1)
	check(objective("bamboo_pass")=="后续目标 · 启程听泉桥","natural report state gives reachable second chapter")
	ui_matches("bamboo_pass")
	check(scene.state.selected_stage=="bamboo_pass" and str(scene.get_meta("ink_stage_id"))=="bamboo_pass","guidance does not jump selected chapter")
	check(not scene.buttons.depart_stage.disabled,"cleared selected route remains explicitly replayable")
	# Legacy/gapped progress must use State's first unfinished chapter, not +1.
	fresh();scene.state.realm=6;scene.state.stage_clears.creek_bridge=1;scene.state.chapter_reward_claimed.creek_bridge=true
	check(objective("creek_bridge")=="后续目标 · 启程青竹关","legacy gap points to first unfinished chapter")

func test_pending_and_run_priority():
	fresh();scene.state.realm=1;clear_through(1,false)
	for herbs in [0,scene.state.MAX_RESOURCE]:
		scene.state.herbs=herbs
		check(objective("bamboo_pass").begins_with("首通心意待领"),"pending reward never described as already claimed")
		ui_matches("bamboo_pass")
		check(is_instance_valid(scene.buttons.get("chapter_reward")),"pending objective has the actual claim control")
		check(not scene.state.chapter_reward_claimed.bamboo_pass,"view never claims reward")
	check(scene.state.select_stage("creek_bridge"),"fixture selects second route")
	var run:Dictionary=scene.state.start_stage()
	check(bool(run.ok),"fixture starts finite run")
	check(objective("bamboo_pass").begins_with("行程进行中 · 听泉桥"),"active run outranks old chapter pending reward")
	check(objective("summit_gate").begins_with("行程进行中 · 听泉桥"),"active run outranks inspected locked gate")
	check(bool(scene.state.begin_stage_corpse(int(run.run_id),0).ok),"fixture creates earned unsearched corpse")
	check(objective("bamboo_pass").contains("遗物尚未搜取"),"active corpse not mistaken for paid progression")
	scene.state.pause_stage(int(run.run_id))
	check(objective("bamboo_pass").begins_with("上次停在 · 听泉桥") and objective("bamboo_pass").contains("遗物尚未搜取"),"paused corpse remains the actionable owner")
	ui_matches("bamboo_pass")
	check(scene.buttons.abandon_stage.text.contains("遗物尚未搜取"),"corpse objective matches return control")
	# Fixture separately covers a retained opportunity, defeat and normal pause.
	fresh();scene.state.realm=1;clear_through(1)
	scene.state.select_stage("creek_bridge");run=scene.state.start_stage()
	scene.state.stage_run.kills=2;scene.state.stage_run.opportunity_checked=true
	scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":"creek_bridge","run_id":int(run.run_id)}
	check(objective("bamboo_pass").contains("机缘待回应"),"active opportunity is not a new departure")
	scene.state.pause_stage(int(run.run_id))
	check(objective("bamboo_pass").contains("机缘待回应"),"paused opportunity retained")
	fresh();clear_through(1);scene.state.realm=1
	scene.state.select_stage("creek_bridge");run=scene.state.start_stage()
	scene.state.stage_run.kills=2;scene.state.fail_stage(int(run.run_id))
	check(objective("bamboo_pass")=="败退留有余地 · 听泉桥 · 已过 2 / 3 敌","defeat shows retained route and actual progress")
	scene.state.stage_run.failed=false
	check(objective("bamboo_pass")=="上次停在 · 听泉桥 · 已过 2 / 3 敌","ordinary pause shows retained route")
	ui_matches("bamboo_pass")
	check(scene.buttons.depart_stage.text=="回到未完之程","paused objective agrees with explicit return button")
	# A legal retained old choice outlives its cancelled route and takes the
	# same priority as build_expedition's response button, even over rewards.
	fresh();scene.state.realm=1;clear_through(1,false)
	scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":"bamboo_pass","run_id":1}
	check(scene.state.stage_run.is_empty() and not bool(scene.state.stage_status().opportunity_pending),"retained old choice is not an active route choice")
	check(objective("bamboo_pass").begins_with("机缘待回应 · 石龛留香"),"retained choice outranks pending chapter reward")
	ui_matches("bamboo_pass")
	check(is_instance_valid(scene.buttons.get("expedition_opportunity")),"retained choice has response control")
	check(not is_instance_valid(scene.buttons.get("chapter_reward")),"hidden reward is not misleadingly offered")
	check(not scene.state.chapter_reward_claimed.bamboo_pass and not scene.state.pending_opportunity.is_empty(),"view claims neither retained choice nor reward")

func test_endings():
	fresh();clear_through(6);scene.state.realm=12
	for id in scene.state.Content.CHAPTER_ORDER:
		check(objective(id).contains("突破至归真"),"all-clear below max still needs real final realm")
		ui_matches(id)
	scene.state.realm=scene.state.MAX_REALM
	for id in scene.state.Content.CHAPTER_ORDER:
		var text:=objective(id)
		check(text.contains("合印归心") and not text.contains("突破"),"max realm leads to unwritten epilogue")
		ui_matches(id)
		check(is_instance_valid(scene.buttons.get("chapter_ending")),"all-clear objective has ending navigation")
	check(scene.state.ending_finished_at<0,"view never writes epilogue")
	scene.state.ending_finished_at=0
	for id in scene.state.Content.CHAPTER_ORDER:
		check(objective(id).contains("山河已宁") and not objective(id).contains("突破"),"written epilogue permits replay without false progression")
	# An unclaimed final package takes priority; max realm does not grant it.
	scene.state.chapter_reward_claimed.summit_gate=false
	check(objective("summit_gate").begins_with("首通心意待领"),"final chapter pending reward remains explicit")
	ui_matches("summit_gate")
	check(is_instance_valid(scene.buttons.get("chapter_reward")),"final pending reward matches claim control")

func run():
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path
	root.add_child(scene);await process_frame
	scene.set_process(false)
	test_live_gate_matrix()
	test_pending_and_run_priority()
	test_endings()
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Chapter objective UI: %d checks, %d failures"%[checks,failures])
	quit(0 if failures==0 else 1)
