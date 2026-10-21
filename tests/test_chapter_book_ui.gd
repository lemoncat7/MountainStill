extends SceneTree
## Six chapters, first-five-minute onboarding, resumable inspection and ending.
## All assertions run against the actual host and isolated save; no camera mock.
const Ink=preload("res://scripts/ink_pages.gd")
const Journal=preload("res://scripts/journal_pages.gd")
var scene
var checks:int=0
var failures:int=0
var save_path:String="user://chapter_book_ui_%d.json"%OS.get_process_id()

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
				check(not rect.intersects(Rect2(other.position,other.size)),"Controls never overlap: "+label+" / "+child.text+" / "+other.text)
			children.append(child)

func open_routes():
	scene.wardrobe_tab="expedition";scene.set_meta("expedition_view","route")
	if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
	else:scene._refresh_drawer()

func open_journal(tab:String):
	scene.set_meta("ink_journal_tab",tab)
	if scene.drawer_name!="practice":scene._toggle_drawer("practice")
	else:scene._refresh_drawer()

func advance(seconds:float):
	for i in range(ceili(seconds*60.0)):scene._process(1.0/60.0)

func _initialize():call_deferred("run")

func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false);scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0
	_test_six_chapters()
	_test_onboarding()
	_test_paused_inspection()
	_test_pending_corpse_navigation()
	_test_route_choice_pages()
	_test_endings()
	_test_text_bounds()
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Chapter book UI: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func _test_six_chapters():
	var rows:Array=scene.state.stage_rows()
	check(rows.size()==6,"Campaign has six route chapters")
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);scene.set_meta("ink_stage_page",0);open_routes()
		geometry("Chapters 1–3 at %d"%width)
		for id in ["bamboo_pass","creek_bridge","cloud_slope"]:check(is_instance_valid(scene.buttons.get("stage_"+id)),"First leaf has "+id)
		check(not is_instance_valid(scene.buttons.get("stage_summit_gate")),"Off-leaf chapter has no hidden hit target")
		var selected:String=scene.state.selected_stage
		press("stage_cloud_slope")
		check(scene.state.selected_stage==selected and not scene.encounter_active,"Locked chapter inspection is read-only")
		check(scene.buttons.depart_stage.disabled and not scene.buttons.stage_cloud_slope.disabled,"Locked chapter readable; departure truthful")
		press("stage_next");geometry("Chapters 4–6 at %d"%width)
		for id in ["ember_ruins","moon_marsh","summit_gate"]:
			press("stage_"+id)
			check(not scene.buttons["stage_"+id].tooltip_text.is_empty(),"Every late chapter has a full story and gate tooltip")
		check(scene.buttons.stage_summit_gate.tooltip_text.contains("化神初期") and scene.buttons.stage_summit_gate.tooltip_text.contains("镜月泽"),"Late chapter shows both realm and preceding-route prerequisites")
		check(scene.buttons.stage_next.disabled,"Sixth chapter is final page")
		check(scene._scene_camera_transform()==Transform2D.IDENTITY and scene.character_x==520.0,"Chapter browsing never reframes world")
		press("stage_prev")
		check(scene.buttons.stage_prev.disabled,"First leaf lower bound")
	scene.size=Vector2(1200,320)
	press("stage_bamboo_pass")
	check(not scene.buttons.depart_stage.disabled,"First route available from fresh save")
	check(not scene.encounter_active,"Selecting available route does not depart")

func _test_onboarding():
	open_journal("guide");geometry("Onboarding")
	check(Journal._recommended_guide_step(scene)==0,"Fresh save recommends actual starter equipment in first roadmap phase")
	check(Journal._guide_rows(scene).size()==8,"Onboarding covers the complete eight-phase player journey")
	for row in Journal._guide_rows(scene):
		var lines:Array[String]=Ink._wrapped_lines(str(row.text),298,11,4)
		check(not lines[-1].ends_with("…"),"Every roadmap explanation remains fully visible: "+str(row.title))
	for i in range(8):press("guide_step_%d"%i);geometry("Guide step %d"%i)
	press("guide_recommend")
	check(int(scene.get_meta("ink_guide_step"))==0,"Recommendation returns to live next action")
	press("guide_action")
	check(scene.drawer_name=="wardrobe" and scene.wardrobe_tab=="equipment","Equipment guide leads to actionable actual page")
	check(not scene.encounter_active,"Guide never starts combat")
	open_journal("guide");press("guide_step_3");press("guide_action")
	check(scene.drawer_name=="practice" and bool(scene.get_meta("ink_guide_follow_current")),"Browsing a future phase returns to live advice without starting or selecting a route")
	press("guide_idle")
	check(not scene.state.auto_advance and str(scene.get_meta("ink_journal_tab"))=="practice","Peaceful route link opens actual practice without enabling automation")
	press("practice_auto")
	check(scene.state.auto_advance,"Automatic quiet practice is a separate explicit opt-in")
	scene.state.auto_advance=false
	check(scene._scene_camera_transform()==Transform2D.IDENTITY and scene.character_x==520.0,"Guide never moves scene or scales camera")

