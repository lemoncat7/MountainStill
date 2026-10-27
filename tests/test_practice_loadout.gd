extends SceneTree
## Synthetic input snapshots, not naturally earned progression or win-rate proof.
const Loadout = preload("res://scripts/practice_loadout.gd")
const State = preload("res://scripts/cultivation_state.gd")
const Session = preload("res://scripts/practice_session.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Ink = preload("res://scripts/ink_pages.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)

func state_snapshot(s) -> String:
	var value: Dictionary = s._snapshot()
	value.erase("saved_at")
	return JSON.stringify(value)

func capture(s, enemy: Dictionary, style: String = "unarmed", seed: int = 17) -> Dictionary:
	return Loadout.capture(s, s.stats(), enemy, str(s.technique), style, seed)

func _initialize() -> void:
	var s = State.new()
	var enemy: Dictionary = Content.STAGES.bamboo_pass.monsters[0].duplicate(true)
	var before := state_snapshot(s)
	var snapshot := capture(s, enemy)
	check(int(snapshot.get("version", 0)) == 1, "versioned temporary snapshot")
	check(snapshot.get("combat_inputs") is Dictionary, "actual combat inputs retained")
	check(state_snapshot(s) == before, "capture leaves formal state and RNG untouched")
	var identical := Loadout.comparison(snapshot, snapshot.duplicate(true))
	check("相同" in identical, "identical comparison explained")
	check("未记录" in Loadout.comparison(snapshot, {}), "missing previous snapshot never claims identical")
	for incomplete in [{"version": 1}, {"version": 1, "combat_inputs": {}}, {"version": 2, "combat_inputs": {"hero": {}}, "equipment": {}}, {"version": 1, "combat_inputs": {"hero": {}}, "equipment": {}}, {"version": 1, "realm": 0, "combat_inputs": {"hero": {}, "enemy": {}, "technique": "mist", "style": "unarmed", "seed": 17}, "equipment": {}}]:
		check("未记录" in Loadout.comparison(snapshot, incomplete), "incomplete or future-version baseline is unrecorded")
		check(Loadout.rows(incomplete).is_empty(), "incomplete or future baseline has no fabricated rows")
	var rows: Array = Loadout.rows(snapshot)
	check(not rows.is_empty(), "readable loadout rows provided")
	for row in rows:
		check(row is Dictionary and row.has("label") and row.has("value"), "row has label and value")
	var frozen := snapshot.duplicate(true)
	var hero: Dictionary = s.stats()
	var captured := Loadout.capture(s, hero, enemy, str(s.technique), "unarmed", 17)
	var captured_before := captured.duplicate(true)
	hero.attack = 9999; enemy.hp = 99999
	check(captured == captured_before, "capture deep-copies source hero and enemy")
	enemy = Content.STAGES.bamboo_pass.monsters[0].duplicate(true)
	for key in ["attack", "defense", "max_hp", "combat_qi_max", "combat_qi_regen", "evasion_chance", "combat_haste", "skill_cost_reduction", "skill_cooldown_reduction"]:
		hero = s.stats(); hero[key] = float(hero.get(key, 0.0)) + 1.0
		var changed := Loadout.capture(s, hero, enemy, str(s.technique), "unarmed", 17)
		check(Loadout.comparison(changed, snapshot) != identical, "effective stat difference detected: " + key)
	for seed in [18, 19]:
		check(Loadout.comparison(capture(s, enemy, "unarmed", seed), snapshot) != identical, "different seed not identical input")
	var other_enemy: Dictionary = Content.STAGES.bamboo_pass.monsters[1].duplicate(true)
	check(Loadout.comparison(capture(s, other_enemy), snapshot) != identical, "different enemy input not identical")
	s.realm = 1
	check(Loadout.comparison(capture(s, enemy), snapshot) != identical, "realm progression detected")
	s.realm = 0
	s.combat_tactic = "guarded"
	check(Loadout.comparison(capture(s, enemy), snapshot) != identical, "tactic change detected")
	s.combat_tactic = "balanced"
	s.gear.inventory = [s.gear._make_item(1, "weapon_sword", "common", 1)]
	s.gear.equip_item(1)
	var sword := capture(s, enemy, "sword")
	check(Loadout.comparison(sword, snapshot) != identical, "weapon change detected")
	s.gear.enhance_item(1)
	check(Loadout.comparison(capture(s, enemy, "sword"), sword) != identical, "same named weapon enhancement detected")
	s.gear.inventory.append(s.gear._make_item(2, "chest_jade", "uncommon", 1))
	s.gear.equip_item(2)
	var armor := capture(s, enemy, "sword")
	s.gear.enhance_item(2)
	check("不同" in Loadout.comparison(capture(s, enemy, "sword"), armor), "armor enhancement not hidden behind unchanged weapon labels")
	check(snapshot == frozen, "later formal loadout changes cannot rewrite old snapshot")
	# Highest owned tiers and every legal method slot must remain readable without ellipsis.
	var full = State.new()
	full.realm = 15
	var item_id := 1
	for template in ["weapon_fan", "head_crown", "chest_blue", "legs_blue", "feet_boots"]:
		full.gear.inventory.append(full.gear._make_item(item_id, template, "epic", 15, 5))
		full.gear.equip_item(item_id); item_id += 1
	for id in Content.TECHNIQUES:
		full.technique_levels[id] = int(Content.TECHNIQUES[id].max_level)
		if not full.attuned_techniques.has(id): full.attuned_techniques.append(id)
	full.equipped_weapon_art = "mist" # legal remembered slot, incompatible held weapon
	full.equipped_heart = "stillness"
	full.equipped_actives.assign(["mist", "barrier"])
	full.equipped_passives.assign(["body"])
	var mist_text := Loadout._method(full.technique_descriptor("mist"))
	check("招式未启" in mist_text and not "未生效" in mist_text, "incompatible mist labels unavailable move, not retained stat bonus")
	full.gear.unequip_slot("weapon")
	full.equipped_weapon_art = "petal"
	var petal_text := Loadout._method(full.technique_descriptor("petal"))
	check("仅身法" in petal_text and not "招式未启" in petal_text, "unarmed petal retains movement contribution")
	full.gear.equip_item(1); full.equipped_weapon_art = "mist"
	for row in Loadout.rows(capture(full, enemy, "fan")):
		var wrapped: Array[String] = Ink._wrapped_lines(str(row.value), 294, 14, 40)
		check(wrapped.size() <= 4, "maximum loadout fits four 14px lines: " + str(row.label))
		check(not "…" in "".join(wrapped), "maximum loadout not ellipsized: " + str(row.label))
	check("兵器" in Loadout.comparison(sword, snapshot), "changed category points to weapon")
	check("衣冠" in Loadout.comparison(capture(s, enemy, "sword"), armor), "changed category points to enhanced armor")
	var session = Session.new()
	hero = s.stats()
	var battle := Loadout.capture(s, hero, enemy, str(s.technique), "sword", 17)
	var battle_frozen := battle.duplicate(true)
	check(session.start(hero, enemy, str(s.technique), "sword", 17, battle).ok, "session accepts actual-start snapshot")
	battle.clear()
	check(session.report().get("practice_loadout", {}) == battle_frozen, "session owns deep immutable copy at start")
	var exposed: Dictionary = session.report()
	exposed.practice_loadout.clear()
	check(session.report().get("practice_loadout", {}) == battle_frozen, "running report cannot mutate snapshot")
	session.advance(120.0)
	check(session.status().finished, "bounded trial finishes")
	exposed = session.report(); exposed.practice_loadout.clear()
	check(session.report().get("practice_loadout", {}) == battle_frozen, "finished report cannot mutate snapshot")
	check(session.start(hero, enemy).ok, "legacy start remains supported")
	check(session.report().get("practice_loadout", {}).is_empty(), "legacy start never inherits previous snapshot")
	session.cancel()
	check(not session.start({}, enemy).ok, "invalid start rejected")
	check(session.report().is_empty(), "invalid start cannot expose stale snapshot")
	print("Practice loadout: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
