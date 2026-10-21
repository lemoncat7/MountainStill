extends SceneTree
var failures := 0
func check(value: bool, label: String) -> void:
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	_run.call_deferred()
func _run() -> void:
	var boot = load("res://bootstrap.tscn").instantiate()
	root.add_child(boot)
	for i in range(8): await process_frame
	var game = current_scene
	check(game != null, "bootstrap starts gameplay")
	game._open_updates()
	var panel = game.update_panel
	check(panel.visible, "settings opens updater")
	check(panel.info.text.contains("1.3.9-test.1"), "version visible")
	check(not panel.check_button.disabled, "check enabled idle")
	check(panel.download_button.disabled, "download disabled without candidate")
	check(panel.apply_button.disabled, "apply disabled without staged update")
	panel.hide()
	game._open_updates()
	check(game.update_panel == panel, "reopen reuses panel")
	var service = root.get_node("UpdateService")
	service.busy = true
	service.changed.emit()
	check(panel.selector.disabled and panel.check_button.disabled and panel.apply_button.disabled, "busy UI prevents overlapping commands")
	check(not panel.cancel_button.disabled, "cancel remains available")
	service.cancel()
	check(not panel.check_button.disabled, "cancel restores UI")
	panel._confirm_apply()
	check(panel.confirmation.visible, "apply asks before mutation")
	panel.confirmation.hide()
	check(not FileAccess.file_exists("user://updates/active.json"), "dismissing confirmation does not activate")
	# Verified narrow content applies to the SAME game/state instance, not a mock.
	var old_game_id = game.get_instance_id()
	var old_state = game.state
	var old_version = root.get_meta("update_store").current_version()
	var data = {"schema": 1, "accent": "#276b99", "message": "热加载实证：青山仍在，墨色已新。"}
	var text = JSON.stringify(data)
	var hash_value = text.sha256_text()
	var path = "user://updates/" + hash_value + ".json"
	var file = FileAccess.open(path, FileAccess.WRITE); file.store_string(text); file.close()
	var record = {"schema":1,"bootstrap":1,"save_schema":4,"engine":"4.6.3","version":"1.3.9-test.2","platform":"windows","kind":"content_json","restart_required":false,"sha256":hash_value,"size":text.to_utf8_buffer().size(),"path":path}
	file = FileAccess.open("user://updates/pending.json", FileAccess.WRITE); file.store_string(JSON.stringify(record)); file.close()
	panel._refresh()
	check(panel.apply_button.text == "热加载内容", "hot content distinguished from restart")
	panel._confirm_apply()
	panel._apply()
	check(game.get_instance_id() == old_game_id and game.state == old_state, "same process scene and state retained")
	check(game.GOLD == Color("#276b99") and game.content_accent == Color(Color("#276b99"), .65), "actual rendered ink colors replaced")
	check(game.toast == data.message, "actual game message replaced")
	check(root.get_meta("update_store").current_version() == old_version and service.content_version == "1.3.9-test.2", "content version separate; no fake game upgrade")
	check(not FileAccess.file_exists("user://updates/pending.json"), "hot apply consumes pending")
	DirAccess.remove_absolute("user://updates/content-active.json")
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	paused = true
	var stopped_elapsed = game.elapsed
	panel._recovery_failure("fixture: interrupted restore")
	for i in range(3): await process_frame
	check(paused and game.elapsed == stopped_elapsed, "partial transaction recovery freezes gameplay")
	check(panel.apply_button.disabled and panel.check_button.disabled, "failed transaction cannot continue mutation")
	check(game.closing and not game._save_current(), "signal-driven quit/save blocked after partial transaction")
	print("UPDATE_PANEL: 21 checks, ", failures, " failures")
	quit(failures)
