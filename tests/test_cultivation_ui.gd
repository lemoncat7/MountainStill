extends SceneTree
## Bounded callback integration tests. No production save is opened or changed.
var test_save := "user://cultivation_ui_test_%d.json" % OS.get_process_id()
const Ledger = preload("res://scripts/equipment_ledger.gd")
const State = preload("res://scripts/cultivation_state.gd")
var checks := 0
var failures := 0
var scene

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func press(key: String) -> bool:
	var button = scene.buttons.get(key)
	var valid := is_instance_valid(button) and button is BaseButton
	check(valid, "Button exists: " + key)
	if not valid:
		return false
	check(not button.disabled, "Button enabled: " + key)
	if button.disabled:
		return false
	button.pressed.emit()
	return true

func open_tab(tab: String) -> void:
	if scene.drawer_name != tab:
		scene._toggle_drawer(tab)
	await process_frame
	check(scene.drawer_name == tab and is_instance_valid(scene.drawer), "Open drawer: " + tab)

func equipment_tab() -> void:
	await open_tab("wardrobe")
	press("wardrobe_equipment")

func fixture_items(count: int = 7) -> void:
	var templates := ["head_pin", "chest_blue", "legs_blue", "feet_cloth", "weapon_sword", "chest_jade", "weapon_fan"]
	var inventory: Array = []
	for i in range(count):
		inventory.append({"id": i + 1, "template_id": templates[i % templates.size()], "rarity": "common", "level": 1})
	scene.state.gear.load_data({"inventory": inventory, "equipped": {}, "chests": 1, "starter_chest_unopened": true})
	scene.selected_item = -1
	scene.selected_slot = "chest"
	scene.inventory_page = 0

func select_item(id: int) -> bool:
	var index := -1
	for i in range(scene.state.gear.inventory.size()):
		if int(scene.state.gear.inventory[i].id) == id:
			index = i
	check(index >= 0, "Owned item selectable: %d" % id)
	if index < 0:
		return false
	scene.inventory_page = int(index / 3)
	scene._refresh_drawer()
	if not press("item_" + str(index % 3)):
		return false
	check(int(scene.selected_item) == id, "Row callback selects instance %d" % id)
	return true

func _initialize() -> void:
	call_deferred("run")

func _remove_test_files() -> void:
	for suffix in ["", ".bak", ".tmp"]:
		var path: String = test_save + String(suffix)
		if FileAccess.file_exists(path):
			DirAccess.remove_absolute(path)

