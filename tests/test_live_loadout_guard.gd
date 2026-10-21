extends SceneTree
## A live duel snapshots its loadout atomically; book previews are read-only.
const Ink = preload("res://scripts/ink_pages.gd")
var scene
var checks := 0
var failures := 0
var save_path := "user://live_loadout_guard_%d.json" % OS.get_process_id()


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)


func click(key: String, force_signal: bool = false) -> void:
	var button = scene.buttons.get(key)
	check(is_instance_valid(button), "Button exists: " + key)
	if is_instance_valid(button):
		if not force_signal:
			check(not button.disabled, "Enabled: " + key)
		if force_signal or not button.disabled:
			button.pressed.emit()


func inspect_manual(id: String) -> void:
	click("tech_category_all")
	var rows: Array = scene.state.technique_rows()
	var index: int = 0
	for i in range(rows.size()):
		if str(rows[i].id) == id: index = i; break
	for _i in range(index / Ink.MANUALS_PER_PAGE): click("tech_next")
	click("equip_" + id)


func until(predicate: Callable, seconds: float, label: String) -> bool:
	for index in range(ceili(seconds * 60.0)):
		if predicate.call():
			check(true, label)
			return true
		scene._process(1.0 / 60.0)
	var reached := bool(predicate.call())
	check(reached, label)
	return reached


func world_snapshot() -> Array:
	return [scene.state.technique, scene.state.equipped_heart, scene.state.equipped_weapon_art, scene.state.equipped_actives.duplicate(), scene.state.equipped_passives.duplicate(), scene.state.gear.equipped.duplicate(true),
		scene.state.stats().attack, scene.state.stats().defense, scene.character_x, scene.character_y,
		scene.route_distance, scene.world_route, scene.encounter_phase, scene.practice_time,
		scene.encounter_run_id, scene.duel.elapsed, scene.duel.technique,
		scene.duel.weapon_style, scene.duel._hero.duplicate(true), scene.vitality, scene.enemy_hp]


func open_tab(tab: String) -> void:
	if scene.drawer_name != "wardrobe":
		scene._toggle_drawer("wardrobe")
	scene.wardrobe_tab = tab
	scene._refresh_drawer()


