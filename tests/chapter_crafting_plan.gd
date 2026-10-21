extends RefCounted
## Reusable earned checkpoint, with no inventory, level, victory or currency fixtures.
## Only the deterministic random seeds and isolated save destination are assigned.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
const DT := 1.0 / 60.0
# Legacy seed 61 is dry only in the obsolete two-draw reward adapter.
# The durable corpse path independently rolls treasure too; seed 15 is verified
# dry by the actual first four routes below, never by mutating a pending reward.
const DRY_SEED := 15
const NATIVE_STATS := {
	"bamboo_pass": [[90, 2, 0], [105, 2, 0], [220, 2, 0]],
	"creek_bridge": [[190, 3, 1], [210, 4, 1], [500, 3, 1]],
	"cloud_slope": [[240, 8, 2], [245, 9, 2], [450, 9, 2]],
	"ember_ruins": [[250, 12, 4], [290, 13, 4], [625, 12, 5]],
}
var state = State.new()
var checks := 0
var errors: Array[String] = []
var records: Array = []
var preparation: Array = []
var battle_seconds := 0.0
var search_seconds := 0.0
var travel_seconds := 0.0
var first_three_seconds := 0.0
var prepared_seconds := 0.0
var chances := {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0}
var initial: Dictionary = {}
var petal_study: Dictionary = {}

func _init() -> void:
	state.auto_advance = true # The v1.3.7 earned benchmark explicitly chose quiet auto progression.
	state._adventure_rng.seed = DRY_SEED
	state.gear.rng.seed = 110
	initial = resources()

func check(condition: bool, label: String) -> bool:
	checks += 1
	if not condition:
		errors.append(label)
		push_error("CHAPTER CRAFTING: " + label)
	return condition

func resources() -> Dictionary:
	return {"seconds": state.lifetime_seconds, "realm": state.realm, "qi": state.qi,
		"herbs": state.herbs, "dew": state.dew, "merit": state.merit,
		"materials": state.materials.to_dict(), "inventory": state.inventory.duplicate(true),
		"equipped": state.equipped.duplicate(), "victories": state.total_victories,
		"stage_clears": state.stage_clears.duplicate(), "claims": state.chapter_reward_claimed.duplicate(),
		"chests": state.chest_count, "counters": state.counters.duplicate(),
		"adventure_rng": state._adventure_rng.state, "gear_rng": state.gear.rng.state}

func configure(chapter: int) -> void:
	var before := resources()
	var loadout: Dictionary = Plan.configure(state, "sword", chapter)
	Plan.buy_affordable_meridians(state)
	preparation.append({"chapter": chapter, "before": before, "after": resources(), "loadout": loadout})

func prepare() -> bool:
	check(state.realm == 0 and state.inventory.is_empty() and state.materials.inventory.is_empty()
		and state.total_victories == 0 and state.stage_clears.is_empty()
		and state.herbs == 3 and state.dew == 1 and state.chest_count == 1, "starts with only the genuine new-game state")
	configure(0)
	for chapter in range(3):
		if not run_stage(String(Content.CHAPTER_ORDER[chapter])): return false
		state.step(0.1)
		if chapter < 2: configure(chapter + 1)
	first_three_seconds = state.lifetime_seconds
	check(state.total_victories == 9 and state.stage_clears == {"bamboo_pass": 1, "creek_bridge": 1, "cloud_slope": 1},
		"exactly nine real victories and one clear of each first chapter, without replay")
	check(state.inventory.size() == 3 and state.chest_count == 1 and int(state.counters.chests_opened) == 0,
		"only three deterministic first-clear items; opener chest is unopened")
	check(chances == {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0},
		"durable seed 15 grants no lucky gear, treasure, chests or opportunities")
	check(state.material_count("spirit_shard") == 9 and state.material_count("cloud_feather") == 7
		and state.material_count("moss_fiber") == 7 and state.material_count("river_ore") == 7,
		"nine searched bodies supply the exact ordinary material budget")
	# Reserve the modest paid fan-manual study before optional later build spending.
	# A full attunement bookcase is managed through the real, reversible UI API.
	var petal: Dictionary = Plan.row(state, "petal")
	if not state.attuned_techniques.has("petal") and state.attuned_techniques.size() >= state.attunement_capacity():
		for id in state.attuned_techniques.duplicate():
			if state.equipped_technique_slots(str(id)).is_empty():
				state.unattune_technique(str(id))
				break
	petal = Plan.row(state, "petal")
	if not check(bool(petal.can_upgrade), "ordinary first-clear earnings immediately afford petal study: " + str(petal.locked_reason)): return false
	var before := resources()
	var study: Dictionary = state.upgrade_technique("petal")
	if not check(bool(study.get("ok", false)), "petal starts a real paid study"): return false
	check(state.herbs == int(before.herbs) - int(study.cost.herbs)
		and state.dew == int(before.dew) - int(study.cost.dew)
		and int(state.technique_levels.petal) == 0, "petal charges its published costs before awarding a level")
	var duration := float(study.duration)
	for tick in range(roundi(duration / DT) - 1): state.step(DT)
	check(int(state.technique_levels.petal) == 0, "petal is not learned before the genuine timer expires")
	state.step(DT)
	check(int(state.technique_levels.petal) == 1 and state.technique_training.is_empty(),
		"paid petal study finishes at the real timer boundary")
	petal_study = {"before": before, "cost": study.cost, "duration": duration, "after": resources()}
	configure(3)
	check(state.realm >= 6, "ordinary paid automatic breakthroughs reach the next chapter gate")
	check(state.inventory.size() == 3 and state.material_count("refinement_stone") == 0
		and state.material_count("spirit_shard") == 9 and state.material_count("cloud_feather") == 7,
		"checkpoint is before any crafting and preserves all earned recipe inputs")
	check(not state.stage_status().active and state.stage_run.is_empty() and not state.expedition_auto,
		"returned home and next adventure remains a manual choice")
	check(state.select_stage("ember_ruins"), "earned route gates allow selecting the next chapter without starting it")
	prepared_seconds = state.lifetime_seconds
	return errors.is_empty()

