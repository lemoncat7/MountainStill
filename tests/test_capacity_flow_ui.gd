extends SceneTree
const Pages=preload("res://scripts/capacity_pages.gd")
const State=preload("res://scripts/cultivation_state.gd")
var h
var checks:=0
var failures:=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func press(key:String):
	var b=h.buttons.get(key)
	check(is_instance_valid(b),"exists "+key)
	if not is_instance_valid(b):return
	check(not b.disabled,"enabled "+key)
	if not b.disabled:b.pressed.emit()
func snapshot()->Dictionary:
	var s:Dictionary=h.state._snapshot().duplicate(true)
	s.erase("saved_at")
	return s
func geometry(label:String):
	var controls:Array=[]
	for child in h.drawer.get_children():
		if child is BaseButton and child.visible:
			var r:=Rect2(child.position,child.size)
			check(h._drawer_rect().encloses(r),label+" inside "+child.name)
			for other in controls:check(not r.intersects(Rect2(other.position,other.size)),label+" no overlap "+child.name+"/"+other.name)
			controls.append(child)
func fill():
	while h.state.inventory.size()<100:h.state.gear.add_item_spec({"template_id":"chest_blue","rarity":"common","level":1})
func reset():
	Pages.clear(h);h.set_meta("capacity_corpse_hold",{});h.state.new_game();h.encounter_active=false;h.encounter_phase="idle"
	h.state.auto_advance=false;h.state.arrival_seen=true;h.demo=true;h.drawer_name="wardrobe";h.wardrobe_tab="expedition"
	h.set_meta("ink_stage_id","bamboo_pass");h.set_meta("expedition_view","route")
func run():
	h=load("res://main.tscn").instantiate();h.state.save_path="user://capacity_flow_%d.json"%OS.get_process_id();root.add_child(h)
	await process_frame
	h.set_process(false);reset();fill();h.state.stage_clears.bamboo_pass=1;h._refresh_drawer()
	var before:Dictionary=snapshot()
	press("chapter_reward")
	check(h.drawer_name=="capacity","first clear actual failure opens guidance")
	check(Pages.rows(h)[0].title.contains("100 / 100"),"100 actual gear slots")
	check(Pages.rows(h)[0].detail.contains("腾出 1位"),"exactly one equipment slot")
	check(Pages.target_label(h)=="青竹关","original chapter shown")
	check(snapshot()==before,"failed reward and guidance fully read only")
	for width in [960,1200,1440]:
		h.size=Vector2(width,540 if width==960 else 400);h._refresh_drawer();geometry("capacity %d"%width)
		for row in Pages.rows(h):
			var lines:Array=h.InkPages._wrapped_lines(str(row.detail),604,14,3)
			check(not lines[-1].ends_with("…"),"capacity detail untruncated")
	press("capacity_organize");geometry("organize wardrobe")
	check(h.wardrobe_tab=="equipment","equipment destination")
	check(snapshot()==before,"organize no selection RNG cooldown resource mutation")
	press("capacity_return");press("capacity_retry")
	check(h.state.chapter_status().pending_rewards.has("bamboo_pass"),"not enough space remains pending")
	press("capacity_organize")
	var id:int=h.state.inventory[0].id;h.selected_item=id;h._refresh_drawer();press("salvage_item")
	h.salvage_dialog.hide();check(h.state.inventory.size()==100,"cancel decomposition leaves equipment")
	press("capacity_return");press("capacity_organize")
	h.selected_item=id;h._refresh_drawer();press("salvage_item");h.salvage_dialog.confirmed.emit();h.salvage_dialog.hide()
	check(h.state.inventory.size()==99,"explicit confirmed decomposition frees one slot")
	press("capacity_return");var retry=h.buttons.capacity_retry;retry.pressed.emit();retry.pressed.emit()
	check(h.state.inventory.size()==100,"reward exactly once")
	check(not h.state.chapter_status().pending_rewards.has("bamboo_pass"),"claimed chapter no pending")
	check(h.drawer_name=="wardrobe" and h.get_meta("ink_stage_id")=="bamboo_pass","returned exact original chapter")
	reset();fill();h.state.gear.chests=2;h.state.gear.starter_chest_unopened=true;h._refresh_drawer();before=snapshot()
	h._open_treasure()
	check(h.drawer_name=="capacity" and snapshot()==before,"full chest warning before any spend")
	check(Pages.rows(h)[0].detail.contains("若开出装备"),"conditional conversion honest")
	var old=h.buttons.capacity_retry
	press("capacity_organize");old.pressed.emit();check(snapshot()==before,"stale chest confirm while organizing no spend")
	press("capacity_return");old.pressed.emit();check(snapshot()==before,"stale chest confirm after return invalid")
	press("capacity_cancel");check(snapshot()==before,"cancel chest no spend")
	h._open_treasure();press("capacity_retry")
	check(h.state.chest_count==1 and h.state.inventory.size()==100,"explicit one chest existing conversion")
	check(h.toast.contains("转换"),"post conversion honest feedback")
	reset();fill();h.state.gear.chests=2;h._refresh_drawer();h._open_treasure();old=h.buttons.capacity_retry
	h._close_drawer();old.pressed.emit();check(h.state.chest_count==2,"close invalidates confirmation")
	reset();fill();h.state.stage_clears.bamboo_pass=1;Pages.open(h,"chapter",{"id":"bamboo_pass"});old=h.buttons.capacity_retry
	h.encounter_active=true;h.encounter_phase="fight";old.pressed.emit();check(h.state.chapter_status().pending_rewards.has("bamboo_pass"),"stale retry respects battle")
	h._refresh_drawer();check(h.buttons.capacity_retry.disabled,"battle retry disabled")
	h.encounter_active=false
	await additional_flows()
	await corpse_flow()
	h.queue_free();await process_frame
	await create_timer(0.15).timeout
	print("CAPACITY_FLOW_UI checks=%d failures=%d"%[checks,failures]);quit(0 if failures==0 else 1)
