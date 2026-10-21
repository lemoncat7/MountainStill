class_name EquipmentLedger
extends RefCounted
## Actual owned item instances. Inventory includes equipped items, so swapping
## or removing equipment never needs spare bag space and never destroys gear.
## Monster equipment chance: 35%; ordinary chest chance: 70%.
## Conditional rarity: common 60%, uncommon 28%, rare 10%, epic 2%.
## The one unopened tutorial chest guarantees a random common level-1 item.

const CAPACITY := 100
const MAX_ID := 2000000000
const MAX_CHESTS := 999999
const SAVE_VERSION := 2
const MAX_ENHANCEMENT := 5
const SLOTS := ["head", "chest", "legs", "feet", "weapon"]
const RARITIES := ["common", "uncommon", "rare", "epic"]
const RARITY_NAMES := {"common": "普通", "uncommon": "精良", "rare": "稀有", "epic": "史诗"}
const RARITY_MULTIPLIERS := {"common": 1.0, "uncommon": 1.35, "rare": 1.8, "epic": 2.5}
const DROP_CHANCES := {"monster": 0.35, "chest": 0.70}
const TEMPLATES := {
	"head_pin": {"name": "清竹发簪", "slot": "head", "attack": 0, "defense": 1, "qi_bonus": 0.01},
	"head_crown": {"name": "莲华冠", "slot": "head", "attack": 0, "defense": 2, "qi_bonus": 0.015},
	"chest_blue": {"name": "月白云衫", "slot": "chest", "attack": 0, "defense": 3, "qi_bonus": 0.01},
	"chest_jade": {"name": "竹影短衫", "slot": "chest", "attack": 0, "defense": 3, "qi_bonus": 0.015},
	"legs_blue": {"name": "云纹长裤", "slot": "legs", "attack": 0, "defense": 2, "qi_bonus": 0.005},
	"legs_jade": {"name": "竹影下装", "slot": "legs", "attack": 0, "defense": 2, "qi_bonus": 0.008},
	"feet_cloth": {"evasion_bonus": 0.02, "name": "素布履", "slot": "feet", "attack": 0, "defense": 1, "qi_bonus": 0.006},
	"feet_boots": {"evasion_bonus": 0.04, "name": "踏云靴", "slot": "feet", "attack": 0, "defense": 2, "qi_bonus": 0.008},
	"weapon_sword": {"attack_module_id": "weapon.sword", "name": "青锋剑", "slot": "weapon", "attack": 5, "defense": 0, "qi_bonus": 0.0, "weapon_skill": {"id": "weapon_sword_pierce", "attack_module_id": "weapon.sword", "name": "青锋 · 破风刺", "move": "weapon_sword_pierce", "qi_cost": 10.0, "cooldown": 9.0, "weapon_template_id": "weapon_sword", "category": "weapon", "active": true}},
	"weapon_fan": {"attack_module_id": "weapon.fan", "name": "流云扇", "slot": "weapon", "attack": 4, "defense": 1, "qi_bonus": 0.01, "weapon_skill": {"id": "weapon_fan_return", "attack_module_id": "weapon.fan", "name": "流云 · 回风扇", "move": "weapon_fan_return", "qi_cost": 12.0, "cooldown": 10.0, "weapon_template_id": "weapon_fan", "category": "weapon", "active": true}},
}

var inventory: Array = []
var equipped: Dictionary = {}
# Acquisition history belongs to the ledger, not the current bag. Salvaging a
# found item never erases its collection entry. Only a new game clears it.
var discovered_templates: Dictionary = {}
var chests: int = 1
var starter_chest_unopened: bool = true
var rng := RandomNumberGenerator.new()
var _next_id: int = 1


func _init() -> void:
	rng.randomize()
	new_game()


func new_game() -> void:
	inventory = []
	equipped = {}
	discovered_templates = {}
	chests = 1
	starter_chest_unopened = true
	_next_id = 1


func get_item(instance_id: int) -> Dictionary:
	for item in inventory:
		if int(item.id) == instance_id:
			return item
	return {}


func equipped_item(slot: String) -> Dictionary:
	if not slot in SLOTS or not equipped.has(slot):
		return {}
	var item := get_item(int(equipped[slot]))
	return item if item.get("slot", "") == slot else {}


func equip_item(instance_id: int) -> bool:
	var item := get_item(instance_id)
	if item.is_empty() or not item.get("slot", "") in SLOTS:
		return false
	equipped[String(item.slot)] = instance_id
	return true


func unequip_slot(slot: String) -> bool:
	if not slot in SLOTS or not equipped.has(slot):
		return false
	equipped.erase(slot)
	return true


func salvage_value(instance_id: int) -> int:
	var item := get_item(instance_id)
	if item.is_empty():
		return 0
	return 1 + RARITIES.find(String(item.rarity)) * 2 + int(int(item.level) / 10.0)


