extends RefCounted
## Fresh-player economic proof. Only RNG seeds and an isolated save path are assigned.
## All progress comes from paid production State actions and actual native-stat duels.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Geometry = preload("res://tests/campaign_build_plan.gd")
const DT := 1.0 / 60.0
const DRY_SEED := 24
var state = State.new()
var checks := 0
var errors: Array[String] = []
var ledger: Array = []
var battles: Array = []
var milestones: Dictionary = {}
var earned_checkpoints: Array = []
var rng_rewards := {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0}
var fan_id := -1
var battle_seconds := 0.0
var search_seconds := 0.0
var travel_seconds := 0.0
var initial: Dictionary

func _init() -> void:
	state._adventure_rng.seed = DRY_SEED
	state.gear.rng.seed = 110
	state.save_path = "user://test_complete_player_journey_%d.json" % OS.get_process_id()
	initial = resources()

func check(value: bool, label: String) -> bool:
	checks += 1
	if not value:
		errors.append(label)
		push_error("FRESH JOURNEY: " + label)
	return value

func resources() -> Dictionary:
	return {"seconds": state.lifetime_seconds, "realm": state.realm, "qi": state.qi,
		"herbs": state.herbs, "dew": state.dew, "merit": state.merit,
		"materials": state.materials.to_dict(), "inventory": state.inventory.duplicate(true),
		"equipped": state.equipped.duplicate(), "victories": state.total_victories,
		"clears": state.stage_clears.duplicate(), "claims": state.chapter_reward_claimed.duplicate(),
		"quests": state.quest_claimed.duplicate(), "counters": state.counters.duplicate(),
		"techniques": state.technique_levels.duplicate(), "meridians": state.meridian_opened.duplicate(),
		"auto": state.auto_advance, "chests": state.chest_count}

func record(action: String, before: Dictionary, detail: Dictionary = {}) -> void:
	ledger.append({"action": action, "before": before, "after": resources(), "detail": detail.duplicate(true)})

func wait_for(seconds: float, label: String) -> void:
	var before := resources()
	var realm: int = state.realm
	state.step(seconds)
	check(state.realm == realm, "waiting never performs a breakthrough: " + label)
	record(label, before, {"requested_seconds": seconds})

func claim_ready() -> void:
	for row in state.quest_rows():
		if not row.ready: continue
		var before := resources()
		var result: Dictionary = state.claim_quest(str(row.id))
		check(bool(result.get("ok", false)), "claim an actually earned optional quest: " + str(row.id))
		record("claim_quest:" + str(row.id), before, result)
	# Sequential claims are re-read, so a just-opened earned quest can be claimed.
	for row in state.quest_rows():
		if row.ready:
			claim_ready()
			break

func study(id: String, target: int) -> bool:
	while int(state.technique_levels.get(id, 0)) < target:
		var before := resources()
		var result: Dictionary = state.upgrade_technique(id)
		if not check(bool(result.get("ok", false)), "afford deliberately selected study " + id + ": " + str(result)): return false
		var cost: Dictionary = result.cost
		check(state.herbs == int(before.herbs) - int(cost.herbs) and state.dew == int(before.dew) - int(cost.dew), "study pays exact published grass/dew")
		check(int(state.technique_levels[id]) == int(before.techniques[id]), "paying for study does not instantly grant its rank")
		record("begin_study:" + id, before, result)
		verify_guide_readonly("paid_pending_study:" + id)
		wait_for(float(result.duration) - .01, "study_timer:" + id)
		check(int(state.technique_levels[id]) == int(before.techniques[id]), "rank stays pending until full study timer")
		wait_for(.01, "finish_study:" + id)
		if not check(int(state.technique_levels[id]) == int(before.techniques[id]) + 1, "study completes exactly one rank"): return false
	return true

