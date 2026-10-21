extends SceneTree
## godot --headless --path . --script tests/test_equipment.gd
## Isolated test saves only. No real player's progress is read or modified.

const Ledger = preload("res://scripts/equipment_ledger.gd")
const State = preload("res://scripts/cultivation_state.gd")
var checks := 0
var failures := 0
var prefix := "user://test_equipment_%d" % OS.get_process_id()


func _initialize() -> void:
	_test_empty_default()
	_test_starter_and_drop_rates()
	_test_equip_stats_and_capacity()
	_test_state_rewards()
	_test_salvage()
	_test_persistence_and_legacy()
	_test_repair()
	_test_oversized_recovery()
	_test_offline_and_qi_rate()
	_cleanup()
	print("Equipment tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)


func _state(suffix: String = "") -> State:
	var state := State.new()
	state.save_path = prefix + suffix + ".json"
	state.gear.rng.seed = 1849
	return state


func _test_empty_default() -> void:
	var state := _state()
	_check(state.inventory.is_empty() and state.equipped.is_empty(), "default has no owned or equipped items")
	_check(state.chest_count == 1 and state.total_victories == 0 and not state.expedition_auto, "one starter chest and peaceful default")
	_check(state.gear_stats() == {"attack": 0, "defense": 0, "qi_bonus": 0.0, "evasion_bonus": 0.0}, "empty gear gives no hidden bonuses")
	_check(state.technique == "mist" and state.active_technique_level("mist") == 1 and state.stats().attack == 11 and state.stats().defense == 0, "base combat stats include selected first-rank mist technique")
	for slot in Ledger.SLOTS:
		_check(state.gear.visual_loadout()[slot] == "" and state.gear.equipped_item(slot).is_empty(), "empty slot returns base visual: " + slot)
	state.equip("outfit", "jade")
	state.equip("weapon", "fan")
	_check(state.inventory.is_empty() and state.equipped.is_empty(), "legacy presets never grant or equip actual items")
	_check(not state.equip_item(999) and not state.unequip_slot("head") and not state.unequip_slot("body"), "invalid equipment actions are safe")


func _test_starter_and_drop_rates() -> void:
	for test_seed in range(20):
		var ledger := Ledger.new()
		ledger.rng.seed = test_seed
		var first := ledger.drop("chest", 99)
		_check(first.ok and first.starter and first.item != null and first.item.rarity == "common" and first.item.level == 1, "starter chest is a basic real item, seed %d" % test_seed)
		_check(ledger.chests == 0 and not ledger.starter_chest_unopened, "starter chest consumed once, seed %d" % test_seed)
		var second := ledger.drop("chest")
		_check(not second.ok and second.reason == "no_chest" and ledger.inventory.size() == 1, "no unlimited free chests, seed %d" % test_seed)
	var ledger := Ledger.new()
	ledger.rng.seed = 7419
	ledger.starter_chest_unopened = false
	var monster_items := 0
	var monster_dry := 0
	var chest_items := 0
	var chest_dry := 0
	var rarities := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0}
	var templates := {}
	for index in range(20000):
		ledger.inventory.clear()
		var reward := ledger.drop("monster", 3)
		if reward.item == null:
			monster_dry += 1
		else:
			monster_items += 1
			rarities[reward.item.rarity] += 1
			templates[reward.item.template_id] = true
	for index in range(10000):
		ledger.inventory.clear()
		ledger.chests = 1
		var reward := ledger.drop("chest", 4)
		if reward.item == null:
			chest_dry += 1
			if index < 10:
				_check(reward.herbs > 0, "dry chest gives resource consolation")
		else:
			chest_items += 1
	_check(monster_items > 6500 and monster_items < 7500 and monster_dry > 0, "monster equipment probability near 35 percent")
	_check(chest_items > 6500 and chest_items < 7500 and chest_dry > 0, "ordinary chest equipment probability near 70 percent")
	_check(templates.size() == 10, "all ten templates can drop")
	_check(rarities.common > monster_items * 0.56 and rarities.common < monster_items * 0.64, "common conditional rarity near 60 percent")
	_check(rarities.uncommon > monster_items * 0.24 and rarities.uncommon < monster_items * 0.32, "uncommon conditional rarity near 28 percent")
	_check(rarities.rare > monster_items * 0.075 and rarities.rare < monster_items * 0.125, "rare conditional rarity near 10 percent")
	_check(rarities.epic > monster_items * 0.01 and rarities.epic < monster_items * 0.03, "epic conditional rarity near 2 percent")
	_check(not ledger.drop("unknown").ok, "invalid reward source rejected")
	print("Seeded drops: monster %d/20000, chest %d/10000; monster rarity counts %s" % [monster_items, chest_items, rarities])


