extends SceneTree
## Purchases must change actual timeline outcomes, not just sheet labels.
const State = preload("res://scripts/cultivation_state.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
var checks := 0
var failures := 0
const ENEMY := {"id": "meridian_test", "visual_type": "moss_beast", "hp": 10000, "attack": 10, "defense": 0, "dodge_chance": 0.0, "guard_chance": 0.0}

func _initialize() -> void:
	_test_tempo_and_pressure()
	_test_defense_odds()
	_test_earned_counter()
	_test_earned_break_followup()
	print("Meridian combat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func build(ids: Array, realm: int = 3, style: String = "mist"):
	var s := State.new()
	s.realm = realm
	s.auto_advance = false
	s.qi = 100000
	s.herbs = 10000
	s.dew = 10000
	s.technique_levels[style] = 1
	check(s.attune_technique(style).ok, "test build attunes its actual chosen manual")
	for equipped_id in s.equipped_actives.duplicate():
		check(s.unequip_technique(equipped_id, "active").ok, "test isolates its chosen active manual")
	if style in ["mist", "petal"]:
		var template := "weapon_sword" if style == "mist" else "weapon_fan"
		s.gear.inventory.append(s.gear._make_item(1, template, "common", 1))
		check(s.equip_item(1), "test equips a real compatible weapon instance")
	check(s.select_technique(style), "test equips the actual learned and attuned manual")
	for id in ids:check(s.unlock_meridian(id).ok, "real paid node " + str(id))
	return s
func start(s, seed_value: int = 1, enemy_changes: Dictionary = {}):
	var d := Duel.new()
	var stats: Dictionary = s.stats()
	stats.max_hp = 10000
	var target: Dictionary = ENEMY.duplicate(true)
	target.merge(enemy_changes, true)
	d.start(stats, target, s.technique, str(s.gear.visual_loadout().get("weapon", "")), seed_value)
	return d
func contact(d, actor: String, counter: bool = false) -> Dictionary:
	for tick in range(600):
		for event in d.advance(0.05):
			if event.type == "contact" and event.actor == actor and (not counter or bool(event.get("counter", false))):return event
	return {}
func _test_tempo_and_pressure() -> void:
	var base = build(["qihai"], 1)
	var edge = build(["qihai", "shangyang"], 1)
	var base_hit := contact(start(base), "hero")
	var edge_hit := contact(start(edge), "hero")
	check(base_hit.damage == edge_hit.damage and edge_hit.poise_damage > base_hit.poise_damage, "商阳 increases real contact pressure without inflating damage")
	check(is_equal_approx(edge_hit.poise_damage / base_hit.poise_damage, 1.08), "paid 8% break modifier consumed exactly")
	var swift = build(["qihai", "shangyang", "hegu"], 1)
	var edge_duel = start(edge)
	var swift_duel = start(swift)
	var normal_action: Dictionary = edge_duel._lanes.hero.action
	var swift_action: Dictionary = swift_duel._lanes.hero.action
	# The wide opening can be limited by the physical approach floor. Haste
	# still changes its strike and real contact, but cannot shorten required steps.
	check(normal_action.windup > float(Duel.BASIC_MOVES[normal_action.move].windup), "wide opening actually exercises the physical approach floor")
	check(swift_action.contacts[0].time < normal_action.contacts[0].time and is_equal_approx(normal_action.strike / swift_action.strike, 1.04), "合谷 accelerates the actual strike/contact even with an approach floor")
	check(contact(swift_duel, "hero").time < contact(edge_duel, "hero").time, "haste reaches a real hit sooner")
	# Match native normal-foe spacing at 1200px, where the authored windup
	# rather than travel time is limiting. Keep exact paid-modifier coverage.
	var in_range := {"route_id": "bamboo_pass", "engagement_distance": 88.0 * 1200.0 / 1040.0}
	var close_normal = start(edge, 1, in_range)
	var close_swift = start(swift, 1, in_range)
	var close_action: Dictionary = close_normal._lanes.hero.action
	var close_fast: Dictionary = close_swift._lanes.hero.action
	check(is_equal_approx(close_action.windup / close_fast.windup, 1.04), "合谷 applies its exact 4% haste to an actual in-range windup")
	check(close_fast.contacts[0].time < close_action.contacts[0].time and close_fast.end < close_action.end, "in-range haste advances both contact and next action opportunity")
	var close_hit := contact(close_normal, "hero")
	var close_fast_hit := contact(close_swift, "hero")
	check(close_fast_hit.time < close_hit.time and close_hit.damage > 0 and close_fast_hit.damage == close_hit.damage, "in-range haste lands real damage sooner without changing its amount")
	var rooted = build(["qihai", "lieque"])
	var recovered = build(["qihai", "lieque", "jianshi"])
	var rooted_duel = start(rooted)
	var recovered_duel = start(recovered)
	check(is_equal_approx(recovered_duel._lanes.hero.action.recovery, rooted_duel._lanes.hero.action.recovery * 0.96), "间使 shortens the actual recovery window")
	check(recovered_duel._lanes.hero.action.end < rooted_duel._lanes.hero.action.end, "recovery modifier advances the next action opportunity")
	var bare = build(["qihai"])
	var bare_duel = start(bare)
	check(is_equal_approx(rooted_duel.pose().hero.max_poise - bare_duel.pose().hero.max_poise, 4.0), "列缺 increases the live displayed and operative poise threshold")
	var bare_enemy := contact(bare_duel, "enemy")
	var rooted_enemy := contact(rooted_duel, "enemy")
	check(is_equal_approx(rooted_enemy.poise_threshold - bare_enemy.poise_threshold, 4.0), "real enemy contact reads the raised poise threshold")
func _test_defense_odds() -> void:
	var baseline = build(["qihai"], 1)
	var guarded = build(["qihai", "lieque", "neiguan"], 1)
	var dodging = build(["qihai", "taixi"], 1)
	var base_guards := 0
	var improved_guards := 0
	var base_dodges := 0
	var improved_dodges := 0
	for seed_value in range(1, 257):
		var a := contact(start(baseline, seed_value), "enemy")
		var b := contact(start(guarded, seed_value), "enemy")
		var c := contact(start(dodging, seed_value), "enemy")
		base_guards += int(a.resolution == "guard")
		improved_guards += int(b.resolution == "guard")
		base_dodges += int(a.resolution == "dodge")
		improved_dodges += int(c.resolution == "dodge")
		if b.resolution == "guard":check(b.damage < b.unguarded_damage, "paid guard outcome really mitigates damage")
		if c.resolution == "dodge":check(c.damage == 0, "paid dodge outcome really avoids damage")
	check(improved_guards > base_guards, "内关 increases actual resolved guards across identical seeds")
	check(improved_dodges > base_dodges, "太溪 increases actual resolved zero-damage dodges across identical seeds")
	print("MERIDIAN DEFENSE paired first contacts: guard %d -> %d, dodge %d -> %d / 256 seeds" % [base_guards, improved_guards, base_dodges, improved_dodges])
func _test_earned_counter() -> void:
	var basic = build(["qihai", "taixi"], 3, "petal")
	var tuned = build(["qihai", "taixi", "zhaohai"], 3, "petal")
	var found := false
	for seed_value in range(1, 33):
		var a := contact(start(basic, seed_value), "hero", true)
		var b := contact(start(tuned, seed_value), "hero", true)
		if a.is_empty() or b.is_empty():continue
		check(a.counter_kind == "dodge_chase" and b.counter_kind == "dodge_chase", "counter bonus requires a real earned dodge response")
		check(is_equal_approx(b.counter_multiplier - a.counter_multiplier, 0.08) and b.raw_damage > a.raw_damage, "照海 increases real earned counter damage")
		found = true
		break
	check(found, "actual petal combat earns a tested counter")

func _test_earned_break_followup() -> void:
	for style in ["mist", "ember"]:
		var basic = build(["qihai", "shangyang", "hegu", "quchi"], 6, style)
		var tuned = build(["qihai", "shangyang", "hegu", "quchi", "jianjing"], 6, style)
		var found := false
		for seed_value in range(1, 33):
			var a := contact(start(basic, seed_value), "hero", true)
			var b := contact(start(tuned, seed_value), "hero", true)
			if a.is_empty() or b.is_empty():continue
			check(a.counter_kind == "break_followup" and b.counter_kind == "break_followup", "real " + style + " interrupt earns a follow-up")
			check(is_equal_approx(b.counter_multiplier - a.counter_multiplier, 0.10) and b.raw_damage > a.raw_damage, "肩井 changes " + style + " earned break follow-up damage")
			found = true
			break
		check(found, style + " has a real tested use for the 劲锋 terminal")
