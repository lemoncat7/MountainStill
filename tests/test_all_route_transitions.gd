extends SceneTree
## Headless integration, using the real host, selection buttons, duel and saves.
## Real predecessor-clear APIs establish route access; preset combat gear is an
## integration fixture. Natural earned-build balance is tested separately.
const ROUTES := ["bamboo_pass", "creek_bridge", "cloud_slope", "ember_ruins", "moon_marsh", "summit_gate"]
const SPECIES := {"bamboo_pass": "moss_beast", "creek_bridge": "river_stone", "cloud_slope": "cloud_crane", "ember_ruins": "ember_guardian", "moon_marsh": "moon_wisp", "summit_gate": "summit_keeper"}
const BOSS_MOVES := {"bamboo_pass": "charge", "creek_bridge": "sweep", "cloud_slope": "burst", "ember_ruins": "burst", "moon_marsh": "sweep", "summit_gate": "charge"}
var scene
var checks := 0
var failures := 0
var context := ""
var save_path := "user://all_route_transitions_%d.json" % OS.get_process_id()
var asset_digests: Dictionary = {}
var fixture_victories := 0
var fixture_clears: Dictionary = {}


func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL [%s]: %s" % [context, label])


func advance(seconds: float) -> void:
	for frame in range(ceili(seconds * 60.0)):
		scene._process(1.0 / 60.0)


func until(predicate: Callable, seconds: float, label: String) -> bool:
	for frame in range(ceili(seconds * 60.0)):
		if predicate.call():
			check(true, label)
			return true
		scene._process(1.0 / 60.0)
	var reached := bool(predicate.call())
	check(reached, "%s (phase=%s, index=%d, hp=%s)" % [label, scene.encounter_phase, scene.encounter_index, scene.enemy_hp])
	return reached


func click(key: String) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "Actual button exists: " + key)
	if is_instance_valid(button):
		check(not button.disabled, "Actual button enabled: " + key)
		if not button.disabled:
			button.pressed.emit()


func loot_snapshot() -> Array:
	# Passive meditation legitimately changes qi while waiting; no gather, brew,
	# journey, quest claim or automatic advancement is enabled in this fixture.
	return [scene.state.herbs, scene.state.dew, scene.state.chest_count,
		scene.state.inventory.duplicate(true), scene.state.equipped.duplicate(true),
		scene.state.total_victories, scene.state.stage_clears.duplicate(true), scene.state.materials.inventory.duplicate(true)]


func open_routes() -> void:
	if scene.drawer_name != "wardrobe":
		scene._toggle_drawer("wardrobe")
	scene.wardrobe_tab = "expedition"
	scene.set_meta("expedition_view", "route")
	scene._refresh_drawer()


func new_host() -> void:
	if is_instance_valid(scene):
		scene.queue_free()
		await process_frame
		await process_frame
	scene = load("res://main.tscn").instantiate()
	# Set before _ready, so even the normal startup load/save is isolated.
	scene.state.save_path = save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo = true
	scene.size = Vector2(1200, 320)


func unlock_predecessor_fixture(state, route: String) -> void:
	state.auto_advance = false
	state.realm = maxi(3, int(state.Content.STAGES[route].unlock_realm))
	for previous in ROUTES:
		if previous == route:
			break
		check(state.select_stage(previous), "Prerequisite fixture selects reachable earlier route: " + previous)
		var started: Dictionary = state.start_stage()
		check(bool(started.get("ok", false)), "Prerequisite fixture begins earlier route")
		for index in range(3):
			if index == 2:
				state.check_route_opportunity(int(started.run_id))
				if state.stage_status().opportunity_pending:
					state.choose_opportunity("gather_gift")
			check(state.defeat_stage_monster(int(started.run_id), index).ok, "Prerequisite fixture pays earlier checkpoint once")


func fixture_seed(route: String, wants_choice: bool) -> int:
	# Discover a reproducible fixture through public stage APIs. Production
	# probability remains 18%; neither host nor state is forced to spawn it.
	for seed_value in range(256):
		var probe = scene.State.new()
		unlock_predecessor_fixture(probe, route)
		probe.select_stage(route)
		probe._adventure_rng.seed = seed_value
		var started: Dictionary = probe.start_stage()
		for index in range(2):
			probe.begin_stage_corpse(int(started.run_id), index)
			probe.advance_stage_search(int(started.run_id), index, 2.0)
			probe.complete_stage_search(int(started.run_id), index)
		var marker: Dictionary = probe.check_route_opportunity(int(started.run_id))
		if bool(marker.opportunity_pending) == wants_choice:
			return seed_value
	check(false, "Natural fixture seed exists")
	return 0


