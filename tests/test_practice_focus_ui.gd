extends SceneTree
## Actual viewport keyboard dispatch; no custom focus neighbours or pressed signals.
const Host = preload("res://scripts/practice_host.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_focus_ui_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func settle():
	if scene.drawer_tween: scene.drawer_tween.kill()
	if scene.content_tween: scene.content_tween.kill()
	if not scene.drawer_name.is_empty():
		scene.paper_reveal = 1.0; scene.content_alpha = 1.0; scene.drawer_alpha = 1.0
		scene.content_offset = 0.0; scene._sync_drawer_visuals()
	await process_frame
	await process_frame
func tap(code: Key, shift := false):
	for down in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code; event.pressed = down; event.shift_pressed = shift
		root.push_input(event, true)
		await process_frame
func focused(key: String, label: String):
	var button = scene.buttons.get(key)
	check(is_instance_valid(button) and root.gui_get_focus_owner() == button and not button.disabled and button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE, label)
func run():
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	var before: Dictionary = scene.state._snapshot(); before.erase("saved_at")
	var rng_before = [scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state]
	check(scene.start_practice("bamboo_sprite"), "start trial")
	await settle()
	check(root.gui_get_focus_owner() == null, "unfocused start does not steal focus")
	scene.buttons.practice_live_pause.grab_focus()
	await tap(KEY_ENTER); await settle()
	check(scene.practice_session.status().paused, "Enter pauses")
	focused("practice_live_pause", "pause rebuild retains actual focus")
	await tap(KEY_ENTER); await settle()
	check(not scene.practice_session.status().paused, "second Enter resumes without refocusing")
	focused("practice_live_pause", "resume rebuild retains actual focus")
	await tap(KEY_TAB); focused("practice_live_end", "normal Tab reaches End")
	await tap(KEY_TAB); focused("practice_live_pause", "normal Tab skips disabled decision")
	await tap(KEY_RIGHT); focused("practice_live_end", "normal right arrow reaches End")
	await tap(KEY_LEFT); focused("practice_live_pause", "normal left arrow returns")
	for cycle in range(3):
		await tap(KEY_ENTER); await settle()
		await tap(KEY_TAB); await tap(KEY_TAB)
		focused("practice_live_decision", "paused Tab reaches decision %d" % cycle)
		await tap(KEY_ENTER)
		check(Host.decision_open(scene), "decision opened %d" % cycle)
		check(root.gui_get_focus_owner() == null, "opening paper does not focus invisible controls")
		scene._refresh_drawer() # Resize/state rebuild while paper is still opening.
		await settle(); focused("practice_decision_back", "decision receives focus after reveal")
		await tap(KEY_ENTER); await settle()
		focused("practice_live_decision", "back restores decision launcher")
		await tap(KEY_SPACE); await settle()
		focused("practice_live_pause", "Space resume routes disabled decision to Pause")
		check(not scene.practice_session.status().paused, "Space resumes")
	# Running End remains selected through pause/resume, not accidentally activated.
	await tap(KEY_TAB)
	await tap(KEY_SPACE); await settle(); focused("practice_live_end", "End focus survives pause")
	await tap(KEY_SPACE); await settle(); focused("practice_live_end", "End focus survives resume")
	for i in range(1300):
		if scene.practice_session.status().finished: break
		scene._process(.1)
	check(scene.practice_session.status().finished, "trial finishes")
	await settle(); focused("practice_loadout", "result routes to read-only comparison")
	await tap(KEY_ENTER); await settle(); focused("practice_loadout", "comparison toggle retains focus")
	# Navigate the real tree, without assigning neighbours or refocusing rebuilds.
	for i in range(20):
		if root.gui_get_focus_owner() == scene.buttons.get("practice_loadout_next"): break
		await tap(KEY_TAB)
	focused("practice_loadout_next", "natural Tab reaches next page")
	for i in range(10):
		if scene.buttons.practice_loadout_next.disabled: break
		await tap(KEY_ENTER); await settle()
	check(scene.buttons.practice_loadout_next.disabled, "reach last comparison page")
	focused("practice_loadout_prev", "last page routes away from disabled next")
	for i in range(10):
		if scene.buttons.practice_loadout_prev.disabled: break
		await tap(KEY_ENTER); await settle()
	check(scene.buttons.practice_loadout_prev.disabled, "return to first comparison page")
	focused("practice_loadout_next", "first page routes away from disabled previous")
	await tap(KEY_ESCAPE); await settle()
	check(scene.practice_session == null, "Escape cleans up trial")
	focused("practice_start", "exit restores start action")
	check(not scene.has_meta("practice_focus_target"), "no pending focus after cleanup")
	await tap(KEY_ENTER); await settle(); focused("practice_live_pause", "keyboard starts another trial")
	await tap(KEY_ESCAPE); await settle(); focused("practice_start", "repeated exit restores start")
	await tap(KEY_ENTER); await settle()
	await tap(KEY_ENTER); await settle()
	await tap(KEY_TAB); await tap(KEY_TAB); await tap(KEY_ENTER)
	check(Host.decision_open(scene), "open decision for interrupted exit")
	await tap(KEY_ESCAPE); await settle()
	focused("practice_start", "exit before reveal cannot restore stale decision focus")
	check(not scene.has_meta("practice_focus_target"), "interrupted pending request cleaned")
	var after: Dictionary = scene.state._snapshot(); after.erase("saved_at")
	check(after == before and rng_before == [scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state], "formal state and RNG unchanged")
	scene.queue_free(); await process_frame; await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(save_path + suffix)
	print("Practice focus UI: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