func _test_paused_inspection():
	scene.state.new_game();scene.state.auto_advance=false
	var run:Dictionary=scene.state.start_stage()
	scene.state.defeat_stage_monster(int(run.run_id),0)
	scene.state.fail_stage(int(run.run_id))
	var checkpoint:Dictionary=scene.state.stage_run.duplicate(true)
	scene.set_meta("ink_stage_id","bamboo_pass");scene.set_meta("ink_stage_page",0);open_routes()
	check(scene.buttons.depart_stage.text=="继续此程","Defeat offers explicit checkpoint continuation")
	press("stage_cloud_slope");press("stage_next");press("stage_summit_gate")
	check(scene.state.stage_run==checkpoint,"Browsing every locked leaf preserves saved checkpoint")
	check(scene.buttons.depart_stage.text=="回到未完之程","Different inspected route offers return to pending chapter")
	press("depart_stage")
	check(not scene.encounter_active and str(scene.get_meta("ink_stage_id"))=="bamboo_pass","Return-to-checkpoint button only navigates on first click")
	check(scene.state.stage_run==checkpoint and scene.buttons.depart_stage.text=="继续此程","Checkpoint remains exact after navigation")
	# A player may deliberately abandon a replay checkpoint without losing loot.
	scene.state.realm=1;scene.state.stage_clears.bamboo_pass=1
	press("stage_creek_bridge");geometry("Deliberate checkpoint abandonment")
	var loot:Array=[scene.state.herbs,scene.state.dew,scene.state.qi,scene.state.chest_count,scene.state.gear.inventory.duplicate(true),scene.state.total_victories]
	var first_control=scene.buttons.abandon_stage
	press("abandon_stage")
	check(scene.state.stage_run==checkpoint and scene.buttons.abandon_stage.text.begins_with("确认放下"),"First abandon click only exposes exact consequence and confirmation")
	geometry("Checkpoint abandon confirmation")
	if is_instance_valid(first_control):first_control.pressed.emit()
	check(scene.state.stage_run==checkpoint,"Stale first-click control cannot double-submit abandonment")
	scene._close_drawer();open_routes()
	check(not scene.buttons.abandon_stage.text.begins_with("确认放下"),"Closing and reopening invalidates pending abandon confirmation")
	press("abandon_stage")
	check(scene.state.stage_run==checkpoint,"Fresh first click still keeps checkpoint")
	press("abandon_stage")
	check(scene.state.stage_run.is_empty() and not scene.state.stage_status().paused,"Second explicit click clears only unfinished checkpoint")
	check(loot==[scene.state.herbs,scene.state.dew,scene.state.qi,scene.state.chest_count,scene.state.gear.inventory.duplicate(true),scene.state.total_victories],"Abandon preserves every already-earned resource, item and victory")
	check(scene.state.selected_stage=="creek_bridge" and not scene.encounter_active and not scene.buttons.depart_stage.disabled,"Chosen unlocked route is ready but never automatically starts")

func _test_pending_corpse_navigation():
	scene.state.new_game();scene.state.auto_advance=false;scene.state.realm=1
	scene.state.stage_clears.bamboo_pass=1
	var run:Dictionary=scene.state.start_stage()
	scene.state.begin_stage_corpse(int(run.run_id),0)
	scene.state.advance_stage_search(int(run.run_id),0,.5)
	scene.state.pause_stage(int(run.run_id))
	var checkpoint:Dictionary=scene.state.stage_run.duplicate(true)
	var loot:Array=[scene.state.herbs,scene.state.dew,scene.state.qi,scene.state.chest_count,scene.state.gear.to_dict(),scene.state.materials.to_dict(),scene.state.total_victories]
	scene.set_meta("ink_stage_id","bamboo_pass");scene.set_meta("ink_stage_page",0);open_routes()
	press("stage_creek_bridge");geometry("Earned corpse chapter navigation")
	check(scene.buttons.abandon_stage.text.begins_with("遗物尚未搜取") and not scene.buttons.abandon_stage.text.contains("放下"),"Unsearched body offers accurate return action rather than impossible abandonment")
	press("abandon_stage")
	check(scene.state.stage_run==checkpoint and scene.state.selected_stage=="bamboo_pass" and str(scene.get_meta("ink_stage_id"))=="bamboo_pass","Returning from another inspected chapter retains exact body and restores owning chapter")
	check(not scene.encounter_active and scene.buttons.depart_stage.text=="继续此程","Corpse return only navigates; continuation still requires explicit departure")
	check(scene.toast.begins_with("遗物尚未搜取") and scene.toast.contains("搜寻进度已保留") and not scene.toast.contains("已放下"),"Notice explains preserved search progress without claiming reset or abandonment")
	check(loot==[scene.state.herbs,scene.state.dew,scene.state.qi,scene.state.chest_count,scene.state.gear.to_dict(),scene.state.materials.to_dict(),scene.state.total_victories],"Corpse navigation cannot claim, consume or reroll earned loot")
	press("stage_cloud_slope");press("abandon_stage")
	check(scene.state.stage_run==checkpoint and str(scene.get_meta("ink_stage_id"))=="bamboo_pass","Browsing a locked chapter also returns safely to pending corpse")
	scene.state.new_game();scene.state.auto_advance=false

