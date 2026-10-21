extends SceneTree
## Real earned-state campaign paths with each selectable combat style.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	for rng_seed in [20261020, 61]:
		for build in Plan.BUILDS:
			_run_build(build, rng_seed)
	print("Campaign build tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)

func _run_build(build: String, rng_seed: int) -> void:
	var s := State.new()
	s.auto_advance = true # Existing auto-enabled build benchmark; fresh manual path has separate coverage.
	s._adventure_rng.seed = rng_seed
	Plan.configure(s, build, 0)
	var seconds := 0.0
	var lowest_vitality := 999
	var winners := 0
	var opportunity_count := 0
	var random_reward_count := 0
	var route_builds: Array = []
	for chapter in range(6):
		var id: String = Content.CHAPTER_ORDER[chapter]
		check(s.select_stage(id), "%s earned gate %s" % [build, id])
		var started := s.start_stage()
		if not bool(started.get("ok", false)):
			check(false, "%s cannot start %s" % [build, id])
			return
		var health := int(s.stats().max_hp)
		route_builds.append("%s %s%d A%d D%d" % [id, s.technique, int(s.technique_levels[s.technique]), s.stats().attack, s.stats().defense])
		for index in range(3):
			if index == 2:
				s.check_route_opportunity(int(started.run_id))
				if s.stage_status().opportunity_pending:
					opportunity_count += 1
					s.choose_opportunity("gather_gift")
			var hero := s.stats().duplicate(true)
			hero.hp = health
			hero.battle_resources = s.stage_battle_resources()
			var duel := Duel.new()
			duel.start(hero, Plan.prepare_enemy(s.stage_status().next_monster, id), s.technique, String(s.gear.visual_loadout().get("weapon", "")), int(started.run_id) * 1337 + index * 79 + 17)
			for tick in range(6000):
				if duel.finished:
					break
				duel.advance(0.1)
				s.step(0.1)
				seconds += 0.1
			check(duel.finished and duel.victory, "%s actual victory %s enemy%d" % [build, id, index])
			if not duel.victory:
				print("BUILD BLOCKED ", build, " ", route_builds, " HP ", duel.hero_hp, " enemy HP ", duel.enemy_hp)
				return
			s.update_stage_battle_resources(int(started.run_id), duel.battle_resource_snapshot())
			health = duel.hero_hp
			lowest_vitality = mini(lowest_vitality, health)
			winners += 1
			var result := s.defeat_stage_monster(int(started.run_id), index)
			check(result.ok, "actual victory pays once")
			if bool(result.chest_rolled) or bool(result.equipment_rolled):
				random_reward_count += 1
			if index < 2:
				var stats:Dictionary=s.stats()
				s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)))
				s.step(9.0)
			if index == 2:
				check(result.chapter_reward.ok and s.equip_item(int(result.chapter_reward.item.id)), "equip only genuinely earned deterministic gear")
		s.step(0.1)
		Plan.configure(s, build, chapter + 1)
		Plan.buy_affordable_meridians(s)
	check(winners == 18 and s.realm == 15 and s.chapter_status().epilogue_ready, "%s naturally reaches all six and ending" % build)
	check(s.complete_home_epilogue().ok and s._valid_save(s._snapshot()), "%s valid complete campaign" % build)
	if rng_seed == 61:
		check(s.inventory.size() == 6 and s.chest_count == 1 and opportunity_count == 0 and random_reward_count == 0, "%s dry RNG earns zero gear drops/chests/opportunities but still completes" % build)
	print("EARNED BUILD %s rng%d: %d wins, %.1fs battles, lowest route vitality %d, %s" % [build, rng_seed, winners, seconds, lowest_vitality, route_builds])
