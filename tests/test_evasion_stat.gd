extends SceneTree
## The displayed rate is the one the single prepared defense roll consumes.
## Isolated saves only; no player progress or RNG streams are touched.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
var checks := 0
var failures := 0
var save_path := "user://evasion_stat_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_test_probability_boundaries()
	_test_sources_and_compatibility()
	_test_persistence()
	_test_single_contact_roll()
	_test_planted_reach()
	_test_live_outcomes()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix): DirAccess.remove_absolute(save_path + suffix)
	print("Evasion stat: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func same(a: float, b: float, label: String) -> void:
	check(is_equal_approx(a, b), "%s (%.8f / %.8f)" % [label, a, b])

func build() -> State:
	var s := State.new()
	s.realm = 12
	s.auto_advance = false
	s.herbs = 100000
	s.dew = 100000
	s.qi = 100000.0
	s.technique_levels.petal = 1
	check(s.attune_technique("petal").ok, "learned movement manual is attuned")
	for id in s.equipped_actives.duplicate(): s.unequip_technique(id, "active")
	s.gear.inventory.append(s.gear._make_item(1, "weapon_sword", "common", 1))
	s.gear.inventory.append(s.gear._make_item(2, "weapon_fan", "common", 1))
	s.gear.inventory.append(s.gear._make_item(3, "feet_cloth", "common", 1))
	s.gear.inventory.append(s.gear._make_item(4, "feet_boots", "epic", 100))
	check(s.equip_item(1), "fixture holds an owned sword")
	return s

func start(s: State, seed_value: int = 7, enemy_changes: Dictionary = {}) -> Duel:
	var stats := s.stats()
	stats.hp = 100000
	stats.max_hp = 100000
	stats.attack = 1
	stats.defense = 0
	var enemy := {"hp":100000, "max_hp":100000, "attack":10, "defense":0, "visual_type":"river_stone", "route_id":"creek_bridge", "dodge_chance":0.0, "guard_chance":0.0}
	enemy.merge(enemy_changes, true)
	var d := Duel.new()
	d.start(stats, enemy, s.technique, str(s.gear.visual_loadout().weapon), seed_value)
	return d

func _test_probability_boundaries() -> void:
	for roll in [0.0, 0.25, 0.5, 0.999999, 1.0]:
		check(Duel.defense_result(roll, 0.0, 0.0) == "hit", "zero evasion never evades at every boundary")
		check(Duel.defense_result(roll, 1.0, 0.0) == "dodge", "unit probability always evades in pure threshold")
		check(Duel.defense_result(roll, 0.0, 1.0) == "guard", "unit guard always blocks without evade")
	same(Content.evasion_breakdown(0.05, 0.4, 10.0, 10.0).chance, 0.72, "all source totals hard cap at 72 percent")
	same(Content.evasion_for_phase(1.0, "ready"), 0.72, "supplied unit combat chance still respects cap")
	same(Content.evasion_for_phase(1.0, "strike"), 0.72 * 0.15, "cap applies before committed penalty")
	same(Content.evasion_for_phase(0.5, "contact"), 0.075, "contact retains fifteen percent")
	same(Content.evasion_for_phase(0.5, "stagger"), 0.0, "stagger cannot evade")
	same(Content.evasion_for_phase(-2.0, "ready"), 0.0, "negative odds clamp to zero")
	same(Content.evasion_for_phase(NAN, "ready"), 0.0, "nonfinite odds cannot enter probability")
	check(Duel.defense_result(0.719999, 0.72, 0.0) == "dodge" and Duel.defense_result(0.72, 0.72, 0.0) == "hit", "exact cap threshold has no off by one")
	check(Duel.defense_result(0.3, 0.2, 0.5) == "guard" and Duel.defense_result(0.2 + (1.0 - 0.2) * 0.5, 0.2, 0.5) == "hit", "guard uses remaining probability after evade once")

func _test_sources_and_compatibility() -> void:
	var s := build()
	same(s.stats().evasion_chance, 0.05, "collected or attuned-only movement grants no evasion")
	check(s.equip_technique("petal", "active").ok, "petal fits a real active slot with sword")
	same(s.stats().evasion_chance, 0.40, "sword can use the equipped manual's body effect")
	var manual := s.technique_descriptor("petal")
	check(manual.movement_active and not manual.active and not manual.compatible, "body effect and fan attack availability are distinct")
	for event in start(s).advance(30.0):
		if event.type == "turn_started" and event.actor == "hero":
			check(not str(event.move).begins_with("petal") and not str(event.move).contains("fan"), "sword never invents incompatible fan attacks")
	check(s.equip_technique("petal", "weapon_art").ok, "same manual can use both legal slots")
	same(s.stats().evasion_chance, 0.40, "two equipped slots do not double count movement")
	s.technique_levels.petal = 5
	same(s.stats().evasion_chance, 0.472, "each additional movement rank adds exact 1.8 points")
	check(s.unequip_slot("weapon"), "weapon unequips")
	same(s.stats().evasion_chance, 0.472, "empty hands retain body-method defense")
	check(s.equip_item(2), "compatible fan equips")
	check(s.technique_descriptor("petal").active, "fan attacks reactivate with compatible actual item")
	same(s.stats().evasion_chance, 0.472, "fan does not grant a duplicate body effect")
	check(s.equip_item(3), "cloth shoes equip")
	same(s.stats().evasion_chance, 0.492, "cloth footwear adds two points immediately")
	check(s.equip_item(4), "cloud boots replace shoes")
	same(s.stats().evasion_chance, 0.512, "boots add four points with no rarity or level inflation")
	check(s.enhance_item(4).ok, "real upgrade succeeds")
	same(s.stats().evasion_chance, 0.514, "equipped upgrade recomputes extra 0.2 points")
	for id in ["qihai", "taixi", "zhaohai", "xuanzhong", "fengchi"]:
		check(s.unlock_meridian(id).ok, "real meridian purchase " + id)
	same(s.stats().evasion_chance, 0.584, "paid meridians add exactly seven points")
	var sources: Dictionary = s.stats().evasion_sources
	same(sources.base + sources.movement + sources.equipment + sources.meridian, sources.chance, "visible source sum agrees with full live total")
	same(start(s).defense_chances("enemy").evasion_chance, sources.chance, "timeline reads full total without adding meridians again")
	check(s.unequip_slot("feet"), "boots remove")
	same(s.stats().evasion_chance, 0.542, "unequip immediately removes full shoe contribution")
	check(s.unequip_technique("petal", "weapon_art").ok and s.unequip_technique("petal", "active").ok, "movement manual fully unequips")
	same(s.stats().evasion_chance, 0.12, "unequip removes body effect while preserving meridians")

func _test_persistence() -> void:
	var s := build()
	check(s.equip_technique("petal", "active").ok and s.equip_item(4), "save fixture has body method and boots")
	check(s.unlock_meridian("qihai").ok and s.unlock_meridian("taixi").ok, "save fixture has purchased evasion node")
	s.settings.paused = true
	s.save_path = save_path
	var wanted := float(s.stats().evasion_chance)
	check(s.save_game(), "save succeeds in isolated path")
	var raw: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(save_path))
	check(int(raw.version) == 4 and not raw.has("evasion_chance"), "derived rate creates no save schema or cached stat")
	var restored := State.new()
	restored.save_path = save_path
	check(restored.load_game().loaded, "existing v4 sources reload")
	same(restored.stats().evasion_chance, wanted, "load recomputes exactly the same combined rate")
	check(restored.gear.equipped == s.gear.equipped and restored.meridian_node_ids() == s.meridian_node_ids(), "saved gear and purchased nodes are preserved")
	check(restored.gear.rng.state == s.gear.rng.state, "no load reroll changes loot RNG")
	restored.gear.get_item(4)["evasion_bonus"] = 999.0
	same(restored.stats().evasion_chance, wanted, "item-supplied fake evasion cannot override canonical template")
	restored.gear.unequip_slot("feet")
	same(restored.stats().evasion_chance, wanted - 0.04, "loaded equipment changes recompute immediately")

