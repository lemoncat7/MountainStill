extends SceneTree
## Real paper controls: navigation, bounded layout, next-encounter choices and evidence.
const Insight = preload("res://scripts/combat_insight_pages.gd")
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://practice_controls_ui_%d.json" % OS.get_process_id()

func _initialize() -> void: call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func press(key: String) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "real button exists: " + key)
	if not is_instance_valid(button): return
	check(not button.disabled, "real button enabled: " + key)
	if not button.disabled: button.pressed.emit()

func geometry(label: String) -> void:
	var paper: Rect2 = scene._drawer_rect()
	var controls: Array = []
	for child in scene.drawer.get_children():
		if child is BaseButton and child.visible:
			var rect := Rect2(child.position, child.size)
			check(paper.encloses(rect), "control inside paper: " + label + " / " + child.name)
			for other in controls:
				check(not rect.intersects(Rect2(other.position, other.size)), "no overlapping controls: " + label + " / " + child.name + " " + str(rect) + " / " + other.name + " " + str(Rect2(other.position,other.size)))
			controls.append(child)

func open_insight() -> void:
	scene.wardrobe_tab = "equipment"
	scene.set_meta("combat_insight_open", false)
	if scene.drawer_name != "wardrobe": scene._toggle_drawer("wardrobe")
	else: scene._refresh_drawer()
	press("evasion_stat")

func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	for width in [960, 1000, 1200, 1440]:
		scene.size = Vector2(width, 540 if width == 960 else 320)
		open_insight()
		press("combat_view_enemies")
		check(Insight._view(scene) == "enemies", "enemy tab reachable")
		scene.set_meta("practice_enemy_page", 0)
		scene._refresh_drawer()
		geometry("enemy %d" % width)
		check(scene.buttons.practice_enemy_prev.disabled, "first enemy bounded")
		var rows: Array = scene.practice_enemy_rows()
		for i in range(1, rows.size()):
			press("practice_enemy_next")
			check(scene.buttons.practice_start.disabled == not bool(rows[i].unlocked), "locked entry cannot start")
			geometry("enemy %d page %d" % [width, i])
		check(scene.buttons.practice_enemy_next.disabled, "last enemy bounded")
	scene.set_meta("practice_enemy_page", 0)
	scene._refresh_drawer()
	press("practice_start")
	check(scene.practice_session != null, "real start creates isolated session")
	check(scene.practice_comparison.is_empty(), "first attempt has no comparison")
	check(scene.drawer_name.is_empty(), "live practice closes paper")
	press("practice_live_pause")
	check(scene.practice_session.status().paused, "live button pauses with paper closed")
	press("practice_live_pause")
	check(scene.practice_session.status().running, "live button resumes with paper closed")
	# Explicitly reopen to exercise safe sheet controls while simulation is paused.
	scene.drawer_name = "wardrobe"
	scene.wardrobe_tab = "equipment"
	scene.set_meta("combat_insight_open", true)
	scene.set_meta("combat_insight_view", "enemies")
	scene._refresh_drawer()
	geometry("active practice")
	check(scene.buttons.combat_view_tactics.disabled, "loadout tab locked")
	check(scene.buttons.combat_back.disabled, "back locked during practice")
	press("practice_pause")
	check(scene.practice_session.status().paused, "pause actual session")
	check(not scene.buttons.practice_pause.disabled, "resume remains enabled")
	press("practice_pause")
	check(scene.practice_session.status().running, "resume actual session")
	scene.practice_session.advance(120.0)
	scene._refresh_drawer()
	check(scene.practice_session.status().finished, "bounded actual session completes")
	geometry("completed practice")
	check(scene.buttons.practice_pause.disabled, "finished session cannot pause")
	var previous: Dictionary = scene.practice_session.report()
	press("practice_retry")
	check(scene.practice_comparison == previous, "retry compares same enemy completed report")
	check(scene.practice_session.status().running, "repeat same opponent restarts")
	press("practice_live_end")
	check(scene.practice_session == null, "exit destroys practice session")
	print("Practice controls UI: %d checks, %d failures" % [checks, failures])
	scene.queue_free()
	await process_frame
	DirAccess.remove_absolute(ProjectSettings.globalize_path(save_path))
	quit(1 if failures else 0)
