extends SceneTree
## Native visual QA fixture, not a campaign-progress or target-OS claim.
var scene
var save_path := "user://meridian_visual_fixture_%d.json" % OS.get_process_id()
func _initialize() -> void:call_deferred("run")
func capture(name: String) -> void:
	await create_timer(1.1).timeout
	await RenderingServer.frame_post_draw
	var path := "user://meridian-" + name + ".png"
	root.get_texture().get_image().save_png(path)
	print("MERIDIAN_CAPTURE " + ProjectSettings.globalize_path(path))
func click(key: String) -> void:
	if is_instance_valid(scene.buttons.get(key)) and not scene.buttons[key].disabled:
		scene.buttons[key].pressed.emit()
func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state.realm = 6
	scene.state.qi = 100000
	scene.state.herbs = 1000
	scene.state.dew = 1000
	scene.get_window().transparent_bg = false
	scene.strip = true
	scene.desktop.transparent_enabled = true
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	for id in ["qihai", "guanyuan", "shenque", "shanzhong", "baihui", "shangyang", "hegu", "quchi", "jianjing", "lieque", "neiguan", "jianshi", "taixi", "zhaohai", "laogong"]:
		scene.state.unlock_meridian(id)
	scene._set_paused(true)
	scene.wardrobe_tab = "meridian"
	scene._toggle_drawer("wardrobe")
	for branch in scene.state.Content.MERIDIAN_BRANCH_ORDER:
		click("meridian_branch_" + branch)
		var selected: String = {"central": "baihui", "edge": "jianjing", "ward": "daling", "flow": "fengchi", "quiet": "mingmen"}[branch]
		click("meridian_row_" + selected)
		await capture(branch)
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):DirAccess.remove_absolute(save_path + suffix)
	quit()
