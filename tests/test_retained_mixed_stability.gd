extends SceneTree
## Linux source/headless, wall-clock same-host exercise; not native GUI or full-release acceptance.
## No synthetic _process calls, time scaling, per-cycle new_game or host replacement.
const Pages = preload("res://scripts/adventure_pages.gd")
const BOUNDS := {"objects": 64, "resources": 8, "nodes": 0, "orphans": 0, "static_bytes": 33554432}
var scene
var checks := 0
var failures := 0
var cycles := 0
var saves := 0
var started := 0
var duration := 3600.0
var measured_started := -1
var host_id: int
var state_id: int
var formal_id: int
var baseline: Dictionary = {}
var save_path: String
var expected_reload := ""
func _initialize(): call_deferred("run")
func check(ok: bool, label: String) -> bool:
	checks += 1
	if not ok:
		failures += 1
		printerr("MIXED_FAIL " + label)
	return ok
func elapsed() -> float: return (Time.get_ticks_msec() - started) / 1000.0
func snapshot() -> String:
	var data: Dictionary = scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)
func disk_canonical(value: String) -> String:
	# Godot JSON parses every numeric token as float (1 -> 1.0); normalize BOTH sides.
	# No fields are dropped beyond saved_at, and no numeric tolerance is introduced.
	return JSON.stringify(JSON.parse_string(value))
func measured_elapsed() -> float:
	return 0.0 if measured_started < 0 else (Time.get_ticks_msec() - measured_started) / 1000.0
func wait_seconds(seconds: float):
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while Time.get_ticks_msec() < end: await process_frame
func settle():
	await wait_seconds(1.0) # Includes the 0.60 second close tween, with real idle frames.
	for i in range(4): await process_frame
func until(predicate: Callable, seconds: float, label: String) -> bool:
	var end := Time.get_ticks_msec() + int(seconds * 1000)
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return check(predicate.call(), label)
func identities():
	check(Engine.time_scale == 1.0, "real time scale remains 1")
	check(scene.get_instance_id() == host_id and scene.state.get_instance_id() == state_id, "same retained host and State")
	check(scene.practice_session != null or scene.duel.get_instance_id() == formal_id, "same retained formal Duel")
func capture() -> Dictionary:
	var refs := {}
	for field in ["practice_session", "duel", "practice_controls"]:
		if scene.get(field) != null: refs[field] = weakref(scene.get(field))
	for field in ["_base_module", "_form_module", "_enemy_module"]:
		if scene.duel.get(field) != null: refs[field] = weakref(scene.duel.get(field))
	for lane in scene.duel._skill_modules:
		refs["skill:" + str(lane)] = weakref(scene.duel._skill_modules[lane])
	for child in scene.practice_controls.get_children(): refs["control:" + str(child.get_instance_id())] = weakref(child)
	check(refs.has("_base_module") and refs.has("_enemy_module"), "capture actual providers")
	return refs
func survivors(refs: Dictionary) -> Array:
	var live := []
	for key in refs:
		if refs[key].get_ref() != null: live.append(key)
	return live
func metrics() -> Dictionary:
	return {"objects": int(Performance.get_monitor(Performance.OBJECT_COUNT)), "resources": int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)), "nodes": int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT)), "orphans": int(Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT)), "static_bytes": OS.get_static_memory_usage()}
func sample():
	var current := metrics()
	if baseline.is_empty():
		baseline = current.duplicate()
		measured_started = Time.get_ticks_msec()
	for key in BOUNDS:
		check(int(current[key]) <= int(baseline[key]) + int(BOUNDS[key]), "fixed settled bound " + key + ": " + str(current[key]) + " <= " + str(int(baseline[key]) + int(BOUNDS[key])))
	print("MIXED_SAMPLE " + JSON.stringify({"sample_unix_seconds": Time.get_unix_time_from_system(), "elapsed": elapsed(), "measured_elapsed": measured_elapsed(), "cycle": cycles, "metrics": current, "baseline": baseline, "bounds": BOUNDS, "checks": checks, "failures": failures}))
