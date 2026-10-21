extends SceneTree
## Explicit departure/arrival/return choreography with fixed scrolling anchor.
var scene
var checks := 0
var failures := 0
var save_path := "user://portal_qa_%d.json" % OS.get_process_id()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)


func advance(seconds: float) -> void:
	for index in range(ceili(seconds * 60.0)):
		scene._process(1.0 / 60.0)


func until(predicate: Callable, seconds: float, label: String) -> bool:
	for index in range(ceili(seconds * 60.0)):
		if predicate.call():
			check(true, label)
			return true
		scene._process(1.0 / 60.0)
	var reached := bool(predicate.call())
	check(reached, label)
	return reached


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.meditation_amount = 1.0
	scene.character_x = 520.0
	scene.meditation_settle = 2.0
	scene._start_encounter()
	check(scene.world_route.is_empty(), "Departure never instantly swaps background")
	advance(0.3)
	check(scene.character_x == 520.0, "Seated actor never slides toward a portal")
	until(func(): return scene.encounter_phase == "teleport_out", 2.0, "Actor stands before portal begins")
	advance(0.8)
	check(scene.portal_dissolve > 0.2, "Equipped actor pixels dissolve progressively")
	var age: float = scene.encounter_phase_age
	var alpha: float = scene.portal_dissolve
	scene._set_paused(true)
	advance(3.0)
	check(scene.encounter_phase_age == age and scene.portal_dissolve == alpha, "Pause freezes portal timing and opacity")
	scene._set_paused(false)
	if until(func(): return not scene.world_route.is_empty(), 3.0, "Portal transfers into selected landscape"):
		check(scene.portal_dissolve > 0.99, "Environment changes only while actor is fully dissolved")
		check(scene.encounter_phase == "teleport_arrive" and scene.character_x == scene.ROUTE_HERO_X, "Route arrival uses fixed side-scrolling hero anchor")
		check(scene._route_reveal() == 0.0, "New route begins with transparent reveal")
		check(scene.route_distance == 0.0 and scene.state.total_victories == 0, "Arrival cannot skip travel or award any fight")
		advance(0.7)
		check(scene.portal_dissolve > 0.0 and scene.portal_dissolve < 1.0, "Arrival progressively rematerializes")
		scene._toggle_drawer("wardrobe")
		var world: String = scene.world_route
		var x: float = scene.character_x
		check(scene._scene_camera_transform() == Transform2D.IDENTITY, "Book leaves route camera untouched")
		check(scene.world_route == world and scene.character_x == x, "Book cannot redirect an active portal")
		until(func(): return scene.encounter_phase == "travel", 2.0, "Scrolling waits for arrival effect to finish")
		var distance: float = scene.route_distance
		advance(1.0)
		check(scene.character_x == scene.ROUTE_HERO_X and scene.route_distance > distance, "World scrolls after arrival while hero remains anchored")
		scene._retreat_encounter()
		check(scene.encounter_phase == "teleport_return_out", "Retreat enters explicit return array")
		check(scene.world_route == world and scene.character_x == scene.ROUTE_HERO_X, "Return does not immediately snap world or hero home")
		advance(1.4)
		check(scene.portal_dissolve > 0.99 and scene.world_route == world, "Route remains until reverse dissolve completes")
		until(func(): return scene.world_route.is_empty(), 1.0, "Reverse portal transfers into courtyard")
		check(scene.character_x == 520.0 and scene.encounter_phase == "teleport_home_in" and scene.portal_dissolve > 0.99, "Courtyard anchor restores while actor is fully hidden")
		advance(0.7)
		check(scene.portal_dissolve > 0.0 and scene.portal_dissolve < 1.0, "Home arrival also rematerializes progressively")
		until(func(): return not scene.encounter_active, 2.0, "Home return completes without another departure")
		check(scene.encounter_phase == "idle" and scene.portal_dissolve == 0.0 and not scene.state.stage_run.is_empty() and bool(scene.state.stage_status().paused), "Completed retreat clears host while preserving an explicit paused route checkpoint")
		advance(60.0)
		check(scene.world_route.is_empty() and not scene.encounter_active and scene.state.total_victories == 0, "Idle remains in courtyard with no phantom rewards")
	# Cancelling before departure must not materialize in the destination.
	scene._close_drawer()
	scene.meditation_amount = 1.0
	scene._start_encounter()
	scene._retreat_encounter()
	check(scene.encounter_phase == "teleport_home_in" and scene.world_route.is_empty(), "Preparation cancellation stays in courtyard")
	until(func(): return not scene.encounter_active, 5.0, "Early cancellation settles without destination flash")
	check(scene.world_route.is_empty() and scene.character_x == 520.0 and scene.state.total_victories == 0, "Early cancellation neither moves anchor nor starts fight")
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("Portal transitions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
