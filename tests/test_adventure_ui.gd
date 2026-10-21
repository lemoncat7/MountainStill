extends SceneTree
## Host/state integration for the scrolling route. Uses only isolated saves.
var scene
var checks := 0
var failures := 0
var save_path := "user://adventure_ui_%d.json" % OS.get_process_id()


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)


func press(key: String) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "Button exists: " + key)
	if is_instance_valid(button):
		check(not button.disabled, "Enabled: " + key)
		if not button.disabled:
			button.pressed.emit()


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
	check(reached, label + " (phase=" + str(scene.encounter_phase) + ")")
	return reached


func geometry(label: String) -> void:
	var paper: Rect2 = scene._drawer_rect()
	for child in scene.drawer.get_children():
		if child is BaseButton:
			check(paper.encloses(Rect2(child.position, child.size)), "Fits paper: " + label + " / " + child.text)


func loot_snapshot() -> Array:
	return [scene.state.herbs, scene.state.dew, scene.state.chest_count,
		scene.state.inventory.duplicate(true), scene.state.equipped.duplicate(true),
		scene.state.total_victories, scene.state.stage_clears.duplicate(true)]


func reset_case(seed_value: int = 1) -> void:
	scene._close_drawer()
	scene._reset_presentation()
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state._adventure_rng.seed = seed_value
	scene.state.save_path = save_path
	scene.character_x = 520.0
	scene.character_y = 230.0
	scene.meditation_amount = 1.0
	scene.meditation_settle = 2.0
	scene.size = Vector2(1200, 320)
	scene.set_meta("expedition_view", "route")


func choice_seed(wants_choice: bool) -> int:
	for seed_value in range(256):
		var probe = scene.State.new()
		probe._adventure_rng.seed = seed_value
		var started: Dictionary = probe.start_stage()
		for index in range(2):
			probe.begin_stage_corpse(int(started.run_id), index)
			probe.advance_stage_search(int(started.run_id), index, 2.0)
			probe.complete_stage_search(int(started.run_id), index)
		var landmark: Dictionary = probe.check_route_opportunity(int(started.run_id))
		if bool(landmark.opportunity_pending) == wants_choice:
			return seed_value
	check(false, "Deterministic route fixture seed exists")
	return 0


