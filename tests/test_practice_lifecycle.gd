extends SceneTree
var scene
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func run():
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://practice_lifecycle_%d.json" % OS.get_process_id()
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game()
	scene.state.settings.click_through = true; scene.strip = true
	scene.drawer_name = "wardrobe"; scene.drawn_page = "wardrobe"
	scene.set_meta("combat_insight_open", true); scene.set_meta("combat_insight_view", "enemies")
	scene._refresh_drawer(true)
	check(scene.start_practice("bamboo_sprite"), "start from open book")
	await create_timer(.8).timeout
	check(not scene.desktop.desired_passthrough, "closing tween cannot restore passthrough during trial")
	scene._resized()
	for key in scene.buttons:
		var button = scene.buttons[key]
		if is_instance_valid(button) and button is BaseButton and not str(key).begins_with("practice_"):
			check(button.disabled, "resize locks " + str(key))
	check(is_equal_approx(scene.encounter_enemy_x-scene.character_x,88.0), "ordinary enemy uses formal engagement geometry")
	for i in range(1300): scene._process(.1)
	check(scene.practice_session.status().finished, "real trial finished")
	check(not scene.desktop.desired_passthrough and scene.drawer_name == "wardrobe", "result book remains interactive")
	var report: Dictionary = scene.practice_session.report()
	scene.end_practice()
	check(scene.practice_previous_reports.get("bamboo_sprite") == report, "completed report retained only in memory")
	check(scene.start_practice("bamboo_sprite"), "same enemy reentry")
	check(scene.practice_comparison == report, "comparison uses same enemy only")
	scene._process(.1); scene.end_practice()
	check(scene.practice_previous_reports.get("bamboo_sprite") == report, "cancel cannot replace completed record")
	check(scene.start_practice("bamboo_guardian"), "boss reentry")
	check(scene.practice_comparison.is_empty(), "different enemy never compared")
	check(is_equal_approx(scene.encounter_enemy_x-scene.character_x,120.0), "boss formal engagement geometry")
	scene.end_practice()
	check(scene.encounter_stage_name.is_empty(), "formal stage label restored")
	check(not scene.desktop.desired_passthrough, "returned open book is interactive")
	scene.queue_free(); await process_frame
	print("Practice lifecycle: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
