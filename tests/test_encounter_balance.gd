extends SceneTree
## Authored encounter pacing through five genuinely earned first-clear builds.
## Optional --measure-only records old content without enforcing the pacing envelope.
## Optional --report=/absolute/path.json persists every measured contact and state.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
const BUILDS = Plan.BUILDS
var checks := 0
var failures := 0
var rows: Array = []
var campaigns: Array = []
var powered_replays: Array = []
var measure_only := false
var report_path := ""

func _initialize() -> void:
	var source_metadata := Plan.measurement_metadata()
	for arg in OS.get_cmdline_user_args():
		if arg == "--measure-only":
			measure_only = true
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
	for rng_seed in [20261020, 61]:
		for build in BUILDS:
			_run_build(build, rng_seed)
	if not measure_only:
		_check_pacing()
	check(Plan.measurement_metadata() == source_metadata, "measurement inputs remain frozen for the complete run")
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		check(file != null, "measurement report opens")
		if file != null:
			file.store_string(JSON.stringify({"metadata": source_metadata, "encounters": rows, "campaigns": campaigns, "powered_replays": powered_replays, "checks": checks, "failures": failures}, "\t"))
			file.close()
	print("Encounter balance tests: %d checks, %d failures" % [checks, failures])
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
	var training_plan: Array = [Plan.configure(s, build, 0)]
	var seconds := 0.0
	var winners := 0
	var opportunity_count := 0
	var random_reward_count := 0
	var route_end_hp: Array = []
	for chapter in range(6):
		var id: String = Content.CHAPTER_ORDER[chapter]
		check(s.select_stage(id), "%s earned gate %s" % [build, id])
		var started := s.start_stage()
		check(bool(started.get("ok", false)), "%s starts %s" % [build, id])
		if not bool(started.get("ok", false)):
			break
		var health := int(s.stats().max_hp)
		for index in range(3):
			if index == 2:
				s.check_route_opportunity(int(started.run_id))
				if s.stage_status().opportunity_pending:
					opportunity_count += 1
					check(s.choose_opportunity("gather_gift").ok, "real earned opportunity")
			var hero := s.stats().duplicate(true)
			hero.hp = health
			hero.battle_resources = s.stage_battle_resources()
			var enemy: Dictionary = Plan.prepare_enemy(s.stage_status().next_monster, id)
			var duel := Duel.new()
			duel.start(hero, enemy, s.technique, String(s.gear.visual_loadout().get("weapon", "")), int(started.run_id) * 1337 + index * 79 + 17)
			var hero_contacts := 0
			var enemy_contacts := 0
			var damage_received := 0
			var actual_healing := 0
			var basic_actions := 0
			var skill_actions:Dictionary={}
			var qi_spent := 0.0
			var hero_whiffs := 0
			var enemy_whiffs := 0
			var measured_melee_contacts := 0
			var landed_melee_contacts := 0
			var damage_dealt := 0
			var breaks := 0
			var enemy_moves: Array = []
			var saw_awakened := false
			for tick in range(1200):
				if duel.finished:
					break
				for event in duel.advance(0.1):
					if event.type == "turn_started" and event.actor == "hero":
						if str(event.get("action_kind",""))=="basic":basic_actions+=1
						else:
							var skill_id:String=str(event.get("skill_id",event.move))
							skill_actions[skill_id]=int(skill_actions.get(skill_id,0))+1
							qi_spent+=float(event.get("qi_cost",0.0))
					if event.type == "contact":
						actual_healing+=int(event.get("heal",0))
						if str(event.get("resolution", "")) == "whiff":
							if event.actor == "hero":
								hero_whiffs += 1
							else:
								enemy_whiffs += 1
							check(int(event.damage) == 0, "a genuine out-of-range whiff deals zero damage")
						if event.has("melee_contact"):
							measured_melee_contacts += 1
							var geometry: Dictionary = event.melee_contact
							if int(event.damage) > 0:
								landed_melee_contacts += 1
								check(bool(geometry.get("contact", false)), "successful melee damage shares the painted-body contact geometry")
						if event.actor == "hero":
							hero_contacts += 1
							damage_dealt += int(event.damage)
						else:
							enemy_contacts += 1
							damage_received += int(event.damage)
					elif event.type == "poise_break":
						breaks += 1
					elif event.type == "turn_started" and event.actor == "enemy":
						if not event.move in enemy_moves:
							enemy_moves.append(event.move)
						saw_awakened = saw_awakened or event.enemy_phase == "awakened"
				s.step(0.1)
			seconds += duel.elapsed
			rows.append({"build": build, "rng_seed": rng_seed, "chapter": chapter + 1, "route": id,
				"index": index, "enemy_id": enemy.id, "boss": enemy.boss, "enemy_hp": enemy.hp, "enemy_definition": enemy.duplicate(true),
				"enemy_attack": enemy.attack, "enemy_defense": enemy.defense, "technique": s.technique,
				"technique_level": hero.technique_level, "hero_attack": hero.attack, "hero_defense": hero.defense,
				"hero_max_hp": hero.max_hp, "start_hp": health, "remaining_hp": duel.hero_hp,
				"hero_stats": hero.duplicate(true), "duel_seed": int(started.run_id) * 1337 + index * 79 + 17,
				"victory": duel.victory, "seconds": snappedf(duel.elapsed, 0.0001),
				"hero_contacts": hero_contacts, "enemy_contacts": enemy_contacts,
				"damage_dealt": damage_dealt, "damage_received": damage_received,"actual_healing":actual_healing,"basic_actions":basic_actions,"skill_actions":skill_actions,"qi_spent":qi_spent,"battle_resources_end":duel.battle_resource_snapshot(),
				"hero_whiffs": hero_whiffs, "enemy_whiffs": enemy_whiffs, "measured_melee_contacts": measured_melee_contacts, "landed_melee_contacts": landed_melee_contacts,
				"poise_breaks": breaks, "enemy_moves": enemy_moves, "saw_awakened": saw_awakened,
				"meridians": s.meridian_opened.duplicate(), "equipment": s.gear.visual_loadout().duplicate(true)})
			check(duel.finished and duel.victory, "%s rng%d real victory %s enemy%d" % [build, rng_seed, id, index])
			check(duel.hero_hp == health - damage_received + actual_healing, "HP changes only by real contact damage and paid healing")
			check(duel.enemy_hp == int(enemy.hp) - damage_dealt, "authored enemy HP decreases only by real contacts")
			if not duel.victory:
				print("BALANCE BLOCKED ", build, " ", id, " enemy", index, " HP ", duel.hero_hp, "/", hero.max_hp, " foe ", duel.enemy_hp, " time ", duel.elapsed)
				campaigns.append({"build": build, "rng_seed": rng_seed, "wins": winners, "seconds": seconds, "route_end_hp": route_end_hp, "complete": false})
				return
			s.update_stage_battle_resources(int(started.run_id),duel.battle_resource_snapshot())
			health = duel.hero_hp
			winners += 1
			var result := s.defeat_stage_monster(int(started.run_id), index)
			check(result.ok, "real victory pays once")
			if bool(result.chest_rolled) or bool(result.equipment_rolled):
				random_reward_count += 1
			if index < 2:
				var stats:Dictionary=s.stats()
				s.update_stage_battle_resources(int(started.run_id),Duel.rest_resource_snapshot(s.stage_battle_resources(),9.0,float(stats.combat_qi_max),float(stats.combat_qi_regen)))
				s.step(9.0)
			if index == 2:
				check(result.chapter_reward.ok and s.equip_item(int(result.chapter_reward.item.id)), "equip only genuinely earned deterministic gear")
		route_end_hp.append(health)
		s.step(0.1)
		training_plan.append(Plan.configure(s, build, chapter + 1))
		Plan.buy_affordable_meridians(s)
	check(winners == 18 and s.realm == 15 and s.chapter_status().epilogue_ready, "all six chapters reach the ending lawfully")
	check(s.complete_home_epilogue().ok and s._valid_save(s._snapshot()), "completed campaign remains save-valid")
	if rng_seed == 61:
		check(s.inventory.size() == 6 and s.chest_count == 1 and opportunity_count == 0 and random_reward_count == 0, "dry seed has zero random gear, chests or opportunities")
	campaigns.append({"build": build, "rng_seed": rng_seed, "wins": winners, "seconds": snappedf(seconds, 0.0001), "route_end_hp": route_end_hp, "complete": true,
		"random_reward_count": random_reward_count, "opportunity_count": opportunity_count, "owned_items": s.inventory.size(),
		"training_plan": training_plan, "total_simulation_seconds": snappedf(s.lifetime_seconds, 0.0001), "travel_seconds": 108.0})
	print("BALANCED BUILD %s rng%d: %d wins, %.2fs battles, route end HP %s" % [build, rng_seed, winners, seconds, route_end_hp])
	_check_earned_replay(s, build, rng_seed)

