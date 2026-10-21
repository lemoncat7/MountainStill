extends SceneTree
## Explicit unit fixtures only. The companion journey test earns all inputs in combat.
const State = preload("res://scripts/cultivation_state.gd")
const Materials = preload("res://scripts/material_registry.gd")
const Guide = preload("res://scripts/chapter_field_guide.gd")
var checks := 0
var failures := 0
func _initialize() -> void:
	check(Materials.validation_errors().is_empty(), "trusted catalog validates")
	test_unlocks_and_atomicity()
	test_conversion_choice()
	test_migration_and_comparison()
	test_guides()
	print("Chapter crafting state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error("FAIL " + label)
func resources(s) -> Array:
	return [s.gear.to_dict(), s.materials.to_dict(), s.herbs, s.dew, s.qi, s.merit, s.total_victories, s.stage_clears.duplicate(), s.chapter_reward_claimed.duplicate(), s._adventure_rng.state]
func test_unlocks_and_atomicity() -> void:
	for id in ["carve_river_pin", "bind_cloud_fan", "weave_moon_robe"]:
		var s := State.new()
		var row := Materials.recipe(id)
		for key in row.materials: s.materials.apply_delta({key: int(row.materials[key]) * 2})
		var before := resources(s)
		var quote := s.crafting_quote(id)
		check(not quote.unlocked and quote.reason == "locked_recipe" and not quote.can_craft, id + " materials do not unlock chapter recipe")
		check(not s.craft_recipe(id).ok and resources(s) == before, id + " locked request is wholly nonmutating")
		s.stage_clears[row.unlock_stage] = 1
		before = resources(s)
		for repeat in range(10): quote = s.crafting_quote(id)
		check(quote.unlocked and quote.can_craft and resources(s) == before, id + " clear discovers recipe without granting or spending")
		var made := s.craft_recipe(id)
		check(made.ok and made.item.template_id == row.template_id and made.item == s.gear.get_item(made.item.id), id + " canonical owned output")
		check(s.gear.equipped.is_empty() and s.chapter_reward_claimed.is_empty(), id + " no auto-equip or first-clear reward side effect")
		for key in row.materials: check(s.material_count(key) == int(row.materials[key]), id + " exact ingredient spend " + key)
		check(s.equip_item(made.item.id), id + " explicitly wearable")
		var equipped_before: Dictionary = s.gear.equipped.duplicate()
		var again := s.craft_recipe(id)
		check(again.ok and again.item.id != made.item.id and s.gear.equipped == equipped_before, id + " second paid craft distinct, never silently replaces")
		before = resources(s)
		check(not s.craft_recipe(id).ok and resources(s) == before, id + " depleted repeated request consumes nothing")
		for key in row.materials: s.materials.apply_delta({key: int(row.materials[key])})
		while s.inventory.size() < s.Equipment.CAPACITY: s.gear.add_item_spec({"template_id": "head_pin", "rarity": "common", "level": 1})
		before = resources(s)
		check(s.craft_recipe(id).reason == "inventory_full" and resources(s) == before, id + " full inventory retains every ingredient")
func test_conversion_choice() -> void:
	var s := State.new()
	s.materials.apply_delta({"moss_fiber": 3, "river_ore": 3, "spirit_jade": 1})
	var quote := s.crafting_quote("refine_route", "river_ore")
	check(quote.selected_material == "river_ore" and quote.materials == {"river_ore": 3}, "explicit material drives displayed quote")
	check(s.craft_recipe("refine_route", "river_ore").ok and s.material_count("moss_fiber") == 3 and s.material_count("spirit_jade") == 1, "only selected ingredient spent")
	var before := resources(s)
	check(not s.craft_recipe("refine_route", "river_ore").ok and resources(s) == before, "depleted selected ingredient never falls back")
	for invalid in ["unknown", "spirit_shard", "res://evil.gd", "refinement_stone"]:
		check(s.craft_recipe("refine_route", invalid).reason == "invalid_material" and resources(s) == before, "non-alternative rejected " + invalid)
	s.craft_recipe("refine_route", "moss_fiber")
	before = resources(s)
	quote = s.crafting_quote("refine_route")
	check(quote.selected_material != "spirit_jade" and not quote.can_craft, "jade alone never selected by default")
	check(not s.craft_recipe("refine_route").ok and resources(s) == before, "implicit request cannot spend rare treasure")
	quote = s.crafting_quote("refine_route", "spirit_jade")
	check(quote.can_craft and quote.materials == {"spirit_jade": 1} and quote.output_count == 3, "rare conversion has explicit one-for-three preview")
	check(s.craft_recipe("refine_route", "spirit_jade").ok and s.material_count("spirit_jade") == 0 and s.material_count("refinement_stone") == 5, "explicit rare conversion exact")
func test_migration_and_comparison() -> void:
	var s := State.new()
	s.stage_clears.cloud_slope = 1
	s.materials.apply_delta({"cloud_feather": 7, "refinement_stone": 3})
	var sword := s.gear.add_item_spec({"template_id": "weapon_sword", "rarity": "uncommon", "level": 4})
	s.equip_item(sword.item.id)
	s.realm = 3
	var quote := s.crafting_quote("bind_cloud_fan")
	check(quote.comparison.equipped_id == sword.item.id and quote.comparison.equipped_name == "青锋剑", "preview compares actual same-slot equipped instance")
	check(quote.comparison.attack_delta == int(quote.output_item.attack) - int(sword.item.attack) and quote.comparison.defense_delta == int(quote.output_item.defense), "signed before-after values from canonical stats")
	check(quote.comparison.qi_delta == float(quote.output_item.qi_bonus) and quote.comparison.evasion_delta == 0.0, "item ratios shown without inventing fan evasion")
	var made := s.craft_recipe("bind_cloud_fan")
	s.equip_item(made.item.id)
	check(s.enhance_item(made.item.id, "materials").ok, "crafted fan strengthens with exact existing path")
	var snapshot := s._snapshot()
	snapshot.loot_crafting_revision = 1
	var before := resources(s)
	var restored := State.new()
	restored._restore_and_award(JSON.parse_string(JSON.stringify(snapshot)), restored._offline_result(), false)
	check(restored.crafting_quote("bind_cloud_fan").unlocked, "v1.3.6 clear unlocks derived recipe on migration")
	check(restored.materials.to_dict() == s.materials.to_dict() and restored.gear.to_dict() == s.gear.to_dict(), "migration retains owned crafted rank and exact material stocks")
	check(not restored.stage_status().active and restored.total_victories == s.total_victories and resources(s) == before, "migration cannot auto-run or create victories")
	var old := State.new()
	var old_snapshot := old._snapshot()
	old_snapshot.erase("materials"); old_snapshot.erase("loot_crafting_revision")
	restored._restore_and_award(old_snapshot, restored._offline_result(), false)
	check(restored.materials.inventory.is_empty() and restored.inventory.is_empty() and not restored.crafting_quote("bind_cloud_fan").unlocked, "new recipe adds no free resources or unlock to genuinely old fresh save")
func test_guides() -> void:
	var s := State.new()
	var before := resources(s)
	for id in s.Content.CHAPTER_ORDER:
		var guide := s.chapter_field_guide(id)
		check(not guide.is_empty() and guide.monster_name == s.Content.STAGES[id].monsters[-1].name, "guide names real guardian " + id)
		check(Materials.has_material(guide.material_id) and not Materials.recipe(guide.recipe_id).is_empty(), "guide routes to valid material and recipe " + id)
		check(not String(guide.identity).is_empty() and not String(guide.preparation).is_empty(), "distinct preparation available " + id)
		guide.monster_name = "mutated"
		check(s.chapter_field_guide(id).monster_name != "mutated", "guide data cannot mutate catalog " + id)
	check(s.chapter_field_guide("missing").is_empty() and resources(s) == before and not s.stage_status().active, "reading guide cannot unlock start or reward")