func break_to(target: int) -> bool:
	while state.realm < target:
		var before := resources()
		var need_qi: float = Content.QI_COSTS[state.realm]
		var need_herbs: int = Content.HERB_COSTS[state.realm]
		if not check(state.qi + .000001 >= need_qi and state.herbs >= need_herbs,
			"earned budget funds explicit realm " + str(state.realm + 1) + ": " + str([state.qi, state.herbs, need_qi, need_herbs])): return false
		if not check(state.breakthrough(), "manual breakthrough succeeds"): return false
		check(state.realm == int(before.realm) + 1 and state.herbs == int(before.herbs) - need_herbs,
			"one click pays herbs and advances exactly one of sixteen stages")
		if state.realm < 15: check(absf(state.qi - (float(before.qi) - need_qi)) < .00001, "one click pays exact qi")
		record("manual_breakthrough", before, {"qi_cost": need_qi, "herb_cost": need_herbs})
	return true

func craft(id: String, material: String = "", equip: bool = false) -> bool:
	var before := resources()
	var quote: Dictionary = state.crafting_quote(id, material)
	var result: Dictionary = state.craft_recipe(id, material)
	if not check(bool(result.get("ok", false)), "earned material budget crafts " + id + ": " + str(quote)): return false
	check(state.equipped == before.equipped, "crafting never silently equips")
	check(result.costs == quote.materials, "craft pays quoted material costs")
	record("craft:" + id, before, result)
	if equip:
		before = resources()
		check(state.equip_item(int(result.item.id)), "explicitly equip crafted " + id)
		record("equip_crafted:" + id, before, {"item": result.item})
		if id == "bind_cloud_fan": fan_id = int(result.item.id)
	return true

func enhance(id: int, method: String) -> bool:
	var before := resources()
	var quote: Dictionary = state.enhancement_quote(id, method)
	var result: Dictionary = state.enhance_item(id, method)
	if not check(bool(result.get("ok", false)), "earned budget enhances owned item: " + str(quote)): return false
	check(int(state.gear.get_item(id).enhancement) == int(quote.from_rank) + 1, "enhancement increments original owned item once")
	record("enhance:" + method, before, {"quote": quote, "result": result})
	return true

func prepare_intro() -> bool:
	check(state.realm == 0 and state.qi == 0 and state.herbs == 3 and state.dew == 1 and state.chest_count == 1
		and state.inventory.is_empty() and state.total_victories == 0 and state.materials.inventory.is_empty(), "genuine new game, no injected progress")
	if not check(not state.auto_advance, "new players choose their own first breakthrough"): return false
	var before := resources()
	var chest: Dictionary = state.open_chest()
	check(chest.get("ok", false) and chest.get("starter", false) and chest.item != null, "real guaranteed starter chest opens")
	check(state.equipped.is_empty(), "starter chest never auto-equips")
	check(state.equip_item(int(chest.item.id)), "starter common item is explicitly equipped")
	record("starter_chest_and_equip", before, chest)
	var heart: Dictionary = state.quote_heart_switch("breath")
	check(heart.get("ok", false) and heart.first_choice and float(heart.duration) == 0, "first learned heart has a transparent free choice")
	check(state.confirm_heart_switch(heart).get("ok", false), "explicitly equip learned breath heart")
	state.set_activity("gather")
	wait_for(24.0, "first_gather")
	check(state.herbs == 6 and state.dew == 2, "24 seconds yields precisely the first study budget")
	state.set_activity("meditate")
	milestones.first_study_started = state.lifetime_seconds
	if not study("mist", 2): return false
	milestones.first_study_finished = state.lifetime_seconds
	wait_for(60.0 - state.lifetime_seconds, "first_minute_meditation")
	claim_ready()
	var stats: Dictionary = state.stats()
	wait_for(maxf(0.0, (float(stats.need_qi) - state.qi) / float(stats.qi_rate)), "first_breakthrough_preparation")
	if not break_to(1): return false
	milestones.first_breakthrough = state.lifetime_seconds
	claim_ready()
	before = resources()
	var point: Dictionary = state.unlock_meridian("qihai")
	if not check(point.get("ok", false), "earned first-quest qi/herbs fund one modest meridian"): return false
	record("open_meridian:qihai", before, point)
	check(state.meridian_count == 1, "intro chooses one meridian rather than buying all branches")
	return errors.is_empty()