func corpse_flow():
	reset();fill();h.state.gear.chests=3
	h.state.select_stage("bamboo_pass")
	var started:Dictionary=h.state.start_stage();var run_id:int=started.get("run_id",h.state.stage_status().run_id)
	h.state.begin_stage_corpse(run_id,0);h.state.advance_stage_search(run_id,0,2.0)
	# Explicit fixture: deterministic already-earned equipment, no random reroll.
	h.state.stage_run.pending_corpse.rewards.item_spec={"template_id":"chest_blue","rarity":"common","level":1}
	h.encounter_active=true;h.encounter_phase="pickup";h.encounter_run_id=run_id;h.encounter_index=0;h.pickup_claimed_at=-1.0;h.pickup_block_reason=""
	var before:Dictionary=snapshot();h._claim_searched_corpse()
	check(h.drawer_name=="capacity" and not Pages.held_corpse(h).is_empty(),"corpse failure creates held target")
	check(snapshot()==before,"corpse failure atomic no RNG change")
	press("capacity_organize")
	h.state.salvage_item(h.state.inventory[0].id)
	before=snapshot();h._claim_searched_corpse()
	check(snapshot()==before and h.pickup_claimed_at<0.0,"no auto collection after making space")
	# Save while enough room exists but the player has not explicitly claimed.
	h.state.save_path="user://capacity_corpse_roundtrip.json";check(h.state.save_game(),"held corpse save succeeds")
	var loaded=State.new();loaded.save_path=h.state.save_path;loaded.load_game()
	check(loaded.stage_corpse_status().search_ready,"readback retains exact completed search")
	h.state=loaded;Pages.clear(h);h.set_meta("capacity_corpse_hold",{})
	h.state.start_stage();h.encounter_run_id=int(h.state.stage_status().run_id);h.encounter_index=0
	before=snapshot();h.world_route="bamboo_pass";h._prepare_stage_monster();h._claim_searched_corpse()
	check(snapshot()==before and h.pickup_claimed_at<0.0,"readback-ready corpse derives hold instead of auto claiming")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(h.state.save_path+suffix):DirAccess.remove_absolute(h.state.save_path+suffix)
	h._close_drawer();h.drawer_name="wardrobe";h.wardrobe_tab="expedition";h._refresh_drawer()
	check(is_instance_valid(h.buttons.get("capacity_return")),"closed explanation retains reopen affordance")
	press("capacity_return");press("capacity_retry")
	check(h.pickup_claimed_at>=0.0 and h.state.stage_status().kills==1,"explicit corpse collects once")
	h._claim_searched_corpse(true);check(h.state.stage_status().kills==1,"duplicate corpse cannot grant twice")

