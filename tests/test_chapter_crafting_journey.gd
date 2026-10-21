extends SceneTree
## Earn the fan, pay for its manual, and finish the untouched fourth chapter.
## No seeded inventory, fake wins, injected currencies, opener chest or grinding.
const Earned = preload("res://tests/chapter_crafting_plan.gd")
const State = preload("res://scripts/cultivation_state.gd")
var journey = Earned.new()
var output := "/tmp/chapter-crafting-journey.json"
var transactions: Array = []
var save_path := "user://test_chapter_crafting_journey_%d.json" % OS.get_process_id()
var fan_id := -1
var fan_level := -1
var acquisition_seconds := 0.0
var reload_verified := false

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	_check_initial_gates()
	if journey.prepare():
		if _craft_and_equip() and _reload():
			_prove_next_chapter()
	var report: Dictionary = journey.report()
	report.crafting = {"transactions": transactions, "fan_id": fan_id, "fan_level": fan_level,
		"enhancement": 1 if fan_id > 0 else 0, "acquisition_seconds": acquisition_seconds,
		"reload_verified": reload_verified}
	report.recipe_unlocks = {}
	for id in ["carve_river_pin", "bind_cloud_fan", "weave_moon_robe"]:
		var quote: Dictionary = journey.state.crafting_quote(id)
		report.recipe_unlocks[id] = {"unlocked": quote.get("unlocked", false), "unlock_stage": quote.get("unlock_stage", "")}
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t"))
		file.close()
	else:
		journey.check(false, "measurement report can be written")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("Earned chapter crafting journey: %d checks, %d failures; report %s" % [journey.checks, journey.errors.size(), output])
	quit(0 if journey.errors.is_empty() else 1)

func _check_initial_gates() -> void:
	var s = journey.state
	for id in ["carve_river_pin", "bind_cloud_fan", "weave_moon_robe"]:
		var before: Dictionary = journey.resources()
		var quote: Dictionary = s.crafting_quote(id)
		journey.check(not bool(quote.get("unlocked", true)) and str(quote.get("reason", "")) == "locked_recipe",
			"new character sees the real chapter-locked recipe: " + id)
		journey.check(not s.craft_recipe(id).get("ok", false) and journey.resources() == before,
			"locked recipe grants or consumes nothing: " + id)

