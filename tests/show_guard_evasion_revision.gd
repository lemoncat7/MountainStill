extends SceneTree
## Native 1200x320 / 60 fps proof. This is a labeled TEST FIXTURE:
## supplied common gear, enemy HP extended, qi/regen fixed at zero.
## Production DuelTimeline chooses every attack and defense from a searched
## deterministic seed; no result, pose, contact, or damage is forced.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var scene
var banner: Label
var details: Label
var output := "/tmp/guard-evasion-proof"
var proof := false
var clock := 0.0
var route := ""
var last_contact := ""
var events: Array = []
var sections: Array = []
var captures: Dictionary = {}
var selected_seeds: Dictionary = {}
var starting_stats: Dictionary = {}
var failed := false
var running := false
var captures_enabled := true
var comparison_mode := false
var comparison_recorded := false
var pose_samples: Dictionary = {}

func _initialize() -> void:
	call_deferred("start")

func start() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg == "--proof": proof = true
		if arg == "--comparison": comparison_mode = true
	DirAccess.make_dir_recursive_absolute(output)
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://guard_evasion_fixture_isolated.json"
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
	for template in ["head_pin", "chest_blue", "legs_blue", "weapon_sword"]:
		var id: int = scene.state.gear.inventory.size() + 1
		scene.state.gear.inventory.append(scene.state.gear._make_item(id, template, "common", 1))
		scene.state.gear.equip_item(id)
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
	for id in ["bamboo_pass", "cloud_slope"]:
		selected_seeds[id] = choose_seed(id)
		if int(selected_seeds[id]) < 0:
			push_error("NO_NATURAL_GUARD_DODGE_SEED " + id)
			failed = true
	if failed:
		finish()
		return
	if proof:
		scene.set_process(false)
		for id in ["bamboo_pass", "cloud_slope"]:
			begin_fight(id)
			for frame in range(20 * 60):
				scene._process(1.0 / 60.0)
				observe(1.0 / 60.0)
		finish()
		return
	if comparison_mode:
		begin_fight("bamboo_pass")
		return
	title("测试夹具 · 原生实机 / 正常速度 / 真实属性页", "临时配置普通衣冠与青锋剑；未装主动功法；后续敌方气血延长、战斗真气归零")
	scene.wardrobe_tab = "equipment"
	scene.selected_item = 4
	scene.selected_slot = "weapon"
	scene._toggle_drawer("wardrobe")
	await create_timer(4.5).timeout
	await capture("actual-stats-panel")
	scene._close_drawer()
	await create_timer(0.8).timeout
	begin_fight("bamboo_pass")
	await create_timer(20.0).timeout
	begin_fight("cloud_slope")
	await create_timer(20.0).timeout
	running = false
	scene.encounter_active = false
	scene.encounter_phase = ""
	scene.duel_pose = {}
	scene.world_route = ""
	scene.duel.cancel()
	title("实机验证 · 斩、刺、挑 / 持剑格挡 / 闪避零伤害", "测试夹具；所有交锋结果来自真实接触与固定随机种子；属性页显示同一份战斗数据")
	scene.wardrobe_tab = "equipment"
	scene._toggle_drawer("wardrobe")
	await create_timer(5.0).timeout
	await capture("actual-stats-panel-ending")
	finish()

func fixture_hero() -> Dictionary:
	var hero: Dictionary = scene.state.stats().duplicate(true)
	hero.hp = int(hero.max_hp)
	hero.combat_qi_regen = 0.0
	hero.battle_resources = {"qi": 0.0, "cooldowns": {}}
	return hero

func fixture_enemy(id: String) -> Dictionary:
	var enemy: Dictionary = Content.STAGES[id].monsters[0].duplicate(true)
	enemy.route_id = id
	enemy.hp = 10000
	enemy.max_hp = 10000
	enemy.engagement_distance = 88.0 * 1200.0 / 1040.0
	enemy.enemy_front_extent = maxf(24.0, -scene.BeastPresentation.visible_bounds(id + "_attack", 112.0).position.x)
	return enemy

