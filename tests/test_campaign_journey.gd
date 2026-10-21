extends SceneTree
## Independent black-box journey and offline accounting QA.
## Only process-specific test saves are written. Real player saves are untouched.

const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Ledger = preload("res://scripts/equipment_ledger.gd")
var checks := 0
var failures := 0
var prefix := "user://test_campaign_journey_%d" % OS.get_process_id()


func _initialize() -> void:
	_test_unassisted_completion_boundary()
	_test_combat_free_quest_journey()
	_test_technique_choices_and_payment()
	_test_brew_and_buff_boundaries()
	_test_journey_boundaries_and_repeat()
	_test_offline_entitlements_and_pause()
	_test_clock_and_checkpoint_recovery()
	_test_legacy_equipment_migration()
	_cleanup()
	print("Independent campaign journey tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)


func _state(suffix: String = "") -> State:
	var state := State.new()
	state.save_path = prefix + suffix + ".json"
	state.gear.rng.seed = 75519
	state._journey_rng.seed = 197411
	return state


func _test_unassisted_completion_boundary() -> void:
	var expected_seconds := 0.0
	var total_herbs := 0
	for index in range(State.MAX_REALM):
		expected_seconds += float(Content.QI_COSTS[index]) / float(Content.QI_RATES[index])
		total_herbs += int(Content.HERB_COSTS[index])
	expected_seconds += float(total_herbs - 3) * 8.0
	_check(is_equal_approx(expected_seconds, 30772.0), "independent content arithmetic gives 8h32m52s base campaign")
	var state := _state()
	state.auto_advance = true # Explicit quiet-path choice; no combat or gifts.
	state.step(28800.0)
	_check(state.realm < State.MAX_REALM and state.lifetime_seconds == 28800.0, "unassisted eight-hour cap cannot prematurely finish campaign")
	state.step(expected_seconds - 28800.0 - 0.01)
	_check(state.realm == State.MAX_REALM - 1 and not state.completion_status().complete, "final breakthrough not awarded before exact boundary")
	state.step(0.01)
	_check(state.realm == State.MAX_REALM and state.completion_status().complete and state.qi == 0.0, "natural new game completes all fifteen advances exactly at boundary")
	_check(absf(state.campaign_finished_at - expected_seconds) < 0.001, "completion timestamp records actual natural completion")
	_check(state.inventory.is_empty() and state.total_victories == 0 and state.chest_count == 1 and state.quest_claimed.is_empty(), "baseline finish requires no combat, equipment, random drop or quest rewards")
	_check(state.herbs == 0 and state.counters.gathered == 689, "every required herb is naturally gathered and spent exactly once")
	var minute := _state()
	minute.auto_advance = true
	for index in range(513):
		minute.step(60.0)
	state.step(8.0)
	_check(minute.realm == state.realm and minute.herbs == state.herbs and minute.dew == state.dew and minute.counters == state.counters, "full campaign one-minute stepping agrees with bulk event stepping")
	_check(absf(minute.merit - state.merit) < 0.001 and absf(minute.campaign_finished_at - state.campaign_finished_at) < 0.001, "post-completion merit and exact finish time are frame-size independent")
	var before := state.merit
	state.step(60.0)
	_check(state.merit > before and state.realm == State.MAX_REALM, "finite campaign ending still permits calm postgame progress")
	print("Natural campaign completed at %.2f seconds; combat victories: %d" % [state.campaign_finished_at, state.total_victories])


func _claim(state: State, id: String) -> void:
	var result: Dictionary = state.claim_quest(id)
	_check(bool(result.ok), "natural quest chain claims " + id)
	var before := [state.herbs, state.dew, state.qi, state.merit, state.chest_count]
	_check(not state.claim_quest(id).ok, "quest cannot be claimed twice: " + id)
	_check([state.herbs, state.dew, state.qi, state.merit, state.chest_count] == before, "repeat claim creates no duplicate resources: " + id)


func _reach_realm(state: State, goal: int) -> void:
	state.auto_advance = true
	# Safety limit is derived from the full unassisted campaign, not a shortcut.
	for minute in range(600):
		if state.realm >= goal:
			break
		state.step(60.0)
	_check(state.realm >= goal, "natural simulation reaches realm %d" % goal)


func _test_combat_free_quest_journey() -> void:
	var state := _state("_natural")
	_check(not state.claim_quest("home").ok and not state.claim_quest("settle").ok and not state.claim_quest("unknown").ok, "locked, unfinished and nonexistent quests grant nothing")
	state.step(60.0)
	_claim(state, "settle")
	state.set_activity("gather")
	state.step(24.0)
	_claim(state, "gather")
	_reach_realm(state, 1)
	_claim(state, "first_realm")
	var reward: Dictionary = state.open_chest()
	_check(reward.ok and reward.starter and reward.item != null, "natural path opens guaranteed real starter item")
	var item_id := int(reward.item.id)
	_check(state.equip_item(item_id), "natural path can wear starter item")
	_claim(state, "first_chest")
	var first_study := state.upgrade_technique("petal")
	_check(first_study.ok, "quest earnings naturally fund first timed gathering technique study")
	if first_study.ok: state.step(float(first_study.duration))
	_check(state.select_technique("petal"), "completed paid study enables chosen gathering form")
	_claim(state, "learn")
	_check(state.select_recipe("qi") and state.set_activity("brew"), "natural path selects qi recipe and brewing")
	state.step(20.0)
	_check(state.pills >= 1, "natural materials produce a real stored pill")
	_claim(state, "brew")
	_check(state.use_pill("qi"), "naturally brewed pill can be consumed")
	_claim(state, "pill")
	_check(state.start_journey("bamboo").ok, "natural path dispatches unlocked companion journey")
	state.auto_advance = true
	state.step(300.0)
	_check(state.journey_completed == 1 and not state.journey_status().active, "single requested trip returns once without silently enabling repeat")
	_claim(state, "fox")
	_reach_realm(state, 6)
	_claim(state, "golden")
	var cost: Dictionary = state.gear.enhancement_cost(item_id)
	var before_herbs := state.herbs
	var before_dew := state.dew
	var visuals: Dictionary = state.gear.visual_loadout()
	_check(state.enhance_item(item_id).ok, "natural quest earnings fund item enhancement")
	_check(state.herbs == before_herbs - int(cost.herbs) and state.dew == before_dew - int(cost.dew), "state pays exact enhancement costs once")
	_check(state.gear.visual_loadout() == visuals and state.gear.get_item(item_id).enhancement == 1, "state enhancement changes actual item stats but preserves visible equipment")
	_claim(state, "enhance")
	_reach_realm(state, 12)
	_claim(state, "spirit")
	_reach_realm(state, 15)
	_claim(state, "home")
	_check(state.quest_claimed.size() == Content.QUESTS.size() and state.completion_status().complete, "entire twelve-quest campaign completes from a new game")
	_check(state.total_victories == 0 and not state.expedition_auto, "no quest or main story progress needs combat")
	_check(state.collection_status().progress > 20 and state.journal_rows().size() > 15, "real play creates collection and journal progression")
	state.settings.paused = true
	_check(state.save_game(), "completed campaign saves")
	var restored := _state("_natural")
	_check(restored.load_game().loaded, "completed campaign reloads")
	var restored_completion: Dictionary = restored.completion_status()
	var original_completion: Dictionary = state.completion_status()
	var finish_delta := absf(float(restored_completion.finished_at) - float(original_completion.finished_at))
	restored_completion.erase("finished_at")
	original_completion.erase("finished_at")
	_check(restored.quest_claimed == state.quest_claimed and restored_completion == original_completion and finish_delta < 0.001, "ending, completion time and all quest claims survive reload")
	_check(restored.gear.to_dict() == state.gear.to_dict() and restored.collection_status() == state.collection_status(), "actual enhanced equipment and collected entries survive reload")
	print("Combat-free quest journey finished at %.2f seconds; claims: %d/%d" % [state.campaign_finished_at, state.quest_claimed.size(), Content.QUESTS.size()])


func _test_technique_choices_and_payment() -> void:
	var state := _state()
	_check(not state.upgrade_technique("ember").ok and not state.select_technique("petal"), "locked/unlearned techniques cannot grant bonuses")
	state.realm = 15
	state.auto_advance = false
	state.herbs = 10000
	state.dew = 10000
	for id in Content.TECHNIQUES:
		var cap := int(Content.TECHNIQUES[id].max_level)
		for target in range(int(state.technique_levels[id]) + 1, cap + 1):
			var study := state.upgrade_technique(id)
			_check(study.ok, "technique begins finite paid study: " + id)
			if not study.ok: break
			state.step(float(study.duration))
		_check(int(state.technique_levels[id]) == cap and not state.upgrade_technique(id).ok, "book-specific rank cap enforced: " + id)
		if state.equipped_technique_slots(id).is_empty(): state.unattune_technique(id)
	var baseline := float(Content.QI_RATES[state.realm])
	state.unequip_technique("mist", "active")
	state.attune_technique("petal")
	state.select_technique("petal")
	_check(is_equal_approx(state.gather_multiplier(), 1.6) and is_equal_approx(state.qi_rate(), baseline) and is_equal_approx(state.brew_multiplier(), 1.0), "selected gathering form preserves its utility")
	state.attune_technique("stillness")
	state.confirm_heart_switch(state.quote_heart_switch("stillness"))
	_check(is_equal_approx(state.qi_rate(), baseline * 1.48) and is_equal_approx(state.gather_multiplier(), 1.6), "independent heart and form compose cultivation benefits")
	state.attune_technique("ember")
	state.select_technique("ember")
	_check(is_equal_approx(state.brew_multiplier(), 1.75) and is_equal_approx(state.qi_rate(), baseline * 1.48), "active fire art retains brewing bonus without replacing heart")
	var item: Dictionary = state.gear._make_item(1, "weapon_fan", "common", 1)
	state.gear.inventory.append(item)
	state.herbs = 0
	var before_dew := state.dew
	_check(not state.enhance_item(1).ok and item.enhancement == 0 and state.dew == before_dew, "insufficient enhancement materials cause no partial payment or rank gain")
	state.herbs = 1000
	for rank in range(5):
		_check(state.enhance_item(1).ok, "state enhances through valid rank %d" % (rank + 1))
	var before := [state.herbs, state.dew, state.counters.enhanced]
	_check(not state.enhance_item(1).ok and [state.herbs, state.dew, state.counters.enhanced] == before, "state max-rank request never charges or increments objective again")


func _test_brew_and_buff_boundaries() -> void:
	var state := _state()
	state.realm = 3
	state.herbs = 100
	state.dew = 100
	state.set_activity("brew")
	state.step(10.0)
	_check(state.select_recipe("spring"), "unlocked spring recipe selected")
	state.step(15.0)
	state.select_recipe("qi")
	_check(is_equal_approx(state.activity_progress, 0.5), "switching recipe restores qi half-progress")
	state.step(10.0)
	_check(state.pills == 1, "return to partial recipe completes exactly one qi pill")
	state.select_recipe("spring")
	state.step(15.0)
	_check(state.pill_stocks.spring == 1 and state.herbs == 92 and state.dew == 97, "different recipe partial timers and exact material charges remain independent")
	state.use_pill("spring")
	state.set_activity("gather")
	var buff_start := state.lifetime_seconds
	state.step(299.99)
	_check(not state.buff_rows().is_empty() and is_equal_approx(state.gather_multiplier(), 1.5), "spring buff remains active until exact expiry")
	state.step(0.01)
	_check(state.buff_rows().is_empty() and is_equal_approx(state.gather_multiplier(), 1.0) and is_equal_approx(state.lifetime_seconds - buff_start, 300.0), "spring buff expires at 300 simulation seconds")
	state.pill_stocks.clarity = 20
	for index in range(12):
		_check(state.use_pill("clarity"), "clarity duration stacks to one-hour bound")
	var stock := int(state.pill_stocks.clarity)
	_check(not state.use_pill("clarity") and state.pill_stocks.clarity == stock, "full-duration buff refuses to waste another pill")
	var bulk := _state()
	var fine := _state()
	for candidate in [bulk, fine]:
		candidate.realm = 3
		candidate.pill_stocks.clarity = 1
		candidate.use_pill("clarity")
		candidate.set_activity("meditate")
	bulk.step(600.0)
	for index in range(36000):
		fine.step(1.0 / 60.0)
	_check(absf(bulk.qi - fine.qi) < 0.01 and bulk.buff_rows().is_empty() and fine.buff_rows().is_empty(), "60-fps and bulk simulation split the same buff expiry boundary")


func _test_journey_boundaries_and_repeat() -> void:
	var state := _state()
	_check(not state.start_journey("creek").ok and not state.start_journey("unknown").ok, "locked and unknown route requests are safe")
	_check(state.start_journey("bamboo").ok and not state.start_journey("bamboo").ok, "only one companion journey can be active")
	state.step(299.99)
	_check(state.journey_completed == 0, "journey reward never arrives early")
	state.step(0.01)
	_check(state.journey_completed == 1 and not state.journey_status().active and state.journey_bond == 1, "single trip completes exactly once at boundary")
	state.step(600.0)
	_check(state.journey_completed == 1, "single-trip completion cannot repeat without consent")
	state.start_journey("bamboo", true)
	state.step(600.0)
	_check(state.journey_completed == 3 and state.chest_count == 2 and state.journey_status().active, "explicit repeat grants one unopened chest exactly every third lifetime journey")
	state.set_journey_repeat(false)
	state.step(300.0)
	_check(state.journey_completed == 4 and not state.journey_status().active, "turning repeat off finishes current trip and stops")
	state.realm = 9
	for id in ["creek", "ridge"]:
		_check(state.start_journey(id).ok, "later route unlock is functional: " + id)
		state.step(float(Content.JOURNEYS[id].seconds))
		_check(state.journey_last_result.id == id and not state.journey_status().active, "later route returns its own outcome: " + id)
	_check(state.journey_completed == 6 and state.chest_count == 3 and state.journey_bond == 9, "mixed routes share exact lifetime chest entitlement and individual bond weights")


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	_check(file != null, "isolated test save can be written")
	if file != null:
		file.store_string(JSON.stringify(data))
		file.close()


func _test_offline_entitlements_and_pause() -> void:
	var state := _state("_offline")
	state.start_journey("bamboo", true)
	for index in range(100):
		state.gear.inventory.append(state.gear._make_item(index + 1, "head_pin", "common", 1))
	state.gear._next_id = 101
	state.equip_item(100)
	var data := state._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 86400
	_write(state.save_path, data)
	var result: Dictionary = state.load_game()
	_check(result.loaded and result.capped and result.seconds == 28800 and absf(state.lifetime_seconds - 28800.0) < 0.001, "offline absence over eight hours is capped exactly once")
	_check(state.journey_completed == 96 and state.journey_bond == 96 and state.chest_count == 33, "eight-hour repeated bamboo journey awards 96 returns and32 unopened chests")
	_check(state.inventory.size() == 100 and state.equipped.head == 100 and state.total_victories == 0, "peaceful offline chest awards do not touch full inventory or start combat")
	var before := [state.chest_count, state.journey_completed, state.journey_bond]
	state.load_game()
	_check([state.chest_count, state.journey_completed, state.journey_bond] == before, "checkpointed offline returns cannot be awarded twice on immediate reload")
	var reward: Dictionary = state.open_chest()
	_check(reward.ok and reward.overflow and state.inventory.size() == 100 and state.equipped.head == 100 and state.chest_count == 32, "full inventory conversion happens only when player opens chest")
	state.settings.paused = true
	data = state._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 3600
	_write(state.save_path, data)
	var paused_time := state.lifetime_seconds
	before = [state.qi, state.herbs, state.dew, state.chest_count, state.journey_completed]
	result = state.load_game()
	_check(result.seconds == 0 and state.lifetime_seconds == paused_time and [state.qi, state.herbs, state.dew, state.chest_count, state.journey_completed] == before, "paused offline state awards no time, materials or returns")
	state.step(3600.0)
	_check(state.lifetime_seconds == paused_time and [state.qi, state.herbs, state.dew, state.chest_count, state.journey_completed] == before, "paused live simulation also freezes companion and cultivation")
	state.settings.paused = false
	for delta in [-1.0, NAN, INF, 0.0]:
		state.step(delta)
	_check(state.lifetime_seconds == paused_time, "invalid time deltas never advance simulation")


func _test_clock_and_checkpoint_recovery() -> void:
	var state := _state("_clock")
	state.start_journey("bamboo", true)
	state.step(290.0)
	var data := state._snapshot()
	var future := int(Time.get_unix_time_from_system()) + 3600
	data.saved_at = future
	_write(state.save_path, data)
	var result: Dictionary = state.load_game()
	_check(result.loaded and result.clock_invalid and result.seconds == 0 and state.journey_completed == 0, "clock rollback grants no premature journey or cultivation reward")
	var saved: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	_check(saved.saved_at >= future, "clock high-water checkpoint cannot be rewritten into an earlier entitlement window")
	result = state.load_game()
	_check(result.clock_invalid and state.journey_completed == 0, "repeated load during rollback remains non-rewarding")
	var recovering := _state("_recover")
	recovering.settings.paused = true
	recovering.realm = 6
	recovering.herbs = 123
	recovering.open_chest()
	_check(recovering.save_game(), "first recovery checkpoint saves")
	recovering.herbs = 124
	_check(recovering.save_game(), "second recovery checkpoint creates backup")
	var file := FileAccess.open(recovering.save_path, FileAccess.WRITE)
	file.store_string("{ truncated invalid save")
	file.close()
	result = recovering.load_game()
	_check(result.loaded and result.recovered and result.invalid_save and result.invalid_preserved, "damaged main save is preserved and previous valid checkpoint recovered")
	_check(recovering.realm == 6 and recovering.herbs == 123 and recovering.inventory.size() == 1, "backup recovery preserves campaign and actual owned equipment")


func _test_legacy_equipment_migration() -> void:
	var state := _state("_legacy")
	state.settings.paused = true
	state.realm = 4
	state.qi = 333.0
	state.herbs = 71
	state.open_chest()
	var id := int(state.inventory[0].id)
	state.equip_item(id)
	var data := state._snapshot()
	data.version = 2
	data.gear.version = 1
	data.gear.erase("discovered_templates")
	data.gear.inventory[0].erase("enhancement")
	for key in ["recipe", "pill_stocks", "technique_levels", "buffs", "journey", "journey_bond", "journey_completed", "discoveries", "quest_claimed", "counters", "journal_entries", "campaign_finished_at"]:
		data.erase(key)
	_write(state.save_path, data)
	var result: Dictionary = state.load_game()
	_check(result.loaded and result.get("migrated", false) and state.realm == 6 and state.realm_name() == "金丹初期", "legacy broad realm4 maps to equivalent golden-core stage")
	_check(state.qi == 333.0 and state.herbs == 71 and state.inventory.size() == 1 and state.equipped.values().has(id), "legacy migration retains cultivation resources and actual worn gear")
	_check(state.gear.get_item(id).enhancement == 0 and state.gear.discovered_templates.size() == 1, "legacy gear gains safe +0 and acquisition collection record")
	result = state.load_game()
	_check(result.loaded and not result.get("migrated", false) and not result.get("gear_repaired", false), "migration checkpoints to clean current format without repeating")


func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with(prefix.trim_prefix("user://")):
			directory.remove(filename)