func reset_case(route: String, wants_choice: bool = false) -> void:
	scene._close_drawer()
	scene._reset_presentation()
	scene.state.new_game()
	scene.state.save_path = save_path
	scene.state.auto_advance = false
	unlock_predecessor_fixture(scene.state, route)
	var late: bool = ROUTES.find(route) >= 3
	if late:
		scene.state.technique_levels.mist = 5
	for template in (["weapon_sword", "chest_jade", "legs_blue", "feet_cloth", "head_crown"] if late else ["weapon_sword", "chest_jade", "legs_blue", "feet_cloth"]):
		var item_id: int = scene.state.gear._allocate_id()
		scene.state.gear.inventory.append(scene.state.gear._make_item(item_id, template, "rare" if late else "common", scene.state.realm + 1 if late else 4))
		scene.state.equip_item(item_id)
	fixture_victories = scene.state.total_victories
	fixture_clears = scene.state.stage_clears.duplicate()
	scene.state._adventure_rng.seed = fixture_seed(route, wants_choice)
	scene.character_x = 520.0
	scene.character_y = 230.0
	scene.meditation_amount = 1.0
	scene.meditation_settle = 2.0
	scene.demo = true
	open_routes()
	if ROUTES.find(route) >= 3:
		click("stage_next")
	click("stage_" + route)
	check(scene.state.selected_stage == route and scene.world_route.is_empty() and not scene.encounter_active, "Selection changes only the chosen route")


func asset_digest(texture, expected_path: String) -> String:
	check(texture is Texture2D, "Loaded native texture: " + expected_path)
	if not texture is Texture2D:
		return ""
	check(texture.resource_path == expected_path, "Texture binds the intended file: " + expected_path)
	var pixels: Image = texture.get_image()
	check(pixels != null and not pixels.is_empty() and pixels.get_used_rect().has_area(), "Texture has visible pixels: " + expected_path)
	if pixels == null or pixels.is_empty():
		return ""
	var digest := HashingContext.new()
	digest.start(HashingContext.HASH_SHA256)
	digest.update(pixels.get_data())
	return digest.finish().hex_encode()


func test_assets(route: String) -> void:
	context = route + " / assets"
	asset_digests[route] = asset_digest(scene.route_panoramas.get(route), "res://assets/cultivation/routes/" + route + "_panorama.png")
	if ROUTES.find(route) < 3:
		asset_digests[route + "_legacy"] = asset_digest(scene.route_assets.get(route), "res://assets/cultivation/routes/" + route + ".png")
		asset_digests[route + "_scroll"] = asset_digest(scene.route_scroll_assets.get(route), "res://assets/cultivation/routes/" + route + "_scroll.png")
	for pose in ["idle", "windup", "attack", "boss_idle", "boss_windup", "boss_attack"]:
		var key: String = route + "_" + pose
		asset_digests[key] = asset_digest(scene.beast_assets.get(key), "res://assets/cultivation/beasts/" + key + ".png")
	check(asset_digests[route + "_idle"] != asset_digests[route + "_boss_idle"], "Boss art is genuinely different from ordinary enemy art")
	check(asset_digests[route + "_boss_idle"] != asset_digests[route + "_boss_windup"] and asset_digests[route + "_boss_windup"] != asset_digests[route + "_boss_attack"], "Boss poses contain distinct authored pixels")


