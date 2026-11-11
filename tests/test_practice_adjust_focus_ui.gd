extends SceneTree
## Real Viewport dispatch across the practice-to-equipment transition.
const Host = preload("res://scripts/practice_host.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_adjust_focus_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func formal() -> Array:
	var data: Dictionary = scene.state._snapshot(); data.erase("saved_at")
	return [data, scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state]
func settle():
	if scene.drawer_tween: scene.drawer_tween.kill()
	if scene.content_tween: scene.content_tween.kill()
	if not scene.drawer_name.is_empty():
		scene.paper_reveal = 1.0; scene.content_alpha = 1.0; scene.drawer_alpha = 1.0
		scene.content_offset = 0.0; scene._sync_drawer_visuals()
	await process_frame; await process_frame
func event(code: Key, pressed: bool, echo := false):
	var key := InputEventKey.new()
	key.keycode = code; key.pressed = pressed; key.echo = echo
	root.push_input(key, true)
	await process_frame
func tap(code: Key):
	await event(code, true); await event(code, false)
func focused(key: String, label: String):
	var button = scene.buttons.get(key)
	check(is_instance_valid(button) and root.gui_get_focus_owner() == button and not button.disabled and button.is_visible_in_tree() and button.focus_mode != Control.FOCUS_NONE, label)
func comparison():
	check(scene.start_practice("bamboo_sprite"), "start trial")
	scene.buttons.practice_live_pause.grab_focus()
	for i in range(1300):
		if scene.practice_session.status().finished: break
		scene._process(.1)
	check(scene.practice_session.status().finished, "trial completes naturally")
	await settle(); focused("practice_loadout", "completed trial focuses comparison")
	await tap(KEY_ENTER); await settle()
	check(bool(scene.get_meta("practice_show_loadout", false)), "comparison opens via Enter")
	for i in range(20):
		if root.gui_get_focus_owner() == scene.buttons.get("practice_adjust"): break
		await tap(KEY_TAB)
	focused("practice_adjust", "natural Tab reaches adjust")
func run():
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	var before := formal()
	for slot in ["chest", "weapon"]:
		scene.selected_slot = slot
		await comparison()
		var report: Dictionary = scene.practice_session.report()
		await event(KEY_ENTER, true); await event(KEY_ENTER, true, true)
		check(scene.practice_session != null, "held Enter does not adjust early")
		await event(KEY_ENTER, false)
		check(scene.practice_session == null and scene.wardrobe_tab == "equipment" and not scene.get_meta("combat_insight_open", false), "adjust returns to actual equipment")
		check(root.gui_get_focus_owner() == null, "opening equipment does not focus hidden controls")
		# An actual layout rebuild while the new leaf is still opening.
		scene.size = Vector2(1200, 400) if slot == "weapon" else Vector2(960, 320)
		scene._refresh_drawer()
		await settle(); focused("slot_" + slot, "selected equipment slot receives focus after rebuild")
		check(not scene.has_meta("practice_focus_target"), "pending focus consumed")
		check(scene.practice_previous_reports.get("bamboo_sprite", {}) == report, "completed report retained")
		check(formal() == before, "return does not equip, spend, save or change RNG")
		await tap(KEY_ENTER); await settle()
		focused("slot_" + slot, "next Enter only inspects selected slot")
		check(formal() == before, "inspection does not alter formal state")
		# Tab remains the existing wardrobe shortcut outside practice.
		await tap(KEY_UP)
		check(root.gui_get_focus_owner() != null, "ordinary equipment arrow navigation continues")
	# No focus intent means no automatic focus, even with the same transition.
	await comparison()
	root.gui_release_focus()
	scene.buttons.practice_adjust.pressed.emit()
	await settle()
	check(root.gui_get_focus_owner() == null and not scene.has_meta("practice_focus_target"), "unfocused action does not steal focus")
	# A newer target selected while paper opens takes priority over the request.
	await comparison(); await tap(KEY_ENTER)
	scene.buttons.settings.grab_focus()
	await settle(); focused("settings", "newer navigation focus wins")
	check(not scene.has_meta("practice_focus_target"), "overridden pending target removed")
	# Closing the leaf before reveal cannot revive an old equipment control.
	await comparison(); await tap(KEY_ENTER)
	scene._close_drawer(); await settle()
	check(root.gui_get_focus_owner() == null, "interrupted close does not focus hidden equipment")
	if scene.drawer_tween: scene.drawer_tween.kill()
	if scene.content_tween: scene.content_tween.kill()
	if is_instance_valid(scene.drawer):
		scene.remove_child(scene.drawer); scene.drawer.queue_free(); scene.drawer = null
	await process_frame; scene._sync_drawer_visuals()
	check(not scene.has_meta("practice_focus_target"), "deleted target cleared")
	check(formal() == before, "all transitions preserve formal state and RNG")
	scene.queue_free(); await process_frame; await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(save_path + suffix)
	print("Practice adjust focus UI: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