func _craft_and_equip() -> bool:
	var s = journey.state
	journey.check(s.crafting_quote("carve_river_pin").get("unlocked", false)
		and s.crafting_quote("bind_cloud_fan").get("unlocked", false)
		and not s.crafting_quote("weave_moon_robe").get("unlocked", true),
		"only the recipes earned through actual first clears are unlocked")
	var untouched: Dictionary = journey.resources()
	for index in range(20):
		s.crafting_rows()
		s.crafting_quote("bind_cloud_fan")
		s.crafting_quote("refine_route", "cloud_feather")
	journey.check(journey.resources() == untouched, "opening recipes and explicit ingredient previews is nonmutating")
	var rng_before: int = s._adventure_rng.state
	var gear_rng_before: int = s.gear.rng.state
	for index in range(2):
		var quote: Dictionary = s.crafting_quote("refine_stone")
		journey.check(quote.materials == {"spirit_shard": 3} and quote.output_materials == {"refinement_stone": 1},
			"three genuinely earned shards quote exactly one stone")
		var made: Dictionary = s.craft_recipe("refine_stone")
		if not journey.check(bool(made.get("ok", false)), "earned shards actually combine"): return false
		transactions.append({"recipe": "refine_stone", "costs": made.costs, "outputs": made.materials, "seconds": s.lifetime_seconds})
	journey.check(s.material_count("spirit_shard") == 3 and s.material_count("refinement_stone") == 2,
		"only six of the nine earned shards fund fan crafting")
	var before: Dictionary = journey.resources()
	var quote: Dictionary = s.crafting_quote("bind_cloud_fan")
	fan_level = s.realm + 1
	journey.check(quote.get("can_craft", false) and quote.materials == {"cloud_feather": 4, "refinement_stone": 2}
		and str(quote.output_item.template_id) == "weapon_fan" and str(quote.output_item.rarity) == "uncommon"
		and int(quote.output_item.level) == fan_level, "earned cloud recipe previews exact costs and genuine current-realm fan")
	var fan: Dictionary = s.craft_recipe("bind_cloud_fan")
	if not journey.check(bool(fan.get("ok", false)), "craft a real owned fan from ordinary chapter materials"): return false
	fan_id = int(fan.item.id)
	acquisition_seconds = s.lifetime_seconds
	transactions.append({"recipe": "bind_cloud_fan", "costs": fan.costs, "item": fan.item.duplicate(true), "seconds": acquisition_seconds})
	journey.check(s.inventory.size() == int(before.inventory.size()) + 1 and s.equipped == before.equipped,
		"manufacture adds one owned item and does not silently equip it")
	journey.check(s.material_count("cloud_feather") == 3 and s.material_count("refinement_stone") == 0
		and s.material_count("spirit_shard") == 3, "fan pays exactly four feathers and two stones")
	journey.check(s.herbs == int(before.herbs) and s.dew == int(before.dew) and is_equal_approx(s.qi, float(before.qi)),
		"crafting charges no unquoted cultivation currency")
	journey.check(s.equip_item(fan_id) and int(s.equipped.weapon) == fan_id
		and str(s.gear.visual_loadout().weapon) == "weapon_fan" and s.gear.equipped_attack_module_id() == "weapon.fan",
		"explicit equip activates the real fan stats, visual and attack module")
	var made: Dictionary = s.craft_recipe("refine_stone")
	if not journey.check(bool(made.get("ok", false)), "remaining three earned shards make the enhancement stone"): return false
	transactions.append({"recipe": "refine_stone", "costs": made.costs, "outputs": made.materials, "seconds": s.lifetime_seconds})
	var upgrade: Dictionary = s.enhancement_quote(fan_id, "materials")
	var attack_before := int(s.stats().attack)
	var enhanced: Dictionary = s.enhance_item(fan_id, "materials")
	journey.check(upgrade.materials == {"refinement_stone": 1} and enhanced.get("ok", false)
		and int(s.gear.get_item(fan_id).enhancement) == 1 and s.inventory.size() == 4
		and int(s.equipped.weapon) == fan_id and int(s.stats().attack) > attack_before,
		"third earned stone strengthens the same equipped fan instance to +1")
	transactions.append({"recipe": "enhance_materials", "costs": upgrade.materials, "before": upgrade.before, "after": upgrade.after})
	journey.check(s.material_count("spirit_shard") == 0 and s.material_count("refinement_stone") == 0
		and s.material_count("moss_fiber") == 7 and s.material_count("river_ore") == 7
		and s.material_count("cloud_feather") == 3 and s.material_count("spirit_jade") == 0,
		"nine shards fund the full fan-plus-enhancement loop with no rare treasure or unrelated material spending")
	journey.check(s._adventure_rng.state == rng_before and s.gear.rng.state == gear_rng_before,
		"combining, manufacture, equip and enhancement never roll RNG")
	before = journey.resources()
	journey.check(not s.craft_recipe("bind_cloud_fan").get("ok", false)
		and not s.enhance_item(fan_id, "materials").get("ok", false) and journey.resources() == before,
		"unfunded repeat crafting and enhancement consume and duplicate nothing")
	for id in s.equipped_actives.duplicate():
		s.unequip_technique(str(id), "active")
	journey.check(s.equip_technique("petal", "weapon_art").get("ok", false)
		and s.equip_technique("petal", "active").get("ok", false), "paid, completed petal manual explicitly equips as form and active")
	if int(s.technique_levels.get("barrier", 0)) > 0:
		journey.check(s.equip_technique("barrier", "active").get("ok", false), "already paid barrier takes the other available active slot")
	var actual: Dictionary = s.stats()
	journey.check(str(actual.weapon_art.id) == "petal" and actual.weapon_art.active
		and str(actual.weapon_skill.move) == "weapon_fan_return", "battle stat payload contains actual learned form and fan innate active")
	return journey.errors.is_empty()

