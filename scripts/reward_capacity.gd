extends RefCounted
## Read-only projections of existing transaction guards. No speculative claims,
## RNG draws, resource consumption, or persistent UI state belong here.
const Content = preload("res://scripts/cultivation_content.gd")
const Equipment = preload("res://scripts/equipment_ledger.gd")
const Materials = preload("res://scripts/material_registry.gd")

static func _number(value: float) -> String:
	return str(int(ceil(value)))

static func _append(rows: Array, id: String, label: String, current: float, cap: float, amount: float, destination: String) -> void:
	if amount <= 0.0 or current + amount <= cap: return
	var need := current + amount - cap
	rows.append({"id": id, "name": label, "current": current, "cap": cap,
		"add": amount, "need": need, "destination": destination,
		"description": "%s需腾出%s%s" % [label, _number(need), "位" if id == "equipment" else ""]})

static func _result(rows: Array) -> Dictionary:
	var descriptions: Array[String] = []
	var destinations: Array[String] = []
	var boundary := false
	for row in rows:
		descriptions.append(String(row.description))
		if row.id != "equipment": boundary = true
		if not String(row.destination).is_empty() and not destinations.has(String(row.destination)):
			destinations.append(String(row.destination))
	return {"blockers": rows, "description": "；".join(descriptions), "destinations": destinations,
		"blocked": not rows.is_empty(), "boundary": boundary,
		"boundary_note": "草露、灵气／功德及堆叠上限为极限容量边界。" if boundary else ""}

static func diagnose(state, rewards: Dictionary, equipment_add: int = 0, check_energy: bool = true) -> Dictionary:
	var rows: Array = []
	_append(rows, "equipment", "衣冠装备", state.gear.inventory.size(), Equipment.CAPACITY, equipment_add, "wardrobe")
	_append(rows, "herbs", "灵草", state.herbs, state.MAX_RESOURCE, float(rewards.get("herbs", 0)), "alchemy")
	_append(rows, "dew", "晨露", state.dew, state.MAX_RESOURCE, float(rewards.get("dew", 0)), "alchemy")
	_append(rows, "chests", "木箱", state.gear.chests, Equipment.MAX_CHESTS, float(rewards.get("chests", 0)), "chests")
	if check_energy:
		var merit: bool = state.realm == state.MAX_REALM
		_append(rows, "merit" if merit else "qi", "功德" if merit else "灵气", state.merit if merit else state.qi,
			state.MAX_ENERGY, float(rewards.get("qi", 0)), "" if merit else "practice")
	var material_delta: Dictionary = rewards.get("materials", {})
	for id in material_delta:
		if not id is String or not Materials.has_material(id): continue
		var definition: Dictionary = Materials.material(id)
		_append(rows, "material:" + id, String(definition.name), state.material_count(id), Materials.MAX_STACK, float(material_delta[id]), "materials")
	var result := _result(rows)
	for row in rows:
		if row.id == "merit":
			result.description += "；归真功德暂无消耗途径，奖励保留"
	return result

static func chapter(state, id: String) -> Dictionary:
	if not Content.CHAPTERS.has(id): return _result([])
	# Every production first-clear package manufactures exactly one item.
	return diagnose(state, Content.CHAPTERS[id].first_clear_reward, 1)

static func quest(state, id: String) -> Dictionary:
	for row in state.quest_rows():
		if String(row.id) == id:
			# claim_quest clips energy through _add_energy; it does not reject it.
			return diagnose(state, row.rewards, 0, false)
	return _result([])

static func opportunity(state, choice_id: String) -> Dictionary:
	for choice in state.opportunity_status().get("choices", []):
		if String(choice.id) == choice_id: return diagnose(state, choice.rewards)
	return _result([])

static func corpse(state, reward: Dictionary = {}) -> Dictionary:
	var actual: Dictionary = reward if not reward.is_empty() else state.stage_corpse_status().get("rewards", {})
	return diagnose(state, actual, 0 if actual.get("item_spec", {}).is_empty() else 1)

static func salvage(state, instance_id: int) -> Dictionary:
	var item: Dictionary = state.gear.get_item(instance_id)
	if item.is_empty() or state.gear.equipped.values().has(instance_id): return _result([])
	return diagnose(state, {"herbs": state.gear.salvage_value(instance_id)})

static func chest(state) -> Dictionary:
	# Chest rolls are not predicted. Existing full-inventory fallback is a
	# conversion only when the roll would award equipment (always for starter).
	var full: bool = state.gear.inventory.size() >= Equipment.CAPACITY
	var result := _result([])
	result.equipment_full = full
	result.conversion_warning = "衣冠已满；若开出装备，将改得5灵草、1晨露（首箱同样）。可先整理，留1位再开。" if full else ""
	result.resource_warning = ""
	result.resource_warnings = []
	result.available = state.gear.chests > 0
	var starter: bool = state.gear.starter_chest_unopened
	# A nonfull starter chest always awards an item, never herbs or dew.
	var herb_max: int = 0 if starter and not full else (5 if full else 2)
	var dew_max: int = 0 if starter and not full else 1
	var labels: Array[String] = []
	if result.available:
		for spec in [{"id": "herbs", "name": "灵草", "current": state.herbs, "max_add": herb_max},
			{"id": "dew", "name": "晨露", "current": state.dew, "max_add": dew_max}]:
			var overflow: int = maxi(0, int(spec.current) + int(spec.max_add) - state.MAX_RESOURCE)
			if overflow <= 0: continue
			var row: Dictionary = spec.duplicate()
			row.cap = state.MAX_RESOURCE
			row.max_overflow = overflow
			row.certain = starter and full
			result.resource_warnings.append(row)
			labels.append("%s%s溢出%d" % [String(spec.name), "将" if row.certain else "最多", overflow])
	if not labels.is_empty():
		result.resource_warning = ("" if starter and full else "若获草露：") + "、".join(labels) + "；超额不保留。"
	return result