func rest(run_id: int, seconds: float) -> void:
	for tick in range(roundi(seconds / DT)):
		var stats: Dictionary = state.stats()
		state.update_stage_battle_resources(run_id, Duel.rest_resource_snapshot(state.stage_battle_resources(), DT,
			float(stats.combat_qi_max), float(stats.combat_qi_regen)))
		state.step(DT)

func event_counts(events: Array) -> Dictionary:
	var counts := {"hero_turns": 0, "enemy_turns": 0, "hero_damage": 0, "enemy_damage": 0,
		"fan_basic_turns": 0, "fan_basic_contacts": 0, "fan_basic_damage": 0,
		"fan_weapon_turns": 0, "fan_weapon_contacts": 0, "fan_weapon_damage": 0,
		"petal_turns": 0, "petal_contacts": 0, "petal_damage": 0, "hero_melee_geometry_contacts": 0}
	for event in events:
		var hero := str(event.get("actor", "")) == "hero"
		var kind := str(event.get("type", ""))
		var action := str(event.get("action_kind", ""))
		var skill := str(event.get("skill_id", ""))
		var category := ""
		if hero and action == "basic" and str(event.get("basic_style", "")) == "fan": category = "fan_basic"
		elif hero and skill == "weapon_fan_return": category = "fan_weapon"
		elif hero and skill == "petal": category = "petal"
		if kind == "turn_started":
			counts["hero_turns" if hero else "enemy_turns"] += 1
			if not category.is_empty(): counts[category + "_turns"] += 1
		if kind == "contact":
			counts["hero_damage" if hero else "enemy_damage"] += int(event.get("damage", 0))
			if not category.is_empty():
				counts[category + "_contacts"] += 1
				counts[category + "_damage"] += int(event.get("damage", 0))
			if hero and bool(event.get("melee_contact", {}).get("contact", false)): counts.hero_melee_geometry_contacts += 1
	return counts