func prepare_after_chapter(chapter: int) -> bool:
	claim_ready()
	match chapter:
		0:
			# Seven bamboo fibers make one stone plus a shirt; keep all shards for the later fan.
			if not craft("refine_route", "moss_fiber") or not craft("weave_armor", "", true): return false
			check(state.material_count("moss_fiber") == 1 and state.material_count("spirit_shard") == 3, "first crafting leaves the future fan shards intact")
			var before := resources()
			state.select_recipe("qi"); state.set_activity("brew")
			wait_for(20.0 / state.brew_multiplier(), "first_brew_timer")
			check(state.pills == 1 and state.counters.brewed == 1, "first real brew pays ingredients and produces one pill")
			check(state.use_pill("qi"), "explicitly use the first pill")
			record("brew_and_use_pill", before)
			state.set_activity("meditate")
			claim_ready()
			if not enhance(int(state.equipped.weapon), "herbs"): return false
			if not study("mist", 3) or not study("barrier", 1): return false
		1:
			if not break_to(3): return false
			if not craft("refine_route", "river_ore") or not craft("carve_river_pin", "", true): return false
			if not study("breath", 2) or not study("mist", 4) or not study("body", 1): return false
			check(state.equip_technique("body", "passive").get("ok", false), "equip learned passive after its real capacity opens")
			check(state.equip_technique("barrier", "active").get("ok", false), "second active capacity opens at foundation")
		2:
			if not break_to(6): return false
			if not study("petal", 1) or not study("barrier", 2) or not study("body", 2): return false
			if not craft("refine_stone") or not craft("refine_stone") or not craft("bind_cloud_fan", "", true): return false
			if not craft("refine_stone") or not enhance(fan_id, "materials"): return false
			check(state.material_count("spirit_shard") == 0 and state.material_count("cloud_feather") == 3, "one pass through three chapters funds fan and +1 with no farming")
			check(state.unequip_technique("mist", "active").get("ok", false), "remove old sword active explicitly")
			check(state.equip_technique("petal", "weapon_art").get("ok", false) and state.equip_technique("petal", "active").get("ok", false), "equip paid petal form and active on the crafted fan")
			milestones.crafted_fan = state.lifetime_seconds
		3:
			if not break_to(9): return false
			if not study("petal", 2) or not study("body", 3) or not study("barrier", 3): return false
		4:
			if not break_to(12): return false
			if not study("petal", 3) or not study("body", 4) or not study("barrier", 4): return false
			if not craft("refine_stone") or not craft("refine_stone") or not craft("refine_route", "ember_cinder") or not craft("weave_moon_robe", "", true): return false
		5:
			if not break_to(15): return false
	return errors.is_empty()

func rest(run_id: int, seconds: float) -> void:
	var stats: Dictionary = state.stats()
	state.update_stage_battle_resources(run_id, Duel.rest_resource_snapshot(state.stage_battle_resources(), seconds,
		float(stats.combat_qi_max), float(stats.combat_qi_regen)))
	state.step(seconds)

