extends SceneTree
## Continuous native fresh-player acceptance walk. This is a UI client, not a
## state fixture: the only assigned production property is an isolated save path
## before the scene enters the tree. Every action uses a live control rectangle
## and real mouse motion/down/up events. All waiting runs normal _process(delta).
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const Content = preload("res://scripts/cultivation_content.gd")
const ROUTES := ["bamboo_pass", "creek_bridge", "cloud_slope", "ember_ruins", "moon_marsh", "summit_gate"]
var scene
var output := "/tmp/complete-player-native"
var save_path := ""
var clock := 0.0
var failed := false
var finished := false
var headless := false
var intro_only := false
var smoke_only := false
var actions: Array = []
var observations: Array = []
var captures: Dictionary = {}
var segments: Array = []
var errors: Array[String] = []
var source_hashes: Dictionary = {}
var initial: Dictionary = {}
var reload_proof: Dictionary = {}
var fan_id := -1
var overlay: CanvasLayer
var banner: Label
var detail: Label
var segment_title := "初入山中 · 一份空白新档"
var segment_detail := "连续实机录制 · 不载入进度、不赠资源，所有操作都点击正式界面"
var last_phase := ""
var last_victories := 0
var previous_capture_second := -1
var fight_started := 0.0
var seen_searches: Dictionary = {}
var seen_fights: Dictionary = {}
var milestones: Dictionary = {}
var reload_count := 0
var wall_start := 0

func _initialize() -> void:
	call_deferred("run")

func run() -> void:
	wall_start = Time.get_ticks_msec()
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--intro-only": intro_only = true
		if arg == "--smoke-only": smoke_only = true
	headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(output)
	save_path = output.path_join("earned-save.json")
	if FileAccess.file_exists(save_path) or FileAccess.file_exists(save_path + ".bak"):
		fail("Refusing to overwrite or preload an existing save: " + save_path); return
	for path in runtime_sources("scripts") + ["project.godot", "main.tscn", "tests/show_complete_player_journey.gd"]:
		source_hashes[path] = FileAccess.get_sha256("res://" + path)
	load_scene()
	await process_frame
	initial = snapshot()
	if not verify(scene.state.realm == 0 and scene.state.herbs == 3 and scene.state.dew == 1 and scene.state.chest_count == 1 and scene.state.inventory.is_empty() and scene.state.total_victories == 0 and scene.state.materials.inventory.is_empty() and not scene.state.auto_advance, "Fresh save has only published starting supplies and manual advancement"): return
	create_overlay()
	mark("初入山中 · 一份空白新档", "赤膊白短裤起步；先读石台札记，再决定怎样修行")
	await wait_seconds(4.0)
	capture("01-fresh-shirtless-arrival")
	await click("guide_note")
	await wait_seconds(4.0)
	capture("02-arrival-guide")
	if smoke_only:
		await close_book()
		await wait_seconds(2.0)
		finish(); return
	mark("安顿衣冠 · 先看所得，再亲手穿戴", "随机首箱保证一件普通入门装备；衣冠五处独立穿脱")
	await click("guide_action")
	await wait_seconds(2.0)
	await click("first_chest")
	await wait_seconds(3.0)
	capture("03-starter-owned-not-equipped")
	verify(scene.state.equipped.is_empty(), "Opening first chest does not equip it")
	await click("equip_selected")
	verify(scene.state.equipped.size() == 1, "First owned item explicitly equipped")
	await wait_seconds(2.0)
	mark("选择心法 · 阅读代价后再确认", "先查看第一部心法，首次选择免费；参悟与装配各由玩家决定")
	await inspect_manual("breath")
	await click("manual_slot_heart")
	await wait_seconds(2.5)
	capture("04-first-heart-confirmation")
	await click("confirm_heart_switch")
	verify(scene.state.equipped_heart == "breath", "First heart chosen through displayed confirmation")
	mark("安居与参悟 · 草露换来真正的一重", "先采够六草二露，再支付并等候九秒；书页不会搬动场景人物")
	await activity("gather")
	await close_book()
	await until(func(): return scene.state.herbs >= 6 and scene.state.dew >= 2, 100.0, "Gather the first study ingredients")
	await activity("meditate")
	await study("mist", 2)
	milestones.first_study_finished = clock
	await close_book()
	await wait_seconds(10.0)
	capture("06-quiet-meditation")
	await until(func(): return scene.state.lifetime_seconds >= 60.0, 60.0, "First peaceful minute")
	await claim_ready()
	mark("第一回成长 · 亲手突破与通脉", "先满足修为与灵草，再点突破；境界不会自行跳过")
	await break_to(1)
	milestones.first_breakthrough = clock
	await claim_ready()
	await wardrobe("meridian")
	await click("meridian_branch_central")
	await click("meridian_row_qihai")
	await wait_seconds(2.0)
	await click("unlock_meridian")
	verify(scene.state.meridian_opened.has("qihai"), "First earned meridian opened")
	capture("07-first-earned-meridian")
	await show_guide()
	if intro_only:
		await close_book()
		finish(); return
	for chapter in range(6):
		if failed: return
		await play_chapter(chapter)
		if failed: return
		await prepare_after_chapter(chapter)
		if failed: return
		if chapter == 2:
			await save_reload()
		if chapter < 5: await show_guide()
	mark("六章归山 · 亲手写下结语", "十八场交锋、逐次搜寻、六份首通；仍是最初那份存档")
	await open_book("practice")
	await click("journal_journal")
	await click("journal_ending")
	await wait_seconds(5.0)
	capture("30-six-chapters-ending-ready")
	await click("ending_action")
	await wait_seconds(5.0)
	capture("31-ending-written")
	verify(scene.state.chapter_status().ending_complete, "Player explicitly wrote the unlocked ending")
	verify(scene.state.total_victories == 18, "Exactly eighteen real searched victories")
	verify(scene.state.stage_clears.size() == 6 and scene.state.chapter_reward_claimed.size() == 6, "All six chapters and their first-clear rewards earned")
	verify(reload_count == 1 and bool(reload_proof.get("preserved", false)), "Same earned save genuinely reloaded once")
	await close_book()
	await wait_seconds(5.0)
	capture("32-home-after-complete-journey")
	await open_book("settings")
	await click("save")
	await close_book()
	finish()