func enhancement_cost(instance_id: int) -> Dictionary:
	var item := get_item(instance_id)
	if item.is_empty() or int(item.get("enhancement", 0)) >= MAX_ENHANCEMENT:
		return {"herbs": 0, "dew": 0}
	var next_rank := int(item.get("enhancement", 0)) + 1
	var rarity_rank := RARITIES.find(String(item.rarity))
	return {"herbs": 8 * next_rank * (rarity_rank + 1), "dew": next_rank + rarity_rank}


func enhance_item(instance_id: int) -> Dictionary:
	# The owning state validates and deducts these exact materials. No random
	# rolls, failure penalties, replacement instances, or visual changes occur.
	var result := {
		"ok": false, "reason": "missing", "item": {}, "previous_enhancement": 0,
		"enhancement": 0, "cost": {"herbs": 0, "dew": 0},
	}
	var item := get_item(instance_id)
	if item.is_empty():
		return result
	var rank := int(item.get("enhancement", 0))
	result.item = item
	result.previous_enhancement = rank
	result.enhancement = rank
	if rank >= MAX_ENHANCEMENT:
		result.reason = "max_enhancement"
		return result
	result.cost = enhancement_cost(instance_id)
	var enhanced := _make_item(int(item.id), String(item.template_id), String(item.rarity), int(item.level), rank + 1)
	# Update in place: existing references, equipped slots, and inventory order
	# all keep identifying the same owned item.
	for key in ["enhancement", "attack", "defense", "qi_bonus"]:
		item[key] = enhanced[key]
	discovered_templates[String(item.template_id)] = true
	result.ok = true
	result.reason = "enhanced"
	result.enhancement = rank + 1
	return result


func remove_item(instance_id: int) -> bool:
	# Equipped items are protected even when the caller bypasses the UI.
	if equipped.values().has(instance_id):
		return false
	for index in range(inventory.size()):
		if int(inventory[index].id) == instance_id:
			discovered_templates[String(inventory[index].template_id)] = true
			inventory.remove_at(index)
			return true
	return false


func visual_loadout() -> Dictionary:
	# Empty strings mean render the base character. The renderer must always
	# retain the opaque white shorts beneath every independent clothing layer.
	var result := {}
	for slot in SLOTS:
		result[slot] = String(equipped_item(slot).get("visual_id", ""))
	return result


func equipped_weapon_skill() -> Dictionary:
	# Canonical owned-template lookup, never cosmetic compatibility presets,
	# instance-supplied skill dictionaries, or rarity/enhancement powers.
	var item := equipped_item("weapon")
	var template_id := String(item.get("template_id", ""))
	if item.is_empty() or not TEMPLATES.has(template_id):
		return {}
	var template: Dictionary = TEMPLATES[template_id]
	if String(template.get("slot", "")) != "weapon":
		return {}
	return template.get("weapon_skill", {}).duplicate(true)


func equipped_attack_module_id() -> String:
	var item := equipped_item("weapon")
	var template: Dictionary = TEMPLATES.get(str(item.get("template_id", "")), {})
	return str(template.get("attack_module_id", "weapon.unarmed"))


func stats() -> Dictionary:
	var result := {"attack": 0, "defense": 0, "qi_bonus": 0.0, "evasion_bonus": 0.0}
	for slot in SLOTS:
		var item := equipped_item(slot)
		if not item.is_empty():
			result.attack += int(item.attack)
			result.defense += int(item.defense)
			result.qi_bonus += float(item.qi_bonus)
			result.evasion_bonus += item_evasion_bonus(item)
	# Equipment is helpful without replacing the calm cultivation rhythm.
	result.qi_bonus = minf(0.35, float(result.qi_bonus))
	return result


func item_evasion_bonus(item: Dictionary) -> float:
	# Derived from the owned template every time. No new save field, reroll,
	# injected item stat, or item-level/rarity inflation can alter evasion.
	var template: Dictionary = TEMPLATES.get(String(item.get("template_id", "")), {})
	var base := float(template.get("evasion_bonus", 0.0))
	if base <= 0.0: return 0.0
	return base + 0.002 * clampi(int(item.get("enhancement", 0)), 0, MAX_ENHANCEMENT)