func _test_route_choice_pages():
	scene.state.new_game();scene.state.auto_advance=false;scene.state.realm=scene.state.MAX_REALM
	for row in scene.state.stage_rows():scene.state.stage_clears[str(row.id)]=1
	var names:Array[String]=[]
	for row in scene.state.stage_rows():
		var id:String=str(row.id)
		scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":id,"run_id":1}
		scene.set_meta("ink_stage_id",id);scene.set_meta("ink_stage_page",(int(row.chapter)-1)/3);open_routes()
		var opportunity:Dictionary=scene.state.opportunity_status()
		names.append(str(opportunity.name))
		check(scene.buttons.expedition_opportunity.text.begins_with(str(opportunity.name)),"Route-specific opportunity title: "+id)
		press("expedition_opportunity");geometry("Choice page "+id)
		check(scene.buttons.opportunity_read_inscription.text.contains("功德"),"Final-realm opportunity states actual energy destination")
		check(scene.buttons.opportunity_gather_gift.text.contains("+"),"Choice makes exact material reward visible")
		var merit_before:float=scene.state.merit
		press("opportunity_read_inscription")
		check(scene.state.pending_opportunity.is_empty() and scene.state.merit>merit_before,"Route-specific choice resolves and credits its displayed energy reward")
	check(names.size()==6 and names[0]!=names[5],"Six chapters retain distinct opportunity identities")
	scene.state.new_game();scene.state.auto_advance=false

func _test_endings():
	open_journal("ending");geometry("Unfinished ending")
	check(not scene.state.chapter_status().ending_complete,"Viewing ending never completes it")
	check(scene.buttons.ending_action.text=="循着山路再出发","Incomplete ending gives a working next action")
	press("ending_action")
	check(scene.drawer_name=="wardrobe" and scene.wardrobe_tab=="expedition","Incomplete ending returns to real chapter book")
	scene.state.realm=scene.state.MAX_REALM;scene.state.merit+=scene.state.qi;scene.state.qi=0.0
	open_journal("ending")
	check(scene.state.completion_status().complete and not scene.state.chapter_status().story_resolved,"Peaceful sixteen-stage ending is independent of adventure")
	for row in scene.state.stage_rows():scene.state.stage_clears[str(row.id)]=1
	open_journal("ending");geometry("Ready ending")
	check(scene.state.chapter_status().epilogue_ready and not scene.state.chapter_status().ending_complete,"Complete campaign waits for player final click")
	var prior=scene.buttons.ending_action
	press("ending_action")
	check(scene.state.chapter_status().ending_complete,"Final actual control records home epilogue")
	var finished:float=float(scene.state.chapter_status().finished_at)
	if is_instance_valid(prior):prior.pressed.emit()
	check(scene.state.chapter_status().ending_complete and float(scene.state.chapter_status().finished_at)==finished,"Stale final click cannot repeat ending")
	geometry("Completed ending")
	press("ending_action")
	check(str(scene.get_meta("ink_journal_tab"))=="practice","Completed ending leaves playable peaceful mountain home")
	check(scene.state.save_game(),"Explicit ending save succeeds")
	var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
	check(loaded.chapter_status().ending_complete,"Explicit ending persists across reload")
	open_journal("journal");geometry("Journal final entry")
	press("journal_ending");check(str(scene.get_meta("ink_journal_tab"))=="ending","Ending remains replayably accessible")

func _test_text_bounds():
	var sample:String="归山印 · 史诗流云扇 · 灵气212000 · 灵草330 · 晨露90"
	var lines:Array[String]=Ink._wrapped_lines(sample,371,10,2)
	check(lines.size()<=2,"Reward uses at most two readable lines")
	for line in lines:check(Ink.SANS.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,10).x<=371.0,"Every wrapped reward line fits its width")
	var truncated:Array[String]=Ink._wrapped_lines("一二三四五六七八九十十一十二十三十四十五十六",55,12,2)
	check(truncated.size()==2 and truncated[-1].ends_with("…"),"Overflow is visibly ellipsized rather than silently lost")
	for line in truncated:check(Ink.SANS.get_string_size(line,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x<=55.0,"Ellipsis itself fits")

	var sentence:String="山中灵脉忽然失序。循着小狐带回的竹叶，安抚青苔兽王，寻找第一枚山印。"
	for line in Ink._wrapped_lines(sentence,371,11,2):
		check(not line.begins_with("。") and not line.begins_with("，"),"Chinese punctuation never starts a line")
	var ending:Array[String]=Ink._wrapped_lines(scene.state.Content.EPILOGUE_TEXT,273,12,5)
	check(not ending[-1].ends_with("…"),"Full final epilogue remains readable without truncation")