func run_stage(route: String, equip_first_clear: bool = true) -> bool:
	var before := resources()
	if not check(state.select_stage(route), "manually select earned chapter " + route): return false
	var started: Dictionary = state.start_stage()
	if not check(started.get("ok", false), "manually depart " + route): return false
	var run_id := int(started.run_id)
	var health := int(state.stats().max_hp)
	var start_realm: int = state.realm
	for index in range(3):
		if index == 2:
			var chance: Dictionary = state.check_route_opportunity(run_id)
			if chance.get("opportunity_pending", false):
				rng_rewards.opportunities += 1
				check(false, "six-chapter seed requires no lucky opportunities")
				return false
		var hero: Dictionary = state.stats().duplicate(true)
		hero.hp = health; hero.battle_resources = state.stage_battle_resources()
		var enemy: Dictionary = Geometry.prepare_enemy(state.stage_status().next_monster, route)
		for field in Content.STAGES[route].monsters[index]:
			check(enemy[field] == Content.STAGES[route].monsters[index][field], "prepared duel preserves authored enemy " + str(field))
		var duel := Duel.new()
		duel.start(hero, enemy, state.technique, str(state.gear.visual_loadout().get("weapon", "")), run_id * 1337 + index * 79 + 17)
		check(duel.enemy_hp == int(enemy.hp) and duel.hero_hp == health, "native full enemy vitality and genuinely carried hero HP enter battle")
		var events: Array = []
		while not duel.finished and duel.elapsed < 180.0:
			events.append_array(duel.advance(DT)); state.step(DT); battle_seconds += DT
		var summary := {"route": route, "index": index, "enemy_hp": enemy.hp, "enemy_attack": enemy.attack, "enemy_defense": enemy.defense,
			"hero": hero, "seconds": duel.elapsed, "hp_end": duel.hero_hp, "victory": duel.victory,
			"fan_contacts": events.filter(func(e): return str(e.get("type", "")) == "contact" and str(e.get("actor", "")) == "hero" and str(e.get("basic_style", "")) == "fan").size()}
		battles.append(summary)
		print("FRESH_DUEL %s/%d %.3fs hp=%d victory=%s" % [route, index, duel.elapsed, duel.hero_hp, duel.victory])
		if not check(duel.finished and duel.victory, "actual modest earned build wins " + route + "/" + str(index)): return false
		check(state.realm == start_realm, "even chapter rewards never silently change the realm in battle")
		state.update_stage_battle_resources(run_id, duel.battle_resource_snapshot()); health = duel.hero_hp
		var paid_before := resources()
		check(state.begin_stage_corpse(run_id, index).get("ok", false), "real victory creates pending loot")
		check(state.total_victories == int(paid_before.victories) and state.materials.to_dict() == paid_before.materials, "death alone grants no loot")
		for tick in range(119):
			state.advance_stage_search(run_id, index, DT); rest(run_id, DT); search_seconds += DT
		check(not state.complete_stage_search(run_id, index).get("ok", false), "search cannot pay before two seconds")
		state.advance_stage_search(run_id, index, DT); rest(run_id, DT); search_seconds += DT
		var reward: Dictionary = state.complete_stage_search(run_id, index)
		if not check(reward.get("ok", false), "completed real search pays exactly once"): return false
		for pair in [["chest_rolled", "chests"], ["equipment_rolled", "equipment"], ["treasure_rolled", "treasure"]]:
			if reward.get(pair[0], false): rng_rewards[pair[1]] += 1
		record("search_reward:" + route + "/" + str(index), paid_before, reward)
		var paid := resources()
		check(not state.complete_stage_search(run_id, index).get("ok", false) and resources() == paid, "duplicate search cannot create resources")
		if index < 2:
			rest(run_id, 9.0); travel_seconds += 9.0
		else:
			check(reward.get("first_clear", false) and reward.get("chapter_reward", {}).get("ok", false), "earned first-clear package arrives once")
			check(not state.claim_chapter_reward(route).get("ok", false) and resources() == paid, "first-clear package is idempotent")
			var item: Dictionary = reward.chapter_reward.item
			# Final trophy is owned; keep the trained crafted fan for the player's chosen build.
			if equip_first_clear and route != "summit_gate": check(state.equip_item(int(item.id)), "explicitly equip earned first-clear item")
	check(state.realm == start_realm and not state.stage_status().active and state.stage_run.is_empty(), "route returns home without breakthrough or next departure")
	milestones[route + "_clear"] = state.lifetime_seconds
	record("chapter_complete:" + route, before)
	earned_checkpoints.append(state._snapshot().duplicate(true))
	return errors.is_empty()

func report() -> Dictionary:
	var metadata: Dictionary = Geometry.measurement_metadata()
	for path in ["tests/complete_player_journey_plan.gd", "tests/test_complete_player_journey.gd", "tests/test_guided_player_journey.gd"]:
		metadata.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	return {"schema": 1, "method": "Fresh production State; published paid actions; deterministic seeds only; manual individual breakthroughs; real 60fps native-stat duels and corpse search. Not a native UI proof.",
		"timing_scope": "Simulation seconds include explicit study, brewing, meditation, gathering, combat, two-second searches and nine-second between-enemy travel; exclude player reading/clicks, outbound travel and portals.",
		"checks": checks, "errors": errors, "initial": initial, "final": resources(), "milestones": milestones,
		"random_rewards": rng_rewards, "seed": DRY_SEED, "battles": battles, "ledger": ledger,
		"durations": {"battle": battle_seconds, "search": search_seconds, "between_enemy_travel": travel_seconds, "total": state.lifetime_seconds},
		"source": metadata}

