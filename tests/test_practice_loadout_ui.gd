extends SceneTree
## Real host and controls with isolated synthetic state. No natural-play claim.
const Loadout = preload("res://scripts/practice_loadout.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_loadout_ui_%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func snapshot() -> String:
	var data: Dictionary = scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)

func press(key: String) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button) and button is BaseButton, "button exists: " + key)
	if not is_instance_valid(button): return
	check(not button.disabled, "button enabled: " + key)
	if not button.disabled: button.pressed.emit()

func geometry(label: String) -> void:
	var paper: Rect2 = scene._drawer_rect()
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect := Rect2(child.position, child.size)
			check(paper.encloses(rect), label + " control inside paper: " + child.name)
			for other in controls:
				check(not rect.intersects(Rect2(other.position, other.size)), label + " controls do not overlap: " + child.name + " / " + other.name)
			controls.append(child)

func open_enemies() -> void:
	scene.drawer_name = "wardrobe"; scene.drawn_page = "wardrobe"; scene.wardrobe_tab = "equipment"
	scene.set_meta("combat_insight_open", true); scene.set_meta("combat_insight_view", "enemies")
	scene.set_meta("practice_enemy_page", 0)
	scene._refresh_drawer(true)

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene); await process_frame
	scene.set_process(false); scene.demo = true; scene.state.new_game(); scene.state.auto_advance = false
	scene.world_route = ""; scene.encounter_active = false; scene.paused = true
	open_enemies()
	var before := snapshot()
	press("practice_start")
	check(scene.practice_session != null, "real practice starts")
	if scene.practice_session == null: quit(1); return
	check(scene.practice_comparison.is_empty(), "first enemy has no previous comparison")
	var at_start: Dictionary = scene.practice_session.report().get("practice_loadout", {})
	check(not at_start.is_empty(), "host supplies actual-start loadout")
	open_enemies()
	check(scene.buttons.combat_view_tactics.disabled and scene.buttons.combat_back.disabled, "active session locks real loadout navigation")
	check(snapshot() == before, "starting and reading trial preserve formal state/RNG")
	scene.practice_session.advance(120.0); scene._refresh_drawer()
	check(scene.practice_session.status().finished, "real bounded trial finishes")
	check(scene.practice_session.report().get("practice_loadout", {}) == at_start, "completion preserves starting configuration")
	var completed: Dictionary = scene.practice_session.report()
	for mode in [{"width": 960, "height": 540, "strip": false}, {"width": 1200, "height": 400, "strip": true}]:
		scene.size = Vector2(mode.width, mode.height); scene.strip = bool(mode.strip)
		scene.state.settings.ui_scale = 1.25
		scene._refresh_drawer()
		geometry("result " + str(mode.width))
		press("practice_loadout")
		geometry("loadout " + str(mode.width))
		var next = scene.buttons.get("practice_loadout_next")
		var count := 0
		while is_instance_valid(next) and not next.disabled and count < 20:
			press("practice_loadout_next"); geometry("loadout page %d" % count)
			count += 1; next = scene.buttons.get("practice_loadout_next")
		check(count < 20, "loadout pagination bounded")
		var prev = scene.buttons.get("practice_loadout_prev")
		while is_instance_valid(prev) and not prev.disabled and count >= 0:
			press("practice_loadout_prev"); count -= 1
			prev = scene.buttons.get("practice_loadout_prev")
		press("practice_loadout")
		check(scene.practice_session.report() == completed, "reading every page does not alter report")
	# The explicit adjustment action exits only; it never changes equipment or starts another trial.
	before = snapshot()
	press("practice_loadout")
	var old_toggle = scene.buttons.get("practice_loadout")
	var old_toggle_callback: Callable = old_toggle.pressed.get_connections()[0].callable
	press("practice_adjust")
	check(scene.practice_session == null and not scene.encounter_active, "adjust exits trial without auto-start")
	check(scene.wardrobe_tab == "equipment" and not bool(scene.get_meta("combat_insight_open", false)), "adjust opens existing equipment view")
	check(snapshot() == before and scene.paused, "adjust preserves formal state and prior pause")
	check(scene.practice_previous_reports.get("bamboo_sprite", {}) == completed, "finished report and configuration retained together")
	var view_before: bool = bool(scene.get_meta("practice_show_loadout", false))
	old_toggle_callback.call()
	check(bool(scene.get_meta("practice_show_loadout", false)) == view_before and scene.practice_session == null, "stale completed-page callback cannot reopen after leaving")
	check(scene.start_practice("bamboo_sprite"), "explicit same-enemy restart")
	old_toggle_callback.call()
	check(not bool(scene.get_meta("practice_show_loadout", false)), "stale completed-page callback ignored during new running trial")
	await process_frame
	check(not is_instance_valid(old_toggle), "replaced page controls are freed; destroyed controls cannot emit UI input")
	check(scene.practice_comparison == completed, "same enemy uses retained report")
	check(Loadout.comparison(scene.practice_session.report().practice_loadout, completed.practice_loadout) == Loadout.comparison(completed.practice_loadout, completed.practice_loadout), "same configuration retry correctly recognized")
	scene.end_practice()
	check(scene.practice_previous_reports.get("bamboo_sprite", {}) == completed, "cancel cannot replace completed baseline")
	scene.state.set_combat_tactic("guarded")
	check(scene.start_practice("bamboo_sprite"), "explicit changed-loadout restart")
	check(Loadout.comparison(scene.practice_session.report().practice_loadout, completed.practice_loadout) != Loadout.comparison(completed.practice_loadout, completed.practice_loadout), "changed tactic differs from remembered starting configuration")
	scene.end_practice()
	check(scene.start_practice("bamboo_guardian"), "explicit other-enemy start")
	check(scene.practice_comparison.is_empty(), "other enemy never inherits baseline")
	scene.end_practice()
	# Old in-memory reports remain readable, but cannot be called identical loadouts.
	scene.practice_previous_reports["bamboo_sprite"] = {"outcome": "victory", "elapsed": 4.0, "damage_taken": 0}
	check(scene.start_practice("bamboo_sprite"), "old report does not prevent trial")
	scene.practice_session.advance(120.0); open_enemies(); press("practice_loadout")
	geometry("old report loadout")
	check(scene.practice_comparison.get("practice_loadout", {}).is_empty(), "old baseline stays honestly unrecorded")
	scene.end_practice()
	var data: Dictionary = scene.state._snapshot()
	check(not data.has("practice_loadout") and not data.has("practice_previous_reports"), "new evidence stays outside save schema")
	before = snapshot()
	scene.set_meta("practice_show_loadout", true); scene.set_meta("practice_loadout_page", 6)
	scene._reset_presentation()
	check(scene.practice_previous_reports.is_empty() and scene.practice_comparison.is_empty(), "new-game presentation reset clears old trial histories")
	check(not bool(scene.get_meta("practice_show_loadout", true)) and int(scene.get_meta("practice_loadout_page", -1)) == 0, "new-game presentation reset clears page selection")
	check(snapshot() == before, "presentation reset does not mutate formal state")
	scene.queue_free(); await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	print("Practice loadout UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
