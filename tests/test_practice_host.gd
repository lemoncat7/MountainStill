extends SceneTree
var scene
var checks := 0
var failures := 0
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func snapshot() -> String:
	var data: Dictionary = scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)
func run():
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://practice_host_%d.json" % OS.get_process_id()
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game()
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	var before: String = snapshot()
	check(scene.practice_can_start().is_empty(), "home can practice")
	var rows: Array = scene.practice_enemy_rows()
	check(rows.size() == 8, "3 enemies plus 5 locked route placeholders")
	check(not scene.start_practice("stream_sprite"), "locked enemy rejected")
	check(snapshot() == before, "locked entry read only")
	var formal_duel = scene.duel
	var character_x = scene.character_x
	for is_paused in [false, true]:
		scene.paused = is_paused
		before = snapshot()
		check(scene.start_practice("bamboo_sprite"), "start practice paused=" + str(is_paused))
		check(scene.duel != formal_duel, "independent real engine")
		check(not scene._save_current(), "save blocked during practice")
		scene._persist_battle_resources()
		var original_activity = scene.state.activity
		var input = InputEventKey.new(); input.keycode = KEY_G; input.pressed = true
		scene._input(input)
		check(scene.state.activity == original_activity, "world keyboard blocked")
		check(scene.buttons.garden.disabled, "world garden button disabled")
		for i in range(20): scene._process(.1)
		check(not scene.combat_number.is_empty(), "actual contact feedback reaches presentation")
		scene._set_paused(not is_paused)
		check(scene.paused == is_paused, "formal pause mutation blocked")
		scene._record_combat_report("victory")
		check(scene.state.combat_reports.is_empty(), "formal report mutation blocked")
		scene.toggle_practice_pause()
		var elapsed: float = scene.practice_session.status().elapsed
		for i in range(20): scene._process(.1)
		check(is_equal_approx(elapsed, scene.practice_session.status().elapsed), "practice pause")
		scene.toggle_practice_pause()
		for i in range(1300): scene._process(.1)
		check(scene.practice_session.status().finished, "bounded completion")
		check(snapshot() == before, "full formal save unchanged after trial")
		check(scene.start_practice("bamboo_sprite"), "repeat finished trial")
		for i in range(3): scene._process(.1)
		scene.end_practice()
		check(scene.practice_session == null, "end releases session")
		check(scene.duel == formal_duel, "formal engine restored")
		check(scene.character_x == character_x and scene.paused == is_paused, "presentation and pause restored")
		check(snapshot() == before, "formal state unchanged after repeat/cancel")
		check(not scene.buttons.garden.disabled, "navigation restored")
	scene.state.stage_run = {"id": "bamboo_pass"}
	check(not scene.start_practice("bamboo_sprite"), "pending route rejected")
	scene.state.stage_run = {}; scene.state.pending_heart_switch = {"id": "mist"}
	check(not scene.start_practice("bamboo_sprite"), "pending heart switch rejected")
	scene.queue_free(); await process_frame
	print("Practice host: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
