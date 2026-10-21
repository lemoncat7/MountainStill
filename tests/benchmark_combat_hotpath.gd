extends SceneTree
## Headless CPU-only benchmark. No draw submission, GPU, audio, or host UI.
## Exact same source, seed, inputs and tick count are used before and after.
const Duel = preload("res://scripts/duel_timeline.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
const STEP := 1.0 / 60.0
const SEED := 377
var tick_count := 480
var warmups := 2
var trials := 5
var label := "unlabeled"
var report_path := ""
var profile_mode := false
var profiler_script: Script

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--ticks="): tick_count = int(arg.trim_prefix("--ticks="))
		elif arg.begins_with("--warmups="): warmups = int(arg.trim_prefix("--warmups="))
		elif arg.begins_with("--trials="): trials = int(arg.trim_prefix("--trials="))
		elif arg.begins_with("--label="): label = arg.trim_prefix("--label=")
		elif arg.begins_with("--report="): report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--profiler="):
			profile_mode = true
			profiler_script = load(arg.trim_prefix("--profiler="))
	var results: Array = []
	var warmup_results: Array = []
	var started := Time.get_ticks_usec()
	for i in range(warmups):
		var result := run_trial()
		warmup_results.append(result)
		print("WARMUP ", label, " ", i + 1, " elapsed_ms=", result.total_ms)
	for i in range(trials):
		var result := run_trial()
		results.append(result)
		print("TRIAL ", label, " ", i + 1, " elapsed_ms=", result.total_ms, " tick_p50_us=", result.tick.p50_us, " tick_p95_us=", result.tick.p95_us, " pose_pct=", result.pose.total_us / result.tick.total_us * 100.0)
	var report := {"label": label, "engine": Engine.get_version_info(), "headless_cpu_only": true,
		"dt": STEP, "ticks": tick_count, "simulated_seconds": STEP * tick_count,
		"seed": SEED, "warmups": warmups, "trials": trials,
		"hero": hero_input(), "enemy": enemy_input(), "technique": "mist", "weapon": "sword",
		"warmup_results": warmup_results, "results": results,
		"source_sha256": source_hashes(), "wall_ms": (Time.get_ticks_usec() - started) / 1000.0,
		"metrics_note": "Times are headless CPU simulation/pose/rig cost, not rendered FPS. Live Object count excludes Dictionary/Array allocations; static bytes are retained-memory observations, not allocation counts."}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		if file == null:
			push_error("Cannot open benchmark report")
			quit(1)
			return
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	print("BENCHMARK_REPORT ", report_path)
	quit(0)

func hero_input() -> Dictionary:
	return {"hp": 420, "max_hp": 420, "attack": 11, "defense": 1}

func enemy_input() -> Dictionary:
	return {"hp": 780, "max_hp": 780, "attack": 8, "defense": 1, "boss": true, "route_id": "bamboo_pass", "dodge_chance": 0.0, "guard_chance": 0.0}

func run_trial() -> Dictionary:
	var object_before := int(Performance.get_monitor(Performance.OBJECT_COUNT))
	var memory_before := OS.get_static_memory_usage()
	var start_time := Time.get_ticks_usec()
	var duel = profiler_script.new() if profile_mode else Duel.new()
	duel.start(hero_input(), enemy_input(), "mist", "sword", SEED)
	var setup_us := Time.get_ticks_usec() - start_time
	if profile_mode: duel.profile_reset()
	var advance_samples := PackedFloat64Array()
	var pose_samples := PackedFloat64Array()
	var rig_samples := PackedFloat64Array()
	var tick_samples := PackedFloat64Array()
	var event_count := 0
	var contact_count := 0
	var action_count := 0
	var checksum := 0.0
	var early_finish := false
	var timed_start := Time.get_ticks_usec()
	for tick in range(tick_count):
		var t0 := Time.get_ticks_usec()
		var events: Array = duel.advance(STEP)
		var t1 := Time.get_ticks_usec()
		var pose: Dictionary = duel.pose()
		var t2 := Time.get_ticks_usec()
		var rig := Rig.sample_pose(pose.hero)
		var t3 := Time.get_ticks_usec()
		advance_samples.append(t1 - t0)
		pose_samples.append(t2 - t1)
		rig_samples.append(t3 - t2)
		tick_samples.append(t3 - t0)
		event_count += events.size()
		for event in events:
			if str(event.type) == "contact": contact_count += 1
			elif str(event.type) == "turn_started": action_count += 1
		checksum += float(pose.hero.phase_progress) + Vector2(rig.near_arm.wrist).x * .001
		if duel.finished: early_finish = true
	var total_us := Time.get_ticks_usec() - timed_start
	var profile: Dictionary = duel.profile_snapshot() if profile_mode else {}
	var state := {"hero_hp": duel.hero_hp, "enemy_hp": duel.enemy_hp, "elapsed": duel.elapsed, "finished": duel.finished, "events": event_count, "contacts": contact_count, "actions": action_count, "pose_checksum": checksum}
	duel = null
	return {"setup_us": setup_us, "total_ms": total_us / 1000.0,
		"tick": stats(tick_samples), "advance": stats(advance_samples), "pose": stats(pose_samples), "rig": stats(rig_samples),
		"state": state, "early_finish": early_finish, "profile_inclusive": profile,
		"object_count_before": object_before, "object_count_after": int(Performance.get_monitor(Performance.OBJECT_COUNT)),
		"static_bytes_before": memory_before, "static_bytes_after": OS.get_static_memory_usage()}

func stats(values: PackedFloat64Array) -> Dictionary:
	var total := 0.0
	for value in values: total += value
	var sorted := values.duplicate()
	sorted.sort()
	return {"count": sorted.size(), "total_us": total, "mean_us": total / maxf(1, sorted.size()),
		"p50_us": sorted[clampi(ceili(sorted.size() * .50) - 1, 0, sorted.size() - 1)],
		"p95_us": sorted[clampi(ceili(sorted.size() * .95) - 1, 0, sorted.size() - 1)], "max_us": sorted[-1]}

func source_hashes() -> Dictionary:
	var output := {}
	for name in ["duel_timeline", "character_sidewalk", "melee_contact_geometry", "monster_move_library", "monster_pose_renderer", "cultivation_content", "combat_action_registry", "combat_rig_registry"]:
		var path: String = "res://scripts/" + str(name) + ".gd"
		if FileAccess.file_exists(path): output[name] = FileAccess.get_sha256(path)
	return output