func _test_equip_stats_and_capacity() -> void:
	var ledger := Ledger.new()
	var id := 1
	for template_id in Ledger.TEMPLATES:
		ledger.inventory.append(ledger._make_item(id, template_id, "rare", 3))
		id += 1
	for slot in Ledger.SLOTS:
		var selected := -1
		for item in ledger.inventory:
			if item.slot == slot:
				selected = int(item.id)
		_check(ledger.equip_item(selected), "independent slot equips: " + slot)
		_check(ledger.equipped_item(slot).id == selected, "equipped instance resolves: " + slot)
		_check(ledger.visual_loadout()[slot] == ledger.get_item(selected).visual_id, "actual item determines visible layer: " + slot)
	_check(ledger.equipped.size() == 5 and ledger.inventory.size() == 10, "equipped gear remains owned in inventory")
	var stats := ledger.stats()
	_check(stats.attack > 0 and stats.defense > 0 and stats.qi_bonus > 0, "equipped items grant real stats")
	var prior: Dictionary = ledger.equipped.duplicate()
	_check(ledger.equip_item(9), "swap weapon")
	_check(ledger.get_item(10).id == 10 and ledger.inventory.size() == 10, "swapped-out weapon is retained")
	for slot in ["head", "chest", "legs", "feet"]:
		_check(ledger.equipped[slot] == prior[slot], "weapon swap leaves independent slot unchanged: " + slot)
	var before: Dictionary = ledger.equipped.duplicate()
	_check(ledger.unequip_slot("chest"), "chest unequips")
	_check(ledger.visual_loadout().chest == "" and ledger.inventory.size() == 10, "removed chest returns base and retains item")
	for slot in ["head", "legs", "feet", "weapon"]:
		_check(ledger.equipped[slot] == before[slot], "removing chest leaves slot unchanged: " + slot)
	for index in range(11, 101):
		ledger.inventory.append(ledger._make_item(index, "head_pin", "common", 1))
	ledger.chests = 1
	var full_reward := ledger.drop("chest")
	_check(full_reward.ok and full_reward.overflow and full_reward.item == null and full_reward.herbs > 0, "full inventory converts incoming item to resources")
	_check(ledger.inventory.size() == 100 and ledger.get_item(9).id == 9, "overflow never deletes worn gear")
	_check(ledger.unequip_slot("weapon") and ledger.inventory.size() == 100, "unequip works at capacity without loss")
	_check(ledger.equip_item(10) and ledger.inventory.size() == 100, "equip works at capacity without loss")


