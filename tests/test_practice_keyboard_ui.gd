extends SceneTree
## Real viewport input dispatch and real enabled buttons, including key-up and
## repeat events. No synthetic pressed signals or direct host _input calls.
const Host = preload("res://scripts/practice_host.gd")
var scene
var checks := 0
var failures := 0
var activations := 0
var gui_events: Array = []
var save_path := "user://practice_keyboard_ui_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func formal() -> Array:
	var data: Dictionary = scene.state._snapshot(); data.erase("saved_at")
	return [data, scene.state._adventure_rng.state, scene.state._journey_rng.state, scene.state.gear.rng.state]
func settle():
	# Finish only presentation transitions; do not advance the trial or world.
	if scene.drawer_tween: scene.drawer_tween.kill()
	if scene.content_tween: scene.content_tween.kill()
	if not scene.drawer_name.is_empty():
		scene.paper_reveal = 1.0; scene.content_alpha = 1.0; scene.drawer_alpha = 1.0
		scene.content_offset = 0.0; scene._sync_drawer_visuals()
	await process_frame
	await process_frame
func focus(key: String) -> Button:
	var b: Button = scene.buttons.get(key)
	check(is_instance_valid(b), "button exists " + key)
	if not is_instance_valid(b): return null
	check(not b.disabled and b.is_visible_in_tree() and b.focus_mode != Control.FOCUS_NONE, "button usable " + key)
	b.grab_focus()
	check(root.gui_get_focus_owner() == b, "actual GUI focus " + key)
	return b
func key_event(code: Key, down: bool, echo := false, shift := false):
	var event := InputEventKey.new()
	event.keycode = code; event.pressed = down; event.echo = echo; event.shift_pressed = shift
	root.push_input(event, true)
	await process_frame
func tap(code: Key, shift := false):
	await key_event(code, true, false, shift)
	await key_event(code, false, false, shift)
func count_activation(): activations += 1
func record_gui(event: InputEvent):
	if event is InputEventKey: gui_events.append([event.keycode,event.pressed,event.echo])
func activate(key: String, code: Key, label: String):
	var b := focus(key)
	if b == null: return
	activations = 0
	b.pressed.connect(count_activation)
	await key_event(code, true)
	check(activations == 0, label + " waits for release")
	await key_event(code, true, true)
	check(activations == 0, label + " key repeat does not activate")
	await key_event(code, false)
	check(activations == 1, label + " activates exactly once through GUI")
	await settle()
func navigation(first: String, second: String, label: String):
	var a := focus(first)
	var b: Button = scene.buttons.get(second)
	if a == null or not is_instance_valid(b): return
	# Explicit neighbours make direction assertions independent of window size.
	a.focus_next = a.get_path_to(b); a.focus_neighbor_right = a.get_path_to(b); a.focus_neighbor_bottom = a.get_path_to(b)
	b.focus_previous = b.get_path_to(a); b.focus_neighbor_left = b.get_path_to(a); b.focus_neighbor_top = b.get_path_to(a)
	await tap(KEY_TAB); check(root.gui_get_focus_owner() == b, label + " Tab advances")
	await tap(KEY_TAB, true); check(root.gui_get_focus_owner() == a, label + " Shift-Tab returns")
	await tap(KEY_RIGHT); check(root.gui_get_focus_owner() == b, label + " right advances")
	await tap(KEY_LEFT); check(root.gui_get_focus_owner() == a, label + " left returns")
	await tap(KEY_DOWN); check(root.gui_get_focus_owner() == b, label + " down advances")
	await tap(KEY_UP); check(root.gui_get_focus_owner() == a, label + " up returns")
func world_keys(label: String):
	var before := formal()
	var drawer: String = scene.drawer_name
	var tab: String = scene.wardrobe_tab
	var session_id: int = scene.practice_session.get_instance_id()
	var strip: bool = scene.strip
	var b := focus("practice_end" if scene.practice_session.status().finished else ("practice_decision_back" if Host.decision_open(scene) else "practice_live_end"))
	if b == null: return
	gui_events.clear(); b.gui_input.connect(record_gui)
	for code in [KEY_I, KEY_A, KEY_R, KEY_M, KEY_G, KEY_F2, KEY_F9]:
		await key_event(code, true); await key_event(code, true, true); await key_event(code, false)
	check(gui_events.is_empty(), label + " world key press/repeat/release never reaches GUI")
	check(formal() == before and scene.drawer_name == drawer and scene.wardrobe_tab == tab and scene.strip == strip and scene.practice_session.get_instance_id() == session_id, label + " world shortcuts do not mutate world or navigate")
	b.gui_input.disconnect(record_gui)
