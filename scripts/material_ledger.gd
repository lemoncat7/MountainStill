class_name MaterialLedger
extends RefCounted
## Separate stack inventory. Transactions validate the entire delta first.
const Registry = preload("res://scripts/material_registry.gd")
const SAVE_VERSION := 1
var inventory: Dictionary = {}

func new_game() -> void:
	inventory = {}

func count(id: String) -> int:
	return int(inventory.get(id, 0)) if Registry.has_material(id) else 0

func rows() -> Array:
	var result: Array = []
	for id in Registry.material_ids():
		var row := Registry.material(String(id))
		row.count = count(String(id))
		row.description = String(row.use)
		result.append(row)
	return result

func validate_delta(delta: Dictionary) -> String:
	for id in delta:
		if not id is String or not Registry.has_material(id): return "invalid_material"
		var amount: Variant = delta[id]
		if not (amount is int or amount is float) or not is_finite(float(amount)) or floor(float(amount)) != float(amount) or absf(float(amount)) > Registry.MAX_STACK: return "invalid_count"
		var total := count(id) + int(amount)
		if total < 0: return "materials"
		if total > Registry.MAX_STACK: return "material_full"
	return ""

func apply_delta(delta: Dictionary) -> Dictionary:
	var reason := validate_delta(delta)
	if not reason.is_empty(): return {"ok": false, "reason": reason}
	for id in delta:
		var total := count(id) + int(delta[id])
		if total == 0: inventory.erase(id)
		else: inventory[id] = total
	return {"ok": true, "reason": "applied"}

func to_dict() -> Dictionary:
	return {"version": SAVE_VERSION, "inventory": inventory.duplicate()}

func load_data(value: Variant) -> Dictionary:
	new_game()
	var report := {"repaired": false, "discarded": 0}
	if not value is Dictionary: return {"repaired": true, "discarded": 0}
	var raw: Variant = value.get("inventory", {})
	if not raw is Dictionary: return {"repaired": true, "discarded": 0}
	for id in raw:
		var amount: Variant = raw[id]
		if not id is String or not Registry.has_material(id) or not (amount is int or amount is float) or not is_finite(float(amount)) or floor(float(amount)) != float(amount) or float(amount) < 0.0:
			report.repaired = true
			report.discarded += 1
			continue
		var bounded := int(minf(float(amount), Registry.MAX_STACK))
		if float(amount) > Registry.MAX_STACK: report.repaired = true
		if bounded > 0: inventory[id] = bounded
	return report