func _test_state_rewards() -> void:
	var state := _state()
	for index in range(7):
		var before_herbs := state.herbs
		var reward := state.reward_encounter()
		_check(reward.ok and state.herbs == before_herbs + int(reward.herbs), "monster consolation applied once, victory %d" % (index + 1))
		_check(int(reward.chests) == (1 if (index + 1) % 3 == 0 else 0), "one earned chest every third victory")
	_check(state.total_victories == 7 and state.chest_count == 3, "victory and chest totals")
	var count := state.inventory.size()
	var reward := state.open_chest()
	_check(reward.starter and reward.item != null and state.chest_count == 2 and state.inventory.size() == count + 1, "state consumes starter chest and adds actual item")
	var victories := state.total_victories
	state.reward_encounter("invalid")
	_check(state.total_victories == victories, "invalid source cannot fabricate victories")
	state.chest_count = 0
	var herbs := state.herbs
	reward = state.open_chest()
	_check(not reward.ok and state.herbs == herbs, "empty chest request grants no resources")
	state.gear.inventory.clear()
	state.gear.equipped.clear()
	for index in range(100):
		state.gear.inventory.append(state.gear._make_item(index + 1, "head_pin", "common", 1))
	state.chest_count = 1
	state.gear.starter_chest_unopened = true
	state.herbs = State.MAX_RESOURCE
	state.dew = State.MAX_RESOURCE
	reward = state.open_chest()
	_check(reward.overflow and reward.herbs == 0 and reward.dew == 0, "capacity reward reports only resources actually received")
	_check(reward.resource_overflow == {"herbs": 5, "dew": 1}, "capacity reward reports resource overflow separately")
	_check(state.inventory.size() == 100 and state.herbs == State.MAX_RESOURCE and state.dew == State.MAX_RESOURCE, "overflow preserves owned items and capped balances")


func _test_salvage() -> void:
	var state := _state("_salvage")
	state.gear.inventory.append(state.gear._make_item(1, "head_pin", "common", 1))
	state.gear.inventory.append(state.gear._make_item(2, "chest_jade", "rare", 10))
	state.equip_item(1)
	var before := state.herbs
	var result := state.salvage_item(1)
	_check(not result.ok and result.reason == "equipped" and result.herbs == 0, "equipped item cannot be salvaged")
	_check(state.inventory.size() == 2 and state.herbs == before, "protected salvage is non-mutating")
	_check(not state.gear.remove_item(1), "ledger also protects equipped items")
	result = state.salvage_item(999)
	_check(not result.ok and result.reason == "missing", "missing salvage target rejected")
	result = state.salvage_item(2)
	_check(result.ok and result.herbs == 6 and result.item_name == "竹影短衫", "salvage returns exact reward and item name")
	_check(state.inventory.size() == 1 and state.herbs == before + 6, "salvage removes exactly one owned item and grants herbs")
	result = state.salvage_item(2)
	_check(not result.ok and state.herbs == before + 6, "salvage cannot be claimed twice")
	state.gear.inventory.append(state.gear._make_item(3, "weapon_fan", "epic", 1))
	state.herbs = State.MAX_RESOURCE - 2
	result = state.salvage_item(3)
	_check(not result.ok and result.reason == "resource_full" and result.herbs == 0 and result.overflow == 5, "resource overflow is reported exactly")
	_check(state.herbs == State.MAX_RESOURCE - 2 and not state.gear.get_item(3).is_empty(), "overflow preserves item and existing resources")
	state.herbs = State.MAX_RESOURCE - 7
	result = state.salvage_item(3)
	_check(result.ok and result.herbs == 7 and state.herbs == State.MAX_RESOURCE, "salvage can fill resource capacity exactly")
	state.unequip_slot("head")
	state.herbs = 0
	_check(state.salvage_item(1).ok and state.inventory.is_empty(), "previously equipped item can be salvaged after explicit removal")