func drop(source: String, item_level: int = 1) -> Dictionary:
	var result := {
		"ok": false, "source": source, "item": null, "herbs": 0, "dew": 0,
		"chests": 0, "overflow": false, "reason": "", "starter": false,
	}
	if not DROP_CHANCES.has(source):
		result.reason = "invalid_source"
		return result
	var guaranteed := false
	if source == "chest":
		if chests <= 0:
			result.reason = "no_chest"
			return result
		chests -= 1
		guaranteed = starter_chest_unopened
		starter_chest_unopened = false
	result.ok = true
	result.starter = guaranteed
	if not guaranteed and rng.randf() >= float(DROP_CHANCES[source]):
		result.reason = "resources"
		result.herbs = 2 if source == "chest" else 1
		result.dew = 1 if source == "chest" else 0
		return result
	if inventory.size() >= CAPACITY:
		result.overflow = true
		result.reason = "inventory_full"
		result.herbs = 5 if source == "chest" else 3
		result.dew = 1 if source == "chest" else 0
		return result
	var template_ids := TEMPLATES.keys()
	var template_id: String = template_ids[rng.randi_range(0, template_ids.size() - 1)]
	var rarity := "common" if guaranteed else _roll_rarity()
	var item := _make_item(_allocate_id(), template_id, rarity, 1 if guaranteed else clampi(item_level, 1, 100))
	inventory.append(item)
	discovered_templates[template_id] = true
	result.item = item
	result.reason = "equipment"
	return result


func item_spec_valid(spec: Dictionary) -> bool:
	return spec.get("template_id") is String and TEMPLATES.has(spec.template_id) and spec.get("rarity") is String and spec.rarity in RARITIES and _item_id(spec.get("level")) >= 1 and int(spec.level) <= 100


func item_preview(spec: Dictionary) -> Dictionary:
	if not item_spec_valid(spec): return {}
	return _make_item(0, String(spec.template_id), String(spec.rarity), int(spec.level))


func add_item_spec(spec: Dictionary) -> Dictionary:
	# Shared deterministic manufacture/pending-loot path. No RNG, no automatic
	# equipping, and no ID allocation or other mutation when storage is full.
	if not item_spec_valid(spec): return {"ok": false, "reason": "invalid_item", "item": {}}
	if inventory.size() >= CAPACITY: return {"ok": false, "reason": "inventory_full", "item": {}}
	var item := _make_item(_allocate_id(), String(spec.template_id), String(spec.rarity), int(spec.level))
	inventory.append(item)
	discovered_templates[String(spec.template_id)] = true
	return {"ok": true, "reason": "equipment", "item": item.duplicate(true)}


func _roll_rarity() -> String:
	var roll := rng.randf()
	if roll < 0.60:
		return "common"
	if roll < 0.88:
		return "uncommon"
	if roll < 0.98:
		return "rare"
	return "epic"


func _allocate_id() -> int:
	if _next_id < 1 or _next_id > MAX_ID:
		_next_id = 1
	while not get_item(_next_id).is_empty():
		_next_id = 1 if _next_id >= MAX_ID else _next_id + 1
	var result := _next_id
	_next_id += 1
	return result


func _make_item(id: int, template_id: String, rarity: String, item_level: int, enhancement: int = 0) -> Dictionary:
	var template: Dictionary = TEMPLATES[template_id]
	var multiplier: float = RARITY_MULTIPLIERS[rarity]
	var level_scale := 1.0 + float(item_level - 1) * 0.12
	var rank := clampi(enhancement, 0, MAX_ENHANCEMENT)
	var enhancement_power := rank * (RARITIES.find(rarity) + 1)
	return {
		"id": id, "template_id": template_id, "slot": String(template.slot),
		"name": String(template.name), "rarity": rarity, "level": item_level,
		"enhancement": rank,
		"attack": int(round(float(template.attack) * multiplier * level_scale)) + (enhancement_power if int(template.attack) > 0 else 0),
		"defense": int(round(float(template.defense) * multiplier * level_scale)) + (enhancement_power if int(template.defense) > 0 else 0),
		"qi_bonus": snappedf(float(template.qi_bonus) * multiplier * (1.0 + (item_level - 1) * 0.015) * (1.0 + rank * 0.15), 0.0001),
		"visual_id": template_id,
	}


func to_dict() -> Dictionary:
	# Include legitimate items created by older versions or tools which did not
	# yet write collection history. This also makes the first migrated save complete.
	for item in inventory:
		if TEMPLATES.has(String(item.get("template_id", ""))):
			discovered_templates[String(item.template_id)] = true
	return {
		"version": SAVE_VERSION, "inventory": inventory.duplicate(true), "equipped": equipped.duplicate(true),
		"discovered_templates": discovered_templates.duplicate(true),
		"chests": chests, "starter_chest_unopened": starter_chest_unopened,
		"next_id": _next_id, "rng_seed": str(rng.seed), "rng_state": str(rng.state),
	}


