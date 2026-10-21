extends SceneTree
## Pure simulation: no player saves, rewards, rendering, or network side effects.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0


func _initialize() -> void:
	_test_contact_and_phases()
	_test_determinism_and_partition()
	_test_real_defenses_and_counter()
	_test_profiles_and_grips()
	_test_enemy_tells()
	_test_enemy_visual_reach()
	_test_equipment_and_meridians()
	_test_terminal_and_cancel()
	_test_every_authored_encounter()
	print("Duel timeline tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		push_error("FAIL: " + label)


func duel(tech: String = "mist", seed_value: int = 42, enemy: Dictionary = {}, hero: Dictionary = {}, weapon: String = "sword") -> Duel:
	var result := Duel.new()
	var target := {"hp": 150, "attack": 6, "defense": 0, "route_id": "bamboo_pass", "dodge_chance": 0.0, "guard_chance": 0.0}
	target.merge(enemy, true)
	var player := {"hp": 100, "attack": 11, "defense": 0}
	player.merge(hero, true)
	result.start(player, target, tech, weapon, seed_value)
	return result


func run_to_end(d: Duel, delta: float = 0.025) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	var iterations := 0
	while not d.finished and iterations < 100000:
		events.append_array(d.advance(delta))
		iterations += 1
	events.append_array(d.advance(0.0))
	return events


func contacts(events: Array[Dictionary], actor: String = "") -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		if event.type == "contact" and (actor.is_empty() or event.actor == actor):
			result.append(event)
	return result


func _test_contact_and_phases() -> void:
	var d := duel()
	var pose := d.pose()
	check(pose.phase == "windup" and pose.hero.combat_move == "basic_sword_cut" and pose.hero.action_kind == "basic", "starts with a free authored sword anticipation")
	check(pose.hero.attack_phase == 0.0 and pose.hero_hp == 100, "whole-move normalized phase starts neutral with 100 HP")
	var first_contact: float = pose.contact_times[0]
	d.advance(float(pose.windup_duration) - 0.01)
	check(d.enemy_hp == 150 and d.pose().phase == "windup", "windup cannot deal damage")
	d.advance(0.02)
	check(d.enemy_hp == 150 and d.pose().phase == "strike", "strike begins before collision")
	var events := d.advance(first_contact - d.elapsed)
	var hits := contacts(events)
	check(hits.size() == 1 and is_equal_approx(hits[0].time, first_contact), "exact scheduled contact produces one hit")
	check(hits[0].pre_hp == 150 and hits[0].post_hp == d.enemy_hp and hits[0].damage == 11, "event HP and actual HP are the same resolution")
	check(d.pose().phase == "contact" and d.pose().enemy.defense_action == "hit", "actual hit controls contact reaction")
	d.advance(0.14)
	check(d.pose().phase == "recovery" and d.enemy_hp == 139, "recovery does not repeat damage")
	d.advance(0.61)
	check(d.pose().hero.action_id > 1 and d.pose().enemy.attack_amount > 0.0, "hero begins another action while enemy independently recovers")
	var sampled := d.pose()
	for i in range(20):
		check(d.pose() == sampled, "sampling while paused is pure")
	d.advance(-100.0)
	check(d.pose() == sampled, "negative delta never rewinds or advances combat")
	d.advance(NAN)
	check(d.pose() == sampled, "nonfinite delta is ignored")


func _test_determinism_and_partition() -> void:
	for tech in ["mist", "petal", "ember", "stillness"]:
		var a := duel(tech, 377, {"hp": 220, "attack": 8, "boss": true, "boss_move": "burst"})
		var b := duel(tech, 377, {"hp": 220, "attack": 8, "boss": true, "boss_move": "burst"})
		var c := duel(tech, 377, {"hp": 220, "attack": 8, "boss": true, "boss_move": "burst"})
		var first := run_to_end(a, 0.017)
		var second := run_to_end(b, 0.143)
		var third := c.advance(10000.0)
		check(first == second and second == third, "fixed seed and varied delta partitions produce exact same events: " + tech)
		check(a.finished and b.finished and c.finished and a.victory == b.victory and a.hero_hp == c.hero_hp, "all integration partitions agree on terminal state: " + tech)
		var ids := {}
		for hit in contacts(first):
			check(not ids.has(hit.contact_id), "a scheduled contact is resolved exactly once: " + tech + "/" + hit.contact_id)
			ids[hit.contact_id] = true
			check(int(hit.pre_hp) - int(hit.post_hp) == int(hit.damage), "contact damage is exactly HP delta")
			check(int(hit.hero_hp_after) >= 0 and int(hit.enemy_hp_after) >= 0, "HP never goes below zero")
		check(contacts(a.advance(10000.0)).is_empty(), "finished encounters cannot emit later contacts")


func _test_real_defenses_and_counter() -> void:
	var dodges := 0
	var guards := 0
	var counters := 0
	for seed_value in range(1, 16):
		var d := duel("petal", seed_value, {"hp": 200, "attack": 7, "boss": true}, {}, "fan")
		var events := run_to_end(d)
		var can_counter := false
		for event in events:
			if event.type == "contact" and event.target == "hero" and event.resolution == "dodge":
				dodges += 1
				can_counter = true
				check(event.damage == 0 and event.pre_hp == event.post_hp, "petal evade actually avoids all contact damage")
			if event.type == "turn_started" and event.actor == "hero":
				if event.counter:
					counters += 1
					check(can_counter, "petal earned basic/skill counter requires a preceding actual dodge")
				can_counter = false
		var still := duel("stillness", seed_value, {"hp": 180, "attack": 9})
		for hit in contacts(run_to_end(still), "enemy"):
			if hit.resolution == "guard":
				guards += 1
				check(hit.calculated_damage < hit.unguarded_damage and hit.damage <= hit.calculated_damage, "visible guard really reduces resolved damage")
			elif hit.resolution == "hit":
				check(hit.calculated_damage == hit.unguarded_damage, "ordinary hit has no hidden guard reduction")
	check(dodges > 20 and counters > 10 and guards > 20, "repeatable seeds visibly exercise dodge, counter, and guarding")
	# Inspect each actual contact pose, including multihit enemy bursts.
	var d := duel("stillness", 7, {"hp": 500, "attack": 7, "boss": true, "boss_move": "burst"})
	for step in range(4000):
		var events := d.advance(0.01)
		for hit in contacts(events):
			var p := d.pose()
			var motion: Dictionary = p.hero if hit.target == "hero" else p.enemy
			if hit.resolution == "whiff":
				check(hit.damage == 0 and hit.pre_hp == hit.post_hp and float(hit.get("poise_damage",0)) == 0, "empty swing grants no damage or posture effect")
			else:
				check(motion.defense_action == hit.resolution, "reaction pose matches current contact: event=%s/%s current=%s/%s" % [hit.contact_id,hit.resolution,motion.get("contact_id",""),motion.defense_action])
		if d.finished:
			break


func _test_profiles_and_grips() -> void:
	var signatures := {}
	for tech in ["mist", "petal", "ember", "stillness"]:
		var d := duel(tech, 22, {"hp": 800, "attack": 1})
		var events := d.advance(40.0)
		var moves := {}
		var times := []
		var damage := []
		for event in events:
			if event.type == "turn_started" and event.actor == "hero":
				moves[event.move] = true
				times.append(event.duration)
			if event.type == "contact" and event.actor == "hero":
				damage.append(event.calculated_damage)
		check(moves.size() >= 2, "technique drives multiple demonstrable moves: " + tech)
		var signature := str(moves.keys()) + str(times) + str(damage)
		check(not signatures.has(signature), "technique changes timings, moves, and combat coefficients: " + tech)
		signatures[signature] = true
		var sword := duel(tech, 99, {}, {}, "sword")
		var fan := duel(tech, 99, {}, {}, "fan")
		var empty := duel(tech, 99, {}, {}, "")
		check(sword.pose().move != fan.pose().move and fan.pose().move != empty.pose().move, "equipped weapon selects distinct free basic modules: " + tech)
		check(sword.pose().hero.attack_style == "sword" and fan.pose().hero.attack_style == "fan" and empty.pose().hero.attack_style == "unarmed", "grip explicitly preserves sword/fan/unarmed without phantom weapons")
		for styled in [sword, fan, empty]:
			var first_move: String = styled.pose().hero.combat_move
			var expected_raw := 11.0 * float(Duel.BASIC_MOVES[first_move].hits[0])
			var first_hit: Dictionary = contacts(styled.advance(float(styled.pose().contact_times[0]) + 0.001), "hero")[0]
			check(is_equal_approx(float(first_hit.raw_damage), expected_raw), "free basic uses its authored contact coefficient with no unrelated technique multiplier")
	for grip in ["", "fan"]:
		var adapted := duel("mist", 42, {"hp": 500, "attack": 1}, {}, grip)
		for event in adapted.advance(12.0):
			if event.type == "turn_started" and event.actor == "hero":
				check(event.action_kind == "basic", "incompatible selected sword art stays disabled")
				check(not str(event.telegraph).contains("剑") and not str(event.telegraph).contains("锋"), "ordinary empty/fan grip never invents a sword")
	# Multi-hit moves contain real distinct contacts, rather than repeated particles.
	var combo := contacts(duel("mist", 42, {"hp": 500, "attack": 1}).advance(12.0), "hero")
	var combo_hits := combo.filter(func(c: Dictionary) -> bool: return c.move == "mist_combo")
	var full_combo := false
	var combo_groups := {}
	for hit in combo_hits:
		if not combo_groups.has(hit.action_id): combo_groups[hit.action_id] = []
		combo_groups[hit.action_id].append(hit)
	for group in combo_groups.values():
		if group.size() == 3:
			full_combo = full_combo or (group[0].time < group[1].time and group[1].time < group[2].time)
	check(full_combo, "mist triple strike resolves three separately timed contacts within an action")
	var pulses := contacts(duel("ember", 42, {"hp": 500, "attack": 1}).advance(9.0), "hero")
	var pulse_groups := {}
	for hit in pulses:
		if hit.move == "ember_pulse":
			pulse_groups[hit.action_id] = int(pulse_groups.get(hit.action_id, 0)) + 1
	check(2 in pulse_groups.values(), "ember pulse resolves two actual damage pulses within an action")


func _test_enemy_tells() -> void:
	var tells := {}
	for route in ["bamboo_pass", "creek_bridge", "cloud_slope"]:
		var normal := duel("stillness", 8, {"hp": 800, "attack": 2, "route_id": route}, {"attack": 1})
		var boss := duel("stillness", 8, {"hp": 800, "attack": 2, "route_id": route, "boss": true, "boss_move": "burst"}, {"attack": 1})
		var n := normal.advance(20.0).filter(func(e: Dictionary) -> bool: return e.type == "turn_started" and e.actor == "enemy")
		var b := boss.advance(20.0).filter(func(e: Dictionary) -> bool: return e.type == "turn_started" and e.actor == "enemy")
		check(n.size() >= 2 and b.size() >= 3, "normal and boss move rotation is visible: " + route)
		check(n[0].move != n[1].move and b[0].move != b[1].move, "enemy types do not repeat one generic animation: " + route)
		check(not tells.has(n[0].telegraph), "species-specific tell text differs: " + route)
		tells[n[0].telegraph] = true
		check(str(b[0].move).ends_with("boss_burst") and b[0].contacts == 3, "boss preferred burst is an actual triple move")
		check(float(b[0].windup) > 0.70 and str(b[0].telegraph).contains("守灵强招"), "boss announces longer anticipation and danger explicitly")
		var normal_damage := contacts(duel("mist", 1, {"hp": 999, "attack": 10, "route_id": route}, {"attack": 1}).advance(4.0), "enemy")
		var boss_damage := contacts(duel("mist", 1, {"hp": 999, "attack": 10, "route_id": route, "boss": true, "boss_move": "charge"}, {"attack": 1}).advance(4.0), "enemy")
		check(boss_damage[0].unguarded_damage > normal_damage[0].unguarded_damage, "boss tell corresponds to materially stronger actual damage")


func _test_equipment_and_meridians() -> void:
	var basic := duel("mist", 42, {"hp": 200})
	var trained := duel("mist", 42, {"hp": 200}, {"attack": 18, "defense": 3})
	var basic_hits := contacts(basic.advance(4.0))
	var trained_hits := contacts(trained.advance(4.0))
	check(trained_hits[0].damage > basic_hits[0].damage, "effective gear/meridian attack increases the actual hit")
	check(trained_hits[1].damage < basic_hits[1].damage, "effective gear/meridian defense reduces the actual enemy hit")
	var armored := duel("mist", 42, {"hp": 1000, "attack": 40}, {"attack": 1, "defense": 99999})
	var hits := contacts(armored.advance(4.0), "enemy")
	check(hits[0].unguarded_damage >= 10, "armor caps at 75% reduction, never blanket invulnerability")
	check(duel("mist", 5, {}, {"hp": 39}).hero_hp == 39, "caller can carry truthful remaining HP into next encounter")


func _test_terminal_and_cancel() -> void:
	var winning := duel("mist", 4, {"hp": 3, "attack": 100}, {"attack": 11})
	var before := winning.advance(0.70)
	check(winning.enemy_hp == 0 and not winning.finished and contacts(before).size() == 1, "lethal collision is visible before encounter completion")
	var after := winning.advance(5.0)
	check(winning.finished and winning.victory and after.size() == 1 and after[0].type == "finished", "only one finish event after lethal recovery and no enemy retaliation")
	check(winning.advance(100.0).is_empty(), "repeat finish polling cannot issue duplicate rewards")
	var losing := duel("mist", 3, {"hp": 900, "attack": 500}, {"attack": 1})
	run_to_end(losing)
	check(losing.finished and not losing.victory and losing.hero_hp == 0 and losing.enemy_hp > 0, "strong enemy can genuinely defeat the hero")
	var stopped := duel()
	stopped.advance(0.6)
	var hp := [stopped.hero_hp, stopped.enemy_hp]
	stopped.cancel()
	var cancel_events := stopped.advance(1000.0)
	check(stopped.finished and stopped.cancelled and not stopped.victory and hp == [stopped.hero_hp, stopped.enemy_hp], "cancel prevents all pending damage and does not fabricate victory")
	check(cancel_events.size() == 1 and cancel_events[0].type == "cancelled", "cancel is reported once without a completion reward")
	check(stopped.advance(10.0).is_empty(), "cancel cannot repeat its event")
	var empty := duel("mist", 1, {"hp": 0})
	check(empty.finished and not empty.victory and contacts(empty.advance(100.0)).is_empty(), "already-dead input cannot fabricate a rewarded kill")
	stopped.start({"attack": 12}, {"hp": 10, "attack": 2}, "ember", "fan", 1)
	run_to_end(stopped)
	check(stopped.finished and stopped.victory and not stopped.cancelled, "start resets cancellation and all encounter-local state")
	# Killing on an early combo hit must suppress later impacts and shorten recovery.
	var combo := duel("mist", 42, {"hp": 27, "attack": 1})
	var all := run_to_end(combo)
	var dead_time := -1.0
	for hit in contacts(all):
		check(dead_time < 0.0, "no combo contacts are emitted after an actor reaches zero HP")
		if hit.post_hp == 0:
			dead_time = hit.time
	check(combo.finished and combo.victory, "early combo lethal safely terminates")


func _test_every_authored_encounter() -> void:
	for route in Content.STAGES:
		for definition in Content.STAGES[route].monsters:
			for tech in ["mist", "petal", "ember", "stillness"]:
				var enemy: Dictionary = definition.duplicate(true)
				enemy.route_id = route
				var d := duel(tech, 246, enemy)
				var events := run_to_end(d, 0.31)
				check(d.finished and d.elapsed < 300.0 and not events.is_empty(), "authored encounter resolves finitely: " + str(definition.id) + "/" + tech)
				check(d.hero_hp == 0 or d.enemy_hp == 0, "terminal authored encounter has a real defeated actor")


func _mechanics(events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for event in events:
		var copy: Dictionary = event.duplicate(true)
		copy.erase("telegraph")
		result.append(copy)
	return result


func _test_enemy_visual_reach() -> void:
	var near := duel("mist", 77, {"hp": 500, "attack": 1, "boss": true, "engagement_distance": 128.0, "enemy_front_extent": 42.0})
	near.advance(1.34)
	check(near.pose().enemy.combat_phase == "contact", "reach sample uses real scheduled enemy contact")
	check(float(near.pose().enemy.get("body_clearance",INF))>=2.99 and float(near.pose().enemy.get("body_clearance",INF))<=9.0, "charge reaches the actual painted body plane at 128px spacing")
	var scaled := duel("mist", 77, {"hp": 500, "attack": 1, "boss": true, "engagement_distance": 138.5, "enemy_front_extent": 60.0})
	scaled.advance(1.34)
	check(is_equal_approx(float(scaled.pose().enemy.actor_lunge)-float(near.pose().enemy.actor_lunge), 10.5), "screen spacing changes painted charge travel by the same exact distance")
	var narrow := duel("mist", 77, {"hp": 500, "attack": 1, "boss": true, "engagement_distance": 20.0, "enemy_front_extent": 60.0})
	narrow.advance(1.34)
	check(is_equal_approx(float(narrow.pose().enemy.actor_lunge), 8.0), "charge visual reach has a safe lower bound")
	var wide := duel("mist", 77, {"hp": 500, "attack": 1, "boss": true, "engagement_distance": 900.0, "enemy_front_extent": 60.0})
	wide.advance(1.34)
	check(is_equal_approx(float(wide.pose().enemy.actor_lunge), 100.0), "charge visual reach has a safe upper bound")
	var small := duel("mist", 77, {"hp": 500, "attack": 1, "engagement_distance": 90.0})
	var large := duel("mist", 77, {"hp": 500, "attack": 1, "engagement_distance": 160.0})
	var near_events := run_to_end(small)
	var far_events := run_to_end(large)
	check(small.finished and large.finished, "near and far spacing both resolve a real encounter")
	for event in near_events + far_events:
		if event.type == "contact" and event.actor == "hero" and event.get("melee_contact", {}).size() > 0:
			check(event.damage == 0 or bool(event.melee_contact.contact), "screen spacing cannot grant damage through empty air")
	check(float(near_events[0].windup) < float(far_events[0].windup), "longer physical approach changes the actual windup clock")