func _test_persistence_and_legacy() -> void:
	var state := _state("_roundtrip")
	for index in range(12):
		state.reward_encounter()
	state.open_chest()
	state.expedition_auto = true
	for item in state.inventory:
		state.equip_item(int(item.id))
	var items: Array = state.inventory.duplicate(true)
	var worn: Dictionary = state.equipped.duplicate()
	var chests := state.chest_count
	_check(state.save_game(), "equipment save succeeds")
	var restored := _state("_roundtrip")
	var result := restored.load_game()
	_check(result.loaded and not result.invalid_save, "equipment save reloads")
	_check(restored.inventory == items and restored.equipped == worn, "item instances and equipped refs roundtrip")
	_check(restored.total_victories == 12 and restored.chest_count == chests and not restored.expedition_auto, "victories and chests roundtrip while manual-stage migration disables auto expedition")
	_check(not restored.gear.starter_chest_unopened, "starter guarantee cannot repeat after reload")
	var next_original := state.reward_encounter()
	var next_restored := restored.reward_encounter()
	_check(next_original == next_restored, "random generator state roundtrip preserves next drop")
	_check(restored.reset_save(), "equipment reset succeeds")
	_check(restored.inventory.is_empty() and restored.equipped.is_empty() and restored.chest_count == 1, "reset restores empty gear and unopened starter chest")
	_check(restored.total_victories == 0 and not restored.expedition_auto, "reset restores peaceful expedition state")
	var old_data := state._snapshot()
	old_data.version = 1
	old_data.erase("gear")
	old_data.erase("total_victories")
	old_data.erase("expedition_auto")
	old_data.outfit = "jade"
	old_data.weapon = "fan"
	_write(state.save_path, old_data)
	result = restored.load_game()
	_check(result.loaded and restored.inventory.is_empty() and restored.equipped.is_empty(), "legacy presets migrate without inventing owned gear")
	_check(restored.chest_count == 1 and restored.gear.starter_chest_unopened, "legacy player receives one unopened starter chest")
	for visual in restored.gear.visual_loadout().values():
		_check(visual == "", "legacy preset cannot override base white-shorts layers")


func _test_repair() -> void:
	var ledger := Ledger.new()
	var good := ledger._make_item(1, "head_pin", "common", 1)
	var duplicate := ledger._make_item(1, "head_crown", "epic", 99)
	var bad_slot := ledger._make_item(2, "chest_blue", "common", 1)
	bad_slot.slot = "weapon"
	var bad_visual := ledger._make_item(3, "legs_blue", "common", 1)
	bad_visual.visual_id = "res://injected_resource.png"
	var bad_template := ledger._make_item(4, "feet_cloth", "common", 1)
	bad_template.template_id = "unknown"
	var repairable := ledger._make_item(5, "chest_jade", "epic", 20)
	repairable.level = -5
	repairable.rarity = "mythic"
	repairable.attack = 999999
	repairable.defense = -50
	repairable.qi_bonus = 99.0
	var bad_id := ledger._make_item(-3, "weapon_sword", "common", 1)
	var too_high := ledger._make_item(6, "feet_boots", "rare", 100)
	too_high.level = 100000
	var report := ledger.load_data({
		"inventory": [good, duplicate, bad_slot, bad_visual, bad_template, repairable, bad_id, too_high, null],
		"equipped": {"head": 1, "chest": 5, "legs": 1, "feet": 0, "weapon": 999, "body": 5},
		"chests": -10, "starter_chest_unopened": 1,
	})
	_check(report.repaired and ledger.inventory.size() == 3, "corrupted items are repaired or discarded individually")
	_check(ledger.get_item(1).template_id == "head_pin", "duplicate IDs cannot replace the first valid item")
	_check(ledger.get_item(2).is_empty() and ledger.get_item(3).is_empty() and ledger.get_item(4).is_empty(), "slot, visual, and template injection rejected")
	_check(ledger.get_item(5).level == 1 and ledger.get_item(5).rarity == "common", "invalid item level and rarity repaired")
	_check(ledger.get_item(5).attack == 0 and ledger.get_item(5).defense == 3 and ledger.get_item(5).qi_bonus < 0.1, "injected stats replaced with canonical template stats")
	_check(ledger.get_item(6).level == 100, "item level upper bound")
	_check(ledger.equipped == {"head": 1, "chest": 5}, "equipped references must exist and match their slot")
	_check(ledger.chests == 0 and not ledger.starter_chest_unopened, "invalid chest values cannot grant tutorial guarantee")
	var state := _state("_repair")
	state.realm = 3
	state.qi = 100.0
	state.auto_advance = false
	var data := state._snapshot()
	data.gear = {"inventory": [good, duplicate, bad_visual], "equipped": {"head": 1}, "chests": 2}
	data.total_victories = -5
	data.expedition_auto = "yes"
	_write(state.save_path, data)
	var result := state.load_game()
	_check(result.loaded and result.gear_repaired and state.realm == 3, "gear repair preserves healthy cultivation progress")
	_check(state.inventory.size() == 1 and state.equipped.head == 1, "repaired equipment persists through state loader")
	_check(state.total_victories == 0 and not state.expedition_auto, "invalid expedition fields sanitized")
	var after := state.load_game()
	_check(after.loaded and not after.gear_repaired, "repaired equipment checkpoint is canonical")