func runtime_sources(folder: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at("res://" + folder):
		if file_name.ends_with(".gd") or file_name.ends_with(".gdshader") or file_name.ends_with(".tscn"):
			paths.append(folder.path_join(file_name))
	for directory in DirAccess.get_directories_at("res://" + folder):
		paths.append_array(runtime_sources(folder.path_join(directory)))
	return paths

func load_scene() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	# Headless preflight keeps the exact 1/60 s process delta but lifts the wall-clock
	# frame cap. Native rendering always retains the production frame settings.
	if headless: Engine.max_fps = 0

func create_overlay() -> void:
	var backdrop_layer := CanvasLayer.new(); backdrop_layer.layer = -100; root.add_child(backdrop_layer)
	var backdrop := ColorRect.new(); backdrop.size = Vector2(1200, 320); backdrop.color = Color("e8e7df"); backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE; backdrop_layer.add_child(backdrop)
	overlay = CanvasLayer.new(); overlay.layer = 90; root.add_child(overlay)
	var backing := ColorRect.new(); backing.position = Vector2(8, 5); backing.size = Vector2(432, 44)
	backing.color = Color(.93, .93, .87, .91); backing.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(backing)
	banner = Label.new(); banner.position = Vector2(15, 7); banner.add_theme_font_override("font", Sans); banner.add_theme_font_size_override("font_size", 10); banner.add_theme_color_override("font_color", Color("354e43")); banner.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(banner)
	detail = Label.new(); detail.position = Vector2(15, 27); detail.add_theme_font_override("font", Sans); detail.add_theme_font_size_override("font_size", 11); detail.add_theme_color_override("font_color", Color("506356")); detail.mouse_filter = Control.MOUSE_FILTER_IGNORE; overlay.add_child(detail)

func mark(title: String, explanation: String) -> void:
	segment_title = title; segment_detail = explanation
	segments.append({"time": clock, "title": title, "detail": explanation, "state": snapshot()})
	print("JOURNEY_SEGMENT %.3f %s" % [clock, title])
	write_progress()

func _process(delta: float) -> bool:
	if finished: return false
	clock += delta
	if is_instance_valid(banner):
		banner.text = "原生实录 · 中性衬底 · 1×游戏时间 · %02d:%02d" % [int(clock)/60, int(clock)%60]
		detail.text = segment_title
	if not is_instance_valid(scene) or initial.is_empty(): return false
	var key := "%s:%d:%s" % [str(scene.world_route), int(scene.encounter_index), str(scene.encounter_phase)]
	if key != last_phase:
		last_phase = key
		observations.append({"time": clock, "phase": key, "state": snapshot()})
		if scene.encounter_phase == "fight": fight_started = clock
		print("JOURNEY_PHASE %.3f %s wins=%d" % [clock, key, scene.state.total_victories])
	if scene.encounter_phase == "fight" and clock - fight_started > 3.0 and not seen_fights.has(key):
		seen_fights[key] = true
		capture("battle-%s-%d" % [scene.world_route, scene.encounter_index + 1])
	if scene.encounter_phase == "pickup" and scene.pickup_collect_started >= 0.0 and scene.pickup_claimed_at < 0.0 and float(scene.pickup_status.get("search_seconds", 0.0)) > .8 and not seen_searches.has(key):
		seen_searches[key] = true
		observations.append({"time": clock, "search_pending": key, "state": snapshot()})
		capture("search-%s-%d" % [scene.world_route, scene.encounter_index + 1])
	if scene.state.total_victories != last_victories:
		last_victories = scene.state.total_victories
		observations.append({"time": clock, "searched_victory": last_victories, "reward": plain(scene.encounter_reward), "state": snapshot()})
		write_progress()
	if int(clock) % 30 == 0 and int(clock) != previous_capture_second:
		previous_capture_second = int(clock); write_progress()
	if clock > 2400.0: fail("Journey exceeded forty minutes; no invisible time skipping is permitted")
	return false

func wait_seconds(seconds: float) -> void:
	var target := clock + maxf(0.0, seconds)
	while clock < target and not failed: await process_frame

func until(predicate: Callable, timeout: float, label: String) -> void:
	var deadline := clock + timeout
	while not failed and not predicate.call():
		if clock > deadline: fail("Timed out: " + label); return
		await process_frame

func click(id: String, read_pause: float = .8) -> void:
	if failed: return
	await until(func():
		var b = scene.buttons.get(id)
		return is_instance_valid(b) and b.is_visible_in_tree() and not b.disabled and b.mouse_filter != Control.MOUSE_FILTER_IGNORE and (b.get_parent() != scene.drawer or (scene.paper_reveal > .97 and scene.content_alpha > .8)), 8.0, "Visible enabled UI control " + id)
	if failed: return
	var button: Control = scene.buttons[id]
	var rect: Rect2 = button.get_global_rect()
	var position: Vector2 = rect.get_center()
	var entry := {"time": clock, "button": id, "text": str(button.text), "rect": {"x": rect.position.x, "y": rect.position.y, "width": rect.size.x, "height": rect.size.y}, "before": snapshot()}
	var motion := InputEventMouseMotion.new(); motion.position = position; motion.global_position = position
	Input.parse_input_event(motion)
	await process_frame
	var down := InputEventMouseButton.new(); down.button_index = MOUSE_BUTTON_LEFT; down.pressed = true; down.position = position; down.global_position = position
	Input.parse_input_event(down)
	await process_frame
	var up := InputEventMouseButton.new(); up.button_index = MOUSE_BUTTON_LEFT; up.pressed = false; up.position = position; up.global_position = position
	Input.parse_input_event(up)
	await process_frame
	await wait_seconds(read_pause)
	entry.after = snapshot(); actions.append(entry)
	print("JOURNEY_CLICK %.3f %s" % [clock, id])

func close_book() -> void:
	if not scene.drawer_name.is_empty(): await click("drawer_close", .8)
	await until(func(): return scene.drawer_alpha < .02, 3.0, "Book fully closed")

func open_book(name: String) -> void:
	if scene.drawer_name == name: return
	await close_book()
	await click(name, 1.0)

func wardrobe(tab: String) -> void:
	await open_book("wardrobe")
	if scene.wardrobe_tab != tab: await click("wardrobe_" + tab)

func activity(id: String) -> void:
	await open_book("practice")
	await click("journal_practice")
	await click("activity_" + id)

func show_guide() -> void:
	await open_book("practice")
	await click("journal_guide")
	await click("guide_recommend")
	await wait_seconds(3.0)
	capture("guide-after-%d-wins" % scene.state.total_victories)

func inspect_manual(id: String) -> void:
	await wardrobe("technique")
	await click("tech_category_all")
	var rows: Array = scene.state.technique_rows()
	var index := -1
	for i in range(rows.size()):
		if str(rows[i].id) == id: index = i; break
	if not verify(index >= 0, "Requested manual exists: " + id): return
	var target: int = index / 3
	while int(scene.get_meta("ink_manual_page", 0)) < target and not failed: await click("tech_next")
	while int(scene.get_meta("ink_manual_page", 0)) > target and not failed: await click("tech_prev")
	await click("equip_" + id)

func study(id: String, target: int) -> void:
	while int(scene.state.technique_levels.get(id, 0)) < target and not failed:
		await inspect_manual(id)
		await wait_seconds(2.0)
		var before: Dictionary = snapshot()
		var level: int = int(scene.state.technique_levels.get(id, 0))
		capture("study-%s-%d-before" % [id, level + 1])
		await click("train_technique")
		verify(int(scene.state.technique_levels.get(id, 0)) == level, "Study payment does not instantly raise rank")
		verify(scene.state.herbs < int(before.herbs), "Study paid earned herbs")
		if id == "mist" and target == 2: capture("05-first-study-paid-and-ticking")
		await until(func(): return int(scene.state.technique_levels.get(id, 0)) == level + 1, 90.0, "Normal study completion: " + id)
		await wait_seconds(2.0)
		capture("study-%s-%d-complete" % [id, level + 1])

func claim_ready() -> void:
	var ready := true
	while ready and not failed:
		ready = false
		var rows: Array = scene.state.quest_rows()
		for index in range(rows.size()):
			var row: Dictionary = rows[index]
			if not bool(row.ready): continue
			ready = true
			await open_book("practice")
			await click("journal_journal")
			await click("journal_quests")
			var target: int = index / 3
			while int(scene.get_meta("ink_journal_page", 0)) < target and not failed: await click("journal_next")
			while int(scene.get_meta("ink_journal_page", 0)) > target and not failed: await click("journal_prev")
			await click("quest_claim_" + str(row.id), 1.2)
			verify(scene.state.quest_claimed.has(str(row.id)), "Actually earned optional quest claimed: " + str(row.id))
			break

func break_to(target: int) -> void:
	while scene.state.realm < target and not failed:
		var realm: int = scene.state.realm
		var need_herbs: int = Content.HERB_COSTS[realm]
		var need_qi: float = Content.QI_COSTS[realm]
		if scene.state.herbs < need_herbs:
			await activity("gather"); await close_book()
			await until(func(): return scene.state.herbs >= need_herbs, 300.0, "Gather published breakthrough herbs")
		await activity("meditate")
		await until(func(): return scene.state.qi >= need_qi, 600.0, "Earn published breakthrough qi")
		await wait_seconds(1.5)
		await click("breakthrough", 2.5)
		verify(scene.state.realm == realm + 1, "One click advances exactly one realm stage")
		capture("realm-%02d-earned" % scene.state.realm)

func equip_item(id: int) -> void:
	await wardrobe("equipment")
	var index := -1
	for i in range(scene.state.inventory.size()):
		if int(scene.state.inventory[i].id) == id: index = i; break
	if not verify(index >= 0, "Equip only an actually owned item"): return
	var page: int = index / 3
	while scene.inventory_page < page and not failed: await click("items_next")
	while scene.inventory_page > page and not failed: await click("items_prev")
	await click("item_%d" % (index % 3))
	await wait_seconds(1.5)
	if not id in scene.state.equipped.values(): await click("equip_selected", 1.5)
	verify(id in scene.state.equipped.values(), "Explicit equipment choice applied")

func craft(id: String, material: String = "", equip: bool = false) -> void:
	await wardrobe("bag")
	await click("bag_view_craft")
	var rows: Array = scene.state.crafting_rows()
	var index := -1
	for i in range(rows.size()):
		if str(rows[i].id) == id: index = i; break
	if not verify(index >= 0, "Recipe exists: " + id): return
	var target: int = index / 4
	while int(scene.get_meta("craft_page", 0)) < target and not failed: await click("craft_next")
	while int(scene.get_meta("craft_page", 0)) > target and not failed: await click("craft_prev")
	await click("craft_recipe_" + id)
	if not material.is_empty():
		var attempts := 0
		while str(scene.get_meta("craft_material_" + id, "")) != material and not failed:
			if attempts > 12: fail("Could not choose the actual recipe material"); return
			await click("craft_material_next"); attempts += 1
	var before: Dictionary = snapshot()
	await wait_seconds(2.0)
	capture("craft-%s-%d-before" % [id, actions.size()])
	await click("craft_selected", 1.8)
	verify(scene.state.equipped == before.equipped, "Crafting never silently equips")
	verify(scene.state.materials.to_dict() != before.materials, "Crafting paid earned materials")
	capture("craft-%s-%d-owned" % [id, actions.size()])
	if equip:
		var item_id: int = scene.selected_item
		await click("craft_to_equipment")
		await click("equip_selected", 1.5)
		verify(item_id in scene.state.equipped.values(), "Crafted item explicitly equipped")
		if id == "bind_cloud_fan": fan_id = item_id

func enhance(id: int, method: String) -> void:
	await equip_item(id)
	if str(scene.get_meta("enhancement_method", "herbs")) != method: await click("enhancement_method")
	var before: int = int(scene.state.gear.get_item(id).get("enhancement", 0))
	await wait_seconds(2.0)
	await click("enhance_item", 1.5)
	verify(int(scene.state.gear.get_item(id).enhancement) == before + 1, "Paid enhancement preserves and raises original item")
	capture("enhance-owned-item-%d" % id)

func equip_manual(id: String, slot: String, equipped: bool = true) -> void:
	await inspect_manual(id)
	var is_equipped: bool = slot in scene.state.equipped_technique_slots(id)
	if is_equipped != equipped: await click("manual_slot_" + slot)
	verify((slot in scene.state.equipped_technique_slots(id)) == equipped, "Player selected manual slot: " + id + "/" + slot)

func play_chapter(index: int) -> void:
	var route: String = ROUTES[index]
	mark("第%d章 · %s" % [index + 1, str(Content.STAGES[route].name)], "亲点出发；完整交锋、倒地搜寻两秒、材料入囊，再返回山居")
	await wardrobe("expedition")
	var target: int = index / 3
	while int(scene.get_meta("ink_stage_page", 0)) < target and not failed: await click("stage_next")
	while int(scene.get_meta("ink_stage_page", 0)) > target and not failed: await click("stage_prev")
	await click("stage_" + route)
	await click("chapter_guide")
	await wait_seconds(4.0)
	capture("chapter-%d-field-guide" % (index + 1))
	await click("chapter_guide")
	await click("depart_stage", .9)
	await close_book()
	var deadline := clock + 360.0
	while scene.encounter_active and not failed:
		if clock > deadline: fail("Chapter failed to return normally: " + route); return
		if scene.encounter_phase == "opportunity":
			await wait_seconds(2.0)
			await click("route_opportunity")
			await wait_seconds(3.0)
			var opportunity: Dictionary = scene.state.opportunity_status()
			if not verify(not opportunity.get("choices", []).is_empty(), "Natural random opportunity exposes real choices"): return
			await click("opportunity_" + str(opportunity.choices[0].id), 1.0)
			await close_book()
		else: await process_frame
	# A genuinely unlucky starter can leave the first route unfinished. Returning
	# and explicitly continuing uses the production checkpoint and normal rest.
	# No earned victories are replayed and no health or save fields are assigned.
	var retries := 0
	while int(scene.state.stage_clears.get(route, 0)) == 0 and not failed and retries < 3:
		var status: Dictionary = scene.state.stage_status()
		if not bool(status.get("paused", false)): break
		retries += 1
		mark("调息后继续 · 已搜取的收获仍在", "正常归山恢复后，亲点继续此程；保留真实已击退进度")
		await wait_seconds(4.0)
		await wardrobe("expedition")
		await click("depart_stage")
		await close_book()
		var retry_deadline := clock + 240.0
		while scene.encounter_active and not failed:
			if clock > retry_deadline: fail("Continuation did not return: " + route); return
			if scene.encounter_phase == "opportunity":
				await click("route_opportunity")
				var opportunity: Dictionary = scene.state.opportunity_status()
				await click("opportunity_" + str(opportunity.choices[0].id))
				await close_book()
			else: await process_frame
	if not verify(int(scene.state.stage_clears.get(route, 0)) == 1, "Chapter genuinely cleared once: " + route): return
	verify(scene.state.total_victories == (index + 1) * 3, "All chapter encounters paid only after search")
	milestones[route + "_clear"] = clock
	await wait_seconds(4.0)
	capture("chapter-%d-returned-home" % (index + 1))
	await claim_ready()
	if index != 5:
		var reward: Dictionary = scene.encounter_chapter_reward
		if not verify(reward.get("item") is Dictionary and not reward.item.is_empty(), "Earned chapter reward contains its actual item"): return
		await equip_item(int(reward.item.id))

func prepare_after_chapter(chapter: int) -> void:
	match chapter:
		0:
			mark("首章所获 · 制衣、炼丹与继续参悟", "青苔纤维制衣；第一炉丹亲手服用，首通青锋剑以草露温养")
			await craft("refine_route", "moss_fiber")
			await craft("weave_armor", "", true)
			await open_book("alchemy")
			await click("recipe_qi")
			await click("start_brew")
			await until(func(): return scene.state.pills >= 1, 40.0, "First real paid brew")
			capture("10-first-brew-complete")
			await click("use_pill")
			await activity("meditate")
			await claim_ready()
			await enhance(int(scene.state.equipped.weapon), "herbs")
			await study("mist", 3)
			await study("barrier", 1)
		1:
			mark("第二章之后 · 筑基开出新的装配栏", "继续使用实得草露；参悟和装配分开，法门不替你悄悄换上")
			await break_to(3)
			await craft("refine_route", "river_ore")
			await craft("carve_river_pin", "", true)
			await study("breath", 2)
			await study("mist", 4)
			await study("body", 1)
			await equip_manual("body", "passive")
			await equip_manual("barrier", "active")
		2:
			mark("第三章之后 · 从山材做到流云扇", "九场实战所得：碎晶合石、云羽制扇，再亲手穿戴与淬炼原物")
			await break_to(6)
			await study("petal", 1)
			await study("barrier", 2)
			await study("body", 2)
			await craft("refine_stone")
			await craft("refine_stone")
			await craft("bind_cloud_fan", "", true)
			await craft("refine_stone")
			await enhance(fan_id, "materials")
			await equip_manual("mist", "active", false)
			await equip_manual("petal", "weapon_art")
			await equip_manual("petal", "active")
			milestones.crafted_fan_ready = clock
			capture("20-crafted-fan-ready-for-next-chapter")
		3:
			mark("第四章之后 · 旧物与功法一起成长", "首通所得打开下一段山路；保留亲制的流云扇继续修习")
			await break_to(9)
			await study("petal", 2)
			await study("body", 3)
			await study("barrier", 3)
		4:
			mark("第五章之后 · 为最后一程制衣", "焰砂与淬灵石制作月白云衫，已学功法继续稳步提升")
			await break_to(12)
			await study("petal", 3)
			await study("body", 4)
			await study("barrier", 4)
			await craft("refine_stone")
			await craft("refine_stone")
			await craft("refine_route", "ember_cinder")
			await craft("weave_moon_robe", "", true)
		5:
			await break_to(15)

func save_reload() -> void:
	mark("保存与重开 · 仍是同一份实得进度", "正式保存后重新打开；材料、制成扇、装配与前三章进度逐项核对")
	await open_book("settings")
	await click("save", 2.0)
	var before: Dictionary = snapshot()
	capture("21-earned-save-before-reopen")
	scene.queue_free(); scene = null
	await process_frame
	load_scene()
	await process_frame
	var after: Dictionary = snapshot()
	var keys := ["realm", "herbs", "dew", "materials", "inventory", "equipped", "victories", "clears", "claims", "quests", "counters", "techniques", "meridians", "auto", "chests", "heart", "weapon_art", "actives", "passives"]
	var preserved := true
	for key in keys:
		if before[key] != after[key]: preserved = false; errors.append("Reload changed " + key)
	reload_count += 1
	reload_proof = {"before": before, "after": after, "keys": keys, "preserved": preserved, "save_path": save_path, "save_sha256": FileAccess.get_sha256(save_path), "method": "Clicked production Save, freed the scene, instantiated the ordinary main scene with the same earned save path before add_child; ordinary _ready loaded it."}
	verify(preserved, "Actual persisted earned build survives normal scene startup")
	await wait_seconds(4.0)
	capture("22-same-earned-save-reopened")
	await wardrobe("equipment")
	await click("slot_weapon")
	await wait_seconds(3.0)
	capture("23-crafted-fan-survives-reload")

func snapshot() -> Dictionary:
	if not is_instance_valid(scene): return {}
	var s = scene.state
	return {"seconds": s.lifetime_seconds, "realm": s.realm, "qi": s.qi, "herbs": s.herbs, "dew": s.dew, "merit": s.merit,
		"materials": plain(s.materials.to_dict()), "inventory": plain(s.inventory), "equipped": s.equipped.duplicate(),
		"victories": s.total_victories, "clears": s.stage_clears.duplicate(), "claims": s.chapter_reward_claimed.duplicate(),
		"quests": s.quest_claimed.duplicate(), "counters": s.counters.duplicate(), "techniques": s.technique_levels.duplicate(),
		"meridians": s.meridian_opened.duplicate(), "auto": s.auto_advance, "chests": s.chest_count,
		"heart": s.equipped_heart, "weapon_art": s.equipped_weapon_art, "actives": s.equipped_actives.duplicate(), "passives": s.equipped_passives.duplicate(),
		"activity": s.activity, "stage": plain(s.stage_status()), "duel_seconds": scene.duel.elapsed, "hero_hp": scene.duel.hero_hp,
		"enemy_hp": scene.duel.enemy_hp, "phase": scene.encounter_phase, "world": scene.world_route,
		"character_x": scene.character_x, "character_y": scene.character_y, "rendered_scale": scene.rendered_stage_scale,
		"drawer": scene.drawer_name, "wardrobe_tab": scene.wardrobe_tab, "journey": plain(s.player_journey_status()) if s.has_method("player_journey_status") else {}}

func capture(id: String) -> void:
	if captures.has(id): return
	captures[id] = clock
	if headless: return
	var texture := root.get_texture()
	if texture != null:
		var frame := texture.get_image()
		if frame != null and not frame.is_empty(): frame.save_png(output.path_join(id + ".png"))

func verify(value: bool, label: String) -> bool:
	if not value: fail(label)
	return value

func fail(label: String) -> void:
	if finished: return
	failed = true; errors.append(label); push_error("CONTINUOUS_JOURNEY: " + label)
	capture("failure-screen")
	finish()

func write_progress() -> void:
	var file := FileAccess.open(output.path_join("progress.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"seconds": clock, "title": segment_title, "failed": failed, "finished": finished, "actions": actions.size(), "state": snapshot(), "errors": errors}, "\t")); file.close()

func finish() -> void:
	if finished: return
	finished = true
	var frozen := true
	for path in source_hashes:
		if source_hashes[path] != FileAccess.get_sha256("res://" + path): frozen = false
	var report := {"schema": 1, "failed": failed, "errors": errors, "seconds": clock, "wall_seconds": (Time.get_ticks_msec() - wall_start)/1000.0,
		"mode": "headless driver preflight" if headless else "continuous native render", "intro_only": intro_only, "smoke_only": smoke_only,
		"engine": Engine.get_version_info(), "display_server": DisplayServer.get_name(), "source_frozen": frozen, "source_sha256": source_hashes,
		"initial": initial, "final": snapshot(), "milestones": milestones, "reload": reload_proof, "segments": segments,
		"actions": actions, "observations": observations, "captures": captures, "observed_fights": seen_fights.size(), "observed_searches": seen_searches.size(),
		"note": "Fresh save allocated before main scene enters tree. No seeded RNG, checkpoint preloads, awarded resources, flags, forced HP, timers, duel stepping, or signal emission. Every action is a production control's live global rectangle plus InputEventMouseMotion and mouse down/up, delivered through Godot's input dispatcher. Waiting runs the ordinary production _process. Full native film preserves all elapsed gameplay at ordinary speed; overlay is recording annotation only. Reload uses only the same save earned during this run."}
	var file := FileAccess.open(output.path_join("complete-player-journey.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(plain(report), "\t")); file.close()
	write_progress()
	print("COMPLETE_PLAYER_JOURNEY_DONE seconds=%.3f failed=%s actions=%d source_frozen=%s" % [clock, failed, actions.size(), frozen])
	if failed:
		quit(1); return
	if is_instance_valid(scene): scene.queue_free(); scene = null
	await process_frame
	await process_frame
	quit(0)

func plain(value: Variant) -> Variant:
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value:
			if typeof(value[key]) == TYPE_OBJECT: continue
			result[str(key)] = plain(value[key])
		return result
	if value is Array:
		var result: Array = []
		for item in value:
			if typeof(item) != TYPE_OBJECT: result.append(plain(item))
		return result
	return value
