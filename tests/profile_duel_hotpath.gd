extends "res://scripts/duel_timeline.gd"
## Inclusive method timing for diagnosis only. Do not use as performance result.
var _profile_totals: Dictionary = {}
func profile_reset() -> void:
	_profile_totals.clear()
func profile_snapshot() -> Dictionary:
	return _profile_totals.duplicate(true)
func _record(method: String, started: int) -> void:
	var duration := Time.get_ticks_usec() - started
	var row: Dictionary = _profile_totals.get(method, {"calls": 0, "inclusive_us": 0, "max_us": 0})
	row.calls += 1
	row.inclusive_us += duration
	row.max_us = maxi(row.max_us, duration)
	_profile_totals[method] = row
func _apply_enemy_motion(motion: Dictionary, at_time: float = -1.0, apply_spacing: bool = true) -> void:
	var started := Time.get_ticks_usec()
	super._apply_enemy_motion(motion, at_time, apply_spacing)
	_record("_apply_enemy_motion", started)
func _enemy_clearance_previews(action: Dictionary, clock: float) -> Array:
	var started := Time.get_ticks_usec()
	var result := super._enemy_clearance_previews(action, clock)
	_record("_enemy_clearance_previews", started)
	return result
func _predicted_enemy_motion(at: float) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._predicted_enemy_motion(at)
	_record("_predicted_enemy_motion", started)
	return result
func _plan_melee_approach(action: Dictionary) -> void:
	var started := Time.get_ticks_usec()
	super._plan_melee_approach(action)
	_record("_plan_melee_approach", started)
func _measure_melee_contact(action: Dictionary, current: Dictionary, planted_target: bool = false) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._measure_melee_contact(action, current, planted_target)
	_record("_measure_melee_contact", started)
	return result
func _resolve_contact(actor: String, action: Dictionary, contact: Dictionary) -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super._resolve_contact(actor, action, contact)
	_record("_resolve_contact", started)
	return result
func battle_resource_snapshot() -> Dictionary:
	var started := Time.get_ticks_usec()
	var result := super.battle_resource_snapshot()
	_record("battle_resource_snapshot", started)
	return result