func _test_oversized_recovery() -> void:
	var ledger := Ledger.new()
	var items := []
	var worn := {}
	var ids := Ledger.TEMPLATES.keys()
	for index in range(120):
		var template_id: String = ids[index % 10]
		var item := ledger._make_item(index + 1, template_id, "uncommon", 2)
		items.append(item)
		worn[item.slot] = int(item.id)
	var report := ledger.load_data({"inventory": items, "equipped": worn})
	_check(report.repaired and report.discarded == 20 and ledger.inventory.size() == 100, "oversized inventory capped at 100")
	_check(ledger.equipped == worn, "all valid equipped references retained while trimming")
	var seen := {}
	for item in ledger.inventory:
		_check(not seen.has(item.id), "retained inventory IDs are unique")
		seen[item.id] = true
	for slot in Ledger.SLOTS:
		_check(not ledger.equipped_item(slot).is_empty(), "high-index equipped item survives cap: " + slot)
	var next_id_state := ledger.to_dict()
	next_id_state.next_id = 1
	ledger.load_data(next_id_state)
	ledger.chests = 1
	ledger.starter_chest_unopened = true
	# Make one free slot without disturbing worn equipment.
	for index in range(ledger.inventory.size()):
		if not ledger.equipped.values().has(int(ledger.inventory[index].id)):
			ledger.inventory.remove_at(index)
			break
	var reward := ledger.drop("chest")
	_check(reward.item != null and not seen.has(reward.item.id), "repaired ID counter cannot collide with existing instances")


func _test_offline_and_qi_rate() -> void:
	var state := _state("_offline")
	state.auto_advance = false
	state.gear.inventory.append(state.gear._make_item(1, "head_crown", "rare", 5))
	state.equip_item(1)
	var rate: float = state.stats().qi_rate
	_check(rate > 1.0 and rate <= 1.35, "equipped qi bonus modestly improves cultivation rate")
	state.step(10.0)
	_check(is_equal_approx(state.qi, 10.0 * rate), "live meditation applies equipped qi bonus")
	state.unequip_slot("head")
	_check(is_equal_approx(state.stats().qi_rate, 1.0), "unequipping restores base cultivation rate")
	state.equip_item(1)
	state.expedition_auto = true
	state.total_victories = 2
	var data := state._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 3600
	_write(state.save_path, data)
	var before_items: Array = state.inventory.duplicate(true)
	var before_chests := state.chest_count
	var result := state.load_game()
	_check(result.loaded and result.qi >= 3600.0 * rate, "offline meditation applies saved equipment bonus")
	_check(state.inventory == before_items and state.chest_count == before_chests and state.total_victories == 2, "offline cultivation never generates combat loot or chests")
	_check(not state.expedition_auto, "offline load enforces explicit manual stage start")


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "test save is writable")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with(prefix.trim_prefix("user://")):
			directory.remove(filename)
