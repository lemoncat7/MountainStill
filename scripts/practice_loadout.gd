extends RefCounted
## Ephemeral evidence only. Capture from the very inputs handed to Session.start;
## never consult live State while displaying an old trial.
const TACTICS := {"balanced": "均衡", "assault": "强攻", "guarded": "守势", "frugal": "节气"}
const PEACEFUL_KEYS := ["qi_rate", "need_qi", "need_herbs", "progress", "activity", "pill_qi", "merit", "herb_progress", "dew_progress", "brew_progress", "gather_multiplier", "brew_multiplier", "campaign_complete", "story_resolved", "ending_complete", "max_realm"]
const SLOTS := ["weapon", "head", "chest", "legs", "feet"]

static func capture(state, hero: Dictionary, enemy: Dictionary, technique: String, style: String, seed: int) -> Dictionary:
	var combat := hero.duplicate(true)
	for key in PEACEFUL_KEYS: combat.erase(key)
	combat.max_hp = clampi(int(combat.get("max_hp", 100)), 1, 100000)
	combat.hp = combat.max_hp
	combat.erase("battle_resources")
	var equipment: Dictionary = {}
	for slot in SLOTS: equipment[slot] = state.gear.equipped_item(slot).duplicate(true)
	return {"version": 1, "realm": int(state.realm), "equipment": equipment,
		"combat_inputs": {"hero": combat, "enemy": enemy.duplicate(true), "technique": technique, "style": style, "seed": seed}}

static func valid(snapshot: Dictionary) -> bool:
	if snapshot.get("version") != 1 or not snapshot.get("realm") is int: return false
	if not snapshot.get("combat_inputs") is Dictionary or not snapshot.get("equipment") is Dictionary: return false
	var inputs: Dictionary = snapshot.combat_inputs
	if not inputs.get("hero") is Dictionary or not inputs.get("enemy") is Dictionary: return false
	if not inputs.get("technique") is String or not inputs.get("style") is String or not inputs.get("seed") is int: return false
	for slot in SLOTS:
		if not snapshot.equipment.get(slot) is Dictionary: return false
	for key in ["weapon_art", "heart_method", "weapon_skill"]:
		if not inputs.hero.get(key, {}) is Dictionary: return false
	for key in ["active_skills", "passive_methods"]:
		if not inputs.hero.get(key, []) is Array: return false
	return true

static func comparison(current: Dictionary, previous: Dictionary) -> String:
	if not valid(current) or not valid(previous): return "搭配未记录，无法核对上次出战条件。"
	var same: bool = current.combat_inputs == previous.combat_inputs and current.equipment == previous.equipment and current.get("realm") == previous.get("realm")
	if same: return "出战记录相同 · 可观察同搭配重试"
	var changed: Array[String] = []
	var now_rows: Array = rows(current)
	var old_rows: Array = rows(previous)
	var names := ["境界/属性", "兵器", "衣冠", "衣冠", "武式/心法", "主动/辅修", "战术/真气"]
	for i in range(now_rows.size()):
		if now_rows[i].value != old_rows[i].value and not changed.has(names[i]): changed.append(names[i])
	if changed.is_empty(): changed.append("其他出战输入")
	return "出战记录不同 · " + "、".join(changed.slice(0, 2)) + ("等" if changed.size() > 2 else "")

static func _method(method: Dictionary) -> String:
	if method.is_empty(): return "未装配"
	var note := ""
	if not bool(method.get("active", false)):
		note = "（仅身法）" if bool(method.get("movement_active", false)) else "（招式未启）"
	return "%s %d重%s" % [str(method.get("name", "功法")), int(method.get("level", 0)), note]

static func _methods(methods: Array) -> String:
	var names: Array[String] = []
	for method in methods:
		if method is Dictionary: names.append(_method(method))
	return "未装配" if names.is_empty() else "\n".join(names)

static func _item(item: Dictionary) -> String:
	if item.is_empty(): return "未装备"
	return "%s · %s\n%d阶 · 温养+%d" % [str(item.get("name", "装备")), str({"common":"普通","uncommon":"精良","rare":"稀有","epic":"史诗"}.get(str(item.get("rarity", "")), "")), int(item.get("level", 1)), int(item.get("enhancement", 0))]

static func rows(snapshot: Dictionary) -> Array:
	if not valid(snapshot): return []
	var hero: Dictionary = snapshot.combat_inputs.hero
	var gear: Dictionary = snapshot.equipment
	return [
		{"label": "境界与实际属性", "value": "%s\n攻%d · 防%d · 气血%d\n闪避%.1f%% · 速度%.1f" % [str(hero.get("realm_name", "境界未记录")), int(hero.get("attack", 0)), int(hero.get("defense", 0)), int(hero.get("max_hp", 0)), 100.0 * float(hero.get("evasion_chance", 0.0)), float(hero.get("speed", 100.0))]},
		{"label": "兵器与温养", "value": _item(gear.get("weapon", {})) + "\n" + str(hero.get("weapon_skill", {}).get("name", "徒手普攻"))},
		{"label": "衣冠 · 头 / 身", "value": _item(gear.get("head", {})) + "\n" + _item(gear.get("chest", {}))},
		{"label": "衣冠 · 腿 / 足", "value": _item(gear.get("legs", {})) + "\n" + _item(gear.get("feet", {}))},
		{"label": "武式与心法", "value": "武式 · " + _method(hero.get("weapon_art", {})) + "\n心法 · " + _method(hero.get("heart_method", {}))},
		{"label": "主动栏与辅修", "value": _methods(hero.get("active_skills", [])) + "\n辅修 · " + _methods(hero.get("passive_methods", []))},
		{"label": "战术与真气", "value": "战术 · " + str(TACTICS.get(str(hero.get("combat_tactic", "balanced")), "均衡")) + "\n真气%.1f · 恢复%.2f/秒\n节耗%.1f%% · 调息%.1f%%" % [float(hero.get("combat_qi_max", 0.0)), float(hero.get("combat_qi_regen", 0.0)), 100.0 * float(hero.get("skill_cost_reduction", 0.0)), 100.0 * float(hero.get("skill_cooldown_reduction", 0.0))]}
	]