func load_data(value: Variant) -> Dictionary:
	new_game()
	var report := {"repaired": false, "discarded": 0, "migrated": false}
	if not value is Dictionary:
		report.repaired = true
		return report
	var data: Dictionary = value
	report.migrated = _safe_int(data.get("version"), 1, SAVE_VERSION, 1) < SAVE_VERSION
	var raw_discovered: Variant = data.get("discovered_templates", {})
	if raw_discovered is Dictionary:
		for template_id in raw_discovered:
			if template_id is String and TEMPLATES.has(template_id) and raw_discovered[template_id] is bool and raw_discovered[template_id]:
				discovered_templates[template_id] = true
			else:
				report.repaired = true
	else:
		report.repaired = true
	chests = _safe_int(data.get("chests"), 0, MAX_CHESTS, 0)
	starter_chest_unopened = data.get("starter_chest_unopened") is bool and data.starter_chest_unopened
	var raw_inventory: Variant = data.get("inventory", [])
	var candidates: Array = []
	var by_id := {}
	if raw_inventory is Array:
		for raw in raw_inventory:
			var item := _sanitize_item(raw)
			if item.is_empty() or by_id.has(int(item.id)):
				report.discarded += 1
				report.repaired = true
				continue
			candidates.append(item)
			by_id[int(item.id)] = item
			discovered_templates[String(item.template_id)] = true
			if not _matches_canonical(raw, item):
				report.repaired = true
	else:
		report.repaired = true
	var raw_equipped: Variant = data.get("equipped", {})
	if raw_equipped is Dictionary:
		for slot in SLOTS:
			if not raw_equipped.has(slot):
				continue
			var id := _item_id(raw_equipped[slot])
			if by_id.has(id) and by_id[id].slot == slot:
				equipped[slot] = id
			else:
				report.repaired = true
		for slot in raw_equipped:
			if not slot in SLOTS:
				report.repaired = true
	else:
		report.repaired = true
	# Prioritize valid equipped instances before trimming an oversized save.
	# This guarantees that a full bag cannot evict or silently destroy worn gear.
	var retained := {}
	for slot in SLOTS:
		if equipped.has(slot):
			var id: int = equipped[slot]
			retained[id] = true
	for item in candidates:
		if retained.has(int(item.id)):
			continue
		if retained.size() < CAPACITY:
			retained[int(item.id)] = true
		else:
			report.discarded += 1
			report.repaired = true
	for item in candidates:
		if retained.has(int(item.id)):
			inventory.append(item)
	var highest_id := 0
	for item in inventory:
		highest_id = maxi(highest_id, int(item.id))
	_next_id = maxi(highest_id + 1, _safe_int(data.get("next_id"), 1, MAX_ID, 1))
	if _next_id > MAX_ID:
		_next_id = 1
	for key in ["rng_seed", "rng_state"]:
		if data.get(key) is String and data[key].is_valid_int() and data[key].length() <= 20:
			if key == "rng_seed":
				rng.seed = int(data[key])
			else:
				rng.state = int(data[key])
	return report


func _sanitize_item(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var raw: Dictionary = value
	if not raw.get("template_id") is String or not TEMPLATES.has(raw.template_id):
		return {}
	var template_id: String = raw.template_id
	var template: Dictionary = TEMPLATES[template_id]
	# No arbitrary atlas names, paths, or slot changes may enter the renderer.
	if raw.has("slot") and (not raw.slot is String or raw.slot != String(template.slot)):
		return {}
	if raw.has("visual_id") and (not raw.visual_id is String or raw.visual_id != template_id):
		return {}
	var id := _item_id(raw.get("id"))
	if id == 0:
		return {}
	var rarity := "common"
	if raw.get("rarity") is String and raw.rarity in RARITIES:
		rarity = raw.rarity
	var item_level := _safe_int(raw.get("level"), 1, 100, 1)
	var enhancement := _safe_int(raw.get("enhancement"), 0, MAX_ENHANCEMENT, 0)
	# Derive stats and localized names from the template. Untrusted save values
	# cannot inject arbitrary combat power, bonuses, names, or visual resources.
	return _make_item(id, template_id, rarity, item_level, enhancement)


func _matches_canonical(raw: Dictionary, item: Dictionary) -> bool:
	for key in item:
		var value: Variant = raw.get(key)
		var expected: Variant = item[key]
		if expected is int or expected is float:
			# JSON numbers reload as floats, and decimal qi bonuses may lose a
			# final binary digit when serialized. Wrong types must be rejected
			# before comparison (Godot does not compare String and int safely).
			if not (value is int or value is float) or not is_finite(float(value)):
				return false
			if expected is int and float(value) != float(expected):
				return false
			if expected is float and absf(float(value) - float(expected)) > 0.000000001:
				return false
		elif typeof(value) != typeof(expected) or value != expected:
			return false
	return true


func _item_id(value: Variant) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return 0
	if floor(float(value)) != float(value) or float(value) < 1.0 or float(value) > MAX_ID:
		return 0
	return int(value)


func _safe_int(value: Variant, minimum: int, maximum: int, fallback: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	if floor(float(value)) != float(value):
		return fallback
	return int(clampf(float(value), float(minimum), float(maximum)))
