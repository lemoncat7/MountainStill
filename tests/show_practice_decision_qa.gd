extends SceneTree
## Explicit synthetic interaction fixture. Not a natural-growth, balance,
## desktop-compositor, Windows/macOS or performance acceptance test.
## F6: 960x320/540. F7: next authored condition. F4: viewport evidence.
var scene
var label: Label
var output := ""
var captures := 0
var fixture := 0
var last_state := ""
const CASES := ["节气留气", "兵器与疗伤", "冷却与护盾", "实际开场"]
func _initialize(): call_deferred("run")
func prepare():
	if scene.practice_session != null: scene.end_practice()
	scene.state.realm = 9; scene.state.attuned_techniques.clear()
	for id in scene.state.Content.TECHNIQUES:
		scene.state.attuned_techniques.append(id); scene.state.technique_levels[id] = 1
	scene.state.equipped_heart = "breath"; scene.state.equipped_weapon_art = ""
	scene.state.equipped_passives.clear(); scene.state.equipped_actives.assign(["ember","barrier"])
	scene.state.combat_tactic = "frugal" if fixture == 0 else "balanced"
	scene.state.gear.unequip_slot("weapon")
	if fixture != 1: scene.state.gear.equip_item(1)
	if fixture == 1: scene.state.equipped_actives.assign(["mist","mending"])
	elif fixture == 2: scene.state.equipped_actives.assign(["frost","barrier"])
	scene.start_practice("bamboo_guardian")
	scene.PracticeHost.advance(scene, .2)
	scene.toggle_practice_pause()
	if fixture != 3:
		# Explicit synthetic battle-state cases. Every displayed reason still
		# comes from the actual unchanged engine's current predicates/policy.
		scene.duel._must_basic = false
		scene.duel._qi_max = 40.0; scene.duel._qi_regen = 0.0
		scene.duel._qi_base = 20.0 if fixture == 0 else 40.0; scene.duel._qi_anchor = scene.duel.elapsed
		if fixture == 0: scene.duel._skills.active_0.qi_cost = 18.0
		elif fixture == 2:
			scene.duel._cooldowns.frost = scene.duel.elapsed + 4.2
			scene.duel._shield = 18; scene.duel._shield_until = scene.duel.elapsed + 10.0
	label.text = "合成夹具 · 非自然游玩\nF6 高度 · F7 " + CASES[fixture] + "\nF4 保存画面"
	scene.queue_redraw()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	root.min_size = Vector2i(960,320); root.size = Vector2i(960,320)
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = "user://SYNTHETIC_practice_decision_gui.json"
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.state.gear.inventory.append(scene.state.gear._make_item(1,"weapon_sword","common",1))
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true
	scene.strip = true; scene.state.settings.ui_scale = 1.0; scene.state.settings.transparent = false
	# Opaque light QA backing only; production transparent settings unchanged.
	scene.get_window().transparent = false; root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color("e8e7df"))
	root.min_size = Vector2i(960,320); root.size = Vector2i(960,320); root.position = Vector2i(140,120)
	label = Label.new(); label.position = Vector2(14,92); label.add_theme_font_override("font",scene.SANS)
	label.add_theme_font_size_override("font_size",14); label.add_theme_color_override("font_color",Color("263b2e")); label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(label)
	root.title = "SYNTHETIC · MountainStill practice decision QA"
	root.window_input.connect(func(event):
		if not event is InputEventKey or not event.pressed or event.echo: return
		if event.keycode == KEY_F6:
			root.min_size = Vector2i(960,320); root.size = Vector2i(960,540) if root.size.y == 320 else Vector2i(960,320)
			scene.strip = root.size.y == 320; scene._refresh_drawer(true)
		elif event.keycode == KEY_F7:
			fixture = (fixture + 1) % CASES.size(); prepare()
		elif event.keycode == KEY_F4: capture.call_deferred())
	prepare()
	print("SYNTHETIC PRACTICE DECISION READY root=",root.size," min=",root.min_size)
func _process(delta: float) -> bool:
	if not is_instance_valid(scene): return false
	if scene.practice_session != null: scene.PracticeHost.advance(scene,delta)
	else: scene._sync_drawer_visuals(); scene.queue_redraw()
	var signature := str([root.size,fixture,scene.drawer_name,scene.get_meta("practice_decision_generation",0),scene.PracticeHost.decision_open(scene),scene.practice_session.status() if scene.practice_session != null else {}])
	if signature != last_state:
		last_state = signature
		if scene.practice_session == null or not scene.practice_session.status().running: print("SYNTHETIC GUI STATE ",signature)
	return false
func capture():
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	captures += 1
	var path := output.path_join("practice-decision-%02d-%dx%d.png" % [captures,root.size.x,root.size.y])
	root.get_texture().get_image().save_png(path)
	print("SYNTHETIC GUI CAPTURE ",path)