func _test_single_contact_roll() -> void:
	var s := build()
	var d := start(s, 42, {"engagement_distance":900.0})
	var probe := RandomNumberGenerator.new()
	probe.state = d._rng.state
	var expected_roll := probe.randf()
	var prepared := {}
	d._roll_resolution("enemy", prepared)
	same(prepared.defense_roll, expected_roll, "preparation consumes exactly one predictable roll")
	check(d._rng.state == probe.state, "one random draw for combined dodge and guard")
	var action: Dictionary = d._lanes.hero.action
	var contact: Dictionary = action.contacts[0]
	contact.prepared = true
	contact.resolution = "hit"
	contact.evasion_chance = 0.72
	contact.defense_roll = 0.9
	d.elapsed = float(action.start) + float(contact.time)
	var rng_before: int = d._rng.state
	var event := d._resolve_contact("hero", action, contact)
	check(event.resolution == "whiff" and event.damage == 0, "out of range contact remains a genuine miss")
	check(d._rng.state == rng_before and not d._counter_ready, "miss never rerolls evade or grants defensive counter")
	for sample in range(100): d.pose()
	check(d._rng.state == rng_before, "visual sampling never rerolls defense")
	contact.resolution = "dodge"
	var dodge := d._resolve_contact("hero", action, contact)
	check(dodge.resolution == "whiff" and not dodge.planted_contact.contact and dodge.damage == 0 and dodge.pre_hp == dodge.post_hp, "prepared dodge at impossible reach remains a whiff, no fake success")
	check(not d._counter_ready, "out of range prepared dodge grants no counter")
	check(d._rng.state == rng_before, "finalizing prepared evade cannot roll it a second time")