func test_route_and_interrupted_boss(route: String) -> void:
	context = route + " / travel and boss restart"
	reset_case(route)
	var baseline := loot_snapshot()
	advance(30.0)
	check(loot_snapshot() == baseline and not scene.encounter_active, "Selected route never starts from idle cultivation")
	click("depart_stage")
	var run_id: int = scene.encounter_run_id
	check(scene.encounter_phase == "prepare_portal" and scene.world_route.is_empty(), "Manual departure first prepares in the courtyard")
	if not until(func(): return scene.encounter_phase == "teleport_arrive", 6.0, "Portal enters the selected route"):
		return
	check(scene.world_route == route and scene.portal_dissolve > 0.99 and scene.character_x == scene.ROUTE_HERO_X, "Correct world loads only while actor is dissolved, at fixed anchor")
	if not until(func(): return scene.encounter_phase == "travel", 3.0, "Arrival completes before travel"):
		return
	check(scene.route_panoramas[scene.world_route].resource_path.ends_with(route + "_panorama.png"), "World route resolves its own landscape texture")
	var distance: float = scene.route_distance
	var enemy_x: float = scene.encounter_enemy_x
	advance(0.5)
	check(scene.route_distance > distance and scene.encounter_enemy_x < enemy_x and scene.character_x == scene.ROUTE_HERO_X, "World and enemy scroll toward a fixed hero")
	check(float(scene.side_motion.get("blend", 0.0)) > 0.0, "Fixed hero has virtual walking motion")
	for index in range(3):
		if not until(func(): return scene.encounter_phase == "fight" and scene.encounter_index == index, 50.0, "Encounter %d begins on the route" % (index + 1)):
			return
		var expected: Dictionary = scene.state.Content.STAGES[route].monsters[index]
		check(scene.route_enemy_definition.id == expected.id and scene.encounter_enemy_name == expected.name and scene.enemy_max_hp == float(expected.hp), "Encounter %d uses its own name, identity and HP" % (index + 1))
		check(scene.route_enemy_definition.visual_type == SPECIES[route] and scene.route_enemy_definition.route_id == route and scene.duel._enemy.visual_type == SPECIES[route], "Host and duel agree on native enemy species")
		check(scene.route_boss == (index == 2) and bool(scene.duel._enemy.boss) == (index == 2), "Only third encounter is a boss")
		check(scene.route_distance == scene.ROUTE_EVENTS[index] and scene.character_x == scene.ROUTE_HERO_X and scene.state.total_victories == fixture_victories + index, "Combat stops at the exact landmark without premature reward")
		distance = scene.route_distance
		enemy_x = scene.encounter_enemy_x
		advance(0.15)
		check(scene.route_distance == distance and scene.encounter_enemy_x == enemy_x and scene.character_x == scene.ROUTE_HERO_X, "Combat stops world scrolling without anchor drift")
		if index < 2:
			if not until(func(): return scene.encounter_phase == "pickup", 35.0, "Ordinary enemy genuinely reaches zero HP"):
				return
			check(scene.enemy_hp == 0 and scene.state.total_victories == fixture_victories + index and not scene.state.stage_corpse_status().is_empty(), "Zero HP creates an unpaid body, not an immediate reward")
			if not until(func(): return scene.pickup_claimed_at >= 0.0, 12.0, "Approach and two-second search commit the ordinary receipt"):
				return
			check(scene.state.total_victories == fixture_victories + index + 1 and scene.state.stage_clears == fixture_clears and scene.state.stage_corpse_status().is_empty(), "Only completed search receives its single ordinary reward")
		else:
			check(scene.route_enemy_definition.boss_move == BOSS_MOVES[route] and scene.duel._enemy.boss_move == BOSS_MOVES[route], "Boss receives route-specific charge, sweep or burst")
			check(scene.state.stage_status().opportunity_checked and not scene.state.stage_status().opportunity_pending, "Boss follows the one-time no-choice checkpoint")
			if not until(func(): return scene.enemy_hp > 0.0 and scene.enemy_hp < scene.enemy_max_hp, 15.0, "Boss takes real damage before interruption"):
				return
	var earned := loot_snapshot()
	var rng_state: int = scene.state._adventure_rng.state
	check(scene.state.total_victories == fixture_victories + 2 and scene.state.stage_run.kills == 2, "Living damaged boss has no reward or clear")
	check(scene._save_current(), "Interrupted live boss saves through normal host API")
	await new_host()
	check(scene.state.stage_status().paused and scene.state.stage_status().kills == 2 and scene.state.stage_status().run_id == run_id, "Restart restores same next-unkilled boss checkpoint")
	check(loot_snapshot() == earned and scene.state._adventure_rng.state == rng_state, "Restart grants no boss reward and consumes no reward RNG")
	advance(30.0)
	check(not scene.encounter_active and scene.world_route.is_empty() and loot_snapshot() == earned, "Interrupted boss waits at home for explicit resume")
	open_routes()
	check(scene.buttons.depart_stage.text == "继续此程", "Book clearly offers checkpoint resume")
	click("depart_stage")
	if not until(func(): return scene.encounter_phase == "fight" and scene.route_boss, 20.0, "Explicit resume reaches only the uncleared boss"):
		return
	check(scene.world_route == route and scene.encounter_run_id == run_id and scene.encounter_index == 2 and scene.enemy_hp == scene.enemy_max_hp, "Boss restarts at full HP in the original route and run")
	check(loot_snapshot() == earned and scene.state._adventure_rng.state == rng_state, "Resume never repeats earlier kills or rerolls the landmark")
	# Enable real automatic key-action persistence for the victory boundary.
	scene.demo = false
	if not until(func(): return scene.encounter_phase == "pickup", 40.0, "Resumed boss reaches genuine zero-HP victory"):
		scene.demo = true
		return
	check(scene.enemy_hp == 0 and scene.state.total_victories == fixture_victories + 2 and not scene.state.stage_corpse_status().is_empty(), "Boss body remains unpaid until searched")
	if not until(func(): return scene.pickup_claimed_at >= 0.0, 12.0, "Boss approach and two-second search commit the saved receipt"):
		scene.demo = true
		return
	scene.demo = true
	check(scene.enemy_hp == 0 and scene.state.total_victories == fixture_victories + 3 and scene.state.stage_clears.get(route, 0) == 1, "Exactly three genuine kills clear selected route once")
	check(scene.state.stage_run.is_empty() and scene.state.pending_opportunity.is_empty() and scene.world_route == route, "State completes after search and before receipt fade/return portal")
	var victory_loot := loot_snapshot()
	check(not scene.state.defeat_stage_monster(run_id, 2).ok and loot_snapshot() == victory_loot, "Duplicate completed-boss callback is rejected")
	# The search receipt callback above already saved. Freeze that exact file: this
	# restart deliberately omits another save after the return animation.
	if until(func(): return scene.encounter_phase == "teleport_return_out", 6.0, "Victory begins the return portal"):
		scene._retreat_encounter()
		check(loot_snapshot() == victory_loot and scene.state.stage_run.is_empty(), "Cancel during victory return cannot revoke or duplicate earned rewards")
		until(func(): return not scene.encounter_active, 5.0, "Cancelled victory return still settles at home")
	await new_host()
	check(scene.state.stage_run.is_empty() and not scene.state.stage_status().paused and not scene.state.stage_status().active, "Immediate post-victory save loads without a new or resumable stage")
	check(scene.world_route.is_empty() and not scene.encounter_active and loot_snapshot() == victory_loot, "Post-victory restart restores all rewards at home exactly once")
	advance(60.0)
	check(not scene.encounter_active and loot_snapshot() == victory_loot, "Completed saved route never restarts while idle")


