extends SceneTree
## Actual contact/commit/resource tests. No game saves, screenshots, or fixtures
## can substitute for deterministic resolved HP and shared ability cooldowns.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0

func _initialize() -> void:
	_test_basics_and_compatibility()
	_test_commit_costs_and_priority()
	_test_interrupt_and_pause()
	_test_restore_and_rest()
	_test_partition()
	_test_support_effects()
	_test_spell_effects_and_training()
	print("Battle qi timeline: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func manual(id: String) -> Dictionary:
	var item: Dictionary = Content.TECHNIQUES[id].duplicate(true)
	item.id = id
	item.active = true
	item.power_scale = 1.0
	return item

func weapon_skill(style: String) -> Dictionary:
	if style not in ["sword", "fan"]: return {}
	var id := "weapon_sword_pierce" if style == "sword" else "weapon_fan_return"
	return {"id": id, "move": id, "name": id, "qi_cost": 10.0 if style == "sword" else 12.0, "cooldown": 9.0 if style == "sword" else 10.0, "category": "weapon", "active": true}

func make_duel(ids: Array = ["mist", "ember"], style: String = "sword", mods: Dictionary = {}, enemy_mods: Dictionary = {}) -> Duel:
	var hero := {"hp": 10000, "max_hp": 10000, "attack": 12, "defense": 2, "combat_qi_max": 40.0, "combat_qi_regen": 2.0,
		"heart_method": {}, "weapon_art": {}, "active_skills": [], "weapon_skill": weapon_skill(style)}
	for id in ids: hero.active_skills.append(manual(str(id)))
	hero.merge(mods, true)
	var enemy := {"hp": 10000, "max_hp": 10000, "attack": 5, "defense": 1, "boss": true, "dodge_chance": 0.0, "guard_chance": 0.0}
	enemy.merge(enemy_mods, true)
	var d := Duel.new()
	d.start(hero, enemy, "mist", style, 377)
	return d

func hero_starts(events: Array[Dictionary]) -> Array[Dictionary]:
	var result: Array[Dictionary] = []
	for e in events:
		if e.type == "turn_started" and e.actor == "hero": result.append(e)
	return result

func _test_basics_and_compatibility() -> void:
	var signatures := {}
	for style in ["sword", "fan", "unarmed"]:
		var d := make_duel(["ember"], style, {"combat_qi_regen": 0.0, "battle_resources": {"qi": 0.0}})
		var moves := {}
		var events := d.advance(18.0)
		for e in hero_starts(events):
			check(e.action_kind == "basic" and e.qi_cost == 0.0, "zero qi always preserves free basic: " + style)
			check(str(e.move).begins_with("basic_" + style), "actual equipped weapon owns basic choreography")
			moves[e.move] = e.duration
			check(e.basic_range > 0.0 and not str(e.trail_kind).is_empty() and not str(e.sound_kind).is_empty(), "basic exposes real reach/trail/sound contract")
		check(moves.size() == (2 if style == "unarmed" else 3), "authored basic sequence has distinct actions: " + style)
		var signature := str(moves)
		check(not signatures.has(signature), "zero qi styles have actually different duration/move modules")
		signatures[signature] = true
		check(d.enemy_hp < 10000 and d.battle_resource_snapshot().qi == 0.0, "zero qi basic deals real damage without spending nonexistent qi")
	var wrong := make_duel(["mist"], "fan", {"weapon_skill": {}})
	check(not wrong.battle_resource_snapshot().active_skills[0].available, "wrong weapon keeps selected art visibly unavailable")
	for e in hero_starts(wrong.advance(12.0)): check(e.action_kind == "basic", "wrong weapon never silently casts selected sword art")
	var no_innate := make_duel([], "sword", {"weapon_skill": {}})
	check(not no_innate.battle_resource_snapshot().weapon_available, "weapon model alone never invents innate skill")
	var form_only := make_duel([], "sword", {"weapon_art": manual("mist"), "weapon_skill": {}})
	check(form_only.pose().hero.basic_form == "mist", "compatible form applies to basic action")
	for e in hero_starts(form_only.advance(10.0)): check(e.action_kind == "basic", "equipped basicform does not automatically equip paidactive")
	var plain := make_duel([], "sword", {"weapon_skill": {}})
	var with_spell := make_duel(["ember"], "sword", {"weapon_skill": {}, "combat_qi_regen": 0.0, "battle_resources": {"qi": 0.0}})
	check(plain.pose().hero.combat_move == with_spell.pose().hero.combat_move and plain.pose().turn_duration == with_spell.pose().turn_duration, "an unrelated spell doesn't replace basic timing or weapon form")

func _test_commit_costs_and_priority() -> void:
	var d := make_duel()
	check(d.pose().hero.action_kind == "basic" and d.battle_resource_snapshot().qi == 40.0, "fight starts with a genuinely free basic")
	var starts := hero_starts(d.advance(35.0))
	var paid := []
	var previous_kind := ""
	var deadlines := {}
	var qi := 40.0
	var last_time := 0.0
	for e in starts:
		qi = minf(40.0, qi + (float(e.time) - last_time) * 2.0)
		last_time = float(e.time)
		if e.action_kind != "basic":
			check(previous_kind == "basic", "every paid skill has at least one committed basic between")
			check(float(e.time) + 0.00001 >= float(deadlines.get(e.skill_id, 0.0)), "individual ability cannot cast before its own cooldown")
			var expected_cost := 10.0 if e.skill_id == "weapon_sword_pierce" else float(Content.TECHNIQUES[e.skill_id].qi_cost)
			var cd := 9.0 if e.skill_id == "weapon_sword_pierce" else float(Content.TECHNIQUES[e.skill_id].cooldown)
			check(is_equal_approx(e.qi_cost, expected_cost), "real authored cost is spent")
			qi -= expected_cost
			check(qi >= -0.00001 and absf(qi - float(e.qi)) < 0.00001, "spend once at windup commit, exact continuous regen")
			deadlines[e.skill_id] = float(e.time) + cd
			paid.append(e.skill_id)
		previous_kind = e.action_kind
	check(paid.size() >= 6 and paid.slice(0,3) == ["mist", "ember", "weapon_sword_pierce"], "roundrobin active slots and innate all execute in real35secondfight")
	for id in ["mist", "ember", "weapon_sword_pierce"]:
		check(paid.count(id) >= 2, "no affordable expensive lane starves: " + id)
	var unaffordable := make_duel(["ember"], "unarmed", {"combat_qi_regen": 0.0, "battle_resources": {"qi": 17.99}})
	for e in hero_starts(unaffordable.advance(15.0)): check(e.action_kind == "basic", "17.99 qi never funds 18 qi skill")
	var exact := make_duel(["ember"], "unarmed", {"combat_qi_regen": 0.0, "battle_resources": {"qi": 18.0}})
	var paid_exact := hero_starts(exact.advance(20.0)).filter(func(e: Dictionary) -> bool: return e.action_kind != "basic")
	check(paid_exact.size() == 1 and exact.battle_resource_snapshot().qi == 0.0, "exactly sufficient qi commits one skill once")

func _test_interrupt_and_pause() -> void:
	var d := make_duel(["ember"], "unarmed", {"combat_qi_regen": 0.0, "battle_resources": {"qi": 18.0}})
	var interrupted_id := 0
	for i in range(500):
		for e in d.advance(0.01):
			if e.type == "turn_started" and e.actor == "hero" and e.action_kind == "spell": interrupted_id = int(e.action_id)
		if interrupted_id > 0: break
	check(interrupted_id > 0 and d.battle_resource_snapshot().qi == 0.0, "skill pays before its first possible contact")
	var resources := d.battle_resource_snapshot()
	var p := d.pose()
	for i in range(25):
		check(d.pose() == p and d.battle_resource_snapshot() == resources, "pause sampling never restores qi or reduces cooldown")
	d.advance(0.0); d.advance(-5.0); d.advance(NAN)
	check(d.battle_resource_snapshot() == resources, "invalid or zero delta freezes resources")
	check(d._freeze_action("hero", 0.42), "a real interruption can cancel pending skill contacts")
	check(d.battle_resource_snapshot() == resources, "interruption doesn't refund cost or cooldown")
	for e in d.advance(3.0):
		check(not (e.type == "contact" and e.action_id == interrupted_id), "interrupted active never resolves a ghost contact")
	d.cancel()
	resources = d.battle_resource_snapshot()
	d.advance(1000.0)
	check(resources == d.battle_resource_snapshot(), "cancelled encounter never regenerates or advances cooldown offline")

func _test_restore_and_rest() -> void:
	var resource := {"qi": 7.25, "cooldowns": {"mist": 4.0, "ember": 6.0, "frost": 9.0, "weapon_sword_pierce": 8.0}}
	var d := make_duel(["mist"], "sword", {"battle_resources": resource})
	var snap := d.battle_resource_snapshot()
	check(snap.qi == 7.25 and snap.cooldowns.mist == 4.0 and snap.cooldowns.frost == 9.0, "start restores spent qi and all inactive ability cooldowns without offline advancement")
	var switched := make_duel(["frost"], "fan", {"battle_resources": snap})
	check(switched.battle_resource_snapshot().active_skills[0].remaining == 9.0 and switched.battle_resource_snapshot().cooldowns.weapon_sword_pierce == 8.0, "switching manuals or equipment cannot reset their retained cooldowns")
	var rested := Duel.rest_resource_snapshot(snap, 2.5, 80.0, 2.0)
	check(rested.qi == 12.25 and rested.cooldowns.frost == 6.5 and rested.cooldowns.mist == 1.5, "live travel advances every retained cooldown and qi by exact elapsed duration")
	check(Duel.rest_resource_snapshot(snap, 0.0, 80.0, 2.0) == snap and Duel.rest_resource_snapshot(snap, NAN, 80.0, 2.0) == snap, "paused/invalid rest is a pure unchanged snapshot")
	check(Duel.rest_resource_snapshot(snap, 100.0, 80.0, 4.0).qi == 80.0, "rest qi respects authored cap80")

func _test_partition() -> void:
	for ids in [["mist", "ember"], ["frost", "thunder"], ["barrier", "mending"]]:
		var a := make_duel(ids, "sword", {"max_hp": 400, "hp": 250})
		var b := make_duel(ids, "sword", {"max_hp": 400, "hp": 250})
		var c := make_duel(ids, "sword", {"max_hp": 400, "hp": 250})
		var ae: Array[Dictionary] = []
		var be: Array[Dictionary] = []
		for i in range(2400): ae.append_array(a.advance(0.025))
		for i in range(400): be.append_array(b.advance(0.15))
		var ce := c.advance(60.0)
		check(ae == be and be == ce, "small/medium/large dt exact events agree for active slots " + str(ids))
		check(a.hero_hp == c.hero_hp and a.enemy_hp == c.enemy_hp and a.battle_resource_snapshot() == c.battle_resource_snapshot(), "resources/statuses/HP partition determinism " + str(ids))
		var contacts := {}
		for e in ce:
			if e.type == "contact":
				check(not contacts.has(e.contact_id), "every skill/basic contact ID resolves once")
				contacts[e.contact_id] = true

func _test_support_effects() -> void:
	var barrier := make_duel(["barrier"], "unarmed", {"combat_qi_regen": 0.0, "battle_resources": {"qi": 16.0}}, {"attack": 12})
	var absorbed := 0
	var shields := 0
	for e in barrier.advance(9.0):
		if e.type != "contact": continue
		if e.get("shield_added", 0) > 0:
			shields += 1
			check(e.shield_added == 18 and e.damage == 0 and e.target == "hero", "ward contact adds18actualabsorption without attacking enemy")
		if e.actor == "enemy":
			absorbed += int(e.shield_absorbed)
			check(e.pre_hp - e.post_hp == e.damage, "shielded enemy hit reports actual reduced HPdelta")
	check(shields == 1 and absorbed > 0 and absorbed <= 18, "barrier spends once and consumes bounded realincomingdamage")
	check(barrier.pose().shield == 0, "spent or expired barrier is no longer shown active")
	var full := make_duel(["mending"], "unarmed", {"hp": 100, "max_hp": 100, "defense": 1000, "weapon_skill": {}}, {"attack": 1})
	for e in hero_starts(full.advance(2.0)): check(e.skill_id != "mending", "full health without status doesn't waste mending qi")
	var hurt := make_duel(["mending"], "unarmed", {"hp": 65, "max_hp": 100, "battle_resources": {"qi": 18.0}, "combat_qi_regen": 0.0}, {"attack": 1})
	var healed := 0
	for e in hurt.advance(4.0):
		if e.type == "contact" and e.get("heal", 0) > 0:
			healed += int(e.heal)
			check(e.post_hp - e.pre_hp == e.heal and e.post_hp <= 100 and e.damage == 0, "mending heals actual HP exactly without overheal/damage")
	check(healed == 18 and hurt.battle_resource_snapshot().qi == 0.0, "mending actual18heal uses exact18qi")
	var cleanse := make_duel(["mending"], "unarmed", {"hp": 100, "max_hp": 100, "combat_qi_regen": 0.0, "battle_resources": {"qi": 18.0}})
	cleanse.apply_slow("hero", 9.0)
	var cleansed := false
	for e in cleanse.advance(4.0):
		if e.type == "contact" and bool(e.get("cleansed_slow", false)): cleansed = true
	check(cleansed and cleanse.pose().hero_slow_remaining == 0.0, "mending clears an actual slowingstatus")

func _test_spell_effects_and_training() -> void:
	var frost := make_duel(["frost"], "unarmed")
	var slow_hit := false
	var slow_action := false
	for e in frost.advance(9.0):
		if e.type == "contact" and e.get("mechanic", "") == "frost_slow": slow_hit = true
		if e.type == "turn_started" and e.actor == "enemy" and bool(e.get("slowed", false)): slow_action = true
	check(slow_hit and slow_action, "frost successful contact genuinely slows nextenemy actiontiming")
	var thunder := make_duel(["thunder"], "unarmed")
	var lightning := []
	for e in thunder.advance(5.0):
		if e.type == "contact" and e.skill_id == "thunder": lightning.append(e)
	check(not lightning.is_empty() and lightning[0].poise_damage > 0.0 and lightning[0].mechanic == "thunder_poise", "thunder has actual increased postureimpact")
	var trained := manual("barrier"); trained.power_scale = 1.2
	var strong := make_duel([], "unarmed", {"active_skills": [trained]})
	var shield := 0
	for e in strong.advance(3.0):
		if e.type == "contact": shield = maxi(shield, int(e.get("shield_added", 0)))
	check(shield == 22, "manualtraining increases actual ward effect")
	var reductions := make_duel(["ember"], "unarmed", {"skill_cost_reduction": 9.0, "skill_cooldown_reduction": 9.0})
	var descriptor: Dictionary = reductions.battle_resource_snapshot().active_skills[0]
	check(is_equal_approx(descriptor.qi_cost, 11.7) and is_equal_approx(descriptor.cooldown, 4.9), "cost/cooldown reductions remain bounded at35/30percent")
