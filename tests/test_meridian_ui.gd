extends SceneTree
## Actual paper callbacks, branch navigation, bounded geometry and live-duel lock.
var scene
var checks := 0
var failures := 0
var save_path := "user://meridian_ui_%d.json" % OS.get_process_id()

func _initialize() -> void:call_deferred("run")
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func press(key: String) -> void:
	var b = scene.buttons.get(key)
	check(is_instance_valid(b), "button exists " + key)
	if is_instance_valid(b):
		check(not b.disabled, "button enabled " + key)
		if not b.disabled:b.pressed.emit()
func geometry(label: String) -> void:
	var paper: Rect2 = scene._drawer_rect()
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton:
			check(paper.encloses(Rect2(child.position, child.size)), "inside paper " + label + " / " + child.text)
			controls.append(child)
	for i in range(controls.size()):
		for j in range(i + 1, controls.size()):
			check(not Rect2(controls[i].position, controls[i].size).intersects(Rect2(controls[j].position, controls[j].size)), "distinct hit areas " + label + " / " + controls[i].text + " / " + controls[j].text)
func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state.realm = 14
	scene.state.qi = 100000.0
	scene.state.herbs = 10000
	scene.state.dew = 10000
	scene.character_x = 520.0
	scene.character_y = 230.0
	scene.meditation_amount = 1.0
	scene._toggle_drawer("wardrobe")
	press("wardrobe_meridian")
	check(scene.buttons.has("meridian_row_baihui") and not scene.buttons.has("meridian_row_fengchi"), "central six only, never 22 cramped controls")
	var world := [scene.character_x, scene.character_y, scene.meditation_amount, scene.world_route, scene._scene_camera_transform()]
	for width in [1000, 1200, 1360]:
		scene.size = Vector2(width, 320)
		for branch in scene.state.Content.MERIDIAN_BRANCH_ORDER:
			press("meridian_branch_" + branch)
			geometry("%s / %d" % [branch, width])
			var count := 0
			for key in scene.buttons:
				if str(key).begins_with("meridian_row_"):count += 1
			check(count == (6 if branch == "central" else 4), "only selected branch's nodes are interactive")
	check(world == [scene.character_x, scene.character_y, scene.meditation_amount, scene.world_route, scene._scene_camera_transform()], "branch browsing preserves independent root portrait and world camera")
	scene.size = Vector2(1200, 320)
	press("meridian_branch_central")
	press("meridian_row_qihai")
	var stale = scene.buttons.unlock_meridian
	press("unlock_meridian")
	check(scene.state.meridian_count == 1 and scene.state.qi == 99970.0 and scene.buttons.unlock_meridian.disabled, "real callback charges root once")
	if is_instance_valid(stale):stale.pressed.emit()
	check(scene.state.meridian_count == 1 and scene.state.qi == 99970.0, "removed stale callback cannot charge twice")
	press("meridian_branch_edge")
	press("meridian_row_shangyang")
	press("unlock_meridian")
	check(scene.state.stats().break_bonus == 0.08 and scene.state.meridian_node_ids() == ["qihai", "shangyang"], "branch callback buys actual chosen combat effect")
	press("meridian_row_quchi")
	press("unlock_meridian")
	press("meridian_row_jianjing")
	check(scene.buttons.unlock_meridian.disabled, "diamond tip waits for both branches")
	press("meridian_branch_quiet")
	press("meridian_row_laogong")
	press("unlock_meridian")
	check(scene.state.brew_multiplier() == 1.04, "quiet utility is actually consumed by brewing")
	press("meridian_branch_edge")
	check(scene.get_meta("meridian_id") == "jianjing", "returning to a branch restores its inspected node")
	press("meridian_row_hegu")
	check(not scene.buttons.unlock_meridian.disabled, "pending node ready before duel")
	scene.encounter_active = true
	scene.encounter_phase = "fight"
	scene._refresh_drawer()
	check(scene.buttons.unlock_meridian.disabled and scene.buttons.unlock_meridian.text == "交锋后通脉", "live duel blocks stat mutation while allowing browsing")
	var before := [scene.state.qi, scene.state.herbs, scene.state.dew, scene.state.meridian_node_ids()]
	scene.buttons.unlock_meridian.pressed.emit()
	check(before == [scene.state.qi, scene.state.herbs, scene.state.dew, scene.state.meridian_node_ids()], "forced signal cannot mutate live duel build")
	press("meridian_branch_flow")
	check(scene.buttons.has("meridian_row_fengchi"), "live duel still permits branch inspection")
	scene.encounter_active = false
	scene.encounter_phase = "idle"
	scene._refresh_drawer()
	press("meridian_branch_edge")
	check(scene.state.stats().combat_haste == 0.0, "closing fight does not auto-apply inspected node")
	press("unlock_meridian")
	check(is_equal_approx(scene.state.stats().combat_haste, 0.04), "manual post-duel purchase applies next combat's haste")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):DirAccess.remove_absolute(save_path + suffix)
	print("Meridian UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