func test_opportunity_restart(route: String) -> void:
	context = route + " / waiting opportunity"
	reset_case(route, true)
	click("depart_stage")
	if not until(func(): return scene.encounter_phase == "opportunity", 100.0, "Naturally seeded opportunity stops before the boss"):
		return
	var pending: Dictionary = scene.state.pending_opportunity.duplicate(true)
	var earned := loot_snapshot()
	var run_id: int = scene.encounter_run_id
	var rng_state: int = scene.state._adventure_rng.state
	check(scene.world_route == route and scene.route_distance == scene.route_opportunity_at and scene.character_x == scene.ROUTE_HERO_X, "Choice waits at correct route landmark and fixed hero anchor")
	check(scene.state.total_victories == fixture_victories + 2 and scene.route_boss and pending.stage_id == route and pending.run_id == run_id, "Choice belongs to this route after exactly two regular kills")
	advance(240.0)
	check(scene.encounter_phase == "opportunity" and scene.route_distance == scene.route_opportunity_at and loot_snapshot() == earned and scene.state.pending_opportunity == pending, "Long unanswered choice has no timeout, reward or movement")
	check(scene._save_current(), "Unanswered choice saves")
	var qi_before_offline: float = scene.state.qi
	# Age only this suite's isolated save to exercise the real offline loader.
	# A legacy true auto flag must still never start a route after migration.
	var saved: Dictionary = scene.state._read_save(save_path).get("data", {})
	check(not saved.is_empty(), "Saved waiting checkpoint can be read before offline fixture")
	if saved.is_empty():
		return
	saved.saved_at = int(Time.get_unix_time_from_system()) - 3600
	saved.expedition_auto = true
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	check(file != null, "Isolated offline timestamp fixture is writable")
	if file == null:
		return
	file.store_string(JSON.stringify(saved))
	file.flush()
	file.close()
	# Two independent fresh hosts verify that simply loading and saving a
	# pending choice cannot reroll, consume or silently start it.
	for restart_index in range(2):
		await new_host()
		if restart_index == 0:
			check(scene.state.last_offline.seconds >= 3600 and scene.state.qi > qi_before_offline, "Actual one-hour offline load still awards passive cultivation")
			check(not scene.state.expedition_auto and scene.state.last_offline.journeys == 0, "Offline load strips legacy combat automation without creating unrelated journeys")
		check(scene.state.stage_status().paused and scene.state.stage_status().opportunity_pending and not scene.encounter_active and scene.world_route.is_empty(), "Restart %d remains home with pending choice" % (restart_index + 1))
		check(scene.state.pending_opportunity == pending and scene.state._adventure_rng.state == rng_state and loot_snapshot() == earned, "Restart %d preserves choice, RNG and paid rewards" % (restart_index + 1))
		advance(15.0)
		check(not scene.encounter_active and scene.state.pending_opportunity == pending, "Loaded pending choice never auto-departs")
	open_routes()
	click("depart_stage")
	if not until(func(): return scene.encounter_phase == "opportunity", 8.0, "Manual resume restores awaiting-choice phase"):
		return
	check(scene.world_route == route and scene.route_distance == scene.route_opportunity_at and scene.encounter_run_id == run_id and loot_snapshot() == earned, "Resume skips paid encounters without skipping choice")
	scene._start_encounter()
	advance(10.0)
	check(scene.encounter_phase == "opportunity" and scene.state.pending_opportunity == pending and scene.state._adventure_rng.state == rng_state, "Repeated start while waiting cannot overwrite or reroll choice")
	scene._open_route_opportunity()
	var gift: Dictionary = scene.state.opportunity_status().choices[0].rewards
	var herbs: int = scene.state.herbs
	var dew: int = scene.state.dew
	var choice_button = scene.buttons.get("opportunity_gather_gift")
	click("opportunity_gather_gift")
	check(scene.state.pending_opportunity.is_empty() and scene.state.herbs == herbs + int(gift.herbs) and scene.state.dew == dew + int(gift.dew), "Explicit choice grants its route-scaled gift exactly once")
	var after_choice := loot_snapshot()
	if is_instance_valid(choice_button):
		choice_button.pressed.emit()
	check(loot_snapshot() == after_choice and not scene.state.choose_opportunity("read_inscription").ok, "Stale button and alternate second choice cannot double-claim")
	advance(0.1)
	check(scene.encounter_phase == "travel" and scene.drawer_name.is_empty(), "Chosen opportunity closes book and resumes travel")
	if until(func(): return not scene.encounter_active, 70.0, "Resolved route defeats boss and returns home"):
		check(scene.state.total_victories == fixture_victories + 3 and scene.state.stage_clears.get(route, 0) == 1 and scene.state.pending_opportunity.is_empty(), "Choice-resumed route clears once with no post-clear opportunity")