func save_check(label: String):
	check(scene._save_current(), label + " actual atomic save succeeds")
	var decoded = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(decoded is Dictionary and int(decoded.get("version", -1)) == 4, label + " disk JSON schema")
	if decoded is Dictionary:
		decoded.erase("saved_at")
		if not check(JSON.stringify(decoded) == disk_canonical(snapshot()), label + " actual saved formal snapshot"):
			print("MIXED_DISK_WITNESS " + JSON.stringify(decoded))
			print("MIXED_STATE_WITNESS " + snapshot())
	check(FileAccess.file_exists(save_path + ".bak"), label + " atomic backup exists")
	saves += 1
func panel_cycle():
	var before := snapshot()
	for panel in ["wardrobe", "practice", "alchemy", "settings"]:
		scene._toggle_drawer(panel)
		check(scene.drawer_name == panel, "panel opened " + panel)
		await wait_seconds(.25)
		scene._close_drawer()
		await settle()
		check(scene.drawer_name.is_empty(), "panel closed " + panel)
	check(snapshot() == before, "paused panels preserve formal state")
func practice_cycle():
	var before := snapshot()
	if not check(scene.start_practice("bamboo_sprite"), "normal practice start"): return
	var completed := capture()
	if not await until(func(): return scene.practice_session.status().finished, 180.0, "practice completes through real engine frames"): return
	check(snapshot() == before, "completed practice preserves full formal state")
	if not check(scene.start_practice("bamboo_sprite"), "repeat finished practice"): return
	await settle()
	check(survivors(completed).is_empty(), "completed practice weakrefs released " + str(survivors(completed)))
	completed.clear()
	var cancelled := capture()
	check(scene.practice_session.status().active, "repeat remains active before cancel")
	scene.toggle_practice_pause()
	# controls() replaces nodes on pause/resume; capture the replacement weakrefs too.
	var paused_controls := capture()
	var paused_report: String = JSON.stringify(scene.practice_session.report())
	await wait_seconds(.75)
	check(JSON.stringify(scene.practice_session.report()) == paused_report, "trial pause freezes report")
	scene.toggle_practice_pause()
	var resumed_controls := capture()
	await wait_seconds(.25)
	check(not scene.practice_session.status().paused, "trial resumes")
	scene.end_practice()
	await settle()
	for witness in [cancelled, paused_controls, resumed_controls]:
		check(survivors(witness).is_empty(), "cancelled practice and replaced controls released " + str(survivors(witness)))
		witness.clear()
	check(scene.practice_session == null and scene.practice_snapshot.is_empty(), "practice aliases cleared")
	check(scene.paused and snapshot() == before, "formal paused snapshot restored exactly")
	check(scene.duel.get_instance_id() == formal_id, "formal Duel restored after practice")
	scene._close_drawer(); await settle()