func open_routes() -> void:
	if scene.drawer_name != "wardrobe":
		scene._toggle_drawer("wardrobe")
	scene.wardrobe_tab = "expedition"
	scene.set_meta("expedition_view", "route")
	scene._refresh_drawer()


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	scene = load("res://main.tscn").instantiate()
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	_test_manual_start_and_scrolling()
	_test_midroute_choice_reload_and_once()
	_test_cancel_and_defeat()
	_test_meridian_buttons()
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("Adventure UI: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _test_manual_start_and_scrolling() -> void:
	reset_case(choice_seed(false))
	advance(90.0)
	check(not scene.encounter_active and not scene.state.stage_status().active, "Idle never starts a route")
	scene.state.expedition_auto = true
	advance(60.0)
	check(not scene.encounter_active and not scene.state.expedition_auto, "Legacy auto flag cannot start encounters")
	open_routes()
	for width in [1000, 1200, 1360]:
		scene.size = Vector2(width, 320)
		scene._refresh_drawer()
		geometry("Expedition %d" % width)
	scene.size = Vector2(1200, 320)
	check(scene._scene_camera_transform() == Transform2D.IDENTITY, "Book never reframes world")
	check(scene.character_x == 520.0 and scene.meditation_amount == 1.0, "Reading routes leaves meditator at rest")
	check(scene.buttons.get("auto_expedition") == null, "No continuous-combat toggle remains")
	press("stage_bamboo_pass")
	check(not scene.encounter_active, "Selecting a route never starts it")
	press("depart_stage")
	check(scene.encounter_active and scene.encounter_phase == "prepare_portal", "Departure begins explicit teleport preparation")
	var run_id: int = scene.encounter_run_id
	scene._start_encounter()
	check(scene.encounter_run_id == run_id, "Repeated departure cannot duplicate run")
	advance(0.2)
	check(scene.meditation_amount > 0 and scene.character_x == 520.0, "Actor stands before departure without seated skating")
	if not until(func(): return scene.encounter_phase == "travel", 8.0, "Portal finishes before scrolling travel"):
		return
	check(scene.world_route == "bamboo_pass" and scene.character_x == scene.ROUTE_HERO_X, "Route uses fixed right-facing hero anchor")
	var distance: float = scene.route_distance
	var enemy_x: float = scene.encounter_enemy_x
	advance(1.0)
	check(scene.route_distance > distance and scene.encounter_enemy_x < enemy_x and scene.character_x == scene.ROUTE_HERO_X, "World and upcoming enemy approach while hero stays fixed")
	check(float(scene.side_motion.get("blend", 0.0)) > 0.0, "Fixed-anchor travel still drives actual side-walk animation")
	scene._toggle_drawer("wardrobe")
	var world: String = scene.world_route
	distance = scene.route_distance
	advance(0.5)
	check(scene._scene_camera_transform() == Transform2D.IDENTITY and scene.character_x == scene.ROUTE_HERO_X and scene.world_route == world, "Opening book during route leaves camera, anchor and world unchanged")
	check(scene.route_distance > distance, "Book overlay does not silently pause route travel")
	scene._close_drawer()
	scene._set_paused(true)
	distance = scene.route_distance
	var age: float = scene.encounter_phase_age
	advance(2.0)
	check(scene.route_distance == distance and scene.encounter_phase_age == age and scene.character_x == scene.ROUTE_HERO_X, "Pause freezes travel and fixed anchor")
	scene._set_paused(false)
	if not until(func(): return scene.encounter_phase == "fight", 12.0, "First roadside enemy starts contact-timed combat"):
		return
	check(scene.encounter_index == 0 and not scene.route_boss and scene.route_distance == scene.ROUTE_EVENTS[0], "First combat begins at first route landmark")
	scene._toggle_drawer("wardrobe")
	var book_duel_time: float = scene.duel.elapsed
	advance(0.2)
	check(scene._scene_camera_transform() == Transform2D.IDENTITY and scene.character_x == scene.ROUTE_HERO_X and scene.duel.elapsed > book_duel_time, "Combat continues under book without camera shift or frame reset")
	scene._close_drawer()
	var duel_time: float = scene.duel.elapsed
	var health := [scene.vitality, scene.enemy_hp]
	scene._set_paused(true)
	advance(3.0)
	check(scene.duel.elapsed == duel_time and [scene.vitality, scene.enemy_hp] == health, "Pause freezes duel clocks and HP")
	scene._set_paused(false)
	if not until(func(): return scene.encounter_phase == "pickup", 30.0, "Enemy defeat creates pickup presentation"):
		return
	check(scene.enemy_hp == 0.0 and scene.state.total_victories == 0 and bool(scene.state.stage_corpse_status().get("pending", false)), "Zero-HP defeat retains unpaid body until search")
	var loot := loot_snapshot()
	check(not scene.state.defeat_stage_monster(run_id, 0).ok and loot_snapshot() == loot, "Duplicate callback cannot award first enemy again")
	until(func(): return scene.pickup_claimed_at >= 0.0, 10.0, "Close-range two-second search claims body")
	check(scene.state.total_victories == 1, "Completed search awards first kill once")
	loot = loot_snapshot()
	check(not scene.state.complete_stage_search(run_id, 0).ok and loot_snapshot() == loot, "Repeated search completion cannot duplicate payout")
	until(func(): return scene.encounter_phase == "travel", 5.0, "Claim receipt settles before continuing")
	check(loot_snapshot() == loot and scene.encounter_phase == "travel", "Receipt animation grants no second reward and resumes scrolling")
	if not until(func(): return scene.encounter_phase == "fight" and scene.route_boss, 80.0, "Second enemy and checked landmark lead to explicit boss"):
		return
	check(scene.encounter_index == 2 and scene.state.total_victories == 2 and scene.state.stage_status().opportunity_checked, "Boss follows two regular wins and the once-only route check")
	check(scene.route_distance == scene.ROUTE_EVENTS[2] and scene.route_enemy_definition.boss, "Boss uses final world landmark and distinct definition")
	if not until(func(): return scene.encounter_phase == "teleport_return_out", 52.0, "Boss victory and close-range search begin return portal"):
		return
	check(scene.enemy_hp == 0.0 and scene.state.total_victories == 3 and scene.state.stage_clears.bamboo_pass == 1, "Only genuine boss victory completes route once")
	check(scene.world_route == "bamboo_pass" and scene.character_x == scene.ROUTE_HERO_X, "Victory never snaps directly to courtyard")
	until(func(): return not scene.encounter_active, 5.0, "Return portal settles at home")
	check(scene.world_route.is_empty() and scene.character_x == 520.0 and scene.encounter_phase == "idle", "Victory restores exact courtyard anchor")
	loot = loot_snapshot()
	advance(90.0)
	check(loot_snapshot() == loot and not scene.encounter_active, "Finished route never chains or repeats rewards")


func _test_midroute_choice_reload_and_once() -> void:
	reset_case(choice_seed(true))
	scene._start_encounter()
	if not until(func(): return scene.encounter_phase == "opportunity", 100.0, "Natural seeded opportunity pauses before boss"):
		return
	check(scene.state.total_victories == 2 and scene.encounter_index == 2 and scene.route_boss and scene.route_distance == scene.route_opportunity_at, "Opportunity belongs between two regular enemies and boss")
	var pending: Dictionary = scene.state.pending_opportunity.duplicate(true)
	var distance: float = scene.route_distance
	var loot := loot_snapshot()
	advance(240.0)
	check(scene.encounter_phase == "opportunity" and scene.route_distance == distance and scene.state.pending_opportunity == pending and loot_snapshot() == loot, "Unanswered opportunity never times out, advances boss or awards anything")
	check(not scene.state.defeat_stage_monster(scene.encounter_run_id, 2).ok, "State blocks any boss reward while choice awaits click")
	check(scene.state.save_game(), "Mid-route waiting choice saves")
	var reloaded = scene.State.new()
	reloaded.save_path = save_path
	reloaded.load_game()
	check(reloaded.stage_status().paused and reloaded.stage_status().opportunity_pending and not reloaded.stage_status().active, "Loading checkpoint keeps choice pending without auto-start")
	scene._reset_presentation()
	scene.state = reloaded
	scene.state.auto_advance = false
	scene.character_x = 520.0
	scene.meditation_amount = 1.0
	advance(60.0)
	check(not scene.encounter_active and scene.world_route.is_empty() and scene.state.total_victories == 2, "Loaded host remains home until explicit resume")
	open_routes()
	check(scene.buttons.depart_stage.text == "继续此程", "Route book offers explicit checkpoint resume")
	press("depart_stage")
	if not until(func(): return scene.encounter_phase == "opportunity", 8.0, "Resume portal restores waiting landmark before boss"):
		return
	check(scene.route_distance == scene.route_opportunity_at and scene.state.total_victories == 2 and scene.state.pending_opportunity == pending, "Resume never repeats claimed ordinary encounters")
	scene._open_route_opportunity()
	geometry("Route opportunity")
	check(scene.drawer_name == "wardrobe" and scene._scene_camera_transform() == Transform2D.IDENTITY and scene.character_x == scene.ROUTE_HERO_X, "Choice opens existing book without a modal or camera jump")
	var old_button = scene.buttons.get("opportunity_gather_gift")
	var herbs_before: int = scene.state.herbs
	press("opportunity_gather_gift")
	check(scene.state.pending_opportunity.is_empty() and scene.state.herbs == herbs_before + 6, "Click consumes exactly one gift choice")
	loot = loot_snapshot()
	if is_instance_valid(old_button):
		old_button.pressed.emit()
	check(loot_snapshot() == loot, "Stale choice button cannot duplicate reward")
	advance(0.1)
	check(scene.encounter_phase == "travel" and scene.drawer_name.is_empty(), "Resolved choice closes book and continues route")
	until(func(): return not scene.encounter_active, 60.0, "Resolved route finishes boss and returns through portal")
	check(scene.state.total_victories == 3 and scene.state.stage_clears.bamboo_pass == 1 and scene.state.pending_opportunity.is_empty(), "Resume completes remaining boss without post-clear opportunity spawn")


func _test_cancel_and_defeat() -> void:
	reset_case(choice_seed(false))
	scene._start_encounter()
	if until(func(): return scene.encounter_phase == "fight", 15.0, "Cancellation fixture reaches fight"):
		var loot := loot_snapshot()
		scene._retreat_encounter()
		check(scene.encounter_phase == "teleport_return_out" and scene.duel.cancelled, "Explicit retreat cancels timeline and uses return portal")
		until(func(): return not scene.encounter_active, 5.0, "Cancelled combat returns safely")
		check(loot_snapshot() == loot and scene.state.stage_status().paused and scene.state.stage_status().kills == 0 and not scene.state.stage_status().failed and scene.state.total_victories == 0, "Voluntary retreat preserves unpaid checkpoint without awarding a living enemy or losing inventory")
	reset_case(choice_seed(false))
	scene._start_encounter()
	if until(func(): return scene.encounter_phase == "pickup", 40.0, "Post-kill retreat fixture reaches pickup"):
		var loot := loot_snapshot()
		scene._retreat_encounter()
		until(func(): return not scene.encounter_active, 5.0, "Retreat after kill returns home")
		check(loot_snapshot() == loot and scene.state.total_victories == 0 and scene.state.stage_clears.is_empty() and bool(scene.state.stage_corpse_status().get("pending", false)), "Retreat preserves unpaid body without losing or awarding unsearched loot")
	reset_case(choice_seed(false))
	scene._start_encounter()
	if until(func(): return scene.encounter_phase == "travel", 8.0, "Defeat fixture enters route"):
		scene.vitality = 1.0
		var loot := loot_snapshot()
		until(func(): return scene.encounter_phase == "teleport_return_out", 40.0, "Actual lethal enemy contact triggers safe return")
		check(scene.vitality == 0.0 and scene.state.total_victories == 0 and not scene.encounter_complete, "Zero HP is truthful and death never counts as victory")
		until(func(): return not scene.encounter_active, 5.0, "Defeated character completes home portal")
		check(loot_snapshot() == loot and scene.state.stage_status().paused and scene.state.stage_status().failed and scene.state.stage_status().kills == 0, "Defeat preserves resources, equipment and unpaid checkpoint without extra rewards")
		advance(60.0)
		check(not scene.encounter_active and scene.world_route.is_empty(), "Death does not silently restart route")
		var failed_run: int = scene.state.stage_status().run_id
		open_routes()
		press("depart_stage")
		check(scene.encounter_run_id == failed_run and not scene.state.stage_status().failed and scene.vitality == scene.state.stats().max_hp, "Explicit retry heals to real realm maximum and retains same unclaimed run")
		if until(func(): return scene.encounter_phase == "pickup", 45.0, "Retried enemy is genuinely defeated after manual restart"):
			check(scene.state.total_victories == 0, "Retry victory alone does not grant unsearched reward")
			until(func(): return scene.pickup_claimed_at >= 0.0, 10.0, "Retry corpse is searched at close range")
			check(scene.state.total_victories == 1, "Only retry's completed search earns one monster reward")
			scene._retreat_encounter()
			until(func(): return not scene.encounter_active, 5.0, "Successful retry can return with checkpoint")


func _test_meridian_buttons() -> void:
	reset_case()
	scene.state.qi = 1000.0
	scene.state.herbs = 99
	scene.state.dew = 99
	scene._toggle_drawer("wardrobe")
	press("wardrobe_meridian")
	geometry("Meridians")
	press("meridian_row_baihui")
	check(scene.buttons.unlock_meridian.disabled, "Later acupoint cannot bypass earlier one")
	press("meridian_row_qihai")
	var qi_before: float = scene.state.qi
	press("unlock_meridian")
	check(scene.state.meridian_count == 1 and scene.state.qi == qi_before - 30.0, "Meridian button consumes exact cost once")
	check(scene.meridian_glow == 1.0 and scene.buttons.unlock_meridian.disabled, "Opened meridian has feedback and cannot be charged twice")