func test_portal_and_boss_cancellation(route: String) -> void:
	context = route + " / portal cancellation"
	for phase in ["prepare_portal", "teleport_out", "teleport_arrive"]:
		reset_case(route)
		var earned := loot_snapshot()
		click("depart_stage")
		if not until(func(): return scene.encounter_phase == phase, 7.0, "Cancellation reaches " + phase):
			continue
		var departed: bool = not scene.world_route.is_empty()
		scene._retreat_encounter()
		# No duel may have started yet; cancel() correctly leaves an unstarted
		# or already-finished engine unchanged. Route ownership is the guard.
		check(scene.state.stage_status().paused and scene.state.stage_status().kills == 0 and not scene.state.stage_status().active and loot_snapshot() == earned, "Retreating during " + phase + " pauses unclaimed checkpoint without rewards")
		check(scene.encounter_phase == ("teleport_return_out" if departed else "teleport_home_in"), "Cancellation chooses correct portal direction")
		var flashed_destination := false
		for frame in range(360):
			if not departed and not scene.world_route.is_empty():
				flashed_destination = true
			scene._process(1.0 / 60.0)
		check(not flashed_destination and not scene.encounter_active and scene.world_route.is_empty() and scene.character_x == 520.0, "Cancelled " + phase + " settles at home without destination flash")
		check(loot_snapshot() == earned, "Cancelled portal awards nothing")
	context = route + " / boss cancellation"
	reset_case(route)
	click("depart_stage")
	if not until(func(): return scene.encounter_phase == "fight" and scene.route_boss, 100.0, "Cancellation reaches live boss after two real victories"):
		return
	var earned := loot_snapshot()
	var run_id: int = scene.encounter_run_id
	check(scene.enemy_hp > 0 and scene.state.total_victories == fixture_victories + 2, "Cancellation fixture has an unbeaten living boss")
	scene._retreat_encounter()
	check(scene.duel.cancelled and scene.state.stage_status().paused and scene.state.stage_status().kills == 2 and scene.state.stage_status().run_id == run_id and scene.encounter_phase == "teleport_return_out", "Retreat cancels actual boss timeline, preserves paid checkpoints and begins return")
	check(not scene.state.defeat_stage_monster(run_id, 2).ok and loot_snapshot() == earned, "Stale cancelled boss cannot award victory")
	until(func(): return not scene.encounter_active, 5.0, "Boss retreat arrives home")
	check(loot_snapshot() == earned and scene.state.stage_clears == fixture_clears, "Retreat preserves both ordinary rewards but no route clear")
	check(scene._save_current(), "Cancelled boss result saves")
	await new_host()
	advance(60.0)
	check(scene.state.stage_status().paused and scene.state.stage_status().kills == 2 and scene.state.stage_status().run_id == run_id and not scene.encounter_active and scene.world_route.is_empty() and loot_snapshot() == earned, "Paused boss reload retains checkpoint, stays idle and cannot auto-resume")
	open_routes()
	# UI browsing may show another route, but must preserve this checkpoint.
	scene.set_meta("ink_stage_id", route)
	scene.set_meta("ink_stage_page", ROUTES.find(route) / 3)
	scene._refresh_drawer()
	click("depart_stage")
	if until(func(): return scene.encounter_phase == "fight" and scene.route_boss, 20.0, "Manual post-retreat resume reaches original boss"):
		check(scene.encounter_run_id == run_id and scene.state.total_victories == fixture_victories + 2 and loot_snapshot() == earned, "Retreat/resume never duplicates earlier enemy rewards")
		scene._retreat_encounter()
		until(func(): return not scene.encounter_active, 5.0, "Retried boss can rest at home again")


