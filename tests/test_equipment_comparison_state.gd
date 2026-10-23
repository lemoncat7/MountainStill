extends SceneTree
## Isolated, deterministic fixtures; comparisons must never change the source.
const State = preload("res://scripts/cultivation_state.gd")
const Ledger = preload("res://scripts/equipment_ledger.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_empty_same_missing()
	_test_effective_stats()
	_test_compatibility()
	_test_capacity_and_read_only()
	print("Equipment comparison state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func add(s: State, template: String, rarity: String = "common", level: int = 1) -> int:
	return int(s.gear.add_item_spec({"template_id": template, "rarity": rarity, "level": level}).item.id)

func frozen(value: Variant) -> Variant:
	# Inspect all script storage without calling snapshot/to_dict/load helpers:
	# some serialization helpers normalize or discover live data themselves.
	if value is RandomNumberGenerator:
		return {"seed": value.seed, "state": value.state}
	if value is Object:
		var result := {}
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE:
				result[property.name] = frozen(value.get(property.name))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = frozen(value[key])
		return result
	if value is Array:
		var result: Array = []
		for element in value: result.append(frozen(element))
		return result
	return value

func verify(s: State, id: int, label: String) -> Dictionary:
	var original: Dictionary = frozen(s)
	var before := s.stats()
	var comparison := s.equipment_comparison(id)
	check(comparison.ok, label + " exists")
	check(comparison.before == before, label + " full before equals official stats")
	check(frozen(s) == original, label + " all live fields and RNG unchanged")
	# Actual equip on this disposable test state is the independent oracle.
	check(s.equip_item(id), label + " actual equip succeeds")
	check(comparison.after == s.stats(), label + " full after equals actual equip")
	check(comparison.after_gear == s.gear_stats(), label + " gear totals match")
	return comparison

func _test_empty_same_missing() -> void:
	var s := State.new()
	var before: Dictionary = frozen(s)
	check(s.equipment_comparison(-1) == {"ok": false, "reason": "missing"}, "missing item safely rejected")
	check(frozen(s) == before, "missing comparison is read only")
	var id := add(s, "weapon_sword")
	var result := verify(s, id, "empty weapon slot")
	check(result.equipped_item.is_empty() and not result.same_item, "empty slot represented explicitly")
	check(result.before.attack_module_id == "weapon.unarmed", "empty slot has unarmed module")
	result = verify(s, id, "already equipped")
	check(result.same_item and result.before == result.after, "same item has zero effective changes")
	result.equipped_item.attack = -999
	check(s.gear.get_item(id).attack != -999, "equipped item return is detached")

func _test_effective_stats() -> void:
	var s := State.new()
	s.realm = 12
	s.qi = 318.0
	s.merit = 19.0
	s.lifetime_seconds = 125.0
	s.buffs = {"clarity": 300.0, "spring": 500.0}
	s.activity = "brew"
	s.recipe = "spring"
	s._gather_clock = 3.0
	s._dew_clock = 5.0
	s._brew_clock = 7.0
	s.combat_tactic = "guarded"
	s.ending_finished_at = 10.0
	for chapter in Content.CHAPTER_ORDER: s.stage_clears[chapter] = 2
	for point in Content.ACUPOINTS: s.meridian_opened[point.id] = true
	s.technique_levels = {"mist": 4, "petal": 5, "stillness": 3, "breath": 4, "ember": 2}
	s.attuned_techniques.assign(["mist", "petal", "stillness", "breath", "ember"])
	s.equipped_heart = "breath"
	s.equipped_weapon_art = "petal"
	s.equipped_actives.assign(["petal", "ember"])
	s.equipped_passives.assign(["stillness"])
	for template in Ledger.TEMPLATES:
		var id := add(s, template, "epic", 23)
		for rank in range(5): s.gear.enhance_item(id)
		verify(s, id, "enhanced " + template)
	# Buff expiration must be observed, not expired/mutated by preview.
	s.lifetime_seconds = 600.0
	verify(s, add(s, "feet_cloth"), "expired buffs and evasion downgrade")

func _test_compatibility() -> void:
	var s := State.new()
	s.realm = 12
	s.technique_levels.petal = 3
	s.attuned_techniques.append("petal")
	s.equipped_actives.assign(["mist", "petal"])
	s.equipped_weapon_art = "mist"
	var sword := add(s, "weapon_sword")
	var fan := add(s, "weapon_fan")
	s.equip_item(sword)
	var result := verify(s, fan, "sword to fan")
	check(result.before.weapon_art.active and not result.after.weapon_art.active, "mist compatibility changes")
	check(not result.before.active_skills[1].active and result.after.active_skills[1].active, "petal compatibility changes")
	check(result.before.weapon_skill.id != result.after.weapon_skill.id, "weapon skills switch")
	check(result.before.attack_module_id != result.after.attack_module_id, "attack module switches")
	s.attuned_techniques.erase("petal")
	result = verify(s, fan, "unattuned petal")
	check(not result.after.active_skills[1].active, "unattuned technique remains inactive")
	s.attuned_techniques.append("petal")
	s.realm = 0
	result = verify(s, fan, "realm locked petal")
	check(not result.after.active_skills[1].active, "realm locked technique remains inactive")
	s.realm = 12
	s.technique_levels.petal = 0
	result = verify(s, fan, "unlearned petal")
	check(not result.after.active_skills[1].active, "unlearned technique remains inactive")

func _test_capacity_and_read_only() -> void:
	var s := State.new()
	var id := add(s, "weapon_fan")
	for index in range(Ledger.CAPACITY - 1): add(s, "head_pin")
	s.stage_run = {"run_id": 17, "battle_resources": {"hp": -9, "qi": 12345}}
	s.pending_heart_switch = {"id": "stillness", "remaining": 4.0}
	s._heart_quote = {"serial": 7, "id": "breath"}
	s.technique_training.assign([{"id": "mist", "remaining": 2.0}])
	s.gear.discovered_templates = {} # Catch accidental serializing normalization.
	s.save_path = "user://comparison_must_not_write_%d.json" % OS.get_process_id()
	var original: Dictionary = frozen(s)
	seed(76123)
	var expected_random := randf()
	seed(76123)
	var result := s.equipment_comparison(id)
	check(randf() == expected_random, "comparison does not advance global RNG")
	for iteration in range(25):
		check(s.equipment_comparison(id) == result, "repeated comparison deterministic %d" % iteration)
	check(result.inventory_count == Ledger.CAPACITY and result.inventory_capacity == Ledger.CAPACITY, "full bag supported")
	check(frozen(s) == original, "full state unchanged including pending combat and training")
	result.item.attack = -1000
	result.after.weapon_skill.id = "changed"
	result.before.active_skills.clear()
	result.before_gear.attack = -1000
	check(frozen(s) == original, "returned nested objects detached")
	for suffix in ["", ".bak", ".tmp"]:
		check(not FileAccess.file_exists(s.save_path + suffix), "no save file created " + suffix)
	verify(s, id, "full bag equip")
