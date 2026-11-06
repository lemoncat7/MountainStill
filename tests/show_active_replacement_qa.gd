extends SceneTree
## Explicit synthetic interaction fixture. F6 toggles 960x320 / 960x540,
## F7 prepares the authored one-slot case; F4 saves current viewport evidence.
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var label: Label
var last_state := ""
var captures := 0
var output := ""
func _initialize(): call_deferred("run")
func select(id: String):
	scene.drawer_name = "wardrobe"; scene.drawn_page = "wardrobe"; scene.wardrobe_tab = "technique"
	scene.set_meta("ink_manual_filter", "all")
	var rows: Array = scene.state.technique_rows()
	for i in range(rows.size()):
		if str(rows[i].id) == id: scene.set_meta("ink_manual_page", i / Ink.MANUALS_PER_PAGE); break
	Ink._manual_inspect(scene,id)
	scene._refresh_drawer(true)
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	root.min_size = Vector2i(960,320); root.size = Vector2i(960,320)
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = "user://SYNTHETIC_active_replacement_gui.json"
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.state.realm = 9; scene.state.herbs = 1000; scene.state.dew = 1000; scene.state.qi = 1000
	scene.state.attuned_techniques.assign(["mist","breath","barrier","mending","petal","body","ember"])
	for id in scene.state.attuned_techniques: scene.state.technique_levels[id] = 1
	scene.state.equipped_actives.assign(["mist","barrier"]); scene.state.equipped_passives.assign(["body"])
	scene.state.equipped_heart = "breath"; scene.state.equipped_weapon_art = "mist"
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true; scene.strip = true
	scene.state.settings.ui_scale = 1.0; scene.state.settings.transparent = false
	# Opaque light QA backing keeps synthetic labels readable. This is fixture
	# presentation only, never a claim about native desktop transparency.
	scene.get_window().transparent = false; root.transparent_bg = false
	RenderingServer.set_default_clear_color(Color("e8e7df"))
	root.min_size = Vector2i(960,320); root.size = Vector2i(960,320); root.position = Vector2i(190,150)
	select("mending")
	label = Label.new(); label.position = Vector2(14,18); label.add_theme_font_override("font",scene.SANS)
	label.add_theme_font_size_override("font_size",14); label.add_theme_color_override("font_color",Color("263b2e")); label.text = "合成夹具 · 非自然游玩\nF6 切换高度 · F7 单格\nF4 留存当前画面"; label.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(label)
	root.title = "SYNTHETIC · MountainStill active replacement QA"
	root.window_input.connect(func(event):
		if not event is InputEventKey or not event.pressed or event.echo: return
		if event.keycode == KEY_F6:
			root.min_size = Vector2i(960,320); root.size = Vector2i(960,540) if root.size.y == 320 else Vector2i(960,320)
			scene.strip = root.size.y == 320; scene._refresh_drawer(true)
		elif event.keycode == KEY_F7:
			scene.state.realm = 1; scene.state.equipped_actives.assign(["mist"]); scene.state.equipped_passives.clear(); select("petal")
		elif event.keycode == KEY_F4: capture.call_deferred())
	print("SYNTHETIC ACTIVE REPLACEMENT READY root=",root.size," min=",root.min_size)
func _process(_delta: float) -> bool:
	if not is_instance_valid(scene): return false
	scene._sync_drawer_visuals(); scene.queue_redraw()
	var signature := str([root.size,scene.state.equipped_actives,scene.get_meta("active_replacement",{}),scene.wardrobe_tab,scene.get_meta("ink_technique_id","")])
	if signature != last_state:
		last_state = signature; print("SYNTHETIC GUI STATE ",signature)
	return false
func capture():
	if output.is_empty(): return
	await RenderingServer.frame_post_draw
	captures += 1
	var path := output.path_join("active-replacement-%02d-%dx%d.png" % [captures,root.size.x,root.size.y])
	root.get_texture().get_image().save_png(path)
	print("SYNTHETIC GUI CAPTURE ",path)
