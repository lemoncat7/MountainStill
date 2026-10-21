extends SceneTree
## Broad combat-RNG sensitivity using snapshots earned by test_encounter_balance.
## Carries actual HP, qi and keyed cooldowns across three fights; only the real
## nine-second route travel interval restores qi/reduces cooldowns. No HP rest.
## This diagnostic is not a replacement for complete lawful campaign tests.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Plan = preload("res://tests/campaign_build_plan.gd")
const BUILDS := ["sword", "fire", "guard", "control", "support"]
var checks := 0
var failures := 0
var input_path := "res://docs/qa/encounter-balance-after.json"
var report_path := ""
var groups: Array = []
var seed_count := 64
var build_filter := ""

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--input="):
			input_path = arg.trim_prefix("--input=")
		elif arg.begins_with("--report="):
			report_path = arg.trim_prefix("--report=")
		elif arg.begins_with("--seed-count="):
			seed_count = maxi(1, int(arg.trim_prefix("--seed-count=")))
		elif arg.begins_with("--build="):
			build_filter = arg.trim_prefix("--build=")
	check(build_filter.is_empty() or build_filter in BUILDS, "optional parallel build shard is one of the five lawful builds")
	if failures:
		quit(1)
		return
	var data: Variant = JSON.parse_string(FileAccess.get_file_as_string(input_path))
	if not data is Dictionary or not data.get("encounters", []) is Array:
		check(false, "earned-state measurement input is readable")
		quit(1)
		return
	var current_metadata := Plan.measurement_metadata()
	check(data.get("metadata", {}).get("source_sha256", {}) == current_metadata.source_sha256,
		"canonical input was measured with the current combat, geometry, content, state and lawful build plan")
	if failures:
		quit(1)
		return
	var rows: Array = data.encounters
	for build in BUILDS:
		if not build_filter.is_empty() and build != build_filter:
			continue
		for chapter in range(1, 7):
			check(Plan.measurement_metadata() == current_metadata, "measurement inputs remain frozen before the next sensitivity group")
			if failures:
				quit(1)
				return
			var profiles := rows.filter(func(r): return r.build == build and r.chapter == chapter and r.rng_seed == 61)
			check(profiles.size() == 3, "three genuine earned encounter snapshots exist")
			if profiles.size() != 3:
				continue
			_measure_group(profiles, build, chapter)
	var wins := 0
	var duel_wins := 0
	var duel_attempts := 0
	for group in groups:
		wins += int(group.wins)
		duel_wins += int(group.duel_wins)
		duel_attempts += group.samples.size()
	check(Plan.measurement_metadata() == current_metadata, "measurement inputs remain frozen for all sensitivity seeds")
	var report := {"metadata": current_metadata,
		"method": "earned snapshots; HP/qi/CD carried; 9s actual travel; canonical duel seed + index * 10007",
		"geometry": "native route art and enemy front extent; actual 1200px window coordinates",
		"seed_count": seed_count, "groups": groups, "route_wins": wins, "routes": groups.size() * seed_count,
		"duel_wins": duel_wins, "duel_attempts": duel_attempts,
		"checks": checks, "failures": failures}
	if not report_path.is_empty():
		var file := FileAccess.open(report_path, FileAccess.WRITE)
		check(file != null, "stress report opens")
		if file != null:
			report.checks = checks
			report.failures = failures
			file.store_string(JSON.stringify(report, "\t"))
			file.close()
	print("Encounter sensitivity: %d/%d complete route wins; %d/%d duel wins; %d checks, %d failures" % [wins, groups.size() * seed_count, duel_wins, duel_attempts, checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("FAIL: " + label)

func _measure_group(profiles: Array, build: String, chapter: int) -> void:
	var wins := 0
	var lowest_hp := 100000
	var ordinary_times: Array = []
	var boss_times: Array = []
	var failed_seeds: Array = []
	var failed_at: Array = []
	var lowest_qi := 100000.0
	var samples: Array = []
	var duel_wins := 0
	for seed_index in range(seed_count):
		var health := int(profiles[0].hero_stats.max_hp)
		var resources: Dictionary = profiles[0].hero_stats.battle_resources.duplicate(true)
		var victory := true
		for row in profiles:
			var enemy: Dictionary = Plan.prepare_enemy(Content.STAGES[row.route].monsters[int(row.index)], row.route)
			check(int(enemy.hp) == int(row.enemy_hp) and int(enemy.attack) == int(row.enemy_attack) and int(enemy.defense) == int(row.enemy_defense), "snapshot uses current authored monster stats")
			var hero: Dictionary = row.hero_stats.duplicate(true)
			hero.hp = health
			hero.battle_resources = resources.duplicate(true)
			var duel := Duel.new()
			duel.start(hero, enemy, row.technique, row.equipment.get("weapon", ""), int(row.duel_seed) + seed_index * 10007)
			var events := duel.advance(120.0)
			var whiffs := 0
			var melee_contacts := 0
			for event in events:
				if event.type == "contact" and event.actor == "hero":
					if str(event.get("resolution", "")) == "whiff":
						whiffs += 1
					if event.has("melee_contact"):
						melee_contacts += 1
			check(duel.finished, "combat reaches a genuine terminal result")
			health = duel.hero_hp
			resources = duel.battle_resource_snapshot()
			lowest_qi = minf(lowest_qi, float(resources.qi))
			check(float(resources.qi) >= 0.0 and float(resources.qi) <= float(resources.max_qi), "real qi stays within its earned capacity")
			if seed_index == 0:
				check(absf(duel.elapsed - float(row.seconds)) <= 0.001 and health == int(row.remaining_hp), "canonical seed reproduces complete-campaign timing and inherited HP")
			samples.append({"seed_index": seed_index, "duel_seed": int(row.duel_seed) + seed_index * 10007,
				"enemy_id": enemy.id, "index": int(row.index), "boss": row.boss,
				"victory": duel.victory, "seconds": snappedf(duel.elapsed, 0.0001),
				"remaining_hp": health, "enemy_hp_left": duel.enemy_hp,
				"end_qi": float(resources.qi), "hero_whiffs": whiffs, "melee_contacts": melee_contacts})
			if not duel.victory:
				victory = false
				failed_seeds.append(seed_index)
				failed_at.append({"seed_index": seed_index, "enemy_id": enemy.id, "seconds": snappedf(duel.elapsed, 0.0001), "enemy_hp_left": duel.enemy_hp})
				break
			duel_wins += 1
			if row.boss:
				boss_times.append(duel.elapsed)
			else:
				ordinary_times.append(duel.elapsed)
				resources = Duel.rest_resource_snapshot(resources, 9.0, float(hero.combat_qi_max), float(hero.combat_qi_regen))
		if victory:
			wins += 1
			lowest_hp = mini(lowest_hp, health)
	var group := {"build": build, "chapter": chapter, "wins": wins, "routes": seed_count,
		"duel_wins": duel_wins,
		"lowest_hp": lowest_hp, "lowest_end_qi": lowest_qi,
		"ordinary_min": ordinary_times.min(), "ordinary_max": ordinary_times.max(),
		"boss_min": boss_times.min(), "boss_max": boss_times.max(),
		"failed_seeds": failed_seeds, "failed_at": failed_at}
	print("RESOURCE STRESS " + JSON.stringify(group))
	group.samples = samples
	groups.append(group)