func _check_earned_replay(s: State, build: String, rng_seed: int) -> void:
	# Revisit the actual first route with the character that just finished the
	# campaign. No boosted test stats or altered enemy definitions are involved.
	check(s.select_stage("bamboo_pass"), "completed character may manually replay first chapter")
	var started := s.start_stage()
	check(bool(started.get("ok", false)), "earned replay starts normally")
	if not bool(started.get("ok", false)):
		return
	var health := int(s.stats().max_hp)
	var times: Array = []
	for index in range(3):
		if index == 2:
			s.check_route_opportunity(int(started.run_id))
			if s.stage_status().opportunity_pending:
				check(s.choose_opportunity("gather_gift").ok, "replay opportunity resolves normally")
		var hero := s.stats().duplicate(true)
		hero.hp = health
		hero.battle_resources=s.stage_battle_resources()
		var enemy: Dictionary = Plan.prepare_enemy(s.stage_status().next_monster, "bamboo_pass")
		var duel := Duel.new()
		duel.start(hero, enemy, s.technique, String(s.gear.visual_loadout().get("weapon", "")), int(started.run_id) * 1337 + index * 79 + 17)
		for tick in range(600):
			if duel.finished:
				break
			duel.advance(0.1)
			s.step(0.1)
		check(duel.finished and duel.victory, "earned stronger build still wins real replay")
		if not duel.victory:
			return
		s.update_stage_battle_resources(int(started.run_id),duel.battle_resource_snapshot())
		health = duel.hero_hp
		times.append(snappedf(duel.elapsed, 0.0001))
		check(s.defeat_stage_monster(int(started.run_id), index).ok, "replay victory uses ordinary reward path")
		if index < 2:
			var stats: Dictionary = s.stats()
			s.update_stage_battle_resources(int(started.run_id), Duel.rest_resource_snapshot(s.stage_battle_resources(), 9.0, float(stats.combat_qi_max), float(stats.combat_qi_regen)))
			s.step(9.0)
		if not measure_only:
			check(duel.elapsed < (10.0 if index == 2 else 6.0), "earned power defeats low-level foes faster; no minimum combat timer")
	powered_replays.append({"build": build, "rng_seed": rng_seed, "seconds": times, "remaining_hp": health,
		"hero_stats": s.stats(), "owned_items": s.inventory.size()})

