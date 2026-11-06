extends SceneTree
## Same actual host, isolated save, bounded repeated UI/lifetime cycles.
const Host = preload("res://scripts/practice_host.gd")
const Pages = preload("res://scripts/practice_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_decision_ui_%d.json" % OS.get_process_id()
func _initialize(): call_deferred("run")
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func press(key: String):
	var b = scene.buttons.get(key)
	check(is_instance_valid(b), "exists " + key)
	if not is_instance_valid(b): return
	check(not b.disabled, "enabled " + key)
	if not b.disabled: b.pressed.emit()
func callback(key: String) -> Callable:
	# Capture the semantic handler token, not _qbutton's visual wrapper: the
	# wrapper captures its Node and Godot rejects calls after queue_free.
	var session_id: int = scene.practice_session.get_instance_id()
	var generation: int = int(scene.get_meta("practice_decision_generation", 0))
	if key == "practice_live_decision": return func(): Host.open_decision(scene,session_id)
	if key == "practice_decision_resume": return func(): Host.leave_decision(scene,session_id,generation,true)
	return func(): Host.end_decision(scene,session_id,generation)
func formal() -> Array:
	var data: Dictionary = scene.state._snapshot(); data.erase("saved_at")
	var disk: Array = []
	for suffix in ["", ".bak", ".tmp"]:
		disk.append(FileAccess.get_file_as_bytes(save_path + suffix) if FileAccess.file_exists(save_path + suffix) else PackedByteArray())
	return [data,disk,scene.state._adventure_rng.state,scene.state._journey_rng.state,scene.state.gear.rng.state]
func combat() -> Array:
	return [scene.duel.battle_resource_snapshot(),scene.duel.combat_report(),scene.duel._rng.state,scene.duel._enemy_rng.state,scene.duel._next_skill_index,scene.duel._skill_uses.duplicate(true),scene.duel._counter_ready,scene.duel._must_basic,scene.duel.elapsed]
func settle():
	for i in range(4): await process_frame
func geometry(label: String):
	var controls: Array = []
	for c in scene.drawer.get_children():
		if c is BaseButton:
			var rect := Rect2(c.position,c.size)
			check(scene._drawer_rect().encloses(rect), label + " enclosed " + c.name)
			for other in controls: check(not rect.intersects(Rect2(other.position,other.size)), label + " no overlap " + c.name + "/" + other.name)
			controls.append(c)
	var snapshot: Dictionary = scene.duel.skill_decision_snapshot()
	for row in snapshot.rows:
		check(scene.SERIF.get_string_size(Pages.decision_reason(row,snapshot),HORIZONTAL_ALIGNMENT_LEFT,-1,14).x <= 405, "reason fits at 14px")
func run():
	scene = load("res://main.tscn").instantiate(); scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.state.realm = 9; scene.state.attuned_techniques.assign(["breath","ember","barrier","mending","mist"])
	for id in scene.state.attuned_techniques: scene.state.technique_levels[id] = 1
	scene.state.equipped_heart = "breath"; scene.state.equipped_actives.assign(["ember","barrier"])
	scene.state.gear.inventory.append(scene.state.gear._make_item(1,"weapon_sword","common",1)); scene.state.gear.equip_item(1)
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true
	scene.demo = false; check(scene._save_current(), "baseline save persists"); scene.demo = true
	var original := formal()
	var formal_duel_id: int = scene.duel.get_instance_id()
	check(not Host.open_decision(scene,0), "formal idle cannot inspect")
	scene.encounter_active = true; scene.encounter_phase = "fight"
	check(not Host.open_decision(scene,formal_duel_id), "formal live cannot inspect")
	scene.encounter_active = false; scene.encounter_phase = ""
	check(scene.start_practice("bamboo_sprite"), "start trial")
	var first_id: int = scene.practice_session.get_instance_id()
	check(scene.buttons.practice_live_decision.disabled, "must manually pause first")
	var stale_open := callback("practice_live_decision")
	stale_open.call(); check(not Host.decision_open(scene), "forced running callback rejected")
	press("practice_live_pause")
	var frozen := combat()
	press("practice_live_decision")
	check(Host.decision_open(scene), "manual paused open")
	check(not Host.open_decision(scene,first_id), "repeated opening rejected")
	var stale_resume := callback("practice_decision_resume")
	var stale_end := callback("practice_decision_end")
	var rows: Array = scene.duel.skill_decision_snapshot().rows
	check(rows.size() == 3, "two active plus innate shown")
	for dimensions in [Vector2i(960,320),Vector2i(960,540)]:
		root.min_size = Vector2i(960,320); root.size = dimensions; scene.strip = dimensions.y == 320
		scene.size = Vector2(dimensions); scene._refresh_drawer(); await settle(); geometry(str(dimensions))
		for i in range(20): scene.queue_redraw(); await process_frame
		check(combat() == frozen and formal() == original, "render/read leaves combat/save/RNG untouched " + str(dimensions))
		check(scene.get_meta("practice_decision_snapshot", {}) == scene.duel.skill_decision_snapshot(), "cached snapshot bound to paused instant")
		check(scene.get_meta("practice_decision_presentation", {}).rows.size() == 3, "visible cache keeps three equipped rows")
	var detached_button = scene.buttons.practice_decision_resume
	var detached_wrapper: Callable = detached_button.pressed.get_connections()[0].callable
	press("practice_decision_back")
	# Actual signal wrapper while the detached queued Node is still valid:
	# is_inside_tree prevents it from dispatching a stale page action.
	detached_wrapper.call()
	check(is_instance_valid(detached_button) and not detached_button.is_inside_tree(), "detached real control harmless before deferred free")
	check(scene.drawer_name.is_empty() and scene.practice_session.status().paused, "back preserves same paused trial")
	stale_resume.call(); stale_end.call()
	check(scene.practice_session != null and scene.practice_session.status().paused and not Host.decision_open(scene), "detached callbacks cannot resume/end")
	await settle(); check(not is_instance_valid(detached_button), "detached actual control freed")
	press("practice_live_decision")
	stale_resume.call(); stale_end.call()
	check(Host.decision_open(scene), "old generation cannot change reopened sheet")
	press("practice_decision_resume")
	check(scene.drawer_name.is_empty() and scene.practice_session.status().running and not scene.has_meta("practice_decision_session"), "resume cleans sheet")
	check(combat() == frozen, "resume alone does not advance engine")
	# Space follows the same explicit resume path; Escape retains trial cancel.
	press("practice_live_pause"); press("practice_live_decision")
	var event := InputEventKey.new(); event.keycode = KEY_SPACE; event.pressed = true
	scene._input(event)
	check(scene.drawer_name.is_empty() and scene.practice_session.status().running and not Host.decision_open(scene), "Space cleans and resumes")
	press("practice_live_pause"); press("practice_live_decision")
	event.keycode = KEY_ESCAPE; scene._input(event)
	check(scene.practice_session == null and not scene.has_meta("practice_decision_session"), "Escape ends and cleans")
	check(scene.practice_previous_reports.is_empty(), "cancel preserves absence of completed reports")
	check(scene.duel.get_instance_id() == formal_duel_id and formal() == original, "formal state restored")
	# Bounded five same-host loops include stale prior-session callback, 3x
	# open/back, actual advancement, end/close, weakref release and final save.
	for cycle in range(5):
		check(scene.start_practice("bamboo_sprite"), "cycle starts")
		scene.PracticeHost.advance(scene,.2)
		press("practice_live_pause")
		var session_ref: WeakRef = weakref(scene.practice_session)
		var duel_ref: WeakRef = weakref(scene.duel)
		var before := combat()
		for repeat in range(3):
			press("practice_live_decision"); geometry("loop")
			var control_ref: WeakRef = weakref(scene.buttons.practice_decision_back)
			stale_open.call(); stale_resume.call(); stale_end.call()
			check(Host.decision_open(scene), "stale earlier session harmless")
			press("practice_decision_back"); await settle()
			check(control_ref.get_ref() == null, "drawer control released")
		check(before == combat(), "repeated inspection not progression")
		press("practice_live_decision")
		if cycle % 2 == 0: press("practice_decision_end")
		else: scene._close_drawer()
		await settle()
		check(session_ref.get_ref() == null and duel_ref.get_ref() == null, "trial and engine released")
		check(not scene.has_meta("practice_decision_session") and formal() == original, "loop formal/save unchanged")
	check(scene.start_practice("bamboo_sprite"), "completion guard start")
	scene.practice_session.advance(120.0); scene._refresh_drawer()
	check(scene.practice_session.status().finished, "actual trial finished")
	check(not Host.open_decision(scene,scene.practice_session.get_instance_id()), "finished trial cannot open")
	var completed: Dictionary = scene.practice_session.report()
	scene.end_practice(); check(scene.practice_previous_reports.bamboo_sprite == completed, "completed report retained")
	check(scene.start_practice("bamboo_sprite"), "new session starts")
	press("practice_live_pause"); press("practice_live_decision"); press("practice_decision_end")
	check(scene.practice_previous_reports.bamboo_sprite == completed and formal() == original, "inspected cancellation cannot replace report/save")
	scene.queue_free(); scene = null; await settle()
	for suffix in ["", ".bak", ".tmp"]: DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path + suffix))
	print("Practice decision UI: %d checks, %d failures; lifecycle cycles=5" % [checks,failures])
	quit(1 if failures else 0)