func _test_planted_reach() -> void:
	var s := build()
	check(s.equip_technique("petal", "active").ok, "planted-reach fixture has real body-method defense")
	var valid_hero_dodges := 0
	var valid_enemy_dodges := 0
	var moved_outside_reach := 0
	for species in ["moss_beast", "cloud_crane"]:
		for seed_value in range(1, 7):
			var d := start(s, seed_value, {"visual_type":species, "route_id":"cloud_slope" if species == "cloud_crane" else "bamboo_pass", "dodge_chance":0.72})
			for event in d.advance(24.0):
				if event.type != "contact" or event.resolution != "dodge": continue
				check(event.has("planted_contact") and event.planted_contact.contact, "genuine dodge requires in-range planted defender")
				check(event.damage == 0 and event.pre_hp == event.post_hp, "in-range planted evade still avoids all damage")
				if event.target == "hero": valid_hero_dodges += 1
				else: valid_enemy_dodges += 1
				var actual: Dictionary = event.get("melee_contact", event.get("enemy_contact", {}))
				if not bool(actual.get("contact", false)): moved_outside_reach += 1
		# Stop a real monster attack far short and prepare a successful evade.
		# Its planted reach must reject it regardless of the pre-drawn result.
		var far := start(s, 3, {"visual_type":species, "route_id":"cloud_slope" if species == "cloud_crane" else "bamboo_pass", "engagement_distance":900.0})
		far.advance(0.18)
		var action: Dictionary = far._lanes.enemy.action
		var contact: Dictionary = action.contacts[0]
		contact.resolution = "dodge"
		contact.prepared = true
		far.elapsed = float(action.start) + float(contact.time)
		var rng_before: int = far._rng.state
		var event := far._resolve_contact("enemy", action, contact)
		check(event.resolution == "whiff" and not event.planted_contact.contact and not far._counter_ready, "out-of-range monster cannot earn a dodge or counter: " + species)
		check(event.damage == 0 and far._rng.state == rng_before, "miss checks geometry with no second roll: " + species)
	check(valid_hero_dodges > 0 and valid_enemy_dodges > 0, "planted reach preserves real dodges for both sides")
	check(moved_outside_reach > 0, "successful evade may move beyond actual reach without being mislabeled whiff")

func _test_live_outcomes() -> void:
	var s := build()
	check(s.equip_technique("petal", "active").ok, "live dodge fixture has real equipped body method")
	var seen_dodge := 0
	var seen_guard := 0
	var d := start(s, 77)
	for event in d.advance(120.0):
		if event.type != "contact" or event.target != "hero": continue
		same(event.evasion_chance, Content.evasion_for_phase(float(s.stats().evasion_chance), str(event.defense_phase)), "event records actual phase-adjusted displayed chance")
		check(event.resolution == Duel.defense_result(event.defense_roll, event.evasion_chance, event.guard_chance), "actual result agrees with its sole stored roll")
		if event.resolution == "dodge":
			seen_dodge += 1
			check(event.damage == 0 and event.pre_hp == event.post_hp and event.poise_damage == 0.0, "live evasion avoids health and posture damage")
		elif event.resolution == "guard":
			seen_guard += 1
			check(event.damage < event.unguarded_damage, "live guard reduces rather than relabels damage")
	check(seen_dodge > 5 and seen_guard > 0, "deterministic seed exercises real dodge and reduced guard outcomes")
	var large := start(s, 89)
	var small := start(s, 89)
	var a := large.advance(30.0)
	var b: Array[Dictionary] = []
	for frame in range(300): b.append_array(small.advance(0.1))
	check(a == b, "new stat and audit fields retain partition-independent deterministic combat")
