extends "res://tests/show_guard_evasion_revision.gd"
## 33-second native render verification with temporary equipment and extended enemy HP.
## Continuous production gait, battle, grip, guard and inventory renderers.

func start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--proof": proof = true
		if arg == "--comparison": comparison_mode = true
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://side_proportion_fixture_isolated.json"
	root.add_child(scene)
	await process_frame
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state.equipped_heart = ""
	scene.state.equipped_weapon_art = ""
	scene.state.equipped_actives.clear()
	scene.state.equipped_passives.clear()
	# Owned, real item templates. No shoes keeps the paired visual sample's
	# defense seed identical to v1.3.2, before footwear gained evasion.
	for template in ["head_pin", "chest_jade", "legs_blue", "feet_boots", "weapon_sword", "weapon_fan"]:
		var id: int = scene.state.gear.inventory.size() + 1
		scene.state.gear.inventory.append(scene.state.gear._make_item(id, template, "common", 1))
		if id <= 5: scene.state.gear.equip_item(id)
	scene.state.settings.paused = false
	scene.paused = false
	scene.get_window().size = Vector2i(1200, 320)
	scene.get_window().transparent_bg = false
	scene.strip = true
	scene.desktop.transparent_enabled = true
	scene.show_combat_move_labels = false
	scene.toast_time = 0.0
	scene.character_x = 390.0
	scene.character_y = 230.0
	scene.meditation_amount = 0.0
	scene.meditation_settle = 0.0
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	banner = Label.new()
	banner.position = Vector2(17, 5)
	banner.add_theme_font_override("font", Sans)
	banner.add_theme_font_size_override("font_size", 11)
	banner.add_theme_color_override("font_color", Color("#354e43"))
	banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(banner)
	details = Label.new()
	details.position = Vector2(17, 22)
	details.add_theme_font_override("font", Sans)
	details.add_theme_font_size_override("font_size", 10)
	details.add_theme_color_override("font_color", Color("#506356"))
	details.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scene.add_child(details)

	starting_stats = scene.state.stats().duplicate(true)
	selected_seeds["bamboo_pass"] = choose_seed("bamboo_pass")
	if int(selected_seeds["bamboo_pass"]) < 0:
		failed = true; finish(); return
	# Bare body at actual scale, then the real travel/gait clock with no fight.
	for slot in ["head","chest","legs","feet","weapon"]: scene.state.gear.unequip_slot(slot)
	scene.world_route="bamboo_pass"
	scene.paused=true
	scene.side_motion={"phase":0.0,"blend":0.0,"facing":1.0,"attack_amount":0.0}
	title("侧身比例 · 素体站立 / 短颈衔接 / 正常角色尺寸", "原生实机测试夹具 · 同一原画与关节，未拉宽整个人物")
	await create_timer(2.0).timeout
	await capture("bare-standing")
	scene.paused=false;scene.encounter_active=true;scene.encounter_phase="travel"
	scene.encounter_index=0;scene.route_target_distance=10000.0
	scene.route_distance=0.0;scene.route_scroll_velocity=0.0
	title("侧身比例 · 素体连续步行 / 脚底承重", "原生实机测试夹具 · 山路与步态使用同一真实行程速度")
	await create_timer(4.0).timeout
	await capture("bare-walking")
	for id in range(1,6):scene.state.gear.equip_item(id)
	begin_fight("bamboo_pass")
	title("侧身比例 · 混搭衣装 / 真实持剑出招、格挡与闪避", "测试夹具 · 普通装备，敌方气血延长至 10000，战斗真气与回气为 0")
	await create_timer(18.0).timeout
	running=false;scene.encounter_active=false;scene.encounter_phase="";scene.duel_pose={};scene.duel.cancel()
	scene.world_route="";scene.paused=true
	scene.wardrobe_tab="equipment";scene.selected_item=5;scene.selected_slot="weapon"
	scene._toggle_drawer("wardrobe")
	title("行囊人物 · 青锋剑独立悬浮 / 双手自然垂落", "原生实机测试夹具 · 兵器与头发、手掌和纸页之间保留清晰间距")
	await create_timer(3.0).timeout
	await capture("inventory-sword")
	scene.state.gear.equip_item(6);scene.selected_item=6;scene._refresh_drawer();scene._sync_character_preview(0.0)
	title("行囊人物 · 换装折扇 / 兵器轻微上下浮动", "原生实机测试夹具 · 只影响行囊展示，战斗中的兵器仍跟随真实握持点")
	await create_timer(3.0).timeout
	await capture("inventory-fan")
	scene.state.gear.unequip_slot("weapon");scene._refresh_drawer();scene._sync_character_preview(0.0)
	title("行囊人物 · 卸下兵器 / 无残留", "原生实机测试夹具 · 人物站位和尺寸保持不变，外观与装备状态一致")
	await create_timer(3.0).timeout
	await capture("inventory-unequipped")
	finish()

func finish()->void:
	running=false
	var moves:={};var guards:=0;var dodges:=0
	for event in events:
		if str(event.actor)=="hero":moves[str(event.move)]=true
		elif str(event.resolution)=="guard":guards+=1
		elif str(event.resolution)=="dodge":dodges+=1
	for move in ["basic_sword_cut","basic_sword_thrust","basic_sword_lift"]:
		if not moves.has(move):failed=true
	if guards<1 or dodges<1:failed=true
	var report:={"fixture":true,"forced_contact_results":false,"forced_animation_poses":false,"native_speed":1.0,"seconds":clock,"seeds":selected_seeds,"sections":sections,"events":events,"captures":captures,"guards":guards,"dodges":dodges,"moves":moves.keys(),"failed":failed}
	var file:=FileAccess.open(output.path_join("side-proportion-events.json"),FileAccess.WRITE)
	file.store_string(JSON.stringify(report,"\t"));file.close()
	print("SIDE_PROPORTION_DONE "+JSON.stringify({"seconds":clock,"guards":guards,"dodges":dodges,"moves":moves.keys(),"failed":failed}))
	if is_instance_valid(scene):scene.queue_free()
	scene=null
	await process_frame;await process_frame
	call_deferred("quit",1 if failed else 0)