func _initialize() -> void:
	call_deferred("run")


func run() -> void:
	await new_host()
	context = "shared native art"
	asset_digest(scene.bamboo_panorama, "res://assets/cultivation/routes/bamboo_pass_panorama.png")
	asset_digest(scene.beast_assets.get("cairn"), "res://assets/cultivation/beasts/opportunity_cairn.png")
	for route in ROUTES:
		test_assets(route)
	context = "distinct route art"
	for suffix in ["", "_idle", "_boss_idle"]:
		for index in range(ROUTES.size()):
			for other in range(index + 1, ROUTES.size()):
				check(asset_digests[ROUTES[index] + suffix] != asset_digests[ROUTES[other] + suffix], "Routes have genuinely distinct pixels: %s / %s%s" % [ROUTES[index], ROUTES[other], suffix])
	for suffix in ["_legacy", "_scroll"]:
		for index in range(3):
			for other in range(index + 1, 3):
				check(asset_digests[ROUTES[index] + suffix] != asset_digests[ROUTES[other] + suffix], "Original route assets remain genuinely distinct: %s / %s%s" % [ROUTES[index], ROUTES[other], suffix])
	for route in ROUTES:
		await test_route_and_interrupted_boss(route)
		await test_opportunity_restart(route)
		await test_portal_and_boss_cancellation(route)
		print("All-route transition coverage complete: " + route)
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("All route transitions: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