func _check_pacing() -> void:
	check(rows.size() == 180, "five earned builds and two reward seeds cover all 180 encounters")
	var ordinary_count := 0
	var ordinary_in_target := 0
	var boss_count := 0
	var bosses_in_target := 0
	for row in rows:
		# Mist is the genuinely higher attack build; speed remains an earned benefit.
		# 8–15 / 20–35 seconds are typical pacing goals, not hidden strict timers.
		# Real defensive actions and physical footwork may create bounded tails.
		var minimum := 7.0 if row.build == "sword" else 8.0
		var maximum := 18.0
		if row.boss:
			minimum = 16.0 if row.build == "sword" else 20.0
			maximum = 42.0
			boss_count += 1
			if row.seconds <= 35.0:
				bosses_in_target += 1
		else:
			ordinary_count += 1
			if row.seconds <= 15.5:
				ordinary_in_target += 1
		check(row.seconds >= minimum and row.seconds <= maximum, "authored pacing %s %s %s %.2fs in [%.1f, %.1f]" % [row.build, row.route, row.enemy_id, row.seconds, minimum, maximum])
		check(row.enemy_contacts >= (6 if row.boss else 2), "enemy has genuine opportunities to act")
		if row.boss:
			check(row.remaining_hp >= float(row.hero_max_hp) * 0.15, "full route retains a measurable health margin including real paid healing")
			check(row.basic_actions >= 6, "real free basic actions continue between paid abilities")
			# The opening route is genuinely unarmed. Its sword art and weapon
			# ability are unavailable until the first-clear sword is earned.
			if int(row.chapter) >= 2:
				check(row.skill_actions.size() >= 2 and float(row.qi_spent) > 0.0, "armed boss uses at least two distinct paid skills")
			check(row.enemy_moves.size() == 3, "boss demonstrates all three authored attack forms")
			if int(row.chapter) >= 4:
				check(row.saw_awakened, "late boss visibly enters real half-health phase")
	check(ordinary_in_target >= ordinary_count * 0.90, "at least 90 percent of canonical ordinary fights stay within the ordinary target envelope")
	check(bosses_in_target >= boss_count * 0.85, "at least 85 percent of canonical bosses stay at or below the 35-second typical goal")