func choose_seed(id: String) -> int:
	for seed_value in range(1, 257):
		var trial = Duel.new()
		trial.start(fixture_hero(), fixture_enemy(id), scene.state.technique, "sword", seed_value)
		var guard_seen := false
		var dodge_seen := false
		for frame in range(18 * 60):
			for event in trial.advance(1.0 / 60.0):
				if str(event.type) != "contact" or str(event.actor) != "enemy": continue
				if str(event.resolution) == "guard" and int(event.damage) < int(event.unguarded_damage) and str(trial.pose().hero.combat_phase) not in ["strike", "contact"]:
					guard_seen = true
				if str(event.resolution) == "dodge" and int(event.damage) == 0:
					dodge_seen = true
			if guard_seen and dodge_seen:
				print("FIXTURE_SEED route=%s seed=%d" % [id, seed_value])
				return seed_value
	return -1

func begin_fight(id: String) -> void:
	route = id
	last_contact = ""
	scene.world_route = id
	scene.encounter_index = 0
	scene.route_boss = false
	scene.route_distance = 190.0
	scene.route_scroll_velocity = 0.0
	scene.route_frame_velocity = 0.0
	scene.character_x = 390.0
	scene.character_y = 230.0
	scene.encounter_enemy_x = 478.0
	scene.encounter_active = true
	scene.encounter_phase = "fight"
	scene.encounter_phase_age = 0.0
	scene.encounter_clock = 0.0
	scene.combat_hitstop = 0.0
	scene.combat_impacts.clear()
	scene.hero_hit = 0.0
	scene.enemy_flash = 0.0
	scene.meditation_amount = 0.0
	scene.route_enemy_definition = fixture_enemy(id)
	scene.encounter_enemy_name = str(scene.route_enemy_definition.name)
	scene.encounter_stage_name = str(Content.STAGES[id].name)
	scene.route_target_distance = 190.0
	var hero := fixture_hero()
	scene.vitality_max = float(hero.max_hp)
	scene.vitality = scene.vitality_max
	scene.enemy_max_hp = 10000.0
	scene.enemy_hp = 10000.0
	scene.duel.start(hero, scene.route_enemy_definition, scene.state.technique, "sword", int(selected_seeds[id]))
	scene.duel_pose = scene.duel.pose()
	scene.side_motion.merge(scene.duel_pose.hero, true)
	scene.battle_resources = scene.duel.battle_resource_snapshot()
	running = true
	title("测试夹具 · " + str(Content.STAGES[id].name) + " / 普通剑招 / 无主动法术", "敌方气血延长至 10000；战斗真气与回气为零；种子 %d；格挡与闪避均自然判定" % int(selected_seeds[id]))
	sections.append({"time": clock, "route": id, "seed": selected_seeds[id], "hero": hero, "enemy": scene.route_enemy_definition.duplicate(true)})

func title(line: String, second: String) -> void:
	banner.text = line
	details.text = second

func _process(delta: float) -> bool:
	if not proof: observe(delta)
	return false