func _reload() -> bool:
	var s = journey.state
	s.settings.paused = true
	s.save_path = save_path
	var before: Dictionary = journey.resources()
	var gear: Dictionary = s.gear.to_dict()
	var manuals: Dictionary = s.technique_levels.duplicate()
	var loadout := [s.equipped_heart, s.equipped_weapon_art, s.equipped_actives.duplicate(), s.equipped_passives.duplicate()]
	journey.check(s.save_game(), "earned crafted build saves to an isolated real file")
	var restored := State.new()
	restored.save_path = save_path
	journey.check(restored.load_game().get("loaded", false), "earned crafted build loads")
	journey.state = restored
	journey.check(_same_resources(journey.resources(), before) and restored.gear.to_dict() == gear
		and restored.technique_levels == manuals
		and [restored.equipped_heart, restored.equipped_weapon_art, restored.equipped_actives, restored.equipped_passives] == loadout,
		"reload preserves exact resources, item identity/level/rank and paid manual loadout without duplication")
	journey.check(restored.load_game().get("loaded", false) and _same_resources(journey.resources(), before),
		"second paused reload duplicates no materials, gear, first-clear rewards or offline earnings")
	journey.check(int(restored.gear.get_item(fan_id).level) == fan_level
		and int(restored.gear.get_item(fan_id).enhancement) == 1 and int(restored.equipped.weapon) == fan_id,
		"the owned equipped fan retains its earned level and +1 rank")
	journey.check(not restored.stage_status().active and restored.stage_run.is_empty() and not restored.expedition_auto,
		"save/reload never silently starts an adventure")
	var paused_before: Dictionary = journey.resources()
	restored.step(60.0)
	journey.check(journey.resources() == paused_before, "paused save remains fully paused")
	restored.settings.paused = false
	var victories := restored.total_victories
	restored.step(Earned.DT)
	journey.check(restored.total_victories == victories and not restored.stage_status().active,
		"unpausing ordinary cultivation still requires explicit route departure")
	reload_verified = journey.errors.is_empty()
	return reload_verified

func _same_resources(actual: Dictionary, expected: Dictionary) -> bool:
	var a := actual.duplicate(true)
	var b := expected.duplicate(true)
	# Decimal JSON roundtrip can shift the last few binary float bits. Integer
	# currency, material/item counts, IDs, ranks, RNG and counters remain exact.
	for key in ["seconds", "qi", "merit"]:
		if absf(float(a[key]) - float(b[key])) > 0.0000001: return false
		a.erase(key)
		b.erase(key)
	return a == b

func _prove_next_chapter() -> void:
	if not journey.run_stage("ember_ruins"): return
	var sums := {"fan_basic_turns": 0, "fan_basic_contacts": 0, "fan_basic_damage": 0,
		"fan_weapon_turns": 0, "fan_weapon_contacts": 0, "fan_weapon_damage": 0,
		"petal_turns": 0, "petal_contacts": 0, "petal_damage": 0, "hero_melee_geometry_contacts": 0}
	for record in journey.records:
		if record.stage != "ember_ruins": continue
		for key in sums: sums[key] += int(record.events[key])
	for category in ["fan_basic", "fan_weapon", "petal"]:
		journey.check(int(sums[category + "_turns"]) > 0 and int(sums[category + "_contacts"]) > 0
			and int(sums[category + "_damage"]) > 0, "next chapter has genuine damaging " + category + " attacks")
	journey.check(int(sums.hero_melee_geometry_contacts) > 0, "fan hits use real painted-body contact geometry")
	journey.check(journey.state.total_victories == 12 and int(journey.state.stage_clears.ember_ruins) == 1,
		"crafted fan build wins all three unchanged native fourth-chapter enemies")
	journey.check(journey.chances == {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0},
		"all four whole chapters succeed without any lucky reward")
	journey.check(not journey.state.stage_status().active and not journey.state.expedition_auto,
		"fourth chapter completion again leaves future routes manual")
	journey.check(journey.state._valid_save(journey.state._snapshot()), "completed genuine four-chapter crafting journey remains save-valid")
