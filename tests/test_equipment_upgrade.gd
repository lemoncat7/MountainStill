extends SceneTree
## Pure ledger checks. No production save files are opened or modified.
## godot --headless --path . --script tests/test_equipment_upgrade.gd

const Ledger = preload("res://scripts/equipment_ledger.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_all_template_rarity_upgrades()
	_test_equipped_stats_and_cap()
	_test_save_migration_and_canonical_stats()
	_test_malformed_enhancements()
	_test_discovery_survives_salvage()
	_test_capacity_and_rng_continuation()
	print("Equipment enhancement tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)


func _test_all_template_rarity_upgrades() -> void:
	_check(Ledger.TEMPLATES.size() == 10 and Ledger.RARITIES.size() == 4 and Ledger.SLOTS.size() == 5, "original templates, rarities and independent slots preserved")
	for template_id in Ledger.TEMPLATES:
		for rarity in Ledger.RARITIES:
			var ledger := Ledger.new()
			var item := ledger._make_item(42, template_id, rarity, 7)
			ledger.inventory.append(item)
			var original := item.duplicate(true)
			var rng_before: int = ledger.rng.state
			var rarity_rank := Ledger.RARITIES.find(rarity)
			_check(item.enhancement == 0, "%s/%s starts at +0" % [template_id, rarity])
			for rank in range(1, 6):
				var cost := ledger.enhancement_cost(42)
				_check(cost == {"herbs": 8 * rank * (rarity_rank + 1), "dew": rank + rarity_rank}, "rank %d cost is deterministic" % rank)
				var previous := item.duplicate(true)
				var result := ledger.enhance_item(42)
				_check(result.ok and result.reason == "enhanced" and result.previous_enhancement == rank - 1 and result.enhancement == rank and result.cost == cost, "successful result reports rank and exact cost")
				_check(item.enhancement == rank and item == result.item, "enhancement mutates the existing owned instance")
				for key in ["id", "template_id", "name", "slot", "rarity", "level", "visual_id"]:
					_check(item[key] == original[key], "enhancement preserves " + key)
				_check(item.attack >= previous.attack and item.defense >= previous.defense and item.qi_bonus >= previous.qi_bonus, "all stats are monotonic")
				_check(item.attack > previous.attack or item.defense > previous.defense, "each rank provides a real combat stat increase")
				_check(item == ledger._make_item(42, template_id, rarity, 7, rank), "stats are canonical at every rank")
			var full := ledger.to_dict()
			var capped := ledger.enhance_item(42)
			_check(not capped.ok and capped.reason == "max_enhancement" and capped.enhancement == 5, "+5 is a hard maximum")
			_check(ledger.to_dict() == full and ledger.rng.state == rng_before, "max-rank and successful enhancements never reroll loot or other state")
			_check(ledger.enhancement_cost(42) == {"herbs": 0, "dew": 0}, "max-rank item cannot quote another paid enhancement")
	var empty := Ledger.new()
	var before := empty.to_dict()
	_check(not empty.enhance_item(100).ok and empty.enhance_item(100).reason == "missing", "missing item cannot be enhanced")
	_check(empty.enhancement_cost(100) == {"herbs": 0, "dew": 0} and empty.to_dict() == before, "missing requests are nonmutating")


func _test_equipped_stats_and_cap() -> void:
	var ledger := Ledger.new()
	var id := 1
	for template_id in ["head_pin", "chest_jade", "legs_blue", "feet_boots", "weapon_fan"]:
		ledger.inventory.append(ledger._make_item(id, template_id, "rare", 2))
		_check(ledger.equip_item(id), "mixed equipment equips independently")
		id += 1
	var visuals := ledger.visual_loadout()
	var equipped := ledger.equipped.duplicate(true)
	var before := ledger.stats()
	for index in range(1, 6):
		_check(ledger.enhance_item(index).ok, "equipped item can be enhanced without removing it")
		_check(not ledger.remove_item(index), "enhanced equipped item remains salvage-protected")
	_check(ledger.stats().attack > before.attack and ledger.stats().defense > before.defense and ledger.stats().qi_bonus > before.qi_bonus, "equipped enhanced stats immediately affect totals")
	_check(ledger.visual_loadout() == visuals and ledger.equipped == equipped and ledger.inventory.size() == 5, "enhancement cannot change mixed visible outfit or lose gear")
	for item in ledger.inventory:
		item.level = 100
		item.rarity = "epic"
		for rank in range(4):
			ledger.enhance_item(int(item.id))
	_check(ledger.stats().qi_bonus <= 0.35, "enhancement respects established cultivation bonus cap")
	_check(ledger.unequip_slot("chest") and ledger.remove_item(2), "enhanced item can be salvaged only after explicit unequip")
	_check(ledger.visual_loadout().chest == "" and ledger.visual_loadout().legs == "legs_blue", "removing enhanced top leaves independent trousers intact")


func _test_save_migration_and_canonical_stats() -> void:
	var ledger := Ledger.new()
	ledger.rng.seed = 210519
	var legacy := []
	var id := 1
	for template_id in Ledger.TEMPLATES:
		var item := ledger._make_item(id, template_id, "uncommon", 3)
		item.erase("enhancement")
		legacy.append(item)
		id += 1
	var report := ledger.load_data({"version": 1, "inventory": legacy, "equipped": {"head": 2, "chest": 4, "legs": 6, "feet": 8, "weapon": 10}, "chests": 8})
	_check(report.migrated and report.discarded == 0 and ledger.inventory.size() == 10, "legacy migration retains every valid owned item")
	_check(ledger.equipped.size() == 5 and ledger.chests == 8 and ledger.discovered_templates.size() == 10, "legacy migration preserves equipped refs, chest balance and discoveries")
	for item in ledger.inventory:
		_check(item.enhancement == 0, "legacy item defaults safely to +0")
		for key in legacy[int(item.id) - 1]:
			_check(item[key] == legacy[int(item.id) - 1][key], "legacy migration preserves canonical " + key)
	ledger.enhance_item(10)
	ledger.enhance_item(10)
	var serialized: Dictionary = JSON.parse_string(JSON.stringify(ledger.to_dict()))
	var restored := Ledger.new()
	report = restored.load_data(serialized)
	_check(not report.repaired and not report.migrated and report.discarded == 0, "new canonical JSON roundtrip needs no repair")
	_check(restored.to_dict() == ledger.to_dict(), "items, enhancement, discoveries, RNG and equipped slots roundtrip exactly")
	serialized.inventory[9].attack = 999999999
	serialized.inventory[9].defense = -100
	serialized.inventory[9].qi_bonus = 1.0e12
	serialized.inventory[9].name = "untrusted name"
	report = restored.load_data(serialized)
	_check(report.repaired and report.discarded == 0, "tampered stat repair never discards valid equipment")
	_check(restored.get_item(10) == ledger.get_item(10), "enhanced item stats and name are regenerated from trusted template, rarity, level and rank")


func _test_malformed_enhancements() -> void:
	var malformed: Array = [-100, 9999999, 1.5, "5", true, {}, [], null, NAN, INF]
	var expected := [0, 5, 0, 0, 0, 0, 0, 0, 0, 0]
	for index in range(malformed.size()):
		var ledger := Ledger.new()
		var raw := ledger._make_item(1, "weapon_sword", "rare", 3)
		raw.enhancement = malformed[index]
		var report := ledger.load_data({"version": 2, "inventory": [raw], "equipped": {"weapon": 1}})
		_check(report.repaired and report.discarded == 0 and ledger.inventory.size() == 1, "malformed rank repaired in place, case %d" % index)
		_check(ledger.get_item(1).enhancement == expected[index], "malformed rank sanitized, case %d" % index)
		_check(ledger.equipped.weapon == 1 and ledger.get_item(1) == ledger._make_item(1, "weapon_sword", "rare", 3, expected[index]), "malformed rank keeps equipped identity and canonical stats")
	var ledger := Ledger.new()
	var raw := ledger._make_item(1, "weapon_fan", "epic", 100, 5)
	raw.enhancement = 3.0
	ledger.load_data({"inventory": [raw]})
	_check(ledger.get_item(1).enhancement == 3, "integer JSON numbers accepted")
	for key in ["slot", "visual_id"]:
		for bad in [1, true, [], {}, null]:
			raw = ledger._make_item(1, "weapon_fan", "epic", 100, 5)
			raw[key] = bad
			var report := ledger.load_data({"inventory": [raw]})
			_check(report.repaired and report.discarded == 1 and ledger.inventory.is_empty(), "wrong-type visual identity rejected without crashing: " + key)
	for key in ["name", "attack", "defense", "qi_bonus"]:
		for bad in ["invalid", true, [], {}, null]:
			raw = ledger._make_item(1, "weapon_fan", "epic", 100, 5)
			raw[key] = bad
			var report := ledger.load_data({"inventory": [raw]})
			_check(report.repaired and report.discarded == 0 and ledger.get_item(1) == ledger._make_item(1, "weapon_fan", "epic", 100, 5), "wrong-type derived stat repaired without losing gear: " + key)


func _test_discovery_survives_salvage() -> void:
	var ledger := Ledger.new()
	ledger.rng.seed = 744
	var reward := ledger.drop("chest")
	var item: Dictionary = reward.item
	_check(ledger.discovered_templates.get(item.template_id, false), "actual acquisition unlocks collection entry")
	_check(ledger.remove_item(int(item.id)) and ledger.inventory.is_empty(), "unequipped found item can be salvaged")
	_check(ledger.discovered_templates.get(item.template_id, false), "salvaging never forgets discovered template")
	var restored := Ledger.new()
	var report := restored.load_data(ledger.to_dict())
	_check(not report.repaired and restored.inventory.is_empty() and restored.discovered_templates == ledger.discovered_templates, "empty inventory retains discoveries across save/load")
	var data := ledger.to_dict()
	data.discovered_templates = {"head_pin": true, "head_crown": false, "unknown": true, "chest_blue": 1, "feet_cloth": "yes"}
	report = restored.load_data(data)
	_check(report.repaired and restored.discovered_templates == {"head_pin": true}, "discovery history accepts only known templates with true booleans")
	restored.new_game()
	_check(restored.discovered_templates.is_empty(), "intentional new game resets collection")


func _test_capacity_and_rng_continuation() -> void:
	var ledger := Ledger.new()
	ledger.rng.seed = 917311
	for index in range(100):
		var template_id: String = Ledger.TEMPLATES.keys()[index % 10]
		ledger.inventory.append(ledger._make_item(index + 1, template_id, "rare", 4, index % 6))
		ledger.equip_item(index + 1)
	ledger._next_id = 101
	var worn := ledger.equipped.duplicate(true)
	var visuals := ledger.visual_loadout()
	_check(ledger.enhance_item(100).ok and ledger.inventory.size() == 100, "enhancement at full capacity creates no extra item")
	var reward := ledger.drop("chest")
	_check(reward.ok and reward.overflow and ledger.inventory.size() == 100 and ledger.equipped == worn and ledger.visual_loadout() == visuals, "full inventory conversion preserves enhanced worn items")
	var restored := Ledger.new()
	restored.load_data(ledger.to_dict())
	for index in range(1, 91):
		ledger.remove_item(index)
		restored.remove_item(index)
	for index in range(50):
		_check(ledger.drop("monster", 7) == restored.drop("monster", 7), "post-save RNG continuation matches for reward %d" % index)
	_check(ledger.to_dict() == restored.to_dict(), "enhancement, collection and 50 subsequent rewards remain deterministic")