func run_stage(route: String) -> bool:
	if not check(state.select_stage(route), "earned gate selects " + route): return false
	var started: Dictionary = state.start_stage()
	if not check(bool(started.get("ok", false)), "manual departure starts " + route): return false
	var run_id := int(started.run_id)
	var health := int(state.stats().max_hp)
	for index in range(3):
		if index == 2:
			var opportunity: Dictionary = state.check_route_opportunity(run_id)
			if bool(opportunity.get("opportunity_pending", false)):
				chances.opportunities += 1
				check(false, "dry seed 15 must not need an opportunity reward")
				return false
		var hero: Dictionary = state.stats().duplicate(true)
		hero.hp = health
		hero.battle_resources = state.stage_battle_resources()
		var definition: Dictionary = Content.STAGES[route].monsters[index].duplicate(true)
		var enemy: Dictionary = Plan.prepare_enemy(state.stage_status().next_monster, route)
		var expected: Array = NATIVE_STATS[route][index]
		check([int(enemy.hp), int(enemy.attack), int(enemy.defense)] == expected,
			"original native HP/attack/defense, unchanged: %s/%d" % [route, index])
		for field in definition: check(enemy[field] == definition[field], "prepared enemy retains " + str(field))
		var seed_value := run_id * 1337 + index * 79 + 17
		var duel := Duel.new()
		duel.start(hero, enemy, state.technique, str(state.gear.visual_loadout().get("weapon", "")), seed_value)
		var initial_battle: Dictionary = duel.battle_resource_snapshot()
		check(duel.hero_hp == health and duel.enemy_hp == int(enemy.hp), "real remaining route HP and full native enemy HP enter duel")
		check(absf(float(initial_battle.qi) - float(hero.battle_resources.qi)) < 0.0001,
			"duel begins with persisted actual combat qi")
		var cooldowns_match := true
		for id in hero.battle_resources.cooldowns:
			if absf(float(initial_battle.cooldowns.get(id, 0.0)) - float(hero.battle_resources.cooldowns[id])) >= 0.0001:
				cooldowns_match = false
		check(cooldowns_match, "duel begins with persisted skill cooldowns")
		var events: Array = []
		while not duel.finished and duel.elapsed < 180.0:
			events.append_array(duel.advance(DT))
			state.step(DT)
			battle_seconds += DT
		var counts := event_counts(events)
		var record := {"stage": route, "index": index, "seed": seed_value, "enemy": enemy,
			"hero": hero, "seconds": duel.elapsed, "hp_end": duel.hero_hp, "victory": duel.victory, "events": counts}
		records.append(record)
		print("EARNED_CRAFTING %s/%d %.4fs hp=%d victory=%s %s" % [route, index, duel.elapsed, duel.hero_hp, duel.victory, JSON.stringify(counts)])
		if not check(duel.finished and duel.victory, "native-HP real duel won " + route + "/" + str(index)): return false
		check(bool(state.update_stage_battle_resources(run_id, duel.battle_resource_snapshot()).get("ok", false)),
			"actual qi and cooldowns persist after battle")
		check(absf(float(state.stage_battle_resources().qi) - float(duel.battle_resource_snapshot().qi)) < 0.0001,
			"persisting duel end does not refill combat qi")
		health = duel.hero_hp
		var before := resources()
		var corpse: Dictionary = state.begin_stage_corpse(run_id, index)
		if not check(bool(corpse.get("ok", false)), "actual victory creates one earned corpse"): return false
		var payout_before := resources()
		check(state.total_victories == int(before.victories) and state.materials.to_dict() == before.materials,
			"death alone grants no rewards or victory count")
		for tick in range(119):
			state.advance_stage_search(run_id, index, DT)
			rest(run_id, DT)
			search_seconds += DT
		check(not state.complete_stage_search(run_id, index).get("ok", false)
			and state.materials.to_dict() == payout_before.materials and state.total_victories == int(payout_before.victories),
			"119 search frames cannot claim a two-second body")
		state.advance_stage_search(run_id, index, DT)
		rest(run_id, DT)
		search_seconds += DT
		var reward: Dictionary = state.complete_stage_search(run_id, index)
		if not check(bool(reward.get("ok", false)), "120 actual search frames pay exactly once"): return false
		for pair in [["chest_rolled", "chests"], ["equipment_rolled", "equipment"], ["treasure_rolled", "treasure"]]:
			if bool(reward.get(pair[0], false)): chances[pair[1]] += 1
		var claimed := resources()
		check(not state.complete_stage_search(run_id, index).get("ok", false) and resources() == claimed,
			"duplicate corpse completion cannot duplicate income")
		record.reward = {"materials": reward.materials, "herbs": reward.herbs, "dew": reward.dew,
			"qi": reward.qi, "chapter_reward": reward.get("chapter_reward", {})}
		if index < 2:
			rest(run_id, 9.0)
			travel_seconds += 9.0
		else:
			check(bool(reward.first_clear) and bool(reward.chapter_reward.get("ok", false)),
				"searched boss awards real first-clear package")
			check(state.equip_item(int(reward.chapter_reward.item.id)), "real first-clear gear is explicitly equipped")
			var after := resources()
			check(not state.claim_chapter_reward(route).get("ok", false) and resources() == after,
				"chapter first-clear package cannot duplicate")
	check(not state.stage_status().active and state.stage_run.is_empty(), "clear returns home without starting another route")
	return errors.is_empty()

func report() -> Dictionary:
	return {"schema": 1, "seed": DRY_SEED, "seed_note": "Legacy seed 61 rolls a mandatory bamboo opportunity with the durable third treasure draw; seed 15 is actually dry for this complete four-route journey.",
		"fps": 60, "checks": checks, "errors": errors,
		"method": "New State; paid campaign Plan; native enemy stats and rendered-body geometry; persistent route HP, qi and cooldowns; 120-frame corpse searches; no injected resources, items, levels or wins",
		"native_baseline": "Configured campaign enemies. Cloud boss uses the authorized 450 HP balance revision; all ember enemies retain original 250/290/625 HP, 12/13/12 attack and 4/4/5 defense.",
		"clock_scope": "Game simulation time includes actual paid study timers, 60fps battle/search and nine seconds of travel between enemies. Excludes UI deliberation, outbound travel and portal animation.",
		"time_seconds": {"first_three_clears": first_three_seconds, "ready_before_crafting": prepared_seconds,
			"battles": battle_seconds, "searches": search_seconds, "between_enemy_travel": travel_seconds,
			"total": state.lifetime_seconds},
		"random_rewards": chances, "initial": initial, "petal_study": petal_study,
		"preparation": preparation, "battles": records, "final": resources(),
		"manual_departure": not state.expedition_auto and not state.stage_status().active,
		"source": measurement_metadata()}

static func measurement_metadata() -> Dictionary:
	var metadata: Dictionary = Plan.measurement_metadata()
	for path in ["tests/chapter_crafting_plan.gd", "tests/test_chapter_crafting_journey.gd", "tests/prepare_chapter_crafting_demo.gd"]:
		metadata.source_sha256[path] = FileAccess.get_sha256("res://" + path)
	return metadata