func observe(delta: float) -> void:
	if not is_instance_valid(scene): return
	clock += delta
	if not running or scene.encounter_phase != "fight": return
	var event: Dictionary = scene.duel._last_contact
	var contact := str(event.get("contact_id", ""))
	if contact.is_empty() or contact == last_contact: return
	last_contact = contact
	var record: Dictionary = event.duplicate(true)
	record.capture_time = clock
	record.route = route
	record.hero_pose = scene.duel_pose.get("hero", {}).duplicate(true)
	record.enemy_pose = scene.duel_pose.get("enemy", {}).duplicate(true)
	events.append(record)
	print("GUARD_EVASION_CONTACT " + JSON.stringify(record))
	if str(event.actor) == "hero":
		if not pose_samples.has(str(event.move)):
			pose_samples[str(event.move)] = scene.side_motion.duplicate(true)
		if str(event.get("action_kind", "")) != "basic":
			failed = true
			push_error("PAID_OR_NONBASIC_ACTION_IN_ORDINARY_SWORD_FIXTURE")
		if not proof and captures_enabled and not captures.has(str(event.move)):
			captures[str(event.move)] = clock
			capture(str(event.move))
	elif str(event.resolution) in ["guard", "dodge"]:
		var kind := str(event.resolution)
		var full_guard := kind == "guard" and str(scene.side_motion.get("combat_phase", "")) not in ["strike", "contact"]
		if not pose_samples.has(kind):
			pose_samples[kind] = scene.side_motion.duplicate(true)
		if full_guard and not pose_samples.has("guard_brace"):
			pose_samples.guard_brace = scene.side_motion.duplicate(true)
		var summary := "自然格挡：原伤害 %d → 实扣 %d" % [int(event.unguarded_damage), int(event.damage)] if kind == "guard" else "自然闪避：气血 %d → %d，实际伤害 0" % [int(event.hero_hp_before), int(event.hero_hp_after)]
		details.text = "测试夹具 · " + summary + " · 战斗真气 0 / 无主动法术"
		if kind == "dodge" and (int(event.damage) != 0 or event.hero_hp_before != event.hero_hp_after): failed = true
		if kind == "dodge" and event.has("planted_contact") and not bool(event.planted_contact.get("contact", false)): failed = true
		if kind == "guard" and int(event.damage) >= int(event.unguarded_damage): failed = true
		var name := route + "-" + kind
		if not proof and captures_enabled and not captures.has(name):
			captures[name] = clock
			capture(name)
		if comparison_mode and full_guard and not comparison_recorded:
			comparison_recorded = true
			scene.set_process(false)
			title("测试夹具 · 同一种子真实格挡接触帧", "采样真实接触后冻结画面供前后对照；普通剑 / 无主动法术 / 无护盾")
			capture_comparison()

func capture(name: String) -> void:
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var result := image.save_png(output.path_join(name + ".png"))
	if result != OK:
		failed = true
		push_error("PNG_CAPTURE_FAILED " + name)

func capture_comparison() -> void:
	await RenderingServer.frame_post_draw
	await capture("physical-sword-guard-comparison")
	finish()

func finish() -> void:
	running = false
	var moves := {}
	var guards := 0
	var dodges := 0
	for event in events:
		if str(event.actor) == "hero": moves[str(event.move)] = true
		elif str(event.resolution) == "guard": guards += 1
		elif str(event.resolution) == "dodge": dodges += 1
	if not comparison_mode:
		for move in ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"]:
			if not moves.has(move): failed = true
		if guards < 2 or dodges < 2: failed = true
	var report := {"fixture": true, "forced_contact_results": false, "forced_animation_poses": false, "ordinary_hero_stats": starting_stats, "qi_zero_regen_zero": true, "enemy_hp_extended": 10000, "native_speed": 1.0, "seconds": clock, "seeds": selected_seeds, "sections": sections, "events": events, "captures": captures, "guards": guards, "dodges": dodges, "moves": moves.keys(), "comparison": comparison_mode, "failed": failed}
	var file := FileAccess.open(output.path_join("guard-evasion-events.json"), FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	var samples := FileAccess.open(output.path_join("pose-samples.bin"), FileAccess.WRITE)
	if samples:
		samples.store_var(pose_samples, true)
		samples.close()
	var samples_json := FileAccess.open(output.path_join("pose-samples.json"), FileAccess.WRITE)
	if samples_json:
		samples_json.store_string(JSON.stringify(pose_samples, "\t"))
		samples_json.close()
	print("GUARD_EVASION_DONE " + JSON.stringify({"seconds": clock, "guards": guards, "dodges": dodges, "moves": moves.keys(), "failed": failed}))
	if is_instance_valid(scene): scene.queue_free()
	scene = null
	await process_frame
	await process_frame
	call_deferred("quit", 1 if failed else 0)