func run():
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.world_route = ""; scene.encounter_active = false; scene.state.stage_run = {}
	var before := formal()
	check(scene.start_practice("bamboo_sprite"), "start actual trial")
	await settle()
	await navigation("practice_live_pause", "practice_live_end", "running")
	await world_keys("running")
	await activate("practice_live_pause", KEY_ENTER, "Enter running pause")
	check(scene.practice_session.status().paused, "Enter pauses actual trial")
	# Keep later coverage independent of the pre-fix expected activation failure.
	if not scene.practice_session.status().paused: scene.toggle_practice_pause()
	await settle()
	await activate("practice_live_decision", KEY_KP_ENTER, "keypad Enter opens paused decision")
	check(Host.decision_open(scene), "decision opened by keyboard")
	if not Host.decision_open(scene): Host.open_decision(scene, scene.practice_session.get_instance_id()); await settle()
	await navigation("practice_decision_back", "practice_decision_resume", "paused decision")
	await world_keys("paused decision")
	await activate("practice_decision_back", KEY_ENTER, "Enter returns from decision")
	check(scene.drawer_name.is_empty() and scene.practice_session.status().paused, "back preserves paused trial")
	if Host.decision_open(scene): Host.leave_decision(scene, scene.practice_session.get_instance_id(), int(scene.get_meta("practice_decision_generation")))
	await settle()
	# Focus End: leaked ui_accept (Space) must not accidentally end the trial.
	var b := focus("practice_live_end")
	gui_events.clear(); b.gui_input.connect(record_gui)
	await key_event(KEY_SPACE, true)
	check(scene.practice_session != null and not scene.practice_session.status().paused, "Space resumes once")
	# Pause rebuilds controls, so observe the current live button for repeat/up.
	await settle(); b = focus("practice_live_end"); b.gui_input.connect(record_gui)
	await key_event(KEY_SPACE, true, true); await key_event(KEY_SPACE, false)
	check(scene.practice_session != null and not scene.practice_session.status().paused, "Space repeat/up do not toggle or activate End")
	check(gui_events.is_empty(), "Space press/repeat/release consumed before GUI")
	await key_event(KEY_SPACE, true); await settle()
	b = focus("practice_live_end"); gui_events.clear(); b.gui_input.connect(record_gui)
	await key_event(KEY_SPACE, true, true); await key_event(KEY_SPACE, false)
	check(scene.practice_session != null and scene.practice_session.status().paused, "second Space pauses exactly once")
	check(gui_events.is_empty(), "paused Space repeat/release consumed")
	scene.toggle_practice_pause()
	for i in range(1300):
		if scene.practice_session.status().finished: break
		scene._process(.1)
	check(scene.practice_session.status().finished, "real engine completes bounded trial")
	await settle()
	await navigation("practice_end", "practice_retry", "finished result")
	await world_keys("finished result")
	var completed: Dictionary = scene.practice_session.report().duplicate(true)
	var completed_id: int = scene.practice_session.get_instance_id()
	b = focus("practice_end"); gui_events.clear(); b.gui_input.connect(record_gui)
	await key_event(KEY_SPACE, true); await settle()
	b = focus("practice_end"); b.gui_input.connect(record_gui)
	await key_event(KEY_SPACE, true, true); await key_event(KEY_SPACE, false)
	check(gui_events.is_empty(), "finished Space press/repeat/release consumed")
	check(scene.practice_session != null and scene.practice_session.get_instance_id() == completed_id and scene.practice_session.report() == completed, "finished Space neither resumes nor activates End")
	await activate("practice_loadout", KEY_ENTER, "Enter opens loadout")
	check(bool(scene.get_meta("practice_show_loadout", false)), "keyboard opens actual loadout")
	if not scene.get_meta("practice_show_loadout", false): scene.set_meta("practice_show_loadout", true); scene._refresh_drawer(); await settle()
	await activate("practice_loadout_next", KEY_KP_ENTER, "keypad Enter turns loadout page")
	check(int(scene.get_meta("practice_loadout_page", 0)) == 1, "loadout page increments once")
	await activate("practice_end", KEY_ENTER, "Enter ends finished trial")
	check(scene.practice_session == null, "finished trial ended by keyboard")
	if scene.practice_session != null: scene.end_practice()
	await settle()
	for code in [KEY_ESCAPE, KEY_F8]:
		check(scene.start_practice("bamboo_sprite"), "start shortcut trial " + str(code)); await settle()
		b = focus("practice_live_end"); gui_events.clear(); b.gui_input.connect(record_gui)
		# Repeat/up must be inert even before the first actual press.
		await key_event(code, true, true); await key_event(code, false)
		check(scene.practice_session != null, "escape shortcut repeat/up does not end " + str(code))
		check(gui_events.is_empty(), "escape shortcut repeat/up not leaked " + str(code))
		await key_event(code, true)
		check(scene.practice_session == null, "escape shortcut initial press ends " + str(code))
		check(gui_events.is_empty(), "escape shortcut press not leaked " + str(code))
		await key_event(code, true, true); await key_event(code, false); await settle()
		check(scene.practice_session == null, "escape shortcut subsequent repeat/up stays ended " + str(code))
	check(formal() == before, "formal progression/resources/save state/RNG unchanged")
	scene.queue_free(); await process_frame; await process_frame
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(save_path + suffix)
	print("Practice keyboard UI: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
