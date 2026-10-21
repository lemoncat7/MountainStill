extends "res://tests/show_complete_player_journey.gd"
## Separate process-start proof. This never substitutes for the fresh-play film.
## It reads only that completed film's exact earned save through ordinary _ready.
var expected_path := ""
var expected: Dictionary = {}
var loaded_save_sha256 := ""
var preserved_keys: Array[String] = []

func run() -> void:
	wall_start = Time.get_ticks_msec()
	output = "/tmp/complete-player-restart"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--earned="): save_path = arg.trim_prefix("--earned=")
		if arg.begins_with("--expected="): expected_path = arg.trim_prefix("--expected=")
	headless = DisplayServer.get_name() == "headless"
	DirAccess.make_dir_recursive_absolute(output)
	if not FileAccess.file_exists(save_path) or not FileAccess.file_exists(expected_path):
		fail("Require the completed walkthrough's exact earned save and report"); return
	expected = JSON.parse_string(FileAccess.get_file_as_string(expected_path))
	if not verify(not bool(expected.get("failed", true)) and bool(expected.get("source_frozen", false)) and int(expected.get("final", {}).get("victories", 0)) == 18, "Only a successful complete earned run may be reopened"): return
	loaded_save_sha256 = FileAccess.get_sha256(save_path)
	source_hashes = expected.source_sha256
	load_scene()
	await process_frame
	initial = snapshot()
	preserved_keys.assign(["realm", "herbs", "dew", "materials", "inventory", "equipped", "victories", "clears", "claims", "quests", "counters", "techniques", "meridians", "auto", "chests", "heart", "weapon_art", "actives", "passives"])
	for key in preserved_keys:
		# The reference report was parsed as JSON numbers (floats). Normalize the
		# observed value through the same JSON representation before deep equality.
		var observed: Variant = JSON.parse_string(JSON.stringify(plain(initial[key])))
		if not verify(observed == expected.final[key], "Process restart preserved " + key): return
	if not verify(scene.state.chapter_status().ending_complete, "Ending remains written after a new process starts"): return
	create_overlay()
	mark("独立进程重启复验 · 同一份已完成存档", "直接打开连续实录留下的原文件；没有新建或改写资源")
	await wait_seconds(3.0)
	capture("restart-01-earned-home")
	await show_guide()
	await wait_seconds(3.0)
	capture("restart-02-complete-guide")
	await wardrobe("equipment")
	await click("slot_weapon")
	await wait_seconds(4.0)
	capture("restart-03-crafted-fan")
	await open_book("practice")
	await click("journal_journal")
	await click("journal_ending")
	await wait_seconds(5.0)
	capture("restart-04-six-chapters-ending")
	finish()

func finish() -> void:
	if finished: return
	finished = true
	var frozen := true
	for path in source_hashes:
		if source_hashes[path] != FileAccess.get_sha256("res://" + path): frozen = false
	var report := {"schema": 1, "mode": "separate native process restart proof", "failed": failed, "errors": errors,
		"display_server": DisplayServer.get_name(), "engine": Engine.get_version_info(), "seconds": clock,
		"wall_seconds": (Time.get_ticks_msec() - wall_start)/1000.0, "source_frozen": frozen,
		"earned_save_path": save_path, "loaded_save_sha256": loaded_save_sha256, "expected_report_path": expected_path,
		"preserved_keys": preserved_keys, "initial": initial, "final": snapshot(), "actions": actions, "captures": captures,
		"natural_startup_deltas_from_continuous_final": {"qi": float(initial.get("qi", 0.0)) - float(expected.get("final", {}).get("qi", 0.0)), "merit": float(initial.get("merit", 0.0)) - float(expected.get("final", {}).get("merit", 0.0)), "lifetime_seconds": float(initial.get("seconds", 0.0)) - float(expected.get("final", {}).get("seconds", 0.0))},
		"startup_delta_note": "Qi, merit and lifetime are intentionally not equality-constrained: ordinary production save/startup timing and capped offline accrual remain enabled. No pause flag or clock adjustment is injected.",
		"note": "A new Godot OS process loaded the continuous walkthrough's exact earned save through ordinary main-scene startup. No checkpoint fixture, copied replacement save, injected resources, seeded RNG, forced state, or direct signal actions. This short proof is separate from the continuous fresh-play movie."}
	var file := FileAccess.open(output.path_join("process-restart-proof.json"), FileAccess.WRITE)
	if file: file.store_string(JSON.stringify(plain(report), "\t")); file.close()
	print("PROCESS_RESTART_PROOF_DONE failed=%s source_frozen=%s seconds=%.3f" % [failed, frozen, clock])
	if is_instance_valid(scene): scene.queue_free(); scene = null
	await process_frame
	await process_frame
	quit(1 if failed else 0)
