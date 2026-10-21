extends SceneTree
## Durable earned corpses + deterministic atomic material/crafting transactions.
const State = preload("res://scripts/cultivation_state.gd")
const Registry = preload("res://scripts/material_registry.gd")
const Materials = preload("res://scripts/material_ledger.gd")
const Gear = preload("res://scripts/equipment_ledger.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
var paths: Array[String] = []

func _initialize() -> void:
	_test_material_catalog_and_sanitize()
	_test_pending_search_and_guards()
	_test_save_cancel_fail_resume()
	_test_pending_payload_validation()
	_test_capacity_keeps_earned_payload()
	_test_boss_and_all_species()
	_test_crafting_and_preview()
	_test_material_enhancement_and_migration()
	_test_new_loot_probabilities()
	for path in paths:
		for suffix in ["", ".bak", ".tmp"]:
			if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("Looting/crafting state tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func state() -> State:
	var s := State.new()
	s.save_path = "user://test_looting_crafting_%d_%d.json" % [OS.get_process_id(), paths.size()]
	paths.append(s.save_path)
	s.auto_advance = false
	s._adventure_rng.seed = 20261020
	return s

func resources(s: State) -> Array:
	return [s.herbs, s.dew, s.qi, s.merit, s.chest_count, s.inventory.duplicate(true), s.materials.to_dict(), s.total_victories, s.stage_clears.duplicate()]

func _test_material_catalog_and_sanitize() -> void:
	check(Registry.validation_errors().is_empty(), "finite material/recipe catalog validates once")
	check(Registry.material_ids().size() == 9 and Registry.RECIPE_ORDER.size() == 7, "bounded nine materials and seven recipes")
	var copied := Registry.material("moss_fiber")
	copied.name = "changed"
	check(Registry.material("moss_fiber").name == "青苔灵纤", "cached catalog cannot be mutated by UI copy")
	for bad in ["../evil", "res://x.gd", "a-b", "NAME", "", 2, true, null]:
		check(not Registry.valid_id(bad), "reject unsafe material id " + str(bad))
	check(Registry.route_material("forest", "moss_beast") == "moss_fiber" and Registry.route_material("forest", "river_stone").is_empty(), "species and route must both match")
	var m := Materials.new()
	check(m.apply_delta({"moss_fiber": 4, "spirit_shard": 3}).ok, "valid stacks added atomically")
	var before := m.to_dict()
	for delta in [{"moss_fiber": -5, "spirit_shard": 1}, {"unknown": 1}, {"moss_fiber": 1.5}, {"moss_fiber": INF}, {"moss_fiber": true}, {"moss_fiber": Registry.MAX_STACK}]:
		check(not m.apply_delta(delta).ok and m.to_dict() == before, "invalid or overflowing entire transaction consumes nothing")
	var restored := Materials.new()
	check(not restored.load_data(JSON.parse_string(JSON.stringify(m.to_dict()))).repaired and restored.to_dict() == before, "stack inventory exact JSON roundtrip")
	var report := restored.load_data({"inventory": {"moss_fiber": 999999, "unknown": 1, "spirit_shard": -1, "cloud_feather": "2", "river_ore": 2.5, "spirit_jade": true, "moon_thread": INF}})
	check(report.repaired and restored.inventory == {"moss_fiber": Registry.MAX_STACK}, "malformed stack counts/types/IDs repaired independently")

func _test_pending_search_and_guards() -> void:
	var s := state()
	check(s.stage_corpse_status().is_empty(), "no body status is empty")
	check(not s.begin_stage_corpse(1, 0).ok and not s.advance_stage_search(1, 0, 1.0).ok and not s.complete_stage_search(1, 0).ok, "idle cannot invent bodies, search or rewards")
	var started := s.start_stage()
	var run := int(started.run_id)
	var before := resources(s)
	check(not s.begin_stage_corpse(run + 1, 0).ok and not s.begin_stage_corpse(run, 1).ok, "wrong token and skipped enemy rejected")
	var corpse := s.begin_stage_corpse(run, 0)
	check(corpse.ok and corpse.monster.id == "bamboo_sprite" and corpse.monster_index == 0 and corpse.stage_id == "bamboo_pass", "real enemy definition retained for corpse rendering")
	check(resources(s) == before and int(s.stage_run.kills) == 0 and float(corpse.search_seconds) == 0.0, "kill freezes earned payload but no income/checkpoint before search")
	var frozen: Dictionary = corpse.rewards.duplicate(true)
	var rng := s._adventure_rng.state
	corpse.rewards.materials.moss_fiber = 999
	check(s.stage_corpse_status().rewards == frozen, "public status cannot mutate frozen payload")
	check(s.begin_stage_corpse(run, 0).reason == "already_pending" and s._adventure_rng.state == rng, "duplicate death callback returns same frozen body without reroll")
	check(not s.defeat_stage_monster(run, 0).ok and not s.begin_stage_corpse(run, 1).ok, "legacy or next enemy cannot bypass pending body")
	for bad in [0.0, -1.0, NAN, INF]: check(not s.advance_stage_search(run, 0, bad).ok, "invalid search delta rejected")
	check(s.complete_stage_search(run, 0).reason == "search_incomplete", "completion before 2 seconds rejected")
	s.advance_stage_search(run, 0, 1.0)
	check(resources(s) == before and is_equal_approx(s.stage_corpse_status().search_progress, 0.5), "one real second gives half progress and zero payout")
	s.settings.paused = true
	check(not s.advance_stage_search(run, 0, 1.0).ok and not s.complete_stage_search(run, 0).ok and float(s.stage_corpse_status().search_seconds) == 1.0, "global pause freezes search and claim")
	s.settings.paused = false
	s.advance_stage_search(run, 0, 0.999)
	check(not s.complete_stage_search(run, 0).ok and resources(s) == before, "1.999 seconds still no income")
	s.advance_stage_search(run, 0, 0.001)
	var reward := s.complete_stage_search(run, 0)
	check(reward.ok and not reward.stage_finished and s.stage_run.kills == 1 and s.total_victories == 1 and s.stage_corpse_status().is_empty(), "completed two-second search atomically clears body and advances once")
	check(s.material_count("moss_fiber") == 2 and s.material_count("spirit_shard") == 1 and s.herbs == int(before[0]) + 1 and s.dew == int(before[1]) + 1 and s.qi == float(before[2]) + 8.0, "exact material and old resource bundle awarded")
	before = resources(s)
	check(not s.complete_stage_search(run, 0).ok and not s.begin_stage_corpse(run, 0).ok and resources(s) == before and s._adventure_rng.state == rng, "stale repeated completions and deaths grant/reroll nothing")

func _test_save_cancel_fail_resume() -> void:
	var s := state()
	var run := int(s.start_stage().run_id)
	s.begin_stage_corpse(run, 0)
	s.advance_stage_search(run, 0, 1.0)
	var frozen := s.stage_corpse_status().duplicate(true)
	var rng := s._adventure_rng.state
	var before := resources(s)
	s.settings.paused = true
	check(s.save_game(), "one-second pending search persists to real save")
	var restored := state()
	restored.save_path = s.save_path
	check(restored.load_game().loaded and not restored.stage_status().active and restored.stage_status().paused, "load remains inactive and explicitly resumable")
	check(restored.stage_corpse_status() == frozen and restored._adventure_rng.state == rng and resources(restored) == before, "load retains elapsed search, original monster and exact frozen reward/RNG")
	restored.settings.paused = false
	check(not restored.advance_stage_search(run, 0, 1.0).ok and not restored.complete_stage_search(run, 0).ok, "loaded route cannot search before explicit start")
	var material_before := restored.materials.to_dict()
	restored.step(State.OFFLINE_CAP_SECONDS)
	check(restored.stage_corpse_status() == frozen and restored.materials.to_dict() == material_before and restored.total_victories == 0 and restored._adventure_rng.state == rng, "eight hours catch-up cannot search, kill, award materials or reroll")
	check(restored.start_stage().ok, "explicit start resumes same body")
	check(restored.cancel_stage().reason == "corpse_preserved" and restored.stage_corpse_status() == frozen and not restored.stage_status().active, "cancel retains earned body/progress and pauses run")
	restored.realm = 1
	restored.stage_clears.bamboo_pass = 1
	check(not restored.select_stage("creek_bridge") and restored.selected_stage == "bamboo_pass", "route switch cannot discard an earned body")
	restored.start_stage()
	check(restored.fail_stage(run).ok and restored.stage_corpse_status() == frozen and restored.total_victories == 0, "defeat/retreat retains earned body without inventing extra kill")
	restored.start_stage()
	restored.advance_stage_search(run, 0, 1.0)
	check(restored.complete_stage_search(run, 0).ok and restored.material_count("moss_fiber") == 2, "resumed remaining second claims once")
	restored.settings.paused = true
	restored.save_game()
	restored.load_game()
	check(restored.stage_run.kills == 1 and restored.stage_corpse_status().is_empty() and restored.material_count("moss_fiber") == 2, "claimed body stays claimed across save/reopen")

func _test_pending_payload_validation() -> void:
	var s := state()
	var run := int(s.start_stage().run_id)
	s.begin_stage_corpse(run, 0)
	s.advance_stage_search(run, 0, 1.0)
	s.settings.paused = true
	var frozen := s.stage_corpse_status()
	var data := s._snapshot()
	data.adventure.stage_run.pending_corpse.rewards.herbs = 999999
	data.adventure.stage_run.pending_corpse.rewards.materials = {"moss_fiber": 9999, "unknown": 999}
	data.adventure.stage_run.pending_corpse.rewards.item_spec = {"template_id": "../../arbitrary", "rarity": "epic", "level": 100, "attack": 999999}
	data.adventure.stage_run.pending_corpse.rewards.equipment_rolled = true
	data.adventure.stage_run.pending_corpse.rewards.treasure_rolled = "yes"
	var restored := state()
	restored._restore_and_award(data, restored._offline_result(), false)
	var body := restored.stage_corpse_status()
	check(body.monster == frozen.monster and body.search_seconds == 1.0 and body.rewards.herbs == 1 and body.rewards.materials == {"spirit_shard": 1, "moss_fiber": 2}, "saved corpse resources and material amounts restored from trusted route, not injected counts")
	check(body.rewards.item_spec.is_empty() and not body.rewards.equipment_rolled and not body.rewards.treasure_rolled, "unknown item paths and nonboolean rare flags cannot enter earned payload")
	for bad in ["2", NAN, INF, true, null]:
		data.adventure.stage_run.pending_corpse.search_seconds = bad
		restored._restore_and_award(data, restored._offline_result(), false)
		check(restored.stage_corpse_status().search_seconds == 0.0, "wrong-type/nonfinite search progress cannot skip the two-second search")
	data.adventure.stage_run.pending_corpse.monster_index = 1
	restored._restore_and_award(data, restored._offline_result(), false)
	check(restored.stage_corpse_status().is_empty() and restored.stage_run.kills == 0 and restored.total_victories == 0, "mismatched pending corpse cannot advance an unearned checkpoint")
	# Save a partially searched boss and verify first-clear stays behind it.
	var boss := state()
	run = int(boss.start_stage().run_id)
	for index in range(2):
		boss.begin_stage_corpse(run, index)
		boss.advance_stage_search(run, index, 2.0)
		boss.complete_stage_search(run, index)
	var landmark := boss.check_route_opportunity(run)
	if landmark.opportunity_pending: boss.choose_opportunity("gather_gift")
	boss.begin_stage_corpse(run, 2)
	boss.advance_stage_search(run, 2, 1.0)
	boss.settings.paused = true
	data = boss._snapshot()
	restored._restore_and_award(data, restored._offline_result(), false)
	check(restored.stage_corpse_status().monster.boss and restored.stage_corpse_status().monster_index == 2 and restored.stage_clears.is_empty() and restored.chapter_reward_claimed.is_empty(), "saved boss remains visibly searchable and cannot prematurely trigger chapter gift or portal")
	restored.settings.paused = false
	restored.start_stage()
	restored.advance_stage_search(run, 2, 1.0)
	var reward := restored.complete_stage_search(run, 2)
	check(reward.ok and reward.stage_finished and reward.first_clear and reward.chapter_reward.ok, "saved boss earns chapter package after remaining real search second")
	var after := resources(restored)
	check(not restored.complete_stage_search(run, 2).ok and resources(restored) == after, "duplicate boss completion cannot repeat chapter or material award")


func _test_capacity_keeps_earned_payload() -> void:
	var s := state()
	var run := int(s.start_stage().run_id)
	s.begin_stage_corpse(run, 0)
	s.advance_stage_search(run, 0, 2.0)
	var frozen := s.stage_corpse_status()
	s.materials.inventory.moss_fiber = Registry.MAX_STACK
	var before := resources(s)
	check(s.complete_stage_search(run, 0).reason == "material_full" and resources(s) == before and s.stage_corpse_status() == frozen, "full material stack retains whole earned body without partial payout")
	s.materials.inventory.moss_fiber = 0
	s.herbs = State.MAX_RESOURCE
	before = resources(s)
	check(s.complete_stage_search(run, 0).reason == "resource_full" and resources(s) == before and s.stage_corpse_status() == frozen, "full old resource also retains body without partial payout")
	s.herbs = 0
	check(s.complete_stage_search(run, 0).ok, "making room allows original earned payload to be claimed")
	# Find an actual rolled equipment body, then fill capacity after the kill.
	var full := state()
	for attempt in range(1000):
		run = int(full.start_stage().run_id)
		full.begin_stage_corpse(run, 0)
		if bool(full.stage_corpse_status().rewards.equipment_rolled): break
		full.advance_stage_search(run, 0, 2.0)
		full.complete_stage_search(run, 0)
		full.cancel_stage()
	check(bool(full.stage_corpse_status().rewards.equipment_rolled), "seed produces an actual equipment body")
	full.advance_stage_search(run, 0, 2.0)
	frozen = full.stage_corpse_status()
	for index in range(Gear.CAPACITY): full.gear.inventory.append(full.gear._make_item(index + 1, "head_pin", "common", 1))
	before = resources(full)
	check(full.complete_stage_search(run, 0).reason == "inventory_full" and resources(full) == before and full.stage_corpse_status() == frozen, "full gear bag preserves frozen rolled item rather than converting/dropping it")
	full.gear.remove_item(1)
	var reward := full.complete_stage_search(run, 0)
	check(reward.ok and reward.item.template_id == frozen.rewards.item_spec.template_id and reward.item.rarity == frozen.rewards.item_spec.rarity, "claim after freeing slot uses original exact equipment roll")

func _test_boss_and_all_species() -> void:
	for stage_id in Content.CHAPTER_ORDER:
		var s := state()
		s.realm = 15
		for prior in Content.CHAPTER_ORDER:
			if prior == stage_id: break
			s.stage_clears[prior] = 1
		check(s.select_stage(stage_id), "route available: " + stage_id)
		var run := int(s.start_stage().run_id)
		var material_id := Registry.route_material(String(Content.STAGES[stage_id].biome), String(Content.STAGES[stage_id].monsters[0].visual_type))
		for index in range(3):
			if index == 2:
				var opportunity := s.check_route_opportunity(run)
				if bool(opportunity.opportunity_pending): s.choose_opportunity("gather_gift")
			var body := s.begin_stage_corpse(run, index)
			check(body.ok and body.rewards.materials.has(material_id) and body.rewards.materials[material_id] == (3 if index == 2 else 2), "species/route-specific material in frozen payload")
			check(int(s.stage_clears.get(stage_id, 0)) == 0 and not bool(s.chapter_reward_claimed.get(stage_id, false)), "boss death alone does not clear chapter or award first-clear package")
			s.advance_stage_search(run, index, 2.0)
			var reward := s.complete_stage_search(run, index)
			check(reward.ok and bool(reward.stage_finished) == (index == 2), "only searched boss finishes route")
		check(s.material_count(material_id) == 7 and s.material_count("spirit_shard") == 3 and s.total_victories == 3, "three searched bodies provide seven species materials and three shards")
		check(int(s.stage_clears[stage_id]) == 1 and s.chapter_reward_claimed[stage_id] and s.stage_run.is_empty() and not s.stage_status().active, "first-clear reward and boss route lifecycle preserved")

func _test_crafting_and_preview() -> void:
	var s := state()
	var before := resources(s)
	check(not s.craft_recipe("invalid").ok and not s.craft_recipe("forge_sword").ok and resources(s) == before, "unknown/unaffordable craft is nonmutating")
	s.materials.apply_delta({"spirit_shard": 9, "moss_fiber": 8, "river_ore": 3})
	var rng := s._adventure_rng.state
	var gear_rng: int = s.gear.rng.state
	var quote := s.crafting_quote("refine_stone")
	check(quote.can_craft and quote.costs[0].owned == 9 and quote.materials == {"spirit_shard": 3} and quote.output_name == "淬炼石", "craft preview exact input/owned/output")
	before = resources(s)
	for index in range(20): s.crafting_rows()
	check(resources(s) == before, "reopening/previews spend and award nothing")
	for index in range(3): check(s.craft_recipe("refine_stone").ok, "raw shard combine succeeds deterministically")
	check(s.material_count("spirit_shard") == 0 and s.material_count("refinement_stone") == 3, "combination consumes exact input and outputs exact stone count")
	s.realm = 3
	quote = s.crafting_quote("forge_sword")
	check(quote.output_item.template_id == "weapon_sword" and quote.output_item.level == 4 and quote.output_item.rarity == "uncommon" and quote.output_item.attack > 0, "manufacture preview is actual canonical level/stat gear")
	var made := s.craft_recipe("forge_sword")
	check(made.ok and s.inventory.size() == 1 and made.item.template_id == "weapon_sword" and made.item.attack == quote.output_item.attack and s.equipped.is_empty(), "manufacture creates owned instance and does not auto-equip")
	check(s.equip_item(int(made.item.id)) and s.gear.visual_loadout().weapon == "weapon_sword" and s.gear.equipped_attack_module_id() == "weapon.sword" and s.gear_stats().attack == made.item.attack, "manufactured sword participates in real stats, visual and registered module")
	made = s.craft_recipe("weave_armor")
	check(made.ok and s.equip_item(int(made.item.id)) and s.gear.visual_loadout().chest == "chest_jade" and s.gear_stats().defense > 0, "manufactured armor has real independent visible slot/defense")
	check(s.material_count("moss_fiber") == 3 and s.material_count("refinement_stone") == 0 and s._adventure_rng.state == rng and s.gear.rng.state == gear_rng, "exact manufacture costs and zero RNG failure/reroll")
	quote = s.crafting_quote("refine_route")
	check(quote.materials == {"moss_fiber": 3} and quote.output_count == 1, "alternate combine previews specific chosen species ingredient")
	check(s.craft_recipe("refine_route").ok and s.material_count("moss_fiber") == 0, "alternate recipe consumes only shown material")
	quote = s.crafting_quote("refine_route")
	check(quote.materials == {"river_ore": 3}, "other route material supports same explicit useful recipe")
	s.craft_recipe("refine_route")
	s.materials.apply_delta({"spirit_jade": 1})
	quote = s.crafting_quote("refine_route", "spirit_jade")
	check(quote.materials == {"spirit_jade": 1} and quote.output_count == 3 and s.craft_recipe("refine_route", "spirit_jade").ok and s.material_count("refinement_stone") == 5, "rare treasure has explicit triple-stone conversion")
	s.materials.inventory.refinement_stone = Registry.MAX_STACK
	s.materials.inventory.spirit_shard = 3
	before = resources(s)
	check(s.craft_recipe("refine_stone").reason == "material_full" and resources(s) == before, "full output stack consumes no input")
	while s.inventory.size() < Gear.CAPACITY: s.gear.add_item_spec({"template_id": "head_pin", "rarity": "common", "level": 1})
	s.materials.inventory.moss_fiber = 10
	before = resources(s)
	check(s.craft_recipe("forge_sword").reason == "inventory_full" and resources(s) == before, "full gear bag consumes no manufacture materials")

func _test_material_enhancement_and_migration() -> void:
	var s := state()
	var added := s.gear.add_item_spec({"template_id": "feet_boots", "rarity": "rare", "level": 4})
	var id := int(added.item.id)
	s.equip_item(id)
	s.materials.apply_delta({"refinement_stone": 15})
	var old_herbs := s.herbs
	var old_dew := s.dew
	var visual := s.gear.visual_loadout()
	for rank in range(1, 6):
		var quote := s.enhancement_quote(id, "materials")
		check(quote.can_enhance and quote.materials.refinement_stone == rank and quote.before.id == id and quote.after.id == id and quote.after.enhancement == rank and quote.after.defense > quote.before.defense, "material enhancement preview deterministic cost/stat increase")
		var result := s.enhance_item(id, "materials")
		check(result.ok and result.enhancement == rank and s.inventory.size() == 1 and s.equipped.feet == id and s.gear.get_item(id).defense == quote.after.defense, "material enhancement changes original equipped instance exactly once")
	check(s.material_count("refinement_stone") == 0 and s.herbs == old_herbs and s.dew == old_dew and s.gear.visual_loadout() == visual, "1+2+3+4+5 stones consumed; old grass/dew and visuals untouched")
	var before := resources(s)
	check(s.enhance_item(id, "materials").reason == "max_enhancement" and resources(s) == before, "+5 cannot be paid or enhanced again")
	var old := state()
	old.gear.add_item_spec({"template_id": "weapon_sword", "rarity": "common", "level": 1})
	old.herbs = 100
	old.dew = 100
	check(old.enhance_item(1).ok and old.gear.get_item(1).enhancement == 1 and old.herbs == 92 and old.dew == 99, "old one-argument grass/dew enhancement remains usable without any new materials")
	old.settings.paused = true
	var snapshot := old._snapshot()
	snapshot.erase("materials")
	snapshot.erase("loot_crafting_revision")
	var file := FileAccess.open(old.save_path, FileAccess.WRITE)
	file.store_string(JSON.stringify(snapshot))
	file.close()
	check(old.load_game().loaded and old.gear.get_item(1).enhancement == 1 and old.materials.inventory.is_empty(), "old save migrates without losing gear/rank or creating free materials")
	s.settings.paused = true
	check(s.save_game(), "manufacture/enhancement state persists")
	var restored := state()
	restored.save_path = s.save_path
	check(restored.load_game().loaded and restored.gear.to_dict() == s.gear.to_dict() and restored.materials.to_dict() == s.materials.to_dict(), "enhancement and material stacks survive reopen without reset")

func _test_new_loot_probabilities() -> void:
	var s := state()
	const TRIALS := 60000
	var chest := 0
	var equipment := 0
	var treasure := 0
	var both := 0
	var neither := 0
	var rarity := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0}
	var before := resources(s)
	for index in range(TRIALS):
		var roll := s._roll_stage_corpse_rewards("bamboo_pass", index % 3)
		if bool(roll.chest_rolled): chest += 1
		if bool(roll.equipment_rolled):
			equipment += 1
			rarity[roll.item_spec.rarity] += 1
		if bool(roll.treasure_rolled): treasure += 1
		if bool(roll.chest_rolled) and bool(roll.equipment_rolled): both += 1
		if not bool(roll.chest_rolled) and not bool(roll.equipment_rolled) and not bool(roll.treasure_rolled): neither += 1
	check(resources(s) == before, "rolling frozen reward never grants any income or owned instance")
	check(chest > 6700 and chest < 7700 and equipment > 1550 and equipment < 2050, "durable loot keeps independent 12% chest and 3% equipment")
	check(both > 150 and both < 285 and neither > 48000, "independent rolls can coincide and ordinary kills have no rare guarantee")
	check(treasure > 500 and treasure < 700 and treasure < TRIALS / 50, "rare material treasure stays near independent 1% with no every-kill guarantee")
	check(rarity.rare > 100 and rarity.rare < 250 and rarity.epic > 10 and rarity.epic < 70, "equipment preserves 0.30% rare and 0.06% epic absolute odds")
	print("CORPSE RNG: %d kills; chest=%d equipment=%d treasure=%d both=%d rarities=%s" % [TRIALS, chest, equipment, treasure, both, rarity])