func run() -> void:
	_remove_test_files()
	var packed = load("res://main.tscn")
	check(packed != null, "Main scene loads")
	if packed == null:
		quit(1)
		return
	scene = packed.instantiate()
	# Set the isolated save path BEFORE _ready() can read or write anything.
	scene.state.save_path = test_save
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.state.new_game()
	check(scene.state.gear.inventory.is_empty(), "New player has no owned equipment")
	check(scene.state.gear.equipped.is_empty(), "New player wears no gear layers")
	check(scene.state.chest_count == 1, "One starter chest is available")
	check(not scene.encounter_active and not scene.state.expedition_auto, "Default is peaceful, no automatic combat")
	check(scene.practice_time == 0, "Default has no forced practice")
	scene._process(5.0)
	check(not scene.encounter_active and not scene.state.expedition_auto, "Peaceful cultivation stays peaceful after time advances")
	check(scene.state.qi > 0, "Peaceful cultivation still progresses")

	# Navigation belongs to the scene objects; there is no old top toolbar.
	for key in ["settings", "wardrobe", "alchemy", "practice", "garden"]:
		var hotspot = scene.buttons.get(key)
		check(is_instance_valid(hotspot) and hotspot is BaseButton, "Scene hotspot exists: " + key)
		if is_instance_valid(hotspot):
			check(hotspot.get_parent() == scene.nav, "Scene hotspot belongs to the navigation layer: " + key)
			check(hotspot.text.is_empty(), "Scene hotspot has no old toolbar label: " + key)
	check(scene.nav.get_child_count() == 9, "Navigation keeps scene hotspots and a separately dismissible two-control ink hint")
	check(is_instance_valid(scene.buttons.get("guide_note")) and is_instance_valid(scene.buttons.get("guide_dismiss")), "First-entry guidance can be opened or dismissed without a modal")
	for key in ["pause", "window", "quit", "auto"]:
		check(not is_instance_valid(scene.buttons.get(key)), "Utility action is absent from the scene toolbar: " + key)
	for key in ["practice", "alchemy", "wardrobe"]:
		press(key)
		await process_frame
		check(scene.drawer_name == key, "Scene-object click opens the correct paper page: " + key)
		check(not scene.buttons.wardrobe.visible and not scene.buttons.alchemy.visible, "Open paper hides the scene's overlapping hit regions")
		press("drawer_close")
		await create_timer(0.18).timeout
	press("garden")
	check(scene.state.activity == "gather" and not scene.state.auto_advance, "Garden hotspot starts deliberate gathering")
	scene.state.new_game()

	for tab in ["practice", "alchemy", "bag", "settings", "desktop", "wardrobe"]:
		await open_tab(tab)
		press("drawer_close")
		await create_timer(0.17).timeout
		check(scene.drawer_name.is_empty(), "Close drawer: " + tab)
	# Reopening during the close tween must not let the old callback destroy it.
	await open_tab("practice")
	press("drawer_close")
	await open_tab("alchemy")
	await create_timer(0.2).timeout
	check(scene.drawer_name == "alchemy" and is_instance_valid(scene.drawer), "Rapid close/reopen keeps the latest drawer")

	# Actual starter chest -> row -> equip -> slot -> unequip callbacks.
	await equipment_tab()
	check(not scene.buttons.first_chest.disabled, "Starter chest button is enabled")
	press("first_chest")
	check(scene.state.chest_count == 0, "Starter callback consumes one chest")
	check(scene.state.gear.inventory.size() == 1, "Starter callback grants exactly one real item")
	check(scene.state.gear.equipped.is_empty(), "Loot is not silently auto-equipped")
	var first: Dictionary = scene.state.gear.inventory[0] if not scene.state.gear.inventory.is_empty() else {}
	if not first.is_empty():
		check(first.rarity == "common" and int(first.level) == 1, "Starter item is common level one")
		select_item(int(first.id))
		press("equip_selected")
		check(int(scene.state.gear.equipped.get(first.slot, -1)) == int(first.id), "Equip callback wears the selected instance")
		check(scene.buttons.equip_selected.disabled, "Already-worn item cannot be equipped twice")
		check("已穿戴" in str(scene.buttons.item_0.text), "Worn row is visibly labeled")
		press("slot_" + str(first.slot))
		press("unequip_slot")
		check(scene.state.gear.equipped_item(first.slot).is_empty(), "Unequip callback clears its slot")
		check(scene.state.gear.inventory.size() == 1, "Unequip never destroys the owned item")
		check(scene.buttons.unequip_slot.disabled, "Empty slot cannot be removed twice")

	# Five independent slots; swapping one slot preserves all others and technique.
	scene.state.realm = 1
	scene.state.technique_levels.petal = 1
	fixture_items()
	await equipment_tab()
	press("wardrobe_technique")
	press("tech_category_weapon_art")
	press("equip_petal")
	check(scene.state.equipped_weapon_art == "mist", "Inspecting petals preserves the current form")
	press("attune_technique")
	press("manual_slot_weapon_art")
	check(scene.state.equipped_weapon_art == "petal", "Explicit form callback selects petals")
	press("wardrobe_equipment")
	for id in range(1, 6):
		select_item(id)
		press("equip_selected")
	check(scene.state.gear.equipped.size() == 5, "Five independent slots can all be equipped")
	check(scene.state.gear.inventory.size() == 7, "Equipping leaves owned instances in the inventory")
	check(scene.state.technique == "petal", "Equipment does not replace the selected technique")
	var before: Dictionary = scene.state.gear.equipped.duplicate(true)
	select_item(6)
	press("equip_selected")
	check(int(scene.state.gear.equipped.chest) == 6, "A second chest piece replaces only the chest slot")
	for slot in ["head", "legs", "feet", "weapon"]:
		check(scene.state.gear.equipped[slot] == before[slot], "Chest swap preserves " + slot)
	check(not scene.state.gear.get_item(2).is_empty(), "Swapped-out chest piece remains owned")
	press("slot_chest")
	press("unequip_slot")
	check(scene.state.gear.visual_loadout().chest.is_empty(), "Removing chest exposes only the base chest layer")
	check(scene.state.gear.visual_loadout().legs == "legs_blue", "Removing chest keeps the pants layer")
	check(scene.state.gear.visual_loadout().feet == "feet_cloth", "Removing chest keeps the footwear layer")
	var equipment_before_technique: Dictionary = scene.state.gear.equipped.duplicate(true)
	press("wardrobe_technique")
	press("equip_mist")
	press("manual_slot_weapon_art")
	check(scene.state.equipped_weapon_art == "mist", "Explicit form callback switches back to mist")
	check(scene.state.gear.equipped == equipment_before_technique, "Changing technique leaves every equipment slot unchanged")
	press("practice_preview")
	check(scene.character_preview.cast_time > 0 and scene.practice_time == 0 and scene.drawer_name == "wardrobe", "Practice starts the independent portrait without disturbing the world")
	check(not scene.encounter_active and not scene.state.expedition_auto, "Practice does not enable adventure combat")
	var reloaded = State.new()
	reloaded.save_path = test_save
	reloaded.load_game()
	check(reloaded.gear.equipped == scene.state.gear.equipped, "Equipment callbacks persist the slot map")
	check(reloaded.technique == scene.state.technique, "Technique callback persists independently")

	# Salvage is explicit, confirmed, and never destroys worn gear or capped rewards.
	await equipment_tab()
	select_item(2)
	var salvage_herbs: int = scene.state.herbs
	var salvage_count: int = scene.state.gear.inventory.size()
	var salvage_worn: Dictionary = scene.state.gear.equipped.duplicate(true)
	var salvage_value: int = scene.state.gear.salvage_value(2)
	press("salvage_item")
	check(scene.salvage_dialog.visible and scene.salvage_pending == 2, "Salvage opens confirmation for the exact selected instance")
	check(not scene.state.gear.get_item(2).is_empty() and scene.state.herbs == salvage_herbs, "Opening salvage confirmation changes nothing")
	scene.salvage_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(not scene.salvage_dialog.visible, "Cancel salvage dismisses confirmation")
	check(scene.state.gear.inventory.size() == salvage_count and scene.state.herbs == salvage_herbs, "Cancel salvage preserves item and resources")
	press("salvage_item")
	scene.salvage_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.state.gear.get_item(2).is_empty() and scene.state.gear.inventory.size() == salvage_count - 1, "Confirmed salvage removes only the selected unequipped instance")
	check(scene.state.herbs == salvage_herbs + salvage_value, "Confirmed salvage credits its exact resource value once")
	check(scene.state.gear.equipped == salvage_worn and scene.state.technique == "mist", "Salvage preserves worn slots and technique")
	check(scene.selected_item == -1 and scene.buttons.salvage_item.disabled, "Successful salvage clears the stale selection")
	reloaded.load_game()
	check(reloaded.gear.get_item(2).is_empty() and reloaded.herbs == scene.state.herbs, "Salvage callback persists both removal and reward")
	select_item(1)
	check(scene.buttons.salvage_item.disabled, "Worn equipment has no enabled salvage action")
	# Even a stale confirmation cannot delete an instance that became worn.
	scene.salvage_pending = 1
	scene.salvage_dialog.confirmed.emit()
	check(not scene.state.gear.get_item(1).is_empty() and scene.state.gear.equipped == salvage_worn, "Stale salvage confirmation protects equipped gear")
	select_item(6)
	scene.state.herbs = State.MAX_RESOURCE
	press("salvage_item")
	scene.salvage_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(not scene.state.gear.get_item(6).is_empty() and scene.state.herbs == State.MAX_RESOURCE, "A capped resource balance preserves the item instead of wasting its value")
	check("未分解" in scene.toast, "Rejected salvage provides visible feedback")
	scene.state.herbs = salvage_herbs + salvage_value
	press("salvage_item")
	scene.salvage_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.state.gear.get_item(6).is_empty(), "Salvage can be retried after resource space becomes available")

	# Bounded paging and resource-only/full-bag reward branches.
	fixture_items(Ledger.CAPACITY)
	await equipment_tab()
	check(scene.buttons.items_prev.disabled, "First inventory page has no previous page")
	press("items_next")
	check(scene.inventory_page == 1, "Next-page callback advances one page")
	press("items_prev")
	check(scene.inventory_page == 0, "Previous-page callback returns one page")
	select_item(Ledger.CAPACITY)
	check(scene.buttons.items_next.disabled, "Last inventory page has no next page")
	press("equip_selected")
	var full_worn: Dictionary = scene.state.gear.equipped.duplicate(true)
	var herbs_before: int = scene.state.herbs
	var dew_before: int = scene.state.dew
	press("wardrobe_adventure")
	press("open_chest")
	check(scene.state.gear.inventory.size() == Ledger.CAPACITY, "Full-bag chest keeps exactly the capacity of owned items")
	check(scene.state.gear.equipped == full_worn, "Full-bag reward cannot evict worn equipment")
	check(scene.state.herbs == herbs_before + 5 and scene.state.dew == dew_before + 1, "Full-bag gear converts safely to resources")
	check(scene.state.chest_count == 0 and scene.buttons.open_chest.disabled, "Full-bag chest is consumed exactly once")
	check(not scene.toast.is_empty(), "Full-bag reward callback provides feedback")
	await equipment_tab()
	select_item(Ledger.CAPACITY)
	press("unequip_slot")
	press("salvage_item")
	scene.salvage_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.state.gear.inventory.size() == Ledger.CAPACITY - 1, "Salvage frees capacity in a full inventory")
	check(scene.inventory_page == 32 and scene.buttons.items_next.disabled, "Removing the only final-page item clamps paging safely")
	press("wardrobe_adventure")
	# Pick a deterministic RNG seed whose first chest roll yields resources.
	scene.state.gear.new_game()
	scene.state.gear.starter_chest_unopened = false
	var probe := RandomNumberGenerator.new()
	for seed_value in range(100):
		probe.seed = seed_value
		if probe.randf() >= 0.70:
			scene.state.gear.rng.seed = seed_value
			break
	scene._refresh_drawer()
	herbs_before = scene.state.herbs
	dew_before = scene.state.dew
	press("open_chest")
	check(scene.state.gear.inventory.is_empty(), "Resource-only chest does not fabricate an item")
	check(scene.state.herbs == herbs_before + 2 and scene.state.dew == dew_before + 1, "Resource-only null-item reward completes without an API error")
	check(scene.state.chest_count == 0, "Resource-only chest still consumes one chest")
	scene._open_treasure()
	check(scene.state.chest_count == 0 and "没有" in scene.toast, "No-chest callback is safely rejected")

	# Explicit finite stage start, pause, retreat, and three bounded rewards.
	press("wardrobe_expedition")
	press("depart_stage")
	check(scene.encounter_active, "Adventure starts only from the explicit callback")
	await open_tab("settings")
	var clock_before: float = scene.encounter_clock
	var hp_before: float = scene.enemy_hp
	press("pause")
	var qi_before: float = scene.state.qi
	scene._process(4.0)
	check(scene.paused and scene.state.qi == qi_before, "Pause callback stops cultivation")
	check(scene.encounter_clock == clock_before and scene.enemy_hp == hp_before, "Pause also freezes combat progression")
	press("pause")
	check(not scene.paused, "Pause callback resumes")
	await open_tab("wardrobe")
	press("wardrobe_expedition")
	press("depart_stage")
	for i in range(600):scene._process(0.05)
	check(not scene.encounter_active and not scene.state.expedition_auto, "Return-to-mountain callback stops adventure and automatic repeats")
	press("depart_stage")
	var victories: int = scene.state.total_victories
	for i in range(4000):
		if scene.encounter_phase == "opportunity":
			scene.state.choose_opportunity("read_inscription")
		if not scene.encounter_active:
			break
		scene._process(0.05)
	check(not scene.encounter_active and scene.state.total_victories == victories + 3, "Finite stage ends and rewards exactly three victories")
	check(not scene.state.expedition_auto, "One encounter does not silently opt into continuous combat")

	# Preserve the existing alchemy and breakthrough integration coverage.
	scene.state.realm = 0
	scene.state.auto_advance = false
	scene.state.pills = 0
	scene.state.herbs = 3
	scene.state.dew = 1
	await open_tab("alchemy")
	press("start_brew")
	check(scene.state.activity == "brew", "Alchemy callback starts brewing")
	scene.state.step(20.0)
	check(scene.state.pills == 1, "A real brew cycle completes")
	scene._refresh_drawer()
	press("use_pill")
	check(scene.state.pills == 0, "Pill callback consumes exactly one pill")
	check(scene.buttons.use_pill.disabled, "No-pill action is disabled")
	scene.state.qi = scene.state.stats().need_qi
	scene.state.herbs = scene.state.stats().need_herbs
	scene.set_meta("ink_journal_tab", "practice")
	await open_tab("practice")
	press("breakthrough")
	check(scene.state.realm == 1 and scene.breakthrough_glow > 0, "Breakthrough callback advances the realm and shows feedback")
	scene._safe_restore()
	check(not scene.strip and not scene.state.settings.click_through, "Safe restore clears strip and passthrough preferences")

	# A cancelled reset preserves state; confirmation invokes the real reset callback.
	await open_tab("settings")
	press("reset")
	check(scene.reset_dialog.visible, "Reset callback opens confirmation")
	var realm_before: int = scene.state.realm
	scene.reset_dialog.get_cancel_button().pressed.emit()
	await process_frame
	check(scene.state.realm == realm_before, "Cancel reset preserves progress")
	check(not scene.reset_dialog.visible, "Cancel reset dismisses the confirmation")
	scene._start_encounter()
	scene.state.expedition_auto = true
	await open_tab("settings")
	press("reset")
	scene.reset_dialog.get_ok_button().pressed.emit()
	await process_frame
	check(scene.state.realm == 0 and scene.state.qi == 0, "Confirmed reset clears progression")
	check(scene.state.gear.inventory.is_empty() and scene.state.gear.equipped.is_empty(), "Confirmed reset clears actual owned and worn gear")
	check(scene.state.chest_count == 1 and scene.state.technique == "mist", "Confirmed reset restores starter chest and technique")
	check(not scene.state.expedition_auto, "Confirmed reset returns to peaceful automatic-cultivation defaults")
	check(not scene.encounter_active and scene.practice_time == 0, "Confirmed reset also ends any in-flight encounter or practice")
	# Real quit callback is tested last, through its visible settings-page control.
	await open_tab("settings")
	press("quit")
	check(FileAccess.file_exists(test_save), "Quit callback saves to the isolated test path")
	check(not scene.music.playing and not scene.audio.playing, "Quit callback stops audio")
	print("Cultivation UI: %d checks, %d failures" % [checks, failures])
	if failures > 0:
		quit(failures)
	else:
		# _quit() releases the scene, then quits the root window after 0.35 seconds; a shell timeout
		# verifies that this actual callback exits rather than hanging.
		await create_timer(0.05).timeout
		_remove_test_files()
