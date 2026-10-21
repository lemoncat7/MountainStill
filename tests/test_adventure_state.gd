extends SceneTree
## Manual adventure, optional meridians, persistence and probability regression.
## All writes use isolated test files, never the player's cultivation save.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Ledger = preload("res://scripts/equipment_ledger.gd")
var checks := 0
var failures := 0
var prefix := "user://test_adventure_state_%d" % OS.get_process_id()


func _initialize() -> void:
	_test_content_and_start_guards()
	_test_finite_rewards_once()
	_test_idle_and_offline_do_not_fight()
	_test_seed_reproduction()
	_test_probabilities()
	_test_opportunity_once_and_persistence()
	_test_meridians_and_caps()
	_test_meridian_simulation_equivalence()
	_test_save_migration()
	_test_adventure_sanitization()
	_test_resource_capacity()
	_cleanup()
	print("Adventure state tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)


func state(suffix: String = "") -> State:
	var result := State.new()
	result.save_path = prefix + suffix + ".json"
	result.auto_advance = false
	result._adventure_rng.seed = 20261019
	return result


func resources(s: State) -> Array:
	return [s.herbs, s.dew, s.qi, s.merit, s.chest_count, s.inventory.duplicate(true), s.total_victories]


func finish(s: State) -> Dictionary:
	var started := s.stage_status() if s.stage_status().active else s.start_stage()
	if not bool(started.get("active", false)):
		return started
	var result: Dictionary = {}
	for index in range(int(started.kills), 3):
		if index == 2:
			var landmark := s.check_route_opportunity(int(started.run_id))
			if bool(landmark.opportunity_pending):
				s.choose_opportunity("gather_gift")
		result = s.defeat_stage_monster(int(started.run_id), index)
	return result


func reach_checkpoint(s: State) -> Dictionary:
	var started := s.start_stage()
	if not bool(started.get("ok", false)):
		return started
	for index in range(2):
		s.defeat_stage_monster(int(started.run_id), index)
	return s.check_route_opportunity(int(started.run_id))


func _test_content_and_start_guards() -> void:
	var s := state()
	var rows := s.stage_rows()
	check(rows.size() == 6 and rows.map(func(r): return r.id) == Content.CHAPTER_ORDER, "six authored routes preserve original order and extend the finite campaign")
	check(rows[0].unlock_realm == 0 and rows[1].unlock_realm == 1 and rows[2].unlock_realm == 3, "stage realm gates 0, 1, 3")
	check(int(rows[0].monsters[0].hp) > 0 and int(rows[0].monsters[1].hp) > 0 and int(rows[0].monsters[2].hp) > maxi(int(rows[0].monsters[0].hp), int(rows[0].monsters[1].hp)), "first-route authored health gives positive ordinary fights and a larger boss budget")
	for row in rows:
		check(row.monsters.map(func(m): return m.boss) == [false, false, true], "each scrolling route ends in a boss after two ordinary encounters")
		check(not String(row.monsters[2].boss_move).is_empty() and row.monsters.all(func(m): return not String(m.visual_type).is_empty()), "every route has an explicit species and distinct boss move")
	check(Content.COMBAT_PROFILES.keys() == ["mist", "petal", "ember", "stillness"] and Content.TECHNIQUES.size() == 10, "legacy combat profiles preserve original IDs alongside expanded manual catalog")
	check(Content.COMBAT_PROFILES.mist.moves == ["mist_thrust", "mist_lift", "mist_combo"] and Content.COMBAT_PROFILES.petal.dodge_chance > Content.COMBAT_PROFILES.mist.dodge_chance, "sword and movement profiles have explicit distinct mechanics")
	check(Content.COMBAT_PROFILES.ember.moves.has("ember_palm") and Content.COMBAT_PROFILES.stillness.guard_chance > 0.5, "fire palm and internal guard profiles configured")
	check(not s.stage_status().active and not s.stage_status().paused and s.stage_run.is_empty(), "new game starts at home without pending combat")
	check(s.selected_stage == "bamboo_pass" and rows[0].selected, "first route is selected, never started")
	check(not s.select_stage("unknown") and not s.select_stage("creek_bridge"), "invalid and locked selection rejected")
	check(not s.cancel_stage().ok, "no phantom run to cancel")
	s.selected_stage = "cloud_slope"
	check(not s.start_stage().ok, "start validates realm separately from selection")
	s.selected_stage = "bamboo_pass"
	s.settings.paused = true
	check(not s.start_stage().ok and s.stage_run.is_empty(), "global pause blocks explicit combat start")
	s.settings.paused = false
	var started := s.start_stage()
	check(started.ok and started.kills == 0 and started.monsters.size() == 3 and started.run_id > 0, "explicit start returns finite canonical encounter data")
	check(not s.start_stage().ok and not s.select_stage("bamboo_pass"), "live run cannot be duplicated or switched")
	var early_rng := s._adventure_rng.state
	check(s.check_route_opportunity(int(started.run_id)).reason == "not_at_checkpoint" and s.check_route_opportunity(int(started.run_id) + 1).reason == "stale_encounter", "early and stale route landmark checks are rejected")
	check(s._adventure_rng.state == early_rng and not s.stage_status().opportunity_checked, "early route checks never consume the one permitted opportunity roll")
	s.settings.paused = true
	check(not s.defeat_stage_monster(int(started.run_id), 0).ok and s.stage_run.kills == 0, "paused combat callbacks cannot reward")
	s.settings.paused = false
	check(s.cancel_stage().ok and not s.stage_status().active, "explicit retreat clears live run")
	s.realm = 15
	for id in Content.CHAPTER_ORDER:
		check(s.select_stage(id) and s.start_stage().ok and s.cancel_stage().ok, "each unlocked route can be deliberately selected, started and cancelled: " + id)
		check(finish(s).stage_finished, "real prior clear unlocks following chapter: " + id)


func _test_finite_rewards_once() -> void:
	var s := state()
	var started := s.start_stage()
	var run_id := int(started.run_id)
	var before := resources(s)
	var rng_before := s._adventure_rng.state
	check(not s.defeat_stage_monster(run_id, 1).ok and not s.defeat_stage_monster(run_id - 1, 0).ok and not s.defeat_stage_monster(run_id, -1).ok, "out-of-order and stale kill callbacks rejected")
	check(resources(s) == before and s._adventure_rng.state == rng_before, "rejected kills cannot mutate resources or random stream")
	for index in range(3):
		if index == 2:
			check(not s.defeat_stage_monster(run_id, 2).ok, "boss requires the between-encounter route checkpoint")
			var landmark := s.check_route_opportunity(run_id)
			if bool(landmark.opportunity_pending):
				s.choose_opportunity("gather_gift")
		before = resources(s)
		var reward := s.defeat_stage_monster(run_id, index)
		check(reward.ok and reward.herbs >= 1 and reward.dew >= 1 and reward.qi == 8.0, "every real kill awards ordinary bounded resources")
		var chapter: Dictionary = reward.get("chapter_reward", {})
		check(s.herbs == int(before[0]) + int(reward.herbs) + int(chapter.get("herbs", 0)) and s.dew == int(before[1]) + int(reward.dew) + int(chapter.get("dew", 0)) and s.qi == float(before[2]) + float(reward.qi) + float(chapter.get("qi", 0.0)), "returned monster gains plus separately reported first-clear package match exact applied awards")
		check(reward.stage_finished == (index == 2), "only third kill completes route")
		before = resources(s)
		rng_before = s._adventure_rng.state
		check(not s.defeat_stage_monster(run_id, index).ok and resources(s) == before and s._adventure_rng.state == rng_before, "duplicate kill callback never repeats rewards")
	check(not s.stage_status().active and not s.stage_status().paused and s.stage_run.is_empty(), "third kill ends run and never starts next one")
	check(s.total_victories == 3 and s.stage_clears.bamboo_pass == 1, "exact victory and completion counts")
	before = resources(s)
	s.step(900.0)
	check(s.total_victories == 3 and s.stage_clears.bamboo_pass == 1 and not s.stage_status().active, "idle after clear cannot repeat route")
	started = s.start_stage()
	check(started.ok and int(started.run_id) != run_id, "another explicit start uses fresh id")
	check(not s.defeat_stage_monster(run_id, 0).ok, "stale previous run token cannot kill next route")
	s.defeat_stage_monster(int(started.run_id), 0)
	before = resources(s)
	check(s.cancel_stage().ok and resources(s) == before, "retreat preserves all earned loot")


func _test_idle_and_offline_do_not_fight() -> void:
	var s := state("_offline")
	s.expedition_auto = true
	check(not s.expedition_auto, "removed auto-expedition cannot be reenabled through compatibility property")
	s.step(State.OFFLINE_CAP_SECONDS)
	check(s.total_victories == 0 and s.stage_run.is_empty() and s.stage_clears.is_empty() and s.chest_count == 1, "eight-hour passive simulation never starts encounters")
	var started := s.start_stage()
	s.defeat_stage_monster(int(started.run_id), 0)
	var adventure_before: Dictionary = s._snapshot().adventure
	var gear_before := s.gear.to_dict()
	var victories_before := s.total_victories
	s.step(100.0)
	check(s.stage_run.kills == 1 and s.total_victories == victories_before, "live step does not resolve even explicitly started enemies")
	var data := s._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 3600
	data.expedition_auto = true
	_write(s.save_path, data)
	var restored := state("_offline")
	var result := restored.load_game()
	check(result.loaded and result.seconds >= 3600 and restored.qi > s.qi, "offline cultivation still earns normal qi")
	check(restored.stage_status().paused and not restored.stage_status().active and restored.stage_run.kills == 1, "reload preserves next monster but pauses combat until explicit start")
	check(restored.total_victories == victories_before and restored.gear.to_dict() == gear_before and not restored.expedition_auto, "offline earns no combat loot and strips legacy automatic combat")
	check(restored._snapshot().adventure.rng_state == adventure_before.rng_state, "offline does not advance adventure RNG")
	check(not restored.defeat_stage_monster(int(started.run_id), 1).ok, "host cannot reward paused reload before explicit resume")
	started = restored.start_stage()
	check(started.ok and started.reason == "resumed" and started.kills == 1, "explicit start resumes saved route rather than repeating claimed enemy")
	check(not restored.defeat_stage_monster(int(started.run_id), 0).ok and restored.defeat_stage_monster(int(started.run_id), 1).ok, "resumed route accepts only unclaimed enemy")
	check(restored.save_game(), "resumed progress checkpoints")
	restored.load_game()
	check(restored.stage_run.kills == 2 and restored.total_victories == 2 and not restored.stage_status().active, "repeat save/load retains exactly two kills without restart")
	check(restored.select_stage("bamboo_pass") and restored.stage_status().paused, "same selection does not discard interrupted progress")
	restored.realm = 1
	check(not restored.select_stage("creek_bridge") and restored.stage_run.kills == 2, "realm alone cannot replace checkpoint with uncleared next chapter")
	check(finish(restored).stage_finished, "finish prior route to earn next chapter access")
	var repeated := restored.start_stage()
	restored.defeat_stage_monster(int(repeated.run_id), 0)
	restored.pause_stage(int(repeated.run_id))
	check(restored.select_stage("creek_bridge") and restored.stage_run.is_empty(), "explicit unlocked new selection can retire interrupted replay")


func _test_seed_reproduction() -> void:
	var a := state("_rng_a")
	var b := state("_rng_b")
	var legacy_a: int = a.gear.rng.state
	var legacy_b: int = b.gear.rng.state
	for run_index in range(120):
		var first := a.start_stage()
		var second := b.start_stage()
		for index in range(3):
			if index == 2:
				check(a.check_route_opportunity(int(first.run_id)) == b.check_route_opportunity(int(second.run_id)), "fixed seed reproduces midway route opportunity")
				if a.stage_status().opportunity_pending:
					check(a.choose_opportunity("read_inscription") == b.choose_opportunity("read_inscription"), "seeded midway choice reward reproduces")
			check(a.defeat_stage_monster(int(first.run_id), index) == b.defeat_stage_monster(int(second.run_id), index), "fixed adventure seed reproduces complete reward, run %d enemy %d" % [run_index, index])
		if not a.pending_opportunity.is_empty():
			check(a.choose_opportunity("read_inscription") == b.choose_opportunity("read_inscription"), "seeded opportunity choices reproduce")
	check(a._adventure_rng.state == b._adventure_rng.state and a.inventory == b.inventory, "seeded complete streams agree")
	check(a.gear.rng.state == legacy_a and b.gear.rng.state == legacy_b, "stages never invoke legacy monster/chest RNG")
	check(a.gear.starter_chest_unopened and b.gear.starter_chest_unopened, "direct stage equipment never consumes or fabricates the tutorial chest guarantee")
	check(a.save_game(), "adventure RNG checkpoint writes")
	var restored := state("_rng_a")
	restored.load_game()
	check(restored._adventure_rng.state == a._adventure_rng.state, "adventure RNG state roundtrips")
	for index in range(25):
		check(finish(a) == finish(restored), "post-reload random continuation exactly matches")
		if not a.pending_opportunity.is_empty():
			a.choose_opportunity("gather_gift")
			restored.choose_opportunity("gather_gift")


func _test_probabilities() -> void:
	var s := state()
	s._adventure_rng.seed = 82417567
	s.chest_count = 0
	var chest_rolls := 0
	var item_rolls := 0
	var simultaneous := 0
	var opportunities := 0
	var dry_routes := 0
	var rarities := {"common": 0, "uncommon": 0, "rare": 0, "epic": 0}
	const RUNS := 20000
	for run_index in range(RUNS):
		var started := s.start_stage()
		var any_special := false
		for index in range(3):
			if index == 2:
				var landmark := s.check_route_opportunity(int(started.run_id))
				if bool(landmark.opportunity_pending):
					opportunities += 1
					s.choose_opportunity("gather_gift")
			s.gear.inventory.clear()
			var reward := s.defeat_stage_monster(int(started.run_id), index)
			if bool(reward.chest_rolled):
				chest_rolls += 1
				any_special = true
			if bool(reward.equipment_rolled):
				item_rolls += 1
				any_special = true
				rarities[String(reward.item.rarity)] += 1
			if bool(reward.chest_rolled) and bool(reward.equipment_rolled):
				simultaneous += 1
		if not any_special:
			dry_routes += 1
	check(chest_rolls > 6700 and chest_rolls < 7700, "chest probability near independent 12 percent over 60000 kills")
	check(item_rolls > 1550 and item_rolls < 2050, "direct equipment probability near 3 percent, not legacy 35 percent")
	check(simultaneous > 150 and simultaneous < 285, "chest and equipment can both occur at independent joint 0.36 percent")
	check(opportunities > 3200 and opportunities < 4000, "mid-route opportunity probability near 18 percent")
	check(rarities.common > item_rolls * 0.54 and rarities.common < item_rolls * 0.66, "conditional common equipment near 60 percent")
	check(rarities.uncommon > item_rolls * 0.22 and rarities.uncommon < item_rolls * 0.34, "conditional uncommon equipment near 28 percent")
	check(rarities.rare > item_rolls * 0.065 and rarities.rare < item_rolls * 0.135 and rarities.rare < 250, "rare direct gear stays around 0.3 percent per kill")
	check(rarities.epic > 10 and rarities.epic < 70, "epic direct gear stays around 0.06 percent per kill")
	check(dry_routes > 10000 and chest_rolls < RUNS and s.chest_count == chest_rolls, "full routes can have no chest or item and no every-third-kill guarantee")
	check(s.total_victories == 60000 and s.stage_clears.bamboo_pass == RUNS, "trial counts finite and exact")
	print("ADVENTURE RNG: 60000 kills; chest=%d item=%d both=%d; rarities=%s; opportunities=%d/20000; no-special routes=%d" % [chest_rolls, item_rolls, simultaneous, rarities, opportunities, dry_routes])


func _test_opportunity_once_and_persistence() -> void:
	var s := state("_choice")
	check(not s.check_route_opportunity(1).ok, "idle checkpoint cannot fabricate route choices")
	for index in range(100):
		var landmark := reach_checkpoint(s)
		if bool(landmark.get("opportunity_pending", false)):
			break
		finish(s)
	var status := s.opportunity_status()
	check(not status.is_empty() and status.choices.size() == 2 and s.stage_run.kills == 2, "natural seeded midway landmark produces two no-cost choices before boss")
	if status.is_empty():
		return
	var run_id := int(s.stage_run.run_id)
	var pending := s.pending_opportunity.duplicate(true)
	var before := resources(s)
	var rng_before := s._adventure_rng.state
	for index in range(30):
		var landmark := s.check_route_opportunity(run_id)
		check(landmark.ok and landmark.reason == "already_checked" and landmark.opportunity == status, "repeated landmark calls return original awaiting choice")
	check(s.pending_opportunity == pending and resources(s) == before and s._adventure_rng.state == rng_before, "repeated checks neither reroll nor reward nor overwrite")
	check(not s.defeat_stage_monster(run_id, 2).ok and s.stage_clears.get("bamboo_pass", 0) == run_id - 1, "pending choice prevents boss resolution and route completion")
	check(not s.choose_opportunity("unknown").ok and resources(s) == before and s.pending_opportunity == pending, "unknown choice does not consume reward")
	s.step(State.OFFLINE_CAP_SECONDS)
	check(s.pending_opportunity == pending and s.stage_run.kills == 2 and s._adventure_rng.state == rng_before, "long idle does not timeout, choose, advance boss or reroll")
	check(s.save_game(), "unresolved midway choice can be saved")
	var restored := state("_choice")
	restored.load_game()
	check(restored.opportunity_status() == status and restored.stage_status().opportunity_pending and restored.stage_status().opportunity_checked and restored.stage_status().travel_checkpoint == 2, "saved before-boss choice reconstructs canonical rewards and checkpoint")
	check(restored.stage_status().paused and not restored.stage_status().active and not restored.check_route_opportunity(run_id).ok, "reload requires explicit route resume while preserving awaiting choice")
	check(restored.start_stage().ok and not restored.defeat_stage_monster(run_id, 2).ok, "explicit resume still waits for choice before boss")
	before = resources(restored)
	var reward := restored.choose_opportunity("gather_gift")
	check(reward.ok and restored.herbs == int(before[0]) + int(reward.rewards.herbs) and restored.dew == int(before[1]) + int(reward.rewards.dew), "first choice awards ordinary resources once")
	before = resources(restored)
	check(restored.pending_opportunity.is_empty() and not restored.choose_opportunity("gather_gift").ok and not restored.choose_opportunity("read_inscription").ok and resources(restored) == before, "choice cannot award both branches or be repeated")
	check(restored.save_game(), "resolved midway choice checkpoints")
	restored.load_game()
	restored.start_stage()
	rng_before = restored._adventure_rng.state
	check(not restored.check_route_opportunity(run_id).opportunity_pending and restored._adventure_rng.state == rng_before, "resolved landmark never rerolls after reload")
	var final_reward := restored.defeat_stage_monster(run_id, 2)
	check(final_reward.ok and final_reward.stage_finished and final_reward.opportunity.is_empty() and restored.pending_opportunity.is_empty(), "boss victory completes route without spawning post-completion choice")
	s.herbs = State.MAX_RESOURCE
	s.dew = State.MAX_RESOURCE
	check(not s.choose_opportunity("gather_gift").ok and s.pending_opportunity == pending, "full resource storage retains unresolved gift")
	var old_qi := s.qi
	reward = s.choose_opportunity("read_inscription")
	check(reward.ok and s.qi == old_qi + float(reward.rewards.qi), "alternate no-cost contemplation choice grants bounded qi")
	# Existing v4 post-clear choices have no live owner; preserve them without
	# letting them block or get overwritten by an unrelated new run.
	var legacy := state("_old_choice")
	var data := legacy._snapshot()
	data.adventure.pending_opportunity = pending.duplicate(true)
	data.adventure.stage_serial = run_id
	_write(legacy.save_path, data)
	legacy.load_game()
	check(legacy.opportunity_status() == status and not legacy.stage_status().opportunity_pending, "old-v4 post-clear choice remains selectable without blocking home")
	for index in range(30):
		var landmark := reach_checkpoint(legacy)
		check(landmark.ok and not landmark.opportunity_pending and landmark.opportunity.is_empty(), "unrelated legacy choice does not block new before-boss checkpoint")
		check(finish(legacy).stage_finished and legacy.pending_opportunity == pending, "unrelated run may finish without consuming or overwriting saved choice")
	check(legacy.choose_opportunity("gather_gift").ok and legacy.pending_opportunity.is_empty(), "legacy choice can still be explicitly collected once")


func _test_meridians_and_caps() -> void:
	var s := state("_meridians")
	var rows := s.meridian_rows()
	check(rows.slice(0, 6).map(func(r): return r.name) == ["气海", "关元", "神阙", "膻中", "百会", "涌泉"], "legacy six named acupoints retain progressive order among the branches")
	check(rows.slice(0, 6).map(func(r): return r.unlock_realm) == [0, 0, 1, 3, 6, 9], "legacy six meridian realm gates fixed")
	check(rows[0].unlocked and not rows[0].can_unlock and not rows[1].unlocked, "next point available but resources and prefix checked")
	check(not s.unlock_meridian("qihai").ok and not s.unlock_meridian("yongquan").ok and not s.unlock_meridian("unknown").ok, "unaffordable, skipped and unknown acupoints rejected")
	s.qi = 10000.0
	s.herbs = 1000
	s.dew = 1000
	var baseline := s.stats()
	for index in range(Content.LEGACY_ACUPOINT_IDS.size()):
		var point: Dictionary = Content.ACUPOINTS[index]
		if int(point.unlock_realm) > 0:
			s.realm = int(point.unlock_realm) - 1
			check(not s.unlock_meridian(String(point.id)).ok, "realm gate prevents premature opening " + String(point.id))
		s.realm = int(point.unlock_realm)
		var before := resources(s)
		var result := s.unlock_meridian(String(point.id))
		check(result.ok and s.meridian_count == index + 1, "next acupoint opens once: " + String(point.id))
		check(s.qi == float(before[2]) - float(point.cost_qi) and s.herbs == int(before[0]) - int(point.cost_herbs) and s.dew == int(before[1]) - int(point.cost_dew), "exact displayed meridian costs paid")
		before = resources(s)
		check(not s.unlock_meridian(String(point.id)).ok and resources(s) == before, "open acupoint never pays or awards twice")
	var bonuses := s.meridian_bonuses()
	check(is_equal_approx(float(bonuses.qi_rate), 0.13) and is_equal_approx(float(bonuses.gather), 0.12) and is_equal_approx(float(bonuses.brew), 0.12) and bonuses.attack == 4 and bonuses.defense == 3, "full meridian bonuses are modest and bounded")
	check(is_equal_approx(s.qi_rate(), float(State.QI_RATES[s.realm]) * 1.13) and is_equal_approx(s.gather_multiplier(), 1.12) and is_equal_approx(s.brew_multiplier(), 1.12), "qi gathering and brewing formulas consume real bonuses")
	check(s.stats().attack == int(baseline.attack) + 4 + s.realm * 2 and s.stats().defense == 3 + int(s.realm / 3.0), "real meridian and realm attack/defense bonuses are both exposed to combat")
	check(s.meridian_rows().slice(0, 6).all(func(r): return r.active and not r.can_unlock), "legacy six opened points stay capped without inventing branches")
	check(s.save_game(), "meridian checkpoint saves")
	var restored := state("_meridians")
	restored.load_game()
	check(restored.meridian_count == 6 and restored.meridian_bonuses() == bonuses, "all six acupoints roundtrip")
	var peaceful := state()
	peaceful.auto_advance = true
	peaceful.step(State.OFFLINE_CAP_SECONDS)
	peaceful.step(7200.0)
	check(peaceful.realm == State.MAX_REALM and peaceful.meridian_count == 0 and peaceful.stage_clears.is_empty(), "realm completion never requires combat or meridians")
	peaceful.merit = 5000.0
	peaceful.herbs = 500
	peaceful.dew = 500
	check(peaceful.unlock_meridian("qihai").ok and peaceful.merit == 4970.0 and peaceful.qi == 0.0, "postgame meridians use existing merit pool without creating invalid qi")
	check(peaceful._valid_save(peaceful._snapshot()), "postgame meridian payment preserves save invariant")


func _test_meridian_simulation_equivalence() -> void:
	for activity_id in ["meditate", "gather", "brew"]:
		var bulk := state()
		var split := state()
		for s in [bulk, split]:
			s.realm = 9
			s.meridian_count = 6
			s.herbs = 1000
			s.dew = 1000
			for method in ["petal", "ember", "stillness"]: s.technique_levels[method] = 3
			var selected := "petal" if activity_id == "gather" else ("ember" if activity_id == "brew" else "stillness")
			s.attune_technique(selected)
			if selected == "stillness": s.confirm_heart_switch(s.quote_heart_switch(selected))
			else: s.select_technique(selected)
			s.select_recipe("clarity")
			s.pill_stocks.spring = 1
			s.pill_stocks.clarity = 1
			s.use_pill("spring")
			s.use_pill("clarity")
			s.set_activity(activity_id)
		bulk.step(600.0)
		for tick in range(6000):
			split.step(0.1)
		check(bulk.herbs == split.herbs and bulk.dew == split.dew and bulk.pill_stocks == split.pill_stocks and is_equal_approx(bulk.qi, split.qi), "meridian, technique and expiring buffs preserve live/offline equivalence: " + activity_id)
		check(is_equal_approx(bulk._gather_clock, split._gather_clock) and is_equal_approx(bulk._dew_clock, split._dew_clock) and is_equal_approx(bulk._brew_clock, split._brew_clock), "fractional activity work is equivalent with meridians: " + activity_id)
		if activity_id == "meditate":
			check(is_equal_approx(bulk.qi, 8.8 * 1.37 * (300.0 * 1.35 + 300.0)), "meridian qi bonus stacks additively with selected technique then multiplies clarity buff")
		elif activity_id == "gather":
			check(bulk.herbs == 1138 and bulk.dew == 1046, "real meridian gather output reflects both speed and exact buff expiry")
		else:
			check(bulk.pill_stocks.clarity == 20 and bulk.herbs == 840 and bulk.dew == 940, "real meridian brewing increases completed pills without increasing per-pill costs")


func _test_save_migration() -> void:
	for version in [1, 2]:
		for old_realm in range(8):
			var s := state("_legacy_%d_%d" % [version, old_realm])
			var data := s._snapshot()
			data.version = version
			data.realm = old_realm
			data.qi = 0.0
			data.expedition_auto = true
			data.erase("adventure")
			_write(s.save_path, data)
			var report := s.load_game()
			check(report.loaded and report.migrated and s.realm == [0, 1, 2, 3, 6, 9, 12, 15][old_realm], "v%d old realm %d migrates exactly once" % [version, old_realm])
			check(not s.expedition_auto and s.meridian_count == 0 and s.stage_run.is_empty(), "legacy schema never invents adventures or meridians")
	for old_realm in range(16):
		var s := state("_v3_%d" % old_realm)
		s.open_chest()
		var owned := s.inventory.duplicate(true)
		var data := s._snapshot()
		data.version = 3
		data.realm = old_realm
		data.qi = 0.0
		data.expedition_auto = true
		data.erase("adventure")
		_write(s.save_path, data)
		var report := s.load_game()
		check(report.loaded and s.realm == old_realm and s.inventory == owned, "v3 expanded realm %d and owned gear never remap in v4" % old_realm)
		check(not s.expedition_auto and s._valid_save(s._snapshot()), "v3 upgrade disables automatic combat and writes valid v4")
		report = s.load_game()
		check(report.loaded and not report.get("migrated", false) and s.realm == old_realm, "reloading v4 does not remigrate v3 realm")


func _test_adventure_sanitization() -> void:
	var s := state("_malformed")
	var data := s._snapshot()
	data.realm = 1
	data.adventure = {"selected_stage": "unknown", "stage_serial": -2, "stage_run": {"id": "cloud_slope", "run_id": 1, "kills": 0},
		"stage_clears": {"bamboo_pass": -3, "creek_bridge": 1.5, "cloud_slope": "many", "unknown": 999},
		"pending_opportunity": {"id": "quiet_cairn", "stage_id": "unknown", "run_id": 1},
		"meridian_count": 9999999, "rng_seed": [], "rng_state": "not a number"}
	_write(s.save_path, data)
	var report := s.load_game()
	check(report.loaded and s.realm == 1 and s.selected_stage == "bamboo_pass", "malformed optional adventure preserves valid character")
	check(s.stage_run.is_empty() and s.stage_clears.is_empty() and s.pending_opportunity.is_empty(), "invalid routes counts and choices are discarded independently")
	check(s.meridian_count == 3, "malformed maximum count cannot bypass realm gates")
	for bad in [1.5, "6", true, [], {}, null]:
		data = s._snapshot()
		data.adventure.erase("meridian_nodes")
		data.adventure.erase("meridian_revision")
		data.adventure.meridian_count = bad
		data.adventure.stage_run = {"id": "bamboo_pass", "run_id": 1, "kills": bad}
		_write(s.save_path, data)
		report = s.load_game()
		check(report.loaded and s.meridian_count == 0 and s.stage_run.is_empty(), "wrong-type adventure integers safely fall back")
	data = s._snapshot()
	data.adventure.stage_run = {"id": "bamboo_pass", "run_id": 42, "kills": 3}
	data.adventure.pending_opportunity = {"id": "quiet_cairn", "stage_id": "bamboo_pass", "run_id": 19, "choices": [{"rewards": {"qi": 1.0e30}}]}
	_write(s.save_path, data)
	s.load_game()
	check(s.stage_run.is_empty() and s.opportunity_status().choices[1].rewards.qi == 40.0, "completed runs cannot replay and saved choice reward injection ignored")
	data = s._snapshot()
	data.adventure.stage_run = {"id": "creek_bridge", "run_id": 42, "kills": 1, "hp": 999999999}
	data.adventure.stage_serial = 0
	_write(s.save_path, data)
	s.load_game()
	check(s.stage_status().paused and s.stage_run.run_id == 42 and s._stage_serial == 42 and s.stage_status().next_monster.hp == Content.STAGES.creek_bridge.monsters[1].hp, "canonical partial run retains token and regenerates monster stats")
	data = s._snapshot()
	data.adventure.pending_opportunity = {}
	data.adventure.stage_run = {"id": "bamboo_pass", "run_id": 42, "kills": 2, "travel_checkpoint": 999, "opportunity_checked": "yes"}
	_write(s.save_path, data)
	s.load_game()
	check(s.stage_status().travel_checkpoint == 2 and not s.stage_status().opportunity_checked, "travel checkpoints derive from paid kills and wrong-type checked flags are rejected")
	s.start_stage()
	check(s.defeat_stage_monster(42, 2).reason == "route_checkpoint_required", "malformed optional marker cannot bypass before-boss check")
	data = s._snapshot()
	data.adventure.stage_run.erase("opportunity_checked")
	data.adventure.pending_opportunity = {"id": "quiet_cairn", "stage_id": "bamboo_pass", "run_id": 42}
	_write(s.save_path, data)
	s.load_game()
	check(s.stage_status().opportunity_pending and s.stage_status().opportunity_checked, "pre-marker v4 midway choice restores as already checked rather than rerolling")
	s.start_stage()
	var checkpoint_rng := s._adventure_rng.state
	check(s.check_route_opportunity(42).opportunity_pending and s._adventure_rng.state == checkpoint_rng, "restored markerless awaiting choice never consumes a fresh RNG roll")
	data = s._snapshot()
	data.erase("adventure")
	_write(s.save_path, data)
	s.load_game()
	check(s.stage_run.is_empty() and s.pending_opportunity.is_empty() and s.meridian_count == 0, "repeated load resets missing optional adventure data")
	check(s.reset_save() and s.stage_run.is_empty() and s.pending_opportunity.is_empty() and s.stage_clears.is_empty() and s.meridian_count == 0, "explicit reset clears every adventure section")


func _test_resource_capacity() -> void:
	var s := state()
	s.herbs = State.MAX_RESOURCE
	s.dew = State.MAX_RESOURCE
	s.qi = State.MAX_ENERGY
	s.chest_count = Ledger.MAX_CHESTS
	for index in range(Ledger.CAPACITY):
		s.gear.inventory.append(s.gear._make_item(index + 1, "head_pin", "common", 1))
	s.gear.equip_item(1)
	var worn := s.equipped.duplicate(true)
	var equipment_overflow := false
	var chest_overflow := false
	for run_index in range(250):
		var started := s.start_stage()
		for index in range(3):
			if index == 2:
				var landmark := s.check_route_opportunity(int(started.run_id))
				if bool(landmark.opportunity_pending):
					s.qi = State.MAX_ENERGY - 1000.0
					s.choose_opportunity("read_inscription")
					s.qi = State.MAX_ENERGY
			var result := s.defeat_stage_monster(int(started.run_id), index)
			check(result.herbs == 0 and result.dew == 0 and result.qi == 0.0 and result.chests == 0, "capped resource awards report only actual gains")
			if bool(result.equipment_rolled):
				equipment_overflow = bool(result.overflow) and result.item == null and result.resource_overflow.herbs == 4
			if bool(result.chest_rolled):
				chest_overflow = result.chest_overflow == 1
	check(equipment_overflow and chest_overflow, "item and chest capacity paths report separate overflows")
	check(s.inventory.size() == Ledger.CAPACITY and s.equipped == worn and s.gear.get_item(1).template_id == "head_pin", "full-bag stage drops never evict or overwrite owned gear")
	check(s._valid_save(s._snapshot()), "saturated adventure remains saveable")


func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		check(false, "isolated adventure test save writable")
		return
	file.store_string(JSON.stringify(data))
	file.close()


func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with(prefix.trim_prefix("user://")):
			directory.remove(filename)