func additional_flows():
	reset();h.state.lifetime_seconds=61;h.state.herbs=h.state.MAX_RESOURCE
	h.drawer_name="practice";h.set_meta("ink_journal_tab","journal");h.set_meta("ink_journal_mode","quests");h.set_meta("ink_journal_page",0);h._refresh_drawer()
	var before:Dictionary=snapshot();press("quest_claim_settle")
	check(h.drawer_name=="capacity" and Pages.rows(h)[0].title.contains("灵草"),"real quest failure gives exact feedback")
	check(snapshot()==before,"quest failed claim atomic")
	check(not Pages.target_label(h).is_empty(),"quest identity displayed")
	for native in [Vector2i(960,540),Vector2i(1440,720),Vector2i(1200,400)]:
		for requested in [1.0,1.25,1.5]:
			var scale:float=preload("res://scripts/readability_layout.gd").effective_scale(native,requested)
			h.size=Vector2(native)/scale;h._refresh_drawer();geometry("scaled capacity")
			check(Pages.BODY_FONT_SIZE*scale>=14,"readable 14 physical px minimum")
			for destination in ["wardrobe","alchemy","chests","practice","materials"]:
				var original:Dictionary=snapshot()
				Pages.organize(h,destination);geometry("scaled "+destination)
				check(snapshot()==original,"destination "+destination+" changes no state")
				check(is_instance_valid(h.buttons.get("capacity_return")),"destination return exists "+destination)
				if destination=="wardrobe":check(not is_instance_valid(h.buttons.get("evasion_stat")),"return replaces invisible header hotspot")
				Pages.return_pending(h)
	h.state.herbs=0;press("capacity_retry");check(h.state.quest_claimed.get("settle",false),"quest retries explicitly")
	reset();h.state.pending_opportunity={"stage_id":"bamboo_pass","run_id":77};h.state.herbs=h.state.MAX_RESOURCE
	h.wardrobe_tab="expedition";h.set_meta("expedition_view","opportunity");h._refresh_drawer();before=snapshot()
	press("opportunity_gather_gift")
	check(h.drawer_name=="capacity" and Pages.target_label(h)=="收下山草","original opportunity choice shown")
	check(snapshot()==before,"opportunity failure no mutation")
	Pages.organize(h,"alchemy");Pages.return_pending(h);check(snapshot()==before,"opportunity nav preserves run and choice")
	var old=h.buttons.capacity_retry
	h.state.pending_opportunity={"stage_id":"bamboo_pass","run_id":78}
	h._refresh_drawer();check(not Pages.valid(h) and Pages.rows(h)[0].title.contains("原目标已变化"),"new run invalidates old opportunity")
	check(Pages.target_label(h)=="收下山草","invalid target retains original displayed name")
	old.pressed.emit();check(int(h.state.pending_opportunity.run_id)==78,"stale target cannot resolve newer opportunity")
	reset();fill();h.state.stage_clears.bamboo_pass=1;h.state.herbs=h.state.MAX_RESOURCE;Pages.open(h,"chapter",{"id":"bamboo_pass"})
	press("capacity_organize");h.selected_item=h.state.inventory[0].id;h._refresh_drawer();press("salvage_item");h.salvage_dialog.confirmed.emit();h.salvage_dialog.hide()
	check(Pages.anchor(h).kind=="salvage" and Pages.rows(h)[0].title.contains("灵草"),"secondary salvage exact blocker")
	check(Pages.anchor(h).has("parent"),"secondary blocker keeps original chapter target")
	press("capacity_cancel");press("capacity_return");check(Pages.anchor(h).kind=="chapter","secondary back returns original chapter context")
	# Published save schema remains unchanged; pending rewards survive restart.
	h.state.save_path="user://capacity_roundtrip.json";check(h.state.save_game(),"capacity fixture saves")
	var loaded=State.new();loaded.save_path=h.state.save_path;loaded.load_game()
	check(loaded.inventory.size()==100 and loaded.chapter_status().pending_rewards.has("bamboo_pass"),"old-schema reload keeps pending 100-item reward")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(h.state.save_path+suffix):DirAccess.remove_absolute(h.state.save_path+suffix)