func select_item(instance_id: int) -> void:
	var item: Dictionary = scene.state.gear.get_item(instance_id)
	scene.selected_item = instance_id
	scene.selected_slot = str(item.slot)
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
	scene.state.new_game()
	scene.state.auto_advance = false
	scene.state.realm = 4
	scene.state.herbs = 1000
	scene.state.dew = 1000
	for id in ["mist", "petal", "ember", "stillness"]:scene.state.technique_levels[id] = 1
	scene.state.attuned_techniques.assign(["mist", "breath", "petal", "ember", "stillness"])
	scene.state.gear.inventory = [
		scene.state.gear._make_item(1, "weapon_sword", "common", 1),
		scene.state.gear._make_item(2, "weapon_fan", "common", 1),
		scene.state.gear._make_item(3, "chest_jade", "common", 1)]
	scene.state.equip_item(1)
	scene.state._adventure_rng.seed = 1
	scene.character_x = 520.0
	scene.meditation_amount = 0.0
	open_tab("technique")
	inspect_manual("stillness")
	click("manual_slot_heart")
	var stale_heart_quote: Dictionary = scene.get_meta("ink_heart_quote", {}).duplicate(true)
	check(not stale_heart_quote.is_empty() and is_instance_valid(scene.buttons.confirm_heart_switch), "Real courtyard heart quote awaits separate confirmation")
	scene._start_encounter()
	if not until(func(): return scene.encounter_phase == "travel", 6.0, "Guard fixture reaches route travel"):
		finish()
		return
	open_tab("equipment")
	select_item(2)
	check(not scene.buttons.equip_selected.disabled, "Travel still allows actual equipment selection")
	var stale_equip = scene.buttons.equip_selected
	var travel_signature := Ink.state_signature(scene)
	if not until(func(): return scene.encounter_phase == "fight", 10.0, "Actual roadside duel begins"):
		finish()
		return
	check(scene.duel.weapon_style == "sword" and scene.duel.technique == "mist", "Duel captures starting sword and mist profile")
	check(Ink.state_signature(scene) != travel_signature and Ink._live_loadout_locked(scene), "Fight phase changes refresh signature immediately")
	check(scene.buttons.equip_selected.disabled and scene.buttons.equip_selected.tooltip_text.contains("交锋"), "Existing open book disables equip at fight boundary with explicit hint")
	var world := world_snapshot()
	if is_instance_valid(stale_equip):
		stale_equip.pressed.emit()
	check(world_snapshot() == world, "Stale previously-enabled equip callback is guarded at execution time")
	click("equip_selected", true)
	check(world_snapshot() == world and scene.state.gear.equipped.weapon == 1, "Forced disabled equip cannot alter visible world grip or snapshot")
	click("item_2")
	check(scene.selected_item == 3 and world_snapshot() == world, "Inspecting another equipment slot remains available and read-only")
	select_item(1)
	check(scene.buttons.unequip_slot.disabled and scene.buttons.enhance_item.disabled, "Worn gear cannot be removed or enhanced during live duel")
	var balance := [scene.state.herbs, scene.state.dew]
	click("unequip_slot", true)
	click("enhance_item", true)
	check(world_snapshot() == world and [scene.state.herbs, scene.state.dew] == balance and scene.state.gear.get_item(1).enhancement == 0, "Worn-gear guards reject stale callbacks without resource charges")
	select_item(2)
	check(not scene.buttons.enhance_item.disabled and not scene.buttons.salvage_item.disabled, "Unworn inventory management remains available")
	click("enhance_item")
	check(scene.state.gear.get_item(2).enhancement == 1 and world_snapshot() == world, "Enhancing unworn gear changes no active combat stats or visuals")
	open_tab("technique")
	check(is_instance_valid(scene.buttons.confirm_heart_switch) and scene.buttons.confirm_heart_switch.disabled, "An existing heart review disables confirmation after actual fight begins")
	balance = [scene.state.herbs, scene.state.dew]
	click("confirm_heart_switch", true)
	check(world_snapshot() == world and [scene.state.herbs, scene.state.dew] == balance and scene.state.pending_heart_switch.is_empty(), "Forced stale heart confirmation cannot charge or switch a live fight")
	check(not bool(scene.state.confirm_heart_switch(stale_heart_quote).ok), "State rejects the real pre-route heart token while a route exists")
	click("cancel_heart_switch")
	var original_levels: Dictionary = scene.state.technique_levels.duplicate(true)
	for id in ["petal", "ember", "stillness", "mist"]:
		world = world_snapshot()
		inspect_manual(id)
		check(scene.get_meta("ink_technique_id") == id and scene.get_meta("preview_technique") == id, "Technique row remains independently inspectable: " + id)
		check(scene.character_preview.displayed_technique() == id and scene.state.technique == "mist", "Portrait uses inspected technique while world keeps actual mist: " + id)
		check(scene.buttons.train_technique.disabled and scene.buttons.train_technique.tooltip_text.contains("交锋"), "Training/auto-activation disabled with explanation")
		balance = [scene.state.herbs, scene.state.dew]
		click("train_technique", true)
		check(scene.state.technique_levels == original_levels and [scene.state.herbs, scene.state.dew] == balance, "Training callback cannot spend or switch live technique")
		click("practice_preview")
		check(scene.character_preview.cast_time == scene.character_preview.CAST_DURATION and world_snapshot() == world, "Selected-technique demonstration changes only portrait: " + id)
		scene.character_preview.advance(0.1, true)
		check(scene.character_preview.cast_time < scene.character_preview.CAST_DURATION and world_snapshot() == world, "Preview animation advances independently of world combat")
		var mapping: String = Ink._combat_description(scene, id)
		check(mapping == str(scene.state.Content.TECHNIQUES[id].description), "Technique page renders authored manual description: " + id)
	check(Ink._combat_description(scene, "petal").contains("持扇") and Ink._combat_description(scene, "stillness").contains("被动") and Ink._combat_description(scene, "ember").contains("发掌"), "Manual text explains real compatibility, passive defense and palm casting")
	inspect_manual("ember")
	check(scene.state.technique == "mist" and scene.character_preview.displayed_technique() == "ember", "Inspected fire-palm profile stays distinct at fight end")
	scene._set_paused(true)
	check(Ink._live_loadout_locked(scene), "Pausing an ongoing duel does not lift atomic loadout guard")
	click("train_technique", true)
	check(scene.state.technique == "mist" and scene.state.technique_levels == original_levels, "Paused live duel remains protected")
	scene._set_paused(false)
	if until(func(): return scene.encounter_phase == "pickup", 20.0, "Current enemy ends normally after preview use"):
		check(not Ink._live_loadout_locked(scene) and not scene.buttons.train_technique.disabled, "Controls unlock immediately when enemy ends")
		check(scene.state.technique == "mist" and scene.state.gear.equipped.weapon == 1, "Preview selection never auto-applies after fight")
		inspect_manual("ember")
		click("manual_slot_active")
		check(scene.state.equipped_actives.has("ember") and scene.state.equipped_weapon_art == "mist", "Explicit post-fight active slot preserves independent form")
		open_tab("equipment")
		select_item(2)
		check(not scene.buttons.equip_selected.disabled, "Actual equipment becomes available between encounters")
		click("equip_selected")
		check(scene.state.gear.equipped.weapon == 2 and scene._attack_style() == "fan", "Explicit between-fights equip changes world weapon")
		check(scene.character_preview.displayed_technique() == scene.state.technique, "Leaving technique page restores portrait's actual active technique")
		if until(func(): return scene.encounter_phase == "fight" and scene.encounter_index == 1, 20.0, "Next encounter starts with newly chosen loadout"):
			check(scene.duel.weapon_style == "fan" and int(scene.duel._hero.attack) == int(scene.state.stats().attack) and scene.state.equipped_actives.has("ember"), "Next duel snapshots updated independent loadout, grip and effective stats exactly once")
	finish()


func finish() -> void:
	scene.queue_free()
	await process_frame
	await process_frame
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):
			DirAccess.remove_absolute(save_path + suffix)
	print("Live loadout guard: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