func formal_cycle():
	scene._set_paused(false)
	var lifetime_before: float = scene.state.lifetime_seconds
	await wait_seconds(.5)
	check(scene.state.lifetime_seconds > lifetime_before, "formal resume advances actual State")
	check(scene.state.select_stage("bamboo_pass"), "select actual unlocked formal route")
	scene._start_encounter()
	if not await until(func(): return scene.encounter_phase == "fight", 90.0, "real portal and travel reach formal fight"): return
	if not await until(func(): return scene.encounter_clock > .1, 5.0, "formal combat actually advances"): return
	scene._set_paused(true)
	var paused_before := snapshot()
	var report_before: String = JSON.stringify(scene.duel.combat_report())
	var rng_before := [scene.duel._rng.state, scene.duel._enemy_rng.state]
	await wait_seconds(.75)
	check(snapshot() == paused_before and JSON.stringify(scene.duel.combat_report()) == report_before, "global pause freezes formal State and combat")
	check(rng_before == [scene.duel._rng.state, scene.duel._enemy_rng.state], "global pause freezes both duel RNGs")
	var reports_before: Array = scene.state.combat_reports.duplicate(true)
	var report_count: int = reports_before.size()
	scene.wardrobe_tab = "expedition"; scene._toggle_drawer("wardrobe"); scene._refresh_drawer()
	if not check(is_instance_valid(scene.buttons.get("depart_stage")) and not scene.buttons.depart_stage.disabled, "actual paused retreat button enabled"): return
	scene.buttons.depart_stage.pressed.emit()
	check(scene.state.combat_reports.size() == mini(report_count + 1, scene.state.COMBAT_REPORT_LIMIT), "one retreat report appended with bounded history")
	check(str(scene.state.combat_reports[0].outcome) == "retreat", "actual retreat report")
	for i in range(mini(report_count, scene.state.COMBAT_REPORT_LIMIT - 1)):
		check(scene.state.combat_reports[i + 1] == reports_before[i], "retreat retains bounded previous report tail")
	var returned := snapshot()
	if not await until(func(): return not scene.encounter_active, 10.0, "paused actual return reaches home"): return
	check(scene.paused and scene.world_route.is_empty() and scene.encounter_phase == "idle", "paused home settled")
	check(snapshot() == returned, "return animation does not advance formal state")
	check(bool(scene.state.stage_status().paused), "retreat checkpoint preserved")
	# Real State abandonment API, never clear stage_run/reset State to permit practice.
	var cancelled: Dictionary = scene.state.cancel_stage()
	check(bool(cancelled.get("ok", false)) and cancelled.get("reason") == "cancelled", "legal unstarted-loot route abandon")
	check(scene.state.stage_run.is_empty(), "abandon permits next practice")
	scene._close_drawer(); await settle()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="): duration = float(arg.trim_prefix("--duration="))
	if not check(is_finite(duration) and duration >= 1.0, "positive finite requested wall duration"):
		quit(1); return
	save_path = "user://retained_mixed_%d.json" % OS.get_process_id()
	for suffix in ["", ".bak", ".tmp"]:
		if not check(not FileAccess.file_exists(save_path + suffix), "fresh owned save path " + suffix):
			quit(1); return
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	started = Time.get_ticks_msec()
	# Normal missing-file initialization. No explicit or per-cycle new_game call.
	scene._set_paused(true)
	scene.state.auto_advance = false
	host_id = scene.get_instance_id(); state_id = scene.state.get_instance_id(); formal_id = scene.duel.get_instance_id()
	print("MIXED_START " + JSON.stringify({"duration": duration, "pid": OS.get_process_id(), "host": host_id, "state": state_id, "formal_duel": formal_id, "save_path": ProjectSettings.globalize_path(save_path), "bounds": BOUNDS, "scope": "Linux source headless, real engine frames"}))
	# First opening acknowledges the legitimate arrival tutorial once, before snapshots.
	scene._toggle_drawer("practice"); scene._close_drawer(); await settle()
	check(scene.state.arrival_seen, "one-time practice arrival acknowledged")
	while (measured_elapsed() < duration or cycles < 3) and failures == 0:
		identities()
		await panel_cycle()
		if failures: break
		await practice_cycle()
		if failures: break
		await formal_cycle()
		if failures: break
		save_check("cycle %d" % cycles)
		await settle()
		cycles += 1
		sample()
		identities()
	if failures == 0:
		check(measured_elapsed() >= duration, "full requested post-warmup wall-clock duration reached")
		save_check("final")
		expected_reload = disk_canonical(snapshot())
		var formal: WeakRef = weakref(scene.duel)
		scene.queue_free(); scene = null
		await settle()
		check(formal.get_ref() == null, "retained formal Duel releases after final host teardown")
		scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
		root.add_child(scene); await settle()
		check(scene.paused and not scene.encounter_active, "final fresh host reload is paused at home")
		check(disk_canonical(snapshot()) == expected_reload, "final actual host reload matches full canonical snapshot")
		check(bool(scene.state.last_offline.get("loaded", false)), "reload actually loaded disk")
		check(float(scene.state.last_offline.get("seconds", -1)) == 0.0, "paused reload awards no offline seconds")
		for flag in ["recovered", "invalid_save", "save_error", "migrated", "gear_repaired", "materials_repaired", "clock_invalid"]:
			check(not bool(scene.state.last_offline.get(flag, false)), "reload has no " + flag)
	if scene != null: scene.queue_free(); scene = null; await settle()
	print("MIXED_RESULT " + JSON.stringify({"elapsed": elapsed(), "measured_elapsed": measured_elapsed(), "requested": duration, "cycles": cycles, "saves": saves, "checks": checks, "failures": failures, "scope": "Linux source headless only"}))
	quit(1 if failures else 0)