func verify_guide_readonly(label: String) -> void:
	var before := resources()
	var random_before := [state._adventure_rng.state, state.gear.rng.state]
	var goal: Dictionary = state.player_journey_status()
	for repeat in range(3):
		check(state.player_journey_status() == goal, "derived guide is stable: " + label)
		check(state.player_journey_rows().size() == 8, "all eight journey phases remain inspectable")
	check(not str(goal.get("id", "")).is_empty() and not str(goal.get("action", "")).is_empty(), "every current guide step has a concrete action")
	check(resources() == before and [state._adventure_rng.state, state.gear.rng.state] == random_before,
		"reading guidance never grants or consumes resources: " + label)

func follow_default_guidance() -> bool:
	if not check(not state.auto_advance and state.lifetime_seconds == 0 and state.inventory.is_empty(), "guided proof also starts genuinely fresh"): return false
	var previous := ""
	for attempt in range(4000):
		var goal: Dictionary = state.player_journey_status()
		var key := str(goal.id) + ":" + str(goal.target)
		if previous != key:
			verify_guide_readonly(key)
			ledger.append({"action": "read_guidance", "goal": goal.duplicate(true), "at": resources()})
			previous = key
		match str(goal.kind):
			"gather", "meditate":
				state.set_activity(str(goal.kind)); state.step(1.0)
			"equipment":
				if str(goal.target).is_empty():
					if state.inventory.is_empty():
						check(state.open_chest().get("ok", false), "guided player opens actual starter chest")
					if state.inventory.is_empty(): return check(false, "guide cannot equip an absent item")
					check(state.equip_item(int(state.inventory[0].id)), "guided player equips existing starter")
				else: check(state.equip_item(int(str(goal.target))), "guided player equips specifically recommended owned item")
			"technique":
				var id := str(goal.target)
				if str(goal.id).begins_with("training_"): state.step(1.0)
				elif str(goal.id) == "first_heart": check(state.confirm_heart_switch(state.quote_heart_switch(id)).get("ok", false), "guided first heart uses real quote and confirmation")
				elif str(goal.id) == "prepare_support": check(state.equip_technique(id, "active").get("ok", false), "guided support actively equipped")
				elif str(goal.id) == "fan_form": check(state.equip_technique(id, "weapon_art").get("ok", false), "guided fan form explicitly equipped")
				elif not study(id, int(state.technique_levels.get(id, 0)) + 1): return false
			"meridian":
				if not check(state.unlock_meridian(str(goal.target)).get("ok", false), "guided modest meridian is affordable"): return false
			"practice":
				if not break_to(state.realm + 1): return false
			"quest":
				if not check(state.claim_quest(str(goal.target)).get("ok", false), "guided reward is genuinely earned"): return false
			"crafting":
				var parts := str(goal.target).split(":")
				if not craft(parts[0], parts[1] if parts.size() > 1 else ""): return false
			"route":
				if not run_stage(str(goal.target), false): return false
			"ending": check(state.complete_home_epilogue().get("ok", false), "guided ending is explicitly written")
			"longterm": break
			_: return check(false, "unsupported current guidance action: " + str(goal))
		if not errors.is_empty(): return false
	check(state.chapter_status().ending_complete and state.total_victories == 18 and state.realm == 15,
		"default recommendations alone reach finite first-volume ending without extra build decisions")
	check(rng_rewards == {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0}, "guided route also never depends on random rewards")
	check(not state.auto_advance and state.meridian_count == 1, "guided route retains manual progression and one selected meridian")
	verify_guide_readonly("completed_first_volume")
	return errors.is_empty()
