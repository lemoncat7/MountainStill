class_name CultivationState
extends RefCounted
## Peaceful cultivation never fails; optional manual adventures retain checkpoints.
## Auto mode meditates first, gathers needed materials, then advances realms.
## A manual activity choice leaves auto mode until the player enables it again.

const Equipment = preload("res://scripts/equipment_ledger.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Materials = preload("res://scripts/material_registry.gd")
const MaterialInventory = preload("res://scripts/material_ledger.gd")
const PlayerJourney = preload("res://scripts/player_journey.gd")
const SEARCH_SECONDS := 2.0

const REALM_NAMES = Content.REALM_NAMES
const ACTIVITY_NAMES := {"meditate": "静坐吐纳", "gather": "采集灵草", "brew": "温火炼丹"}
# Cosmetic compatibility is deliberately separate from learned passive bonuses.
const APPEARANCE_OPTIONS := {"outfit": ["moon", "jade"], "weapon": ["sword", "fan"], "technique": ["mist", "petal", "ember", "stillness", "breath", "frost", "thunder", "barrier", "body", "mending"]}
const DEFAULT_APPEARANCE := {"outfit": "moon", "weapon": "sword", "technique": "mist"}
const QI_COSTS = Content.QI_COSTS
const HERB_COSTS = Content.HERB_COSTS
const QI_RATES = Content.QI_RATES
const MAX_REALM := 15
const MAX_RESOURCE := 2000000000
const MAX_ENERGY := 1.0e12
const OFFLINE_CAP_SECONDS := 8 * 60 * 60
const MIN_VALID_TIMESTAMP := 1704067200
const MAX_VALID_TIMESTAMP := 4102444800
const EPSILON := 0.000001
const DEFAULT_SETTINGS := {
	"music": 0.3, "sfx": 0.5, "low_power": false,
	"always_on_top": false, "transparent": true,
	"click_through": false, "width": 1200,
	"window_mode": "strip", "window_x": -99999, "window_y": -99999, "paused": false,
}

var gear = Equipment.new()
var materials = MaterialInventory.new()
var inventory: Array:
	get:
		return gear.inventory
var equipped: Dictionary:
	get:
		return gear.equipped
var chest_count: int:
	get:
		return gear.chests
	set(value):
		gear.chests = clampi(value, 0, Equipment.MAX_CHESTS)
var total_victories: int = 0
# Retained as a read-compatible legacy property. Combat is always opt-in.
var expedition_auto: bool:
	get:
		return false
	set(_value):
		pass
var selected_stage: String = "bamboo_pass"
var stage_run: Dictionary = {}
var stage_clears: Dictionary = {}
var chapter_reward_claimed: Dictionary = {}
var legacy_unlocked_stages: Dictionary = {}
var story_resolved_at: float = -1.0
var ending_finished_at: float = -1.0
var pending_opportunity: Dictionary = {}
# Explicit IDs preserve branch choices. The old count property remains a legacy
# fixture/import adapter only: assigning it opens at most the original six.
var meridian_opened: Dictionary = {}
var meridian_count: int:
	get:
		return meridian_opened.size()
	set(value):
		meridian_opened.clear()
		for index in range(clampi(value, 0, Content.LEGACY_ACUPOINT_IDS.size())):
			meridian_opened[Content.LEGACY_ACUPOINT_IDS[index]] = true
var _stage_serial: int = 0
var _stage_active: bool = false
var _adventure_rng := RandomNumberGenerator.new()
var realm: int = 0
var qi: float = 0.0
var herbs: int = 3
var dew: int = 1
var pill_stocks: Dictionary = {"qi": 0, "spring": 0, "clarity": 0}
var pills: int:
	get:
		return int(pill_stocks.get("qi", 0))
	set(value):
		pill_stocks["qi"] = clampi(value, 0, MAX_RESOURCE)
var recipe: String = "qi"
var technique_levels: Dictionary = {}
var equipped_heart: String = ""
var equipped_weapon_art: String = "mist"
var equipped_actives: Array[String] = ["mist"]
var equipped_passives: Array[String] = []
var attuned_techniques: Array[String] = ["mist", "breath"]
var technique_training: Array[Dictionary] = []
var pending_heart_switch: Dictionary = {}
var heart_equipped_once: bool = false
var last_equipped_heart: String = ""
var _heart_switch_serial: int = 0
var _heart_quote_serial: int = 0
var _heart_quote: Dictionary = {}
# Compatibility read for callers that used the short-lived fixed spell slot.
var equipped_spell: String:
	get:
		for id in equipped_actives:
			if Content.TECHNIQUES.has(id) and String(Content.TECHNIQUES[id].category) == "spell":
				return id
		return ""
	set(value):
		if not value.is_empty():
			equip_technique(value, "active")
var buffs: Dictionary = {}
var journey: Dictionary = {}
var journey_bond: int = 0
var journey_completed: int = 0
var journey_last_result: Dictionary = {}
var discoveries: Dictionary = {}
var quest_claimed: Dictionary = {}
var counters: Dictionary = {}
var journal_entries: Array = []
var arrival_seen: bool = false
var guidance_dismissed: bool = false
var journey_skipped: Dictionary = {}
var brew_progresses: Dictionary = {}
var campaign_finished_at: float = -1.0
var _journey_rng := RandomNumberGenerator.new()
var _clock_high_water: int = 0
var merit: float = 0.0
var lifetime_seconds: float = 0.0
var activity: String = "meditate"
var outfit: String = "moon"
var weapon: String = "sword"
var technique: String = "mist"
var auto_advance: bool = false
# Keep the compact spelling available for UI integrations, too.
var autoadvance: bool:
	get:
		return auto_advance
	set(value):
		auto_advance = value
var activity_progress: float:
	get:
		if activity == "gather":
			return clampf(_gather_clock / 8.0, 0.0, 1.0)
		if activity == "brew":
			return clampf(_brew_clock / float(Content.RECIPES[recipe].seconds), 0.0, 1.0)
		return clampf(qi / float(QI_COSTS[realm]), 0.0, 1.0) if realm < MAX_REALM else 1.0
var last_offline: Dictionary = {}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate(true)
var save_path: String = "user://cultivation_save.json"
var _gather_clock: float = 0.0
var _dew_clock: float = 0.0
var _brew_clock: float = 0.0
var _last_step_gains: Dictionary = {}


func _init() -> void:
	new_game()


func new_game() -> void:
	gear.new_game()
	materials.new_game()
	total_victories = 0
	expedition_auto = false
	selected_stage = "bamboo_pass"
	stage_run = {}
	stage_clears = {}
	chapter_reward_claimed = {}
	legacy_unlocked_stages = {}
	story_resolved_at = -1.0
	ending_finished_at = -1.0
	pending_opportunity = {}
	meridian_count = 0
	_stage_serial = 0
	_stage_active = false
	_adventure_rng.randomize()
	realm = 0
	qi = 0.0
	herbs = 3
	dew = 1
	pill_stocks = {"qi": 0, "spring": 0, "clarity": 0}
	recipe = "qi"
	technique_levels = {}
	for id in Content.TECHNIQUES:
		technique_levels[id] = 1 if id in ["mist", "breath"] else 0
	equipped_heart = ""
	equipped_weapon_art = "mist"
	equipped_actives = ["mist"]
	equipped_passives = []
	attuned_techniques = ["mist", "breath"]
	technique_training = []
	pending_heart_switch = {}
	heart_equipped_once = false
	last_equipped_heart = ""
	_heart_switch_serial = 0
	_heart_quote_serial = 0
	_heart_quote = {}
	buffs = {}
	journey = {}
	journey_bond = 0
	journey_completed = 0
	journey_last_result = {}
	discoveries = {}
	quest_claimed = {}
	counters = {"gathered": 0, "brewed": 0, "pills_used": 0, "chests_opened": 0, "techniques_trained": 0, "enhanced": 0, "crafted": 0}
	journal_entries = []
	arrival_seen = false
	guidance_dismissed = false
	journey_skipped = {}
	brew_progresses = {"qi": 0.0, "spring": 0.0, "clarity": 0.0}
	campaign_finished_at = -1.0
	_journey_rng.randomize()
	_clock_high_water = 0
	merit = 0.0
	lifetime_seconds = 0.0
	activity = "meditate"
	outfit = "moon"
	weapon = "sword"
	technique = "mist"
	# New arrivals make their first paid breakthrough deliberately. Existing saves
	# restore their own choice; the optional quiet auto path still reaches归真.
	auto_advance = false
	settings = DEFAULT_SETTINGS.duplicate(true)
	_gather_clock = 0.0
	_dew_clock = 0.0
	_brew_clock = 0.0
	_last_step_gains = _empty_gains()
	last_offline = _offline_result()
	_record("入山 · 一盏清茶，一段不必赶路的修行。")


func realm_name() -> String:
	return REALM_NAMES[realm]


func player_journey_status() -> Dictionary:
	return PlayerJourney.status(self)


func player_journey_rows() -> Array:
	return PlayerJourney.rows(self)


func skip_player_journey_suggestion(id: String) -> bool:
	var current := player_journey_status()
	if id != String(current.id) or not bool(current.get("skippable", false)):
		return false
	journey_skipped[id] = true
	return true


func reset_player_journey_suggestions() -> void:
	journey_skipped.clear()
	guidance_dismissed = false


func breakthrough_preview() -> Dictionary:
	if realm >= MAX_REALM:
		return {"ready": false, "title": "此心归真", "cost": "修为已圆满", "unlocks": "功德继续积累；收藏、养成与重游仍可继续。"}
	var next := realm + 1
	var unlocked: Array[String] = []
	for id in Content.TECHNIQUES:
		if int(Content.TECHNIQUES[id].unlock_realm) == next:
			unlocked.append(String(Content.TECHNIQUES[id].name))
	for id in Content.CHAPTER_ORDER:
		if int(Content.STAGES[id].unlock_realm) == next:
			unlocked.append(String(Content.STAGES[id].name) + "（仍需前章通关）")
	if next == 3: unlocked.append("第二主动栏、辅修栏")
	if next == 6: unlocked.append("第二研习位")
	if next == MAX_REALM: unlocked.append("归真、归山终章资格")
	return {"ready": qi + EPSILON >= QI_COSTS[realm] and herbs >= HERB_COSTS[realm],
		"title": next_realm_name(), "cost": "消耗灵气 %d、灵草 %d；本次只升一阶。" % [QI_COSTS[realm], HERB_COSTS[realm]],
		"unlocks": "攻击 +2、气血 +4" + ("、防御 +1" if next % 3 == 0 else "") + "；" + ("、".join(unlocked) if not unlocked.is_empty() else "继续提高当前功法重数与装备成长空间。")}


func next_realm_name() -> String:
	return REALM_NAMES[realm + 1] if realm < MAX_REALM else "归真圆满"


func activity_name() -> String:
	return ACTIVITY_NAMES.get(activity, ACTIVITY_NAMES.meditate)


func set_activity(value: String) -> bool:
	if not ACTIVITY_NAMES.has(value):
		return false
	activity = value
	auto_advance = false
	return true


func equip(category: String, id: String) -> bool:
	# Legacy preset compatibility only. This never grants or equips inventory
	# items. The current wardrobe uses equip_item() and independent gear slots.
	if not APPEARANCE_OPTIONS.has(category) or not id in APPEARANCE_OPTIONS[category]:
		return false
	match category:
		"outfit":
			outfit = id
		"weapon":
			weapon = id
		"technique":
			technique = id
	return true


func equip_item(instance_id: int) -> bool:
	return gear.equip_item(instance_id)


func unequip_slot(slot: String) -> bool:
	return gear.unequip_slot(slot)


func salvage_item(instance_id: int) -> Dictionary:
	var result := {"ok": false, "herbs": 0, "item_name": "", "reason": "", "overflow": 0}
	var item: Dictionary = gear.get_item(instance_id)
	if item.is_empty():
		result.reason = "missing"
		return result
	result.item_name = String(item.name)
	if gear.equipped.values().has(instance_id):
		result.reason = "equipped"
		return result
	var value: int = gear.salvage_value(instance_id)
	var room := MAX_RESOURCE - herbs
	if value > room:
		# Preserve the item when its full reward cannot fit. The UI can report
		# the exact overflow instead of silently throwing away resources.
		result.reason = "resource_full"
		result.overflow = value - room
		return result
	if not gear.remove_item(instance_id):
		result.reason = "missing"
		return result
	herbs += value
	result.ok = true
	result.herbs = value
	result.reason = "salvaged"
	return result


func gear_stats() -> Dictionary:
	return gear.stats()


func qi_rate() -> float:
	return float(QI_RATES[realm]) * (1.0 + float(gear_stats().qi_bonus) + 0.08 * active_technique_level("stillness") + float(meridian_bonuses().qi_rate)) * (1.35 if _buff_active("clarity") else 1.0)


func open_chest() -> Dictionary:
	var reward: Dictionary = gear.drop("chest", realm + 1)
	_apply_encounter_resources(reward)
	if bool(reward.get("ok", false)):
		_increment("chests_opened")
	return reward


func reward_encounter(source: String = "monster") -> Dictionary:
	if source == "chest":
		return open_chest()
	var reward: Dictionary = gear.drop(source, realm + 1)
	if bool(reward.ok) and source == "monster":
		total_victories = mini(MAX_RESOURCE, total_victories + 1)
		if total_victories % 3 == 0 and gear.chests < Equipment.MAX_CHESTS:
			gear.chests += 1
			reward.chests = 1
	_apply_encounter_resources(reward)
	return reward


func _apply_encounter_resources(reward: Dictionary) -> void:
	if not bool(reward.get("ok", false)):
		return
	var requested_herbs := maxi(0, int(reward.get("herbs", 0)))
	var requested_dew := maxi(0, int(reward.get("dew", 0)))
	var gained_herbs := mini(MAX_RESOURCE - herbs, requested_herbs)
	var gained_dew := mini(MAX_RESOURCE - dew, requested_dew)
	herbs += gained_herbs
	dew += gained_dew
	reward.herbs = gained_herbs
	reward.dew = gained_dew
	reward.resource_overflow = {"herbs": requested_herbs - gained_herbs, "dew": requested_dew - gained_dew}


func _safe_appearance(category: String, value: Variant) -> String:
	if value is String and value in APPEARANCE_OPTIONS[category]:
		return value
	return DEFAULT_APPEARANCE[category]


func evasion_stats() -> Dictionary:
	# Recomputed, never persisted: gear changes, manuals and loaded meridians
	# feed the very same chance later consumed by the encounter timeline.
	var base := Content.EVASION_BASE
	var heart := technique_descriptor(equipped_heart)
	if not heart.is_empty() and bool(heart.get("active", false)):
		base = float(heart.get("dodge_chance", base))
	for method in passive_method_descriptors():
		if str(method.get("id", "")) == "stillness": base = float(Content.TECHNIQUES.stillness.dodge_chance)
	# 身法 is defensive utility of a legal equipped manual, like its gathering
	# benefit. The fan's attack/skill compatibility remains separate.
	var level := clampi(active_technique_level("petal"), 0, 5)
	var movement_rate := float(Content.TECHNIQUES.petal.dodge_chance) + (level - 1) * Content.PETAL_EVASION_PER_RANK if level > 0 else 0.0
	var result := Content.evasion_breakdown(base, movement_rate, float(gear_stats().evasion_bonus), float(meridian_bonuses().dodge_bonus))
	result.movement_level = level
	return result


func stats() -> Dictionary:
	var need_qi: float = QI_COSTS[realm]
	var pulse := meridian_bonuses()
	var evasion := evasion_stats()
	var heart := technique_descriptor(equipped_heart)
	var passives := passive_method_descriptors()
	var methods: Array = passives.duplicate()
	if not heart.is_empty() and bool(heart.active):
		methods.append(heart)
	var qi_max_bonus := 0.0
	var qi_regen_bonus := 0.0
	var hp_bonus := 0.0
	var poise_bonus := 0.0
	for method in methods:
		qi_max_bonus += float(method.get("combat_qi_max", 0.0))
		qi_regen_bonus += float(method.get("combat_qi_regen", 0.0))
		hp_bonus += float(method.get("max_hp", 0.0))
		poise_bonus += float(method.get("poise_bonus", 0.0))
	return {
		"qi_rate": qi_rate(),
		"attack": 8 + realm * 2 + int(gear_stats().attack) + 3 * active_technique_level("mist") + int(meridian_bonuses().attack),
		"defense": int(realm / 3.0) + int(gear_stats().defense) + int(meridian_bonuses().defense),
		"max_hp": 100 + realm * 4 + int(hp_bonus), "realm_attack": realm * 2, "realm_defense": int(realm / 3.0),
		"technique_level": int(technique_levels.get(technique, 0)),
		# These are effective combat modifiers, consumed directly by DuelTimeline.
		"speed": 100.0 * (1.0 + clampf(float(pulse.combat_haste), 0.0, 0.35)),
		"combat_haste": pulse.combat_haste, "poise_bonus": float(pulse.poise_bonus) + poise_bonus,
		"break_bonus": pulse.break_bonus, "counter_bonus": pulse.counter_bonus,
		"guard_bonus": pulse.guard_bonus, "dodge_bonus": pulse.dodge_bonus,
		"evasion_chance": evasion.chance, "evasion_sources": evasion,
		"recovery_bonus": pulse.recovery_bonus,
		"combat_qi_max": clampf(Content.COMBAT_QI_BASE + realm * Content.COMBAT_QI_PER_REALM + float(pulse.combat_qi_max) + qi_max_bonus, 1.0, Content.COMBAT_QI_LIMIT),
		"combat_qi_regen": clampf(Content.COMBAT_QI_REGEN + float(pulse.combat_qi_regen) + qi_regen_bonus, 0.0, Content.COMBAT_QI_REGEN_LIMIT),
		"skill_cost_reduction": clampf(float(pulse.skill_cost_reduction), 0.0, Content.SKILL_COST_REDUCTION_CAP),
		"skill_cooldown_reduction": clampf(float(pulse.skill_cooldown_reduction), 0.0, Content.SKILL_COOLDOWN_REDUCTION_CAP),
		"attack_module_id": gear.equipped_attack_module_id(),
		"heart_method": heart, "weapon_art": technique_descriptor(equipped_weapon_art),
		"active_skills": active_skill_descriptors(), "passive_methods": passives,
		"spell": technique_descriptor(equipped_spell), "weapon_skill": gear.equipped_weapon_skill(),
		"need_qi": need_qi,
		"need_herbs": int(HERB_COSTS[realm]),
		"progress": clampf(qi / need_qi, 0.0, 1.0) if need_qi > 0.0 else 1.0,
		"realm_name": realm_name(), "activity": activity_name(),
		"pill_qi": pill_qi(), "merit": merit,
		"herb_progress": _gather_clock / 8.0,
		"dew_progress": _dew_clock / 24.0,
		"brew_progress": activity_progress if activity == "brew" else _brew_clock / float(Content.RECIPES[recipe].seconds),
		"technique_name": String(Content.TECHNIQUES[technique].name),
		"gather_multiplier": gather_multiplier(), "brew_multiplier": brew_multiplier(),
		"campaign_complete": realm == MAX_REALM, "story_resolved": _all_chapters_cleared(), "ending_complete": ending_finished_at >= 0.0,
		"max_realm": realm == MAX_REALM,
	}


func pill_qi() -> float:
	return 55.0 * (1.0 + float(realm) * 0.45)


func use_pill(id: String = "qi") -> bool:
	if not Content.RECIPES.has(id) or int(pill_stocks.get(id, 0)) <= 0:
		return false
	if id != "qi" and float(buffs.get(id, lifetime_seconds)) - lifetime_seconds >= Content.BUFF_CAP - EPSILON:
		return false
	pill_stocks[id] = int(pill_stocks[id]) - 1
	_increment("pills_used")
	if id == "qi":
		_add_energy(pill_qi())
	else:
		buffs[id] = minf(lifetime_seconds + Content.BUFF_CAP, maxf(lifetime_seconds, float(buffs.get(id, 0.0))) + Content.BUFF_SECONDS)
	return true


func breakthrough() -> bool:
	if realm >= MAX_REALM:
		return false
	var cost: float = QI_COSTS[realm]
	var herb_cost: int = HERB_COSTS[realm]
	if qi + EPSILON < cost or herbs < herb_cost:
		return false
	qi = maxf(0.0, qi - cost)
	herbs -= herb_cost
	realm += 1
	_record("境界提升 · " + realm_name())
	if realm == MAX_REALM:
		campaign_finished_at = lifetime_seconds
		_record("静修圆满 · 此心归处。你已抵达归真，六印历练与山居生活仍可从容继续。")
		merit = minf(MAX_ENERGY, merit + qi)
		qi = 0.0
	return true


func step(delta: float) -> Array[String]:
	var events: Array[String] = []
	_last_step_gains = _empty_gains()
	if not is_finite(delta) or delta <= 0.0 or bool(settings.get("paused", false)):
		return events
	var remaining := minf(delta, float(OFFLINE_CAP_SECONDS))
	var initial_realm := realm
	# Integrate every activity, buff expiry and fox return at the same event
	# boundaries. A single eight-hour offline tick is identical to small ticks.
	while remaining > EPSILON:
		_expire_buffs()
		if auto_advance:
			_prepare_auto(events)
		var span := remaining
		for id in buffs:
			span = minf(span, maxf(EPSILON, float(buffs[id]) - lifetime_seconds))
		if not journey.is_empty():
			span = minf(span, maxf(EPSILON, float(journey.remaining)))
		for training in technique_training:
			span = minf(span, maxf(EPSILON, float(training.remaining)))
		if not pending_heart_switch.is_empty():
			span = minf(span, maxf(EPSILON, float(pending_heart_switch.remaining)))
		if activity == "gather":
			var speed := gather_multiplier()
			span = minf(span, minf((8.0 - _gather_clock) / speed, (24.0 - _dew_clock) / speed))
			_gather_clock += span * speed
			_dew_clock += span * speed
			if _gather_clock >= 8.0 - EPSILON:
				_gather_clock = maxf(0.0, _gather_clock - 8.0)
				if herbs < MAX_RESOURCE:
					herbs += 1
					_increment("gathered")
					_last_step_gains.herbs += 1
			if _dew_clock >= 24.0 - EPSILON:
				_dew_clock = maxf(0.0, _dew_clock - 24.0)
				if dew < MAX_RESOURCE:
					dew += 1
					_last_step_gains.dew += 1
		elif activity == "brew" and can_brew():
			var formula: Dictionary = Content.RECIPES[recipe]
			var speed := brew_multiplier()
			span = minf(span, (float(formula.seconds) - _brew_clock) / speed)
			_brew_clock += span * speed
			if _brew_clock >= float(formula.seconds) - EPSILON:
				_brew_clock = maxf(0.0, _brew_clock - float(formula.seconds))
				herbs -= int(formula.herbs)
				dew -= int(formula.dew)
				pill_stocks[recipe] = int(pill_stocks[recipe]) + 1
				_increment("brewed")
				_last_step_gains.pills += 1
		else:
			var rate := qi_rate() * (0.3 if activity == "brew" else 1.0)
			if auto_advance and realm < MAX_REALM:
				span = minf(span, maxf(EPSILON, (float(QI_COSTS[realm]) - qi) / rate))
			_add_energy(span * rate)
		lifetime_seconds = minf(MAX_ENERGY, lifetime_seconds + span)
		_advance_journey(span, events)
		_advance_technique_training(span, events)
		remaining = maxf(0.0, remaining - maxf(span, EPSILON))
	_expire_buffs()
	if auto_advance:
		_prepare_auto(events)
	_last_step_gains.realm_up = realm - initial_realm
	if int(_last_step_gains.herbs) > 0:
		events.append("采得灵草 +%d" % int(_last_step_gains.herbs))
	if int(_last_step_gains.dew) > 0:
		events.append("收集晨露 +%d" % int(_last_step_gains.dew))
	if int(_last_step_gains.pills) > 0:
		events.append("炼成丹药 +%d" % int(_last_step_gains.pills))
	return events


func _prepare_auto(events: Array[String]) -> void:
	while realm < MAX_REALM:
		if qi + EPSILON < float(QI_COSTS[realm]) and pills > 0:
			var needed := int(ceil((float(QI_COSTS[realm]) - qi) / pill_qi()))
			var consumed := mini(pills, needed)
			pills -= consumed
			_increment("pills_used", consumed)
			_add_energy(pill_qi() * consumed)
			events.append("服用灵丹 %d 枚，温养灵气。" % consumed)
		if breakthrough():
			events.append("境界提升 · " + realm_name())
		else:
			break
	var next_activity := "meditate"
	if realm < MAX_REALM and qi + EPSILON >= float(QI_COSTS[realm]) and herbs < int(HERB_COSTS[realm]):
		next_activity = "gather"
	if next_activity != activity:
		activity = next_activity
		events.append("随心修行 · " + activity_name())


func _add_energy(amount: float) -> void:
	if realm == MAX_REALM:
		var gain := minf(amount, MAX_ENERGY - merit)
		merit += gain
		_last_step_gains.merit = float(_last_step_gains.get("merit", 0.0)) + gain
	else:
		var gain := minf(amount, MAX_ENERGY - qi)
		qi += gain
		_last_step_gains.qi = float(_last_step_gains.get("qi", 0.0)) + gain


func _empty_gains() -> Dictionary:
	return {"qi": 0.0, "herbs": 0, "dew": 0, "pills": 0, "merit": 0.0, "realm_up": 0, "journeys": 0, "bond": 0}


func save_game() -> bool:
	var temp := save_path + ".tmp"
	var backup := save_path + ".bak"
	var file := FileAccess.open(temp, FileAccess.WRITE)
	if file == null:
		return false
	file.store_string(JSON.stringify(_snapshot(), "\t"))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK or not bool(_read_save(temp).ok):
		return false
	if FileAccess.file_exists(save_path):
		if FileAccess.file_exists(backup) and DirAccess.remove_absolute(backup) != OK:
			return false
		if DirAccess.rename_absolute(save_path, backup) != OK:
			return false
	if DirAccess.rename_absolute(temp, save_path) != OK:
		if FileAccess.file_exists(backup) and not FileAccess.file_exists(save_path):
			DirAccess.rename_absolute(backup, save_path)
		return false
	_clock_high_water = maxi(_clock_high_water, int(Time.get_unix_time_from_system()))
	return true


func load_game() -> Dictionary:
	last_offline = _load_game()
	return last_offline


func _load_game() -> Dictionary:
	var result := _offline_result()
	if not FileAccess.file_exists(save_path):
		var backup := _read_save(save_path + ".bak")
		if bool(backup.ok):
			result.recovered = true
			return _restore_and_award(backup.data, result)
		new_game()
		return result
	var decoded := _read_save(save_path)
	if not bool(decoded.ok):
		result.invalid_save = true
		result.invalid_preserved = _preserve_invalid(save_path)
		var backup := _read_save(save_path + ".bak")
		if bool(backup.ok):
			result.recovered = true
			return _restore_and_award(backup.data, result, bool(result.invalid_preserved))
		new_game()
		return result
	return _restore_and_award(decoded.data, result)


func reset_save() -> bool:
	for suffix in ["", ".bak", ".tmp"]:
		var path := save_path + String(suffix)
		if FileAccess.file_exists(path) and DirAccess.remove_absolute(path) != OK:
			return false
	new_game()
	return save_game()


func _snapshot() -> Dictionary:
	if not stage_run.is_empty(): stage_battle_resources()
	var safe_settings := settings.duplicate(true)
	safe_settings.click_through = false
	return {
		"version": Content.VERSION, "saved_at": maxi(_clock_high_water, int(Time.get_unix_time_from_system())),
		"realm": realm, "qi": qi, "herbs": herbs, "dew": dew, "pills": pills,
		"merit": merit, "lifetime_seconds": lifetime_seconds,
		"gear": gear.to_dict(), "materials": materials.to_dict(), "loot_crafting_revision": 2, "total_victories": total_victories,
		"expedition_auto": false,
		"adventure": {"selected_stage": selected_stage, "stage_run": stage_run.duplicate(true),
			"stage_clears": stage_clears.duplicate(), "pending_opportunity": pending_opportunity.duplicate(true),
			"campaign_revision": Content.CAMPAIGN_REVISION, "chapter_reward_claimed": chapter_reward_claimed.duplicate(),
			"legacy_unlocked_stages": legacy_unlocked_stages.duplicate(),
			"story_resolved_at": story_resolved_at, "ending_finished_at": ending_finished_at,
			"meridian_count": meridian_count, "meridian_revision": Content.MERIDIAN_REVISION,
			"meridian_nodes": meridian_node_ids(), "stage_serial": _stage_serial,
			"rng_seed": str(_adventure_rng.seed), "rng_state": str(_adventure_rng.state)},
		"activity": activity, "auto_advance": auto_advance, "settings": safe_settings,
		"outfit": _safe_appearance("outfit", outfit),
		"weapon": _safe_appearance("weapon", weapon),
		"technique": _safe_appearance("technique", technique),
		"manual_revision": 1, "equipped_heart": equipped_heart, "equipped_weapon_art": equipped_weapon_art,
		"equipped_actives": equipped_actives.duplicate(), "equipped_passives": equipped_passives.duplicate(),
		"attuned_techniques": attuned_techniques.duplicate(), "technique_training": technique_training.duplicate(true),
		"pending_heart_switch": pending_heart_switch.duplicate(true), "heart_equipped_once": heart_equipped_once,
		"heart_switch_serial": _heart_switch_serial, "last_equipped_heart": last_equipped_heart,
		"gather_clock": _gather_clock, "dew_clock": _dew_clock, "brew_clock": _brew_clock,
		"recipe": recipe, "pill_stocks": pill_stocks.duplicate(), "technique_levels": technique_levels.duplicate(),
		"buffs": buffs.duplicate(), "brew_progresses": brew_progresses.duplicate(),
		"journey": journey.duplicate(true), "journey_bond": journey_bond, "journey_completed": journey_completed,
		"journey_last_result": journey_last_result.duplicate(true), "discoveries": discoveries.duplicate(),
		"quest_claimed": quest_claimed.duplicate(), "counters": counters.duplicate(),
		"journal_entries": journal_entries.duplicate(true), "campaign_finished_at": campaign_finished_at,
		"arrival_seen": arrival_seen, "guidance_dismissed": guidance_dismissed, "journey_skipped": journey_skipped.duplicate(),
		"journey_rng_seed": str(_journey_rng.seed), "journey_rng_state": str(_journey_rng.state),
	}


func _offline_result() -> Dictionary:
	var result := _empty_gains()
	result.merge({
		"seconds": 0, "capped": false, "clock_invalid": false,
		"loaded": false, "invalid_save": false, "invalid_preserved": false,
		"recovered": false, "save_error": false, "events": [],
	})
	return result


func _restore_and_award(data: Dictionary, result: Dictionary, may_save: bool = true) -> Dictionary:
	new_game()
	realm = int(data.realm)
	if int(data.version) < Content.EXPANDED_REALM_VERSION:
		realm = int([0, 1, 2, 3, 6, 9, 12, 15][realm])
		result.migrated = true
	if int(data.version) < Content.VERSION:
		result.migrated = true
	qi = float(data.qi)
	herbs = int(data.herbs)
	dew = int(data.dew)
	pills = int(data.pills)
	merit = float(data.merit)
	lifetime_seconds = float(data.lifetime_seconds)
	activity = String(data.activity)
	gear.new_game()
	if data.has("gear"):
		var gear_report: Dictionary = gear.load_data(data.gear)
		result.gear_repaired = bool(gear_report.repaired)
	else:
		result.gear_repaired = false
	var material_report: Dictionary = materials.load_data(data.get("materials", {}))
	result.materials_repaired = bool(material_report.repaired)
	total_victories = _bounded_saved_int(data.get("total_victories"), 0, MAX_RESOURCE, 0)
	expedition_auto = false
	# Appearance is optional in older saves. Bad cosmetic values fall back
	# individually, preserving the player's otherwise valid cultivation state.
	outfit = _safe_appearance("outfit", data.get("outfit"))
	weapon = _safe_appearance("weapon", data.get("weapon"))
	technique = _safe_appearance("technique", data.get("technique"))
	auto_advance = bool(data.auto_advance)
	_gather_clock = float(data.gather_clock)
	_dew_clock = float(data.dew_clock)
	_brew_clock = float(data.brew_clock)
	settings = DEFAULT_SETTINGS.duplicate(true)
	for key in DEFAULT_SETTINGS:
		if data.settings.has(key):
			settings[key] = data.settings[key]
	settings.click_through = false
	settings.width = int(settings.width)
	_restore_campaign(data)
	_restore_adventure(data.get("adventure", {}))
	result.loaded = true
	var now := int(Time.get_unix_time_from_system())
	var saved_at := int(data.saved_at)
	var elapsed := now - saved_at
	_clock_high_water = maxi(now, saved_at) if saved_at >= MIN_VALID_TIMESTAMP and saved_at <= MAX_VALID_TIMESTAMP else now
	if saved_at < MIN_VALID_TIMESTAMP or saved_at > MAX_VALID_TIMESTAMP or elapsed < 0:
		result.clock_invalid = true
	elif not bool(settings.get("paused", false)):
		result.seconds = mini(elapsed, OFFLINE_CAP_SECONDS)
		result.capped = elapsed > OFFLINE_CAP_SECONDS
		result.events = step(float(result.seconds))
		for key in _last_step_gains:
			result[key] = _last_step_gains[key]
	result.save_error = not save_game() if may_save else true
	return result


func _read_save(path: String) -> Dictionary:
	var bad := {"ok": false, "data": {}}
	if not FileAccess.file_exists(path):
		return bad
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return bad
	if file.get_length() > 262144:
		file.close()
		return bad
	var content := file.get_as_text()
	file.close()
	var parser := JSON.new()
	if parser.parse(content) != OK or not parser.data is Dictionary:
		return bad
	var data: Dictionary = parser.data
	if not _valid_save(data):
		return bad
	return {"ok": true, "data": data}


func _valid_save(data: Dictionary) -> bool:
	var integer_bounds := {
		"version": [1, Content.VERSION], "saved_at": [0, 9007199254740991], "realm": [0, MAX_REALM],
		"herbs": [0, MAX_RESOURCE], "dew": [0, MAX_RESOURCE], "pills": [0, MAX_RESOURCE],
	}
	for key in integer_bounds:
		if not _valid_integer(data.get(key), int(integer_bounds[key][0]), int(integer_bounds[key][1])):
			return false
	for key in ["qi", "merit", "lifetime_seconds"]:
		if not _valid_number(data.get(key), 0.0, MAX_ENERGY):
			return false
	if int(data.version) < Content.EXPANDED_REALM_VERSION and int(data.realm) > 7:
		return false
	var final_realm := 7 if int(data.version) < Content.EXPANDED_REALM_VERSION else MAX_REALM
	if int(data.realm) == final_realm and float(data.qi) > EPSILON:
		return false
	for key in ["gather_clock", "dew_clock", "brew_clock"]:
		var selected: String = String(data.get("recipe", "qi")) if data.get("recipe", "qi") is String else "qi"
		var brew_max := float(Content.RECIPES.get(selected, Content.RECIPES.qi).seconds)
		var maximum: float = {"gather_clock": 8.0, "dew_clock": 24.0, "brew_clock": brew_max}[key]
		if not _valid_number(data.get(key), 0.0, maximum - EPSILON):
			return false
	if not data.get("activity") is String or not ACTIVITY_NAMES.has(data.activity):
		return false
	if not data.get("auto_advance") is bool or not data.get("settings") is Dictionary:
		return false
	for key in ["music", "sfx"]:
		if data.settings.has(key) and not _valid_number(data.settings[key], 0.0, 1.0):
			return false
	for key in ["low_power", "always_on_top", "transparent", "click_through", "paused"]:
		if data.settings.has(key) and not data.settings[key] is bool:
			return false
	if data.settings.has("width") and not _valid_integer(data.settings.width, 480, 7680):
		return false
	return true


func _bounded_saved_int(value: Variant, low: int, high: int, fallback: int) -> int:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	if floor(float(value)) != float(value):
		return fallback
	return int(clampf(float(value), float(low), float(high)))


func _valid_integer(value: Variant, low: int, high: int) -> bool:
	return _valid_number(value, float(low), float(high)) and floor(float(value)) == float(value)


func _valid_number(value: Variant, low: float, high: float) -> bool:
	if not (value is int or value is float):
		return false
	return is_finite(float(value)) and float(value) >= low and float(value) <= high


func _preserve_invalid(path: String) -> bool:
	var base := path + ".invalid-" + str(int(Time.get_unix_time_from_system()))
	var target := base
	var index := 0
	while FileAccess.file_exists(target):
		index += 1
		target = base + "-" + str(index)
	return DirAccess.rename_absolute(path, target) == OK


func _increment(key: String, count: int = 1) -> void:
	counters[key] = mini(MAX_RESOURCE, int(counters.get(key, 0)) + maxi(0, count))


func _record(message: String) -> void:
	journal_entries.push_front({"text": message, "time": lifetime_seconds})
	if journal_entries.size() > 60:
		journal_entries.resize(60)


func journal_rows() -> Array:
	return journal_entries.duplicate(true)


func _buff_active(id: String) -> bool:
	return float(buffs.get(id, 0.0)) > lifetime_seconds + EPSILON


func _expire_buffs() -> void:
	for id in buffs.keys():
		if float(buffs[id]) <= lifetime_seconds + EPSILON:
			buffs.erase(id)


func active_technique_level(id: String) -> int:
	# Utility bonuses follow explicitly operating slots, not every collected or
	# attuned manual. Weapon compatibility gates moves, not the old utility perk.
	return int(technique_levels.get(id, 0)) if _manual_eligible(id) and not equipped_technique_slots(id).is_empty() else 0


func gather_multiplier() -> float:
	return (1.0 + 0.12 * active_technique_level("petal") + float(meridian_bonuses().gather)) * (1.5 if _buff_active("spring") else 1.0)


func brew_multiplier() -> float:
	return 1.0 + 0.15 * active_technique_level("ember") + float(meridian_bonuses().brew)


func attunement_capacity() -> int:
	if realm >= 12: return 8
	if realm >= 9: return 7
	if realm >= 6: return 6
	if realm >= 3: return 5
	if realm >= 1: return 4
	return 3


func active_capacity() -> int:
	return 2 if realm >= 3 else 1


func passive_capacity() -> int:
	return 1 if realm >= 3 else 0


func training_capacity() -> int:
	return 2 if realm >= 6 else 1


func equipped_technique_slots(id: String) -> Array[String]:
	var result: Array[String] = []
	if id == equipped_heart: result.append("heart")
	if id == equipped_weapon_art: result.append("weapon_art")
	if equipped_actives.has(id): result.append("active")
	if equipped_passives.has(id): result.append("passive")
	return result


func _manual_eligible(id: String) -> bool:
	return Content.TECHNIQUES.has(id) and attuned_techniques.has(id) and int(technique_levels.get(id, 0)) > 0 and realm >= int(Content.TECHNIQUES[id].unlock_realm)


func technique_descriptor(id: String) -> Dictionary:
	if not Content.TECHNIQUES.has(id):
		return {}
	var result: Dictionary = Content.TECHNIQUES[id].duplicate(true)
	var level := int(technique_levels.get(id, 0))
	var required := String(result.get("required_weapon", ""))
	var actual := String(gear.equipped_item("weapon").get("template_id", ""))
	var compatible := required.is_empty() or actual == required
	result.merge({"id": id, "level": level, "power_scale": 1.0 + 0.05 * maxi(0, level - 1),
		"compatible": compatible, "active": _manual_eligible(id) and compatible,
		"category_name": String(Content.TECHNIQUE_CATEGORIES.get(result.category, "功法")),
		"inactive_reason": "" if compatible else ("需持青锋剑" if required == "weapon_sword" else "需持流云扇")})
	if id == "petal":
		result.movement_active = active_technique_level("petal") > 0
		result.effect = "身法闪避 %.1f%% · 无扇也生效 · 扇招%s" % [(float(Content.TECHNIQUES.petal.dodge_chance) + Content.PETAL_EVASION_PER_RANK * maxi(0, level - 1)) * 100.0, "可用" if compatible else "需持扇"]
		if not compatible: result.inactive_reason = "身法按装配生效；扇招需持流云扇"
	elif id == "breath":
		result.combat_qi_max = 6.0 + 2.0 * maxi(0, level - 1)
		result.combat_qi_regen = 0.35 + 0.05 * maxi(0, level - 1)
		result.effect = "被动养气 · 真气上限 +%d · 恢复 +%.2f/秒" % [int(result.combat_qi_max), float(result.combat_qi_regen)]
	elif id == "stillness":
		result.poise_bonus = 6.0 + maxi(0, level - 1)
		result.effect = "被动护体 · 基础格挡68%% · 定力 +%d · 吐纳 +%d%%" % [int(result.poise_bonus), 8 * maxi(1, level)]
	elif id == "body":
		result.max_hp = 16.0 + 4.0 * maxi(1, level)
		result.poise_bonus = 3.0 + maxi(1, level)
		result.effect = "被动强身 · 气血 +%d · 定力 +%d" % [int(result.max_hp), int(result.poise_bonus)]
	return result


func active_skill_descriptors() -> Array:
	var result: Array = []
	for id in equipped_actives:
		var method := technique_descriptor(id)
		if not method.is_empty(): result.append(method)
	return result


func passive_method_descriptors() -> Array:
	var result: Array = []
	for id in equipped_passives:
		var method := technique_descriptor(id)
		if id != equipped_heart and not method.is_empty() and bool(method.active): result.append(method)
	return result


func attune_technique(id: String) -> Dictionary:
	if not Content.TECHNIQUES.has(id): return {"ok": false, "reason": "missing"}
	if attuned_techniques.has(id): return {"ok": true, "reason": "already_attuned"}
	if realm < int(Content.TECHNIQUES[id].unlock_realm): return {"ok": false, "reason": "locked"}
	if attuned_techniques.size() >= attunement_capacity(): return {"ok": false, "reason": "attunement_full"}
	attuned_techniques.append(id)
	_invalidate_heart_quote()
	return {"ok": true, "reason": "attuned", "id": id}


func unattune_technique(id: String) -> Dictionary:
	if not attuned_techniques.has(id): return {"ok": false, "reason": "not_attuned"}
	if not equipped_technique_slots(id).is_empty(): return {"ok": false, "reason": "equipped"}
	if not _training_for(id).is_empty(): return {"ok": false, "reason": "training"}
	if String(pending_heart_switch.get("to_id", "")) == id: return {"ok": false, "reason": "heart_adjusting"}
	attuned_techniques.erase(id)
	_invalidate_heart_quote()
	return {"ok": true, "reason": "dormant", "id": id}


func equip_technique(id: String, slot: String = "") -> Dictionary:
	if not Content.TECHNIQUES.has(id): return {"ok": false, "reason": "missing"}
	if slot.is_empty(): slot = String(Content.TECHNIQUES[id].slot)
	if not slot in Content.TECHNIQUES[id].slots: return {"ok": false, "reason": "wrong_slot"}
	if not _manual_eligible(id): return {"ok": false, "reason": "not_attuned_or_learned"}
	if slot == "heart": return {"ok": false, "reason": "confirmation_required"}
	if equipped_technique_slots(id).has(slot): return {"ok": true, "reason": "already_equipped"}
	if slot == "weapon_art":
		equipped_weapon_art = id
	elif slot == "active":
		if equipped_actives.size() >= active_capacity(): return {"ok": false, "reason": "active_slots_full"}
		equipped_actives.append(id)
	elif slot == "passive":
		if id == equipped_heart: return {"ok": false, "reason": "already_primary"}
		if equipped_passives.size() >= passive_capacity(): return {"ok": false, "reason": "passive_slots_full"}
		equipped_passives.append(id)
	else:
		return {"ok": false, "reason": "wrong_slot"}
	technique = id
	_invalidate_heart_quote()
	return {"ok": true, "reason": "equipped", "id": id, "slot": slot}


func unequip_technique(id: String, slot: String = "") -> Dictionary:
	if not Content.TECHNIQUES.has(id): return {"ok": false, "reason": "missing"}
	if slot.is_empty(): slot = String(Content.TECHNIQUES[id].slot)
	if not equipped_technique_slots(id).has(slot): return {"ok": false, "reason": "not_equipped"}
	if slot == "heart":
		if not stage_run.is_empty(): return {"ok": false, "reason": "courtyard_only"}
		if not pending_heart_switch.is_empty(): return {"ok": false, "reason": "heart_adjusting"}
		equipped_heart = ""
	elif slot == "weapon_art": equipped_weapon_art = ""
	elif slot == "active": equipped_actives.erase(id)
	elif slot == "passive": equipped_passives.erase(id)
	_invalidate_heart_quote()
	return {"ok": true, "reason": "unequipped", "id": id, "slot": slot}


func deselect_technique(category: String) -> bool:
	if category == "heart": return bool(unequip_technique(equipped_heart, "heart").ok)
	if category == "weapon_art": return bool(unequip_technique(equipped_weapon_art, "weapon_art").ok)
	if category == "spell": return bool(unequip_technique(equipped_spell, "active").ok)
	return false


func select_technique(id: String) -> bool:
	# Legacy selector chooses the book's natural slot. Its old weapon-art
	# behavior also fills an available active slot; explicit new slot APIs do not.
	var result := equip_technique(id)
	if not bool(result.ok): return false
	if String(Content.TECHNIQUES[id].slot) == "weapon_art" and not equipped_actives.has(id) and equipped_actives.size() < active_capacity():
		equip_technique(id, "active")
	return true


func _training_for(id: String) -> Dictionary:
	for training in technique_training:
		if String(training.id) == id: return training
	return {}


func _training_duration(id: String, target: int) -> float:
	return clampf(float(Content.TECHNIQUES[id].get("training_seconds", 8.0)) + float(target - 1), 8.0, 24.0)


func _training_prerequisites(id: String) -> Array[String]:
	var missing: Array[String] = []
	var required: Dictionary = Content.TECHNIQUES[id].get("prerequisites", {})
	for other in required:
		if int(technique_levels.get(other, 0)) < int(required[other]):
			missing.append("%s%d重" % [String(Content.TECHNIQUES[other].name), int(required[other])])
	return missing


func technique_rows() -> Array:
	var rows: Array = []
	for id in Content.TECHNIQUES:
		var row := technique_descriptor(String(id))
		var level := int(technique_levels.get(id, 0))
		var target := mini(level + 1, int(row.max_level))
		var next_realm := int(row.rank_realms[target - 1])
		var training := _training_for(String(id))
		var slots := equipped_technique_slots(String(id))
		var missing := _training_prerequisites(String(id))
		var attuned := attuned_techniques.has(id)
		var cost_herbs := int(row.get("training_herbs", 8)) * (level + 1)
		# The first paid refresher is deliberately reachable after 24s of gathering
		# from the real starter supplies. Later ranks retain their published costs.
		if id == "mist" and level == 1: cost_herbs = Content.FIRST_MIST_STUDY_HERBS
		var cost_dew := level + 1
		var locked_reason := ""
		if level >= int(row.max_level): locked_reason = "已臻圆满"
		elif not training.is_empty(): locked_reason = "正在研习"
		elif realm < next_realm: locked_reason = "需达 " + REALM_NAMES[next_realm]
		elif not missing.is_empty(): locked_reason = "先修 " + "、".join(missing)
		elif not attuned and attuned_techniques.size() >= attunement_capacity(): locked_reason = "参修已满，先将未装配功法封存"
		elif technique_training.size() >= training_capacity(): locked_reason = "研习位已满"
		elif String(pending_heart_switch.get("to_id", "")) == id: locked_reason = "正在调息换心法"
		elif herbs < cost_herbs or dew < cost_dew: locked_reason = "草露不足"
		row.merge({"id": id, "unlocked": realm >= int(row.unlock_realm), "level": level,
			"selected": not slots.is_empty(), "equipped_slots": slots, "attuned": attuned,
			"dormant": level > 0 and not attuned, "active": not slots.is_empty() and bool(row.active),
			"cost_herbs": cost_herbs, "cost_dew": cost_dew, "cost_qi": 0.0,
			"next_rank_realm": next_realm, "prerequisite_text": "、".join(missing),
			"training": not training.is_empty(), "training_remaining": float(training.get("remaining", 0.0)),
			"training_duration": float(training.get("duration", _training_duration(String(id), level + 1))),
			"training_progress": 1.0 - float(training.remaining) / float(training.duration) if not training.is_empty() else 0.0,
			"can_attune": not attuned and realm >= int(row.unlock_realm) and attuned_techniques.size() < attunement_capacity(),
			"can_upgrade": locked_reason.is_empty(), "locked_reason": locked_reason}, true)
		rows.append(row)
	return rows


func upgrade_technique(id: String) -> Dictionary:
	for row in technique_rows():
		if String(row.id) != id: continue
		if not bool(row.can_upgrade):
			return {"ok": false, "reason": "max_level" if int(row.level) >= int(row.max_level) else ("training" if bool(row.training) else "locked_or_resources"), "name": row.name, "level": row.level, "detail": row.locked_reason}
		if not attuned_techniques.has(id):
			var attunement := attune_technique(id)
			if not bool(attunement.ok): return attunement
		herbs -= int(row.cost_herbs)
		dew -= int(row.cost_dew)
		var duration := _training_duration(id, int(row.level) + 1)
		technique_training.append({"id": id, "target_level": int(row.level) + 1, "duration": duration, "remaining": duration})
		_invalidate_heart_quote()
		_record("展卷研习 · %s 第 %d 重，需 %.0f 秒。" % [String(row.name), int(row.level) + 1, duration])
		return {"ok": true, "reason": "training_started", "queued": true, "name": row.name, "level": row.level,
			"target_level": int(row.level) + 1, "duration": duration, "cost": {"herbs": row.cost_herbs, "dew": row.cost_dew}}
	return {"ok": false, "reason": "missing", "name": "", "level": 0}


func cancel_technique_training(id: String) -> Dictionary:
	for index in range(technique_training.size()):
		if String(technique_training[index].id) == id:
			technique_training.remove_at(index)
			_invalidate_heart_quote()
			return {"ok": true, "reason": "cancelled", "refunded": false}
	return {"ok": false, "reason": "not_training"}


func _advance_technique_training(delta: float, events: Array[String]) -> void:
	for index in range(technique_training.size() - 1, -1, -1):
		var training: Dictionary = technique_training[index]
		training.remaining = maxf(0.0, float(training.remaining) - delta)
		if float(training.remaining) > EPSILON: continue
		var id := String(training.id)
		if int(training.target_level) == int(technique_levels.get(id, 0)) + 1:
			technique_levels[id] = int(training.target_level)
			_increment("techniques_trained")
			var text := "研习完成 · %s 第 %d 重" % [String(Content.TECHNIQUES[id].name), int(training.target_level)]
			_record(text)
			events.append(text)
		technique_training.remove_at(index)
		_invalidate_heart_quote()
	_advance_heart_switch(delta, events)


func _restore_manual_loadout(data: Dictionary) -> void:
	var modern := data.has("manual_revision") or data.has("attuned_techniques") or data.has("equipped_actives")
	attuned_techniques = []
	equipped_heart = ""
	equipped_weapon_art = ""
	equipped_actives = []
	equipped_passives = []
	technique_training = []
	pending_heart_switch = {}
	var candidates: Array = []
	if modern:
		var raw_attuned: Variant = data.get("attuned_techniques", [])
		if raw_attuned is Array: candidates = raw_attuned
	else:
		# Keep the formerly selected manual operating first. Any excess learned
		# books remain owned and retain ranks; they simply await explicit attunement.
		candidates = [technique, "breath"]
		for id in Content.TECHNIQUES:
			if int(technique_levels.get(id, 0)) > 0: candidates.append(id)
	for raw in candidates:
		if raw is String and Content.TECHNIQUES.has(raw) and realm >= int(Content.TECHNIQUES[raw].unlock_realm) and not attuned_techniques.has(raw) and attuned_techniques.size() < attunement_capacity():
			attuned_techniques.append(raw)
	if modern:
		equipped_heart = _restore_manual_slot(data.get("equipped_heart"), "heart")
		equipped_weapon_art = _restore_manual_slot(data.get("equipped_weapon_art"), "weapon_art")
		_restore_manual_array(data.get("equipped_actives", []), "active", equipped_actives, active_capacity())
		_restore_manual_array(data.get("equipped_passives", []), "passive", equipped_passives, passive_capacity())
	else:
		if _manual_eligible(technique):
			var slot := String(Content.TECHNIQUES[technique].slot)
			if slot == "heart": equipped_heart = technique
			elif slot == "weapon_art":
				equipped_weapon_art = technique
				equipped_actives.append(technique)
			elif slot == "active": equipped_actives.append(technique)
	heart_equipped_once = (data.get("heart_equipped_once") is bool and data.heart_equipped_once) or not equipped_heart.is_empty()
	last_equipped_heart = equipped_heart
	if last_equipped_heart.is_empty() and heart_equipped_once:
		var previous: Variant = data.get("last_equipped_heart", "")
		if previous is String and Content.TECHNIQUES.has(previous) and "heart" in Content.TECHNIQUES[previous].slots:
			last_equipped_heart = previous
	_heart_switch_serial = _bounded_saved_int(data.get("heart_switch_serial"), 0, MAX_RESOURCE, 0)
	var raw_training: Variant = data.get("technique_training", [])
	if raw_training is Array:
		for raw in raw_training:
			if technique_training.size() >= training_capacity(): break
			if not raw is Dictionary or not raw.get("id") is String: continue
			var id := String(raw.id)
			if not Content.TECHNIQUES.has(id) or not attuned_techniques.has(id) or not _training_for(id).is_empty(): continue
			var target := int(technique_levels.get(id, 0)) + 1
			if target > int(Content.TECHNIQUES[id].max_level) or not _valid_integer(raw.get("target_level"), target, target): continue
			if realm < int(Content.TECHNIQUES[id].rank_realms[target - 1]) or not _training_prerequisites(id).is_empty(): continue
			var duration := _training_duration(id, target)
			var remaining := _finite_bounded(raw.get("remaining"), 0.0, duration, duration)
			technique_training.append({"id": id, "target_level": target, "duration": duration, "remaining": remaining})
	_restore_heart_switch(data.get("pending_heart_switch", {}))
	_invalidate_heart_quote()


func _restore_manual_slot(value: Variant, slot: String) -> String:
	if not value is String or not _manual_eligible(value) or not slot in Content.TECHNIQUES[value].slots: return ""
	return value


func _restore_manual_array(value: Variant, slot: String, destination: Array[String], capacity: int) -> void:
	if not value is Array: return
	for raw in value:
		var id := _restore_manual_slot(raw, slot)
		if not id.is_empty() and not destination.has(id) and destination.size() < capacity and not (slot == "passive" and id == equipped_heart):
			destination.append(id)


func recipe_rows() -> Array:
	var rows: Array = []
	for id in Content.RECIPES:
		var row: Dictionary = Content.RECIPES[id].duplicate(true)
		row.merge({"id": id, "unlocked": realm >= int(row.unlock_realm), "selected": recipe == id,
			"count": int(pill_stocks[id]), "can_brew": can_brew(id)})
		row.seconds = float(row.seconds) / brew_multiplier()
		rows.append(row)
	return rows


func select_recipe(id: String) -> bool:
	if not Content.RECIPES.has(id) or realm < int(Content.RECIPES[id].unlock_realm):
		return false
	brew_progresses[recipe] = _brew_clock
	recipe = id
	_brew_clock = float(brew_progresses.get(id, 0.0))
	return true


func can_brew(id: String = "") -> bool:
	if id.is_empty():
		id = recipe
	if not Content.RECIPES.has(id):
		return false
	var formula: Dictionary = Content.RECIPES[id]
	return realm >= int(formula.unlock_realm) and herbs >= int(formula.herbs) and dew >= int(formula.dew) and int(pill_stocks[id]) < MAX_RESOURCE


func buff_rows() -> Array:
	var rows: Array = []
	for id in ["spring", "clarity"]:
		if _buff_active(id):
			rows.append({"id": id, "name": String(Content.RECIPES[id].name), "seconds": float(buffs[id]) - lifetime_seconds,
				"effect": "采集 +50%" if id == "spring" else "吐纳 +35%"})
	return rows


func journey_rows() -> Array:
	var rows: Array = []
	for id in Content.JOURNEYS:
		var row: Dictionary = Content.JOURNEYS[id].duplicate(true)
		row.erase("events")
		row.merge({"id": id, "unlocked": realm >= int(row.unlock_realm)})
		rows.append(row)
	return rows


func start_journey(id: String, repeat: bool = false) -> Dictionary:
	var result := {"ok": false, "reason": "missing"}
	if not Content.JOURNEYS.has(id):
		return result
	if not journey.is_empty():
		result.reason = "busy"
		return result
	if realm < int(Content.JOURNEYS[id].unlock_realm):
		result.reason = "locked"
		return result
	journey = {"id": id, "remaining": float(Content.JOURNEYS[id].seconds), "repeat": repeat}
	_record("灵狐出游 · " + String(Content.JOURNEYS[id].name))
	result.ok = true
	result.reason = "started"
	return result


func set_journey_repeat(value: bool) -> void:
	if not journey.is_empty():
		journey["repeat"] = value


func journey_status() -> Dictionary:
	var active := not journey.is_empty()
	var id := String(journey.get("id", ""))
	var seconds := float(Content.JOURNEYS[id].seconds) if active else 1.0
	var left := float(journey.get("remaining", 0.0))
	return {"active": active, "id": id, "name": String(Content.JOURNEYS[id].name) if active else "灵狐在家",
		"seconds_left": left, "progress": clampf(1.0 - left / seconds, 0.0, 1.0) if active else 0.0,
		"repeat": bool(journey.get("repeat", false)), "bond": journey_bond,
		"bond_name": "相伴如初" if journey_bond >= 60 else ("心意相通" if journey_bond >= 20 else ("渐渐亲近" if journey_bond >= 5 else "初见相识")),
		"completed": journey_completed, "last_result": journey_last_result.duplicate(true)}


func _advance_journey(delta: float, events: Array[String]) -> void:
	if journey.is_empty():
		return
	journey.remaining = maxf(0.0, float(journey.remaining) - delta)
	if float(journey.remaining) > EPSILON:
		return
	var id := String(journey.id)
	var repeat := bool(journey.get("repeat", false))
	var biome: Dictionary = Content.JOURNEYS[id]
	var outcome: Dictionary = biome.events[_journey_rng.randi_range(0, biome.events.size() - 1)].duplicate(true)
	outcome.name = String(biome.name)
	outcome.id = id
	var before_herbs := herbs
	var before_dew := dew
	var before_bond := journey_bond
	herbs = mini(MAX_RESOURCE, herbs + int(outcome.herbs))
	dew = mini(MAX_RESOURCE, dew + int(outcome.dew))
	journey_bond = mini(MAX_RESOURCE, journey_bond + int(outcome.bond))
	outcome.herbs = herbs - before_herbs
	outcome.dew = dew - before_dew
	outcome.bond = journey_bond - before_bond
	var before_energy := merit if realm == MAX_REALM else qi
	_add_energy(float(outcome.qi))
	outcome.qi = (merit if realm == MAX_REALM else qi) - before_energy
	_last_step_gains.herbs += int(outcome.herbs)
	_last_step_gains.dew += int(outcome.dew)
	_last_step_gains.journeys += 1
	_last_step_gains.bond += int(outcome.bond)
	journey_completed = mini(MAX_RESOURCE, journey_completed + 1)
	outcome.chests = 0
	if journey_completed % 3 == 0 and gear.chests < Equipment.MAX_CHESTS:
		gear.chests += 1
		outcome.chests = 1
	if not String(outcome.discovery).is_empty():
		discoveries[String(outcome.discovery)] = true
	journey_last_result = outcome
	journey = {"id": id, "remaining": float(biome.seconds), "repeat": true} if repeat else {}
	_record("灵狐归来 · " + String(outcome.text) + (" 另带回宝箱一只。" if int(outcome.chests) > 0 else ""))
	events.append("灵狐从%s归来：灵草 +%d，晨露 +%d，亲密 +%d" % [String(biome.name), int(outcome.herbs), int(outcome.dew), int(outcome.bond)] + ("，宝箱 +1" if int(outcome.chests) > 0 else ""))


func _quest_progress(key: String) -> int:
	match key:
		"seconds": return int(lifetime_seconds)
		"realm": return realm
		"journeys": return journey_completed
	return int(counters.get(key, 0))


func quest_rows() -> Array:
	var rows: Array = []
	var unlocked := true
	for definition in Content.QUESTS:
		var row: Dictionary = definition.duplicate(true)
		var progress := _quest_progress(String(row.counter))
		var claimed := bool(quest_claimed.get(String(row.id), false))
		row.merge({"progress": mini(progress, int(row.target)), "claimed": claimed,
			"unlocked": unlocked, "ready": unlocked and not claimed and progress >= int(row.target)})
		rows.append(row)
		unlocked = claimed
	return rows


func claim_quest(id: String) -> Dictionary:
	var result := {"ok": false, "reason": "missing", "rewards": {}}
	for row in quest_rows():
		if String(row.id) != id:
			continue
		if bool(row.claimed):
			result.reason = "claimed"
		elif not bool(row.ready):
			result.reason = "not_ready"
		else:
			var rewards: Dictionary = row.rewards
			# Keep an earned reward claimable when the resource bag is full.
			if herbs + int(rewards.get("herbs", 0)) > MAX_RESOURCE or dew + int(rewards.get("dew", 0)) > MAX_RESOURCE or gear.chests + int(rewards.get("chests", 0)) > Equipment.MAX_CHESTS:
				result.reason = "resource_full"
				return result
			quest_claimed[id] = true
			herbs += int(rewards.get("herbs", 0))
			dew += int(rewards.get("dew", 0))
			gear.chests += int(rewards.get("chests", 0))
			_add_energy(float(rewards.get("qi", 0.0)))
			result.ok = true
			result.reason = "claimed"
			result.rewards = rewards.duplicate(true)
			_record("山居小记 · " + String(row.name))
		return result
	return result


func material_count(id: String) -> int:
	return materials.count(id)


func material_rows() -> Array:
	return materials.rows()


func recipes_unlocked_by_chapter(stage_id: String) -> Array:
	var names: Array = []
	for id in Materials.RECIPE_ORDER:
		var row: Dictionary = Materials.recipe(String(id))
		if String(row.get("unlock_stage", "")) == stage_id and not stage_id.is_empty(): names.append(String(row.name))
	return names


func crafting_rows() -> Array:
	var result: Array = []
	for id in Materials.RECIPE_ORDER: result.append(crafting_quote(String(id)))
	return result


func crafting_quote(id: String, material_id: String = "") -> Dictionary:
	var row: Dictionary = Materials.recipe(id)
	if row.is_empty(): return {"id": id, "can_craft": false, "ok": false, "reason": "invalid_recipe"}
	var costs: Dictionary = row.materials.duplicate()
	var output_materials: Dictionary = row.get("output_materials", {}).duplicate()
	var selected := ""
	if row.has("alternatives"):
		# A preview can choose mundane stock once; UI passes that exact ID back.
		# Rare jade is never selected implicitly, even when it is the only stock.
		if not material_id.is_empty() and not material_id in row.alternatives:
			return {"id": id, "can_craft": false, "ok": false, "reason": "invalid_material"}
		selected = material_id
		if selected.is_empty():
			selected = String(row.alternatives[0])
			var best_count := -1
			for candidate in row.alternatives:
				if candidate == "spirit_jade": continue
				var owned := material_count(String(candidate))
				if owned >= 3:
					selected = String(candidate)
					break
				if owned > best_count:
					best_count = owned
					selected = String(candidate)
		costs[selected] = 1 if selected == "spirit_jade" else 3
		output_materials.refinement_stone = 3 if selected == "spirit_jade" else 1
	var delta: Dictionary = output_materials.duplicate()
	for cost_id in costs: delta[cost_id] = int(delta.get(cost_id, 0)) - int(costs[cost_id])
	var spec: Dictionary = {}
	var preview: Dictionary = {}
	var output_name := ""
	var output_count := 1
	if row.has("template_id"):
		spec = {"template_id": String(row.template_id), "rarity": String(row.rarity), "level": clampi(realm + 1, 1, 100)}
		preview = gear.item_preview(spec)
		output_name = String(preview.get("name", ""))
	else:
		for output_id in output_materials:
			output_name = String(Materials.material(String(output_id)).name)
			output_count = int(output_materials[output_id])
	var reason := materials.validate_delta(delta)
	if not spec.is_empty() and preview.is_empty(): reason = "invalid_item"
	if not spec.is_empty() and inventory.size() >= Equipment.CAPACITY: reason = "inventory_full"
	var unlock_stage := String(row.get("unlock_stage", ""))
	var unlocked := unlock_stage.is_empty() or int(stage_clears.get(unlock_stage, 0)) > 0
	var unlock_text := "入门百工" if unlock_stage.is_empty() else String(Content.STAGES[unlock_stage].name) + "通关后领悟"
	if not unlocked: reason = "locked_recipe"
	row.merge({"selected_material": selected, "unlocked": unlocked, "unlock_stage": unlock_stage, "unlock_text": unlock_text,
		"comparison": _craft_equipment_comparison(preview), "materials": costs, "costs": _material_cost_rows(costs), "output_materials": output_materials,
		"output_name": output_name, "output_count": output_count, "output_item": preview, "output": preview if not preview.is_empty() else output_materials.duplicate(),
		"item_spec": spec, "delta": delta, "can_craft": reason.is_empty(), "ok": reason.is_empty(), "reason": reason}, true)
	return row


func _craft_equipment_comparison(preview: Dictionary) -> Dictionary:
	if preview.is_empty(): return {}
	var equipped_item: Dictionary = gear.equipped_item(String(preview.slot))
	return {"slot": String(preview.slot), "equipped_name": String(equipped_item.get("name", "未穿戴")),
		"equipped_id": int(equipped_item.get("id", 0)),
		"attack_delta": int(preview.attack) - int(equipped_item.get("attack", 0)),
		"defense_delta": int(preview.defense) - int(equipped_item.get("defense", 0)),
		"evasion_delta": gear.item_evasion_bonus(preview) - gear.item_evasion_bonus(equipped_item),
		"qi_delta": float(preview.qi_bonus) - float(equipped_item.get("qi_bonus", 0.0))}


func _material_cost_rows(costs: Dictionary) -> Array:
	var rows: Array = []
	for id in costs:
		var definition: Dictionary = Materials.material(String(id))
		rows.append({"id": id, "name": String(definition.get("name", id)), "count": int(costs[id]), "owned": material_count(String(id))})
	return rows


func craft_recipe(id: String, material_id: String = "") -> Dictionary:
	var quote := crafting_quote(id, material_id)
	if not bool(quote.get("can_craft", false)): return {"ok": false, "reason": String(quote.reason), "quote": quote}
	# All checks happen before the first mutation. Catalog outputs are
	# canonical and fixed; no animation/UI reopen can spend another cost.
	var item: Dictionary = {}
	if not quote.item_spec.is_empty():
		var added: Dictionary = gear.add_item_spec(quote.item_spec)
		if not bool(added.ok): return added
		item = added.item
	materials.apply_delta(quote.delta)
	_increment("crafted")
	_record("炉边造物 · " + String(quote.name))
	return {"ok": true, "reason": "crafted", "id": id, "name": String(quote.name), "item": item,
		"materials": quote.output_materials.duplicate(), "costs": quote.materials.duplicate(), "output_count": int(quote.output_count)}


func enhancement_quote(instance_id: int, method: String = "herbs") -> Dictionary:
	var item: Dictionary = gear.get_item(instance_id)
	var quote := {"id": instance_id, "method": method, "can_enhance": false, "ok": false,
		"reason": "missing", "materials": {}, "costs": [], "before": {}, "after": {}, "from_rank": 0, "to_rank": 0, "herbs": 0, "dew": 0}
	if item.is_empty(): return quote
	var rank := int(item.get("enhancement", 0))
	quote.before = item.duplicate(true)
	quote.after = gear._make_item(instance_id, String(item.template_id), String(item.rarity), int(item.level), mini(rank + 1, Equipment.MAX_ENHANCEMENT))
	quote.before.evasion_bonus = gear.item_evasion_bonus(item)
	quote.after.evasion_bonus = gear.item_evasion_bonus(quote.after)
	quote.from_rank = rank
	quote.to_rank = mini(rank + 1, Equipment.MAX_ENHANCEMENT)
	if rank >= Equipment.MAX_ENHANCEMENT:
		quote.reason = "max_enhancement"
		return quote
	if method == "materials":
		quote.materials = {"refinement_stone": rank + 1}
		quote.costs = _material_cost_rows(quote.materials)
		quote.reason = materials.validate_delta({"refinement_stone": -(rank + 1)})
	elif method == "herbs":
		var cost: Dictionary = gear.enhancement_cost(instance_id)
		quote.herbs = int(cost.herbs)
		quote.dew = int(cost.dew)
		quote.costs = [{"id": "herbs", "name": "灵草", "count": int(cost.herbs), "owned": herbs}, {"id": "dew", "name": "晨露", "count": int(cost.dew), "owned": dew}]
		quote.reason = "resources" if herbs < int(cost.herbs) or dew < int(cost.dew) else ""
	else:
		quote.reason = "invalid_method"
	quote.can_enhance = String(quote.reason).is_empty()
	quote.ok = quote.can_enhance
	return quote


func enhance_item(instance_id: int, method: String = "herbs") -> Dictionary:
	var quote := enhancement_quote(instance_id, method)
	if not bool(quote.can_enhance): return {"ok": false, "reason": String(quote.reason), "quote": quote, "cost": {"herbs": int(quote.herbs), "dew": int(quote.dew)}}
	var result: Dictionary = gear.enhance_item(instance_id)
	if bool(result.ok):
		if method == "materials":
			materials.apply_delta({"refinement_stone": -int(quote.materials.refinement_stone)})
			result.cost = {"herbs": 0, "dew": 0, "materials": quote.materials.duplicate()}
		else:
			herbs -= int(quote.herbs)
			dew -= int(quote.dew)
		result.method = method
		_increment("enhanced")
		_record("温养旧物 · %s +%d" % [String(result.item.name), int(result.enhancement)])
	return result


func collection_status() -> Dictionary:
	var result := {"realms": [], "items": [], "discoveries": [], "techniques": [], "recipes": [], "progress": 0, "total": 0}
	for index in range(REALM_NAMES.size()):
		result.realms.append({"id": str(index), "name": REALM_NAMES[index], "unlocked": realm >= index})
	for id in Equipment.TEMPLATES:
		result.items.append({"id": id, "name": Equipment.TEMPLATES[id].name, "unlocked": bool(gear.discovered_templates.get(id, false))})
	for id in Content.DISCOVERIES:
		result.discoveries.append({"id": id, "name": Content.DISCOVERIES[id], "unlocked": bool(discoveries.get(id, false))})
	for id in Content.TECHNIQUES:
		result.techniques.append({"id": id, "name": Content.TECHNIQUES[id].name, "unlocked": int(technique_levels[id]) > 0})
	for id in Content.RECIPES:
		result.recipes.append({"id": id, "name": Content.RECIPES[id].name, "unlocked": realm >= int(Content.RECIPES[id].unlock_realm)})
	for key in ["realms", "items", "discoveries", "techniques", "recipes"]:
		for row in result[key]:
			result.total += 1
			if bool(row.unlocked):
				result.progress += 1
	return result


func completion_status() -> Dictionary:
	return {"complete": realm == MAX_REALM, "title": "静修圆满 · 此心归处" if realm == MAX_REALM else "山隐 · 修行之路",
		"description": "你已走过五境十五阶，归于本真。感谢这一程相伴。往后仍可温养旧物、收藏山色，与灵狐从容出游。" if realm == MAX_REALM else "从炼气到化神，走过五境各三阶，最终抵达归真。所有突破都必定成功。",
		"progress": float(realm) / float(MAX_REALM), "realm_count": realm + 1,
		"quest_claimed": quest_claimed.size(), "quest_total": Content.QUESTS.size(),
		"journeys": journey_completed, "finished_at": campaign_finished_at}


func _restore_campaign(data: Dictionary) -> void:
	# Optional v3 sections are independently sanitized: damaged side content
	# never discards a healthy core character or injects arbitrary metadata.
	if int(data.version) < Content.EXPANDED_REALM_VERSION:
		if realm == MAX_REALM:
			campaign_finished_at = lifetime_seconds
		_record("旧卷续写 · 已将原有境界、衣橱与修行进度迁入第一卷。")
	var levels: Variant = data.get("technique_levels", {})
	if levels is Dictionary:
		for id in Content.TECHNIQUES:
			technique_levels[id] = _bounded_saved_int(levels.get(id), 0, int(Content.TECHNIQUES[id].max_level), 1 if id in ["mist", "breath"] else 0)
	_restore_manual_loadout(data)
	var stocks: Variant = data.get("pill_stocks", {})
	if stocks is Dictionary:
		for id in Content.RECIPES:
			pill_stocks[id] = _bounded_saved_int(stocks.get(id), 0, MAX_RESOURCE, pills if id == "qi" else 0)
	var raw_recipe: Variant = data.get("recipe", "qi")
	recipe = raw_recipe if raw_recipe is String and Content.RECIPES.has(raw_recipe) and realm >= int(Content.RECIPES[raw_recipe].unlock_realm) else "qi"
	_brew_clock = minf(_brew_clock, float(Content.RECIPES[recipe].seconds) - EPSILON)
	var raw_progresses: Variant = data.get("brew_progresses", {})
	if raw_progresses is Dictionary:
		for id in Content.RECIPES:
			var progress: Variant = raw_progresses.get(id, 0.0)
			brew_progresses[id] = float(progress) if _valid_number(progress, 0.0, float(Content.RECIPES[id].seconds) - EPSILON) else 0.0
	brew_progresses[recipe] = _brew_clock
	var raw_buffs: Variant = data.get("buffs", {})
	if raw_buffs is Dictionary:
		for id in ["spring", "clarity"]:
			var expiry: Variant = raw_buffs.get(id, 0.0)
			if _valid_number(expiry, lifetime_seconds + EPSILON, minf(MAX_ENERGY, lifetime_seconds + Content.BUFF_CAP)):
				buffs[id] = float(expiry)
	journey_bond = _bounded_saved_int(data.get("journey_bond"), 0, MAX_RESOURCE, 0)
	journey_completed = _bounded_saved_int(data.get("journey_completed"), 0, MAX_RESOURCE, 0)
	var raw_journey: Variant = data.get("journey", {})
	if raw_journey is Dictionary and raw_journey.get("id") is String and Content.JOURNEYS.has(raw_journey.id):
		var id := String(raw_journey.id)
		if realm >= int(Content.JOURNEYS[id].unlock_realm) and _valid_number(raw_journey.get("remaining"), 0.0, float(Content.JOURNEYS[id].seconds)):
			journey = {"id": id, "remaining": maxf(EPSILON, float(raw_journey.remaining)), "repeat": raw_journey.get("repeat") is bool and raw_journey["repeat"]}
	var raw_discoveries: Variant = data.get("discoveries", {})
	if raw_discoveries is Dictionary:
		for id in Content.DISCOVERIES:
			if raw_discoveries.get(id) is bool and raw_discoveries[id]:
				discoveries[id] = true
	var raw_claims: Variant = data.get("quest_claimed", {})
	if raw_claims is Dictionary:
		for quest in Content.QUESTS:
			if raw_claims.get(quest.id) is bool and raw_claims[quest.id]:
				quest_claimed[String(quest.id)] = true
	var raw_counters: Variant = data.get("counters", {})
	if raw_counters is Dictionary:
		for key in counters:
			counters[key] = _bounded_saved_int(raw_counters.get(key), 0, MAX_RESOURCE, 0)
	# Old arrivals keep their world and auto preference; never reopen onboarding
	# or award anything merely because the guidance schema is new.
	arrival_seen = data.get("arrival_seen", true) if data.get("arrival_seen", true) is bool else true
	guidance_dismissed = data.get("guidance_dismissed", false) if data.get("guidance_dismissed", false) is bool else false
	var raw_skipped: Variant = data.get("journey_skipped", {})
	if raw_skipped is Dictionary:
		for id in raw_skipped:
			if id is String and id.length() <= 80 and raw_skipped[id] is bool and raw_skipped[id] and journey_skipped.size() < 64:
				journey_skipped[id] = true
	var raw_journal: Variant = data.get("journal_entries", [])
	if raw_journal is Array and not raw_journal.is_empty():
		journal_entries = []
		for entry in raw_journal.slice(0, 60):
			if entry is Dictionary and entry.get("text") is String and _valid_number(entry.get("time"), 0.0, MAX_ENERGY):
				journal_entries.append({"text": String(entry.text).left(400), "time": float(entry.time)})
	var finished: Variant = data.get("campaign_finished_at", -1.0)
	if realm == MAX_REALM:
		campaign_finished_at = float(finished) if _valid_number(finished, 0.0, lifetime_seconds) else lifetime_seconds
	var raw_last: Variant = data.get("journey_last_result", {})
	if raw_last is Dictionary and raw_last.get("id") is String and Content.JOURNEYS.has(raw_last.id):
		var id := String(raw_last.id)
		journey_last_result = {"id": id, "name": String(Content.JOURNEYS[id].name), "text": String(raw_last.text).left(200) if raw_last.get("text") is String else "灵狐平安归来。", "discovery": ""}
		for key in ["herbs", "dew", "bond", "chests"]:
			journey_last_result[key] = _bounded_saved_int(raw_last.get(key), 0, MAX_RESOURCE, 0)
		journey_last_result.qi = float(raw_last.qi) if _valid_number(raw_last.get("qi"), 0.0, MAX_ENERGY) else 0.0
		if raw_last.get("discovery") is String and Content.DISCOVERIES.has(raw_last.discovery):
			journey_last_result.discovery = raw_last.discovery
	for key in ["journey_rng_seed", "journey_rng_state"]:
		if data.get(key) is String and data[key].is_valid_int() and data[key].length() <= 20:
			if key == "journey_rng_seed":
				_journey_rng.seed = int(data[key])
			else:
				_journey_rng.state = int(data[key])
	settings.window_mode = "window" if settings.get("window_mode") is String and settings.window_mode in ["window","normal"] else "strip"
	settings.window_x = _bounded_saved_int(settings.get("window_x"), -99999, 100000, -99999)
	settings.window_y = _bounded_saved_int(settings.get("window_y"), -99999, 100000, -99999)


# Adventure state deliberately has no integration hook in step(). The host
# owns animation/combat timing and may resolve only the next live enemy.
func stage_rows() -> Array:
	var rows: Array = []
	for id in Content.CHAPTER_ORDER:
		var row: Dictionary = Content.STAGES[id].duplicate(true)
		row.merge(Content.CHAPTERS[id].duplicate(true))
		var cleared := int(stage_clears.get(id, 0)) > 0
		var claimed := bool(chapter_reward_claimed.get(id, false))
		row.merge({"id": id, "selected": selected_stage == id,
			"unlocked": _stage_locked_reason(id).is_empty(), "locked_reason": _stage_locked_reason(id),
			"clears": int(stage_clears.get(id, 0)), "first_clear_claimed": claimed,
			"reward_pending": cleared and not claimed, "token_owned": cleared})
		rows.append(row)
	return rows


func chapter_rows() -> Array:
	return stage_rows()


func chapter_field_guide(id: String) -> Dictionary:
	return preload("res://scripts/chapter_field_guide.gd").entry(id)


func _stage_locked_reason(id: String) -> String:
	if not Content.STAGES.has(id):
		return "未发现此路"
	if realm < int(Content.STAGES[id].unlock_realm):
		return "需达到" + REALM_NAMES[int(Content.STAGES[id].unlock_realm)]
	# Routes already opened in pre-campaign v4 saves stay open; only their
	# original three routes are grandfathered. New chapters keep their gates.
	if int(stage_clears.get(id, 0)) > 0 or bool(legacy_unlocked_stages.get(id, false)):
		return ""
	var previous := String(Content.CHAPTERS[id].prerequisite)
	if not previous.is_empty() and int(stage_clears.get(previous, 0)) <= 0:
		return "先完成" + String(Content.STAGES[previous].name)
	return ""


func _all_chapters_cleared() -> bool:
	for id in Content.CHAPTER_ORDER:
		if int(stage_clears.get(id, 0)) <= 0:
			return false
	return true


func chapter_status() -> Dictionary:
	var completed := 0
	var tokens: Array = []
	var current_id := "summit_gate"
	var found_next := false
	var pending: Array = []
	for id in Content.CHAPTER_ORDER:
		if int(stage_clears.get(id, 0)) > 0:
			completed += 1
			tokens.append(String(Content.CHAPTERS[id].token))
			if not bool(chapter_reward_claimed.get(id, false)):
				pending.append(id)
		elif not found_next:
			current_id = id
			found_next = true
	var resolved := completed == Content.CHAPTER_ORDER.size()
	var ready := resolved and realm == MAX_REALM and not _stage_active and ending_finished_at < 0.0
	var objective := "启程" + String(Content.STAGES[current_id].name)
	var locked := _stage_locked_reason(current_id)
	if not locked.is_empty():
		objective = locked + "，再往" + String(Content.STAGES[current_id].name)
	if resolved:
		objective = "归家突破至归真，合拢六印，写下终章。" if realm < MAX_REALM else "回到山居，合印归心。"
	if ending_finished_at >= 0.0:
		objective = "山河已宁。仍可收藏、出游、静修，或重访旧路。"
	return {"completed": completed, "total": Content.CHAPTER_ORDER.size(),
		"current_chapter": int(Content.CHAPTERS[current_id].chapter), "current_stage_id": current_id,
		"story_resolved": resolved, "epilogue_ready": ready, "ending_complete": ending_finished_at >= 0.0,
		"ending_title": Content.EPILOGUE_TITLE, "title": Content.CAMPAIGN_TITLE,
		"summary": Content.EPILOGUE_TEXT if ending_finished_at >= 0.0 else (String(Content.CHAPTERS.summit_gate.resolution) if resolved else String(Content.CHAPTERS[current_id].summary)),
		"next_objective": objective, "tokens": tokens, "pending_rewards": pending,
		"story_resolved_at": story_resolved_at, "finished_at": ending_finished_at,
		"peaceful_complete": realm == MAX_REALM}


func complete_home_epilogue() -> Dictionary:
	if ending_finished_at >= 0.0:
		return {"ok": false, "reason": "already_complete", "title": Content.EPILOGUE_TITLE, "text": Content.EPILOGUE_TEXT}
	if not bool(chapter_status().epilogue_ready):
		return {"ok": false, "reason": "not_ready", "title": Content.EPILOGUE_TITLE, "text": "六印齐聚、抵达归真后，归家写下终章。"}
	ending_finished_at = lifetime_seconds
	_record(Content.EPILOGUE_TITLE + " · " + Content.EPILOGUE_TEXT)
	return {"ok": true, "reason": "completed", "title": Content.EPILOGUE_TITLE, "text": Content.EPILOGUE_TEXT}


func claim_chapter_reward(id: String) -> Dictionary:
	var result := {"ok": false, "reason": "missing", "stage_id": id, "herbs": 0, "dew": 0, "qi": 0.0, "item": null}
	if not Content.CHAPTERS.has(id):
		return result
	if int(stage_clears.get(id, 0)) <= 0:
		result.reason = "not_cleared"
		return result
	if bool(chapter_reward_claimed.get(id, false)):
		result.reason = "already_claimed"
		return result
	var reward: Dictionary = Content.CHAPTERS[id].first_clear_reward
	var energy := merit if realm == MAX_REALM else qi
	# All-or-nothing claim: neither rare owned gear nor resources are silently
	# lost at capacity. The earned package remains claimable after making room.
	if gear.inventory.size() >= Equipment.CAPACITY:
		result.reason = "inventory_full"
		return result
	if herbs + int(reward.herbs) > MAX_RESOURCE or dew + int(reward.dew) > MAX_RESOURCE or energy + float(reward.qi) > MAX_ENERGY:
		result.reason = "resource_full"
		return result
	var item: Dictionary = gear._make_item(gear._allocate_id(), String(reward.template_id), String(reward.rarity), int(reward.level))
	gear.inventory.append(item)
	gear.discovered_templates[String(reward.template_id)] = true
	herbs += int(reward.herbs)
	dew += int(reward.dew)
	_add_energy(float(reward.qi))
	chapter_reward_claimed[id] = true
	result.merge({"ok": true, "reason": "claimed", "herbs": int(reward.herbs), "dew": int(reward.dew), "qi": float(reward.qi),
		"item": item.duplicate(true), "token": String(Content.CHAPTERS[id].token), "text": String(Content.CHAPTERS[id].first_clear_reward_text)}, true)
	_record("山印回响 · " + String(Content.CHAPTERS[id].first_clear_reward_text))
	return result


func select_stage(id: String) -> bool:
	if _stage_active or not _stage_locked_reason(id).is_empty() or (id != selected_stage and bool(stage_corpse_status().get("pending", false))):
		return false
	if selected_stage != id:
		stage_run = {}
	selected_stage = id
	return true


func stage_status() -> Dictionary:
	var id: String = String(stage_run.get("id", selected_stage))
	var definition: Dictionary = Content.STAGES[id]
	var kills: int = int(stage_run.get("kills", 0))
	return {"active": _stage_active and not stage_run.is_empty(),
		"paused": not _stage_active and not stage_run.is_empty(), "id": id,
		"name": String(definition.name), "run_id": int(stage_run.get("run_id", 0)),
		"kills": kills, "total": definition.monsters.size(),
		"travel_checkpoint": kills, "failed": bool(stage_run.get("failed", false)),
		"retry_available": not _stage_active and not stage_run.is_empty(), "locked_reason": _stage_locked_reason(id),
		"opportunity_checked": bool(stage_run.get("opportunity_checked", false)),
		"opportunity_pending": _route_opportunity_pending(),
		"corpse_pending": bool(stage_corpse_status().get("pending", false)), "corpse": stage_corpse_status(),
		"battle_resources": stage_battle_resources(),
		"next_monster": definition.monsters[kills].duplicate(true) if kills < definition.monsters.size() else {},
		"monsters": definition.monsters.duplicate(true)}


func start_stage() -> Dictionary:
	if not pending_heart_switch.is_empty():
		return {"ok": false, "reason": "heart_adjusting"}
	if bool(settings.get("paused", false)):
		return {"ok": false, "reason": "paused"}
	if _stage_active:
		return {"ok": false, "reason": "busy"}
	if not _stage_locked_reason(selected_stage).is_empty():
		return {"ok": false, "reason": "locked", "locked_reason": _stage_locked_reason(selected_stage)}
	var resuming := not stage_run.is_empty()
	if not resuming:
		if _stage_serial >= MAX_RESOURCE:
			return {"ok": false, "reason": "run_limit"}
		_stage_serial += 1
		stage_run = {"id": selected_stage, "run_id": _stage_serial, "kills": 0, "travel_checkpoint": 0, "opportunity_checked": false}
	_stage_active = true
	stage_run.failed = false
	stage_battle_resources()
	_invalidate_heart_quote()
	var result := stage_status()
	result.merge({"ok": true, "reason": "resumed" if resuming else "started"})
	_record(("继续历练 · " if resuming else "启程历练 · ") + String(result.name))
	return result


func pause_stage(run_id: int = -1) -> Dictionary:
	if stage_run.is_empty():
		return {"ok": false, "reason": "idle"}
	if run_id != -1 and run_id != int(stage_run.run_id):
		return {"ok": false, "reason": "stale_encounter"}
	if not _stage_active:
		return {"ok": false, "reason": "already_paused"}
	_stage_active = false
	_record("归山调息 · " + String(Content.STAGES[stage_run.id].name) + "，已过路段与收获保留。")
	var result := stage_status()
	result.merge({"ok": true, "reason": "paused"})
	return result


func fail_stage(run_id: int) -> Dictionary:
	var result := pause_stage(run_id)
	if bool(result.get("ok", false)):
		stage_run.failed = true
		result.failed = true
		result.reason = "defeated"
		_record("历练小憩 · 此次切磋暂止。归家调息后，可从未过的守灵继续。")
	return result


func cancel_stage() -> Dictionary:
	if stage_run.is_empty():
		return {"ok": false, "reason": "idle"}
	if bool(stage_corpse_status().get("pending", false)):
		_stage_active = false
		_record("归山调息 · 已击退守灵与未搜遗物保留，继续此程即可搜取。")
		return {"ok": true, "reason": "corpse_preserved", "corpse": stage_corpse_status()}
	var id := String(stage_run.id)
	stage_run = {}
	_stage_active = false
	_record("历练归来 · " + String(Content.STAGES[id].name) + "，已获收获均已收入行囊。")
	return {"ok": true, "reason": "cancelled"}


func stage_corpse_status() -> Dictionary:
	var corpse: Dictionary = stage_run.get("pending_corpse", {})
	if corpse.is_empty(): return {}
	var index := int(corpse.monster_index)
	var id := String(stage_run.id)
	var elapsed := float(corpse.search_seconds)
	return {"pending": true, "stage_id": id, "run_id": int(stage_run.run_id), "monster_index": index,
		"monster": Content.STAGES[id].monsters[index].duplicate(true), "search_seconds": elapsed,
		"search_required": SEARCH_SECONDS, "search_progress": clampf(elapsed / SEARCH_SECONDS, 0.0, 1.0),
		"search_ready": elapsed + EPSILON >= SEARCH_SECONDS, "rewards": corpse.rewards.duplicate(true)}


func _stage_encounter_guard(run_id: int, monster_index: int) -> String:
	if not _stage_active or stage_run.is_empty(): return "idle"
	if bool(settings.get("paused", false)): return "paused"
	if run_id != int(stage_run.run_id) or monster_index != int(stage_run.kills): return "stale_encounter"
	var definition: Dictionary = Content.STAGES[stage_run.id]
	if monster_index < 0 or monster_index >= definition.monsters.size(): return "invalid_monster"
	if monster_index == 2:
		if not bool(stage_run.get("opportunity_checked", false)): return "route_checkpoint_required"
		if _route_opportunity_pending(): return "opportunity_pending"
	return ""


func begin_stage_corpse(run_id: int, monster_index: int) -> Dictionary:
	var reason := _stage_encounter_guard(run_id, monster_index)
	if not reason.is_empty(): return {"ok": false, "reason": reason}
	if not stage_run.get("pending_corpse", {}).is_empty():
		var existing := stage_corpse_status()
		existing.merge({"ok": true, "reason": "already_pending"})
		return existing
	# Kill evidence is supplied once by the actual combat host. Roll now and
	# persist the earned payload; never reroll at claim, reload or retreat.
	stage_run.pending_corpse = {"version": 1, "monster_index": monster_index, "search_seconds": 0.0,
		"rewards": _roll_stage_corpse_rewards(String(stage_run.id), monster_index)}
	var result := stage_corpse_status()
	result.merge({"ok": true, "reason": "corpse_created"})
	return result


func advance_stage_search(run_id: int, monster_index: int, delta: float) -> Dictionary:
	var reason := _stage_encounter_guard(run_id, monster_index)
	if not reason.is_empty(): return {"ok": false, "reason": reason}
	if not is_finite(delta) or delta <= 0.0: return {"ok": false, "reason": "invalid_delta"}
	if stage_run.get("pending_corpse", {}).is_empty(): return {"ok": false, "reason": "no_corpse"}
	# Only the host's actual close-range search phase calls this API. General
	# step(), travel, offline catch-up and UI animation never advance it.
	stage_run.pending_corpse.search_seconds = minf(SEARCH_SECONDS, float(stage_run.pending_corpse.search_seconds) + delta)
	var result := stage_corpse_status()
	result.merge({"ok": true, "reason": "searching"})
	return result


func complete_stage_search(run_id: int, monster_index: int) -> Dictionary:
	var reason := _stage_encounter_guard(run_id, monster_index)
	if not reason.is_empty(): return {"ok": false, "reason": reason, "stage_finished": false}
	var corpse := stage_corpse_status()
	if not bool(corpse.get("pending", false)): return {"ok": false, "reason": "no_corpse", "stage_finished": false}
	if not bool(corpse.search_ready): return {"ok": false, "reason": "search_incomplete", "stage_finished": false}
	var reward: Dictionary = corpse.rewards
	# Earned loot stays in the corpse if any stack, resource or bag is full.
	# There is no silent conversion, truncation, partial payout or lost item.
	reason = _corpse_capacity_reason(reward)
	if not reason.is_empty(): return {"ok": false, "reason": reason, "stage_finished": false, "rewards": reward}
	var item: Variant = null
	if not reward.item_spec.is_empty(): item = gear.add_item_spec(reward.item_spec).item
	materials.apply_delta(reward.materials)
	herbs += int(reward.herbs)
	dew += int(reward.dew)
	gear.chests += int(reward.chests)
	_add_energy(float(reward.qi))
	# Clearing the token and advancing the checkpoint happen in this same
	# transaction. Repeating complete cannot grant any part of this body twice.
	stage_run.erase("pending_corpse")
	stage_run.kills = monster_index + 1
	stage_run.travel_checkpoint = monster_index + 1
	total_victories = mini(MAX_RESOURCE, total_victories + 1)
	var result: Dictionary = reward.duplicate(true)
	result.merge({"ok": true, "reason": "searched", "source": "stage_corpse", "item": item,
		"run_id": run_id, "monster_index": monster_index, "stage_id": String(corpse.stage_id),
		"stage_finished": false, "opportunity": {}, "first_clear": false, "chapter_reward": {},
		"material_rows": _material_cost_rows(reward.materials), "overflow": false, "chest_overflow": 0,
		"resource_overflow": {"herbs": 0, "dew": 0, "qi": 0.0}}, true)
	_record("搜取遗物 · " + String(corpse.monster.name))
	_finish_stage_reward(result, String(corpse.stage_id))
	return result


func _corpse_capacity_reason(reward: Dictionary) -> String:
	var reason := materials.validate_delta(reward.materials)
	if not reason.is_empty(): return reason
	if not reward.item_spec.is_empty() and inventory.size() >= Equipment.CAPACITY: return "inventory_full"
	if gear.chests + int(reward.chests) > Equipment.MAX_CHESTS: return "chest_full"
	var energy := merit if realm == MAX_REALM else qi
	if herbs + int(reward.herbs) > MAX_RESOURCE or dew + int(reward.dew) > MAX_RESOURCE or energy + float(reward.qi) > MAX_ENERGY: return "resource_full"
	return ""


func _base_corpse_materials(stage_id: String, monster_index: int) -> Dictionary:
	var definition: Dictionary = Content.STAGES[stage_id]
	var monster: Dictionary = definition.monsters[monster_index]
	var material_id := Materials.route_material(String(definition.biome), String(monster.visual_type))
	var result := {"spirit_shard": 1}
	if not material_id.is_empty(): result[material_id] = 3 if bool(monster.boss) else 2
	return result


func _roll_stage_corpse_rewards(stage_id: String, monster_index: int) -> Dictionary:
	var definition: Dictionary = Content.STAGES[stage_id]
	var result := {"herbs": int(definition.reward.herbs), "dew": int(definition.reward.dew), "qi": float(definition.reward.qi),
		"chests": 0, "item_spec": {}, "materials": _base_corpse_materials(stage_id, monster_index),
		"chest_rolled": false, "equipment_rolled": false, "treasure_rolled": false}
	# Independent 12% and 3% rolls retain the original distribution and rarity.
	result.chest_rolled = _adventure_rng.randf() < Content.STAGE_CHEST_CHANCE
	result.equipment_rolled = _adventure_rng.randf() < Content.STAGE_EQUIPMENT_CHANCE
	result.chests = 1 if bool(result.chest_rolled) else 0
	if bool(result.equipment_rolled):
		var template_ids: Array = Equipment.TEMPLATES.keys()
		var template_id: String = String(template_ids[_adventure_rng.randi_range(0, template_ids.size() - 1)])
		var roll := _adventure_rng.randf()
		var rarity := "common" if roll < 0.60 else ("uncommon" if roll < 0.88 else ("rare" if roll < 0.98 else "epic"))
		result.item_spec = {"template_id": template_id, "rarity": rarity, "level": int(definition.unlock_realm) + 1}
	result.treasure_rolled = _adventure_rng.randf() < Materials.TREASURE_CHANCE
	if bool(result.treasure_rolled): result.materials.spirit_jade = 1
	return result


func _restore_stage_corpse(raw: Variant) -> void:
	if stage_run.is_empty() or not raw is Dictionary: return
	if not _valid_integer(raw.get("monster_index"), int(stage_run.kills), int(stage_run.kills)): return
	var saved: Variant = raw.get("rewards")
	if not saved is Dictionary: return
	var id := String(stage_run.id)
	var index := int(stage_run.kills)
	var definition: Dictionary = Content.STAGES[id]
	# Only finite IDs/flags are retained. Fixed resources/materials are derived
	# from trusted route data, never arbitrary names, paths or saved stat blobs.
	var reward := {"herbs": int(definition.reward.herbs), "dew": int(definition.reward.dew), "qi": float(definition.reward.qi),
		"chests": 0, "item_spec": {}, "materials": _base_corpse_materials(id, index),
		"chest_rolled": saved.get("chest_rolled") is bool and saved.chest_rolled,
		"equipment_rolled": saved.get("equipment_rolled") is bool and saved.equipment_rolled,
		"treasure_rolled": saved.get("treasure_rolled") is bool and saved.treasure_rolled}
	reward.chests = 1 if bool(reward.chest_rolled) else 0
	if bool(reward.equipment_rolled) and saved.get("item_spec") is Dictionary and gear.item_spec_valid(saved.item_spec):
		reward.item_spec = {"template_id": String(saved.item_spec.template_id), "rarity": String(saved.item_spec.rarity), "level": int(definition.unlock_realm) + 1}
	else: reward.equipment_rolled = false
	if bool(reward.treasure_rolled): reward.materials.spirit_jade = 1
	stage_run.pending_corpse = {"version": 1, "monster_index": index,
		"search_seconds": _finite_bounded(raw.get("search_seconds"), 0.0, SEARCH_SECONDS, 0.0), "rewards": reward}
	if index == 2: stage_run.opportunity_checked = true


func _finish_stage_reward(result: Dictionary, id: String) -> void:
	var definition: Dictionary = Content.STAGES[id]
	if int(stage_run.kills) != definition.monsters.size(): return
	result.first_clear = int(stage_clears.get(id, 0)) == 0
	stage_clears[id] = mini(MAX_RESOURCE, int(stage_clears.get(id, 0)) + 1)
	stage_run = {}
	_stage_active = false
	result.stage_finished = true
	if bool(result.first_clear):
		result.recipe_unlocks = recipes_unlocked_by_chapter(id)
		result.chapter_reward = claim_chapter_reward(id)
		result.chapter_resolution = String(Content.CHAPTERS[id].resolution)
		_record("第%d章 · %s" % [int(Content.CHAPTERS[id].chapter), String(Content.CHAPTERS[id].resolution)])
		if _all_chapters_cleared() and story_resolved_at < 0.0:
			story_resolved_at = lifetime_seconds
			_record("六印归一 · 山河灵脉已重新相连。归家后可写下山居终章。")
	_record("历练完成 · " + String(definition.name) + "。守关首领已退，传送归家静修。")


func defeat_stage_monster(run_id: int, monster_index: int) -> Dictionary:
	# Legacy test/import compatibility only. The live host must use the durable
	# begin/advance/complete corpse APIs, never this immediate reward adapter.
	if bool(stage_corpse_status().get("pending", false)):
		return {"ok": false, "reason": "corpse_pending", "stage_finished": false}
	var result := {"ok": false, "reason": "idle", "herbs": 0, "dew": 0, "qi": 0.0,
		"chests": 0, "item": null, "stage_finished": false, "opportunity": {}, "first_clear": false, "chapter_reward": {}}
	if not _stage_active or stage_run.is_empty():
		return result
	if bool(settings.get("paused", false)):
		result.reason = "paused"
		return result
	if run_id != int(stage_run.run_id) or monster_index != int(stage_run.kills):
		result.reason = "stale_encounter"
		return result
	var id := String(stage_run.id)
	var definition: Dictionary = Content.STAGES[id]
	if monster_index < 0 or monster_index >= definition.monsters.size():
		result.reason = "invalid_monster"
		return result
	if monster_index == 2:
		if not bool(stage_run.get("opportunity_checked", false)):
			result.reason = "route_checkpoint_required"
			return result
		if _route_opportunity_pending():
			result.reason = "opportunity_pending"
			return result
	stage_run.kills = monster_index + 1
	stage_run.travel_checkpoint = monster_index + 1
	total_victories = mini(MAX_RESOURCE, total_victories + 1)
	result = _stage_kill_reward(id)
	result.merge({"run_id": run_id, "monster_index": monster_index,
		"stage_id": id, "stage_finished": false, "opportunity": {}, "first_clear": false, "chapter_reward": {}})
	_finish_stage_reward(result, id)

	return result


func _route_opportunity_pending() -> bool:
	# A legacy post-clear choice or a choice left after retreat remains
	# claimable, but may not silently block a different route instance.
	return not stage_run.is_empty() and not pending_opportunity.is_empty() and int(pending_opportunity.run_id) == int(stage_run.run_id) and String(pending_opportunity.stage_id) == String(stage_run.id)


func check_route_opportunity(run_id: int) -> Dictionary:
	var result := {"ok": false, "reason": "idle", "opportunity": {}, "opportunity_pending": false}
	if not _stage_active or stage_run.is_empty():
		return result
	if bool(settings.get("paused", false)):
		result.reason = "paused"
		return result
	if run_id != int(stage_run.run_id):
		result.reason = "stale_encounter"
		return result
	if int(stage_run.kills) != 2:
		result.reason = "not_at_checkpoint"
		return result
	result.ok = true
	if bool(stage_run.get("opportunity_checked", false)):
		result.reason = "already_checked"
	else:
		stage_run.opportunity_checked = true
		stage_run.travel_checkpoint = 2
		result.reason = "checked"
		# This is a route landmark between the second enemy and the boss.
		# Keep an existing v4 choice intact; never overwrite or time it out.
		if pending_opportunity.is_empty() and _adventure_rng.randf() < Content.OPPORTUNITY_CHANCE:
			pending_opportunity = {"id": "quiet_cairn", "stage_id": String(stage_run.id), "run_id": run_id}
			_record("途中奇遇 · " + String(Content.ROUTE_OPPORTUNITIES[stage_run.id].name) + "。停步择一，再赴守关首领。")
	result.opportunity_pending = _route_opportunity_pending()
	result.opportunity = opportunity_status() if bool(result.opportunity_pending) else {}
	return result


func _stage_kill_reward(stage_id: String) -> Dictionary:
	var definition: Dictionary = Content.STAGES[stage_id]
	var result := {"ok": true, "reason": "resources", "source": "stage_monster",
		"herbs": int(definition.reward.herbs), "dew": int(definition.reward.dew),
		"qi": float(definition.reward.qi), "chests": 0, "item": null, "overflow": false,
		"chest_rolled": false, "equipment_rolled": false, "chest_overflow": 0}
	# Both coins are rolled first, independently of capacity or item rarity.
	result.chest_rolled = _adventure_rng.randf() < Content.STAGE_CHEST_CHANCE
	result.equipment_rolled = _adventure_rng.randf() < Content.STAGE_EQUIPMENT_CHANCE
	if bool(result.chest_rolled):
		if gear.chests < Equipment.MAX_CHESTS:
			gear.chests += 1
			result.chests = 1
		else:
			result.chest_overflow = 1
	if bool(result.equipment_rolled):
		var template_ids: Array = Equipment.TEMPLATES.keys()
		var template_id: String = String(template_ids[_adventure_rng.randi_range(0, template_ids.size() - 1)])
		var rarity_roll := _adventure_rng.randf()
		var rarity := "common" if rarity_roll < 0.60 else ("uncommon" if rarity_roll < 0.88 else ("rare" if rarity_roll < 0.98 else "epic"))
		if gear.inventory.size() >= Equipment.CAPACITY:
			result.overflow = true
			result.reason = "inventory_full"
			result.herbs += 3
			result.dew += 1
		else:
			# Use the ledger's canonical factory and collision-safe allocator;
			# do not invoke its legacy 35% monster roll or tutorial guarantee.
			var item: Dictionary = gear._make_item(gear._allocate_id(), template_id, rarity, int(definition.unlock_realm) + 1)
			gear.inventory.append(item)
			gear.discovered_templates[template_id] = true
			result.item = item.duplicate(true)
			result.reason = "equipment"
	_apply_encounter_resources(result)
	var before_energy := merit if realm == MAX_REALM else qi
	var requested_qi := float(result.qi)
	_add_energy(requested_qi)
	result.qi = (merit if realm == MAX_REALM else qi) - before_energy
	result.resource_overflow.qi = requested_qi - float(result.qi)
	return result


func opportunity_status() -> Dictionary:
	if pending_opportunity.is_empty():
		return {}
	var stage_id := String(pending_opportunity.stage_id)
	var scene: Dictionary = Content.ROUTE_OPPORTUNITIES[stage_id]
	return {"id": "quiet_cairn", "name": String(scene.name), "stage_id": stage_id,
		"run_id": int(pending_opportunity.run_id), "stage_name": String(Content.STAGES[stage_id].name),
		"description": String(scene.description), "choices": scene.choices.duplicate(true),
		"energy_name": "功德" if realm == MAX_REALM else "灵气"}


func choose_opportunity(choice_id: String) -> Dictionary:
	var status := opportunity_status()
	if status.is_empty():
		return {"ok": false, "reason": "missing", "rewards": {}}
	for choice in status.choices:
		if String(choice.id) != choice_id:
			continue
		var rewards: Dictionary = choice.rewards
		var energy := merit if realm == MAX_REALM else qi
		if herbs + int(rewards.get("herbs", 0)) > MAX_RESOURCE or dew + int(rewards.get("dew", 0)) > MAX_RESOURCE or energy + float(rewards.get("qi", 0.0)) > MAX_ENERGY:
			return {"ok": false, "reason": "resource_full", "rewards": {}}
		pending_opportunity = {}
		herbs += int(rewards.get("herbs", 0))
		dew += int(rewards.get("dew", 0))
		_add_energy(float(rewards.get("qi", 0.0)))
		_record("奇遇了结 · " + String(choice.name))
		return {"ok": true, "reason": "chosen", "name": String(choice.name), "rewards": rewards.duplicate(true)}
	return {"ok": false, "reason": "invalid_choice", "rewards": {}}


func meridian_node_ids() -> Array[String]:
	# Stable content order, independent of the order in which branches were bought.
	var ids: Array[String] = []
	for point in Content.ACUPOINTS:
		if meridian_opened.get(String(point.id), false) == true:
			ids.append(String(point.id))
	return ids


func meridian_branch_rows() -> Array:
	var rows: Array = []
	for id in Content.MERIDIAN_BRANCH_ORDER:
		var branch: Dictionary = Content.MERIDIAN_BRANCHES[id].duplicate(true)
		var total := 0
		var opened := 0
		for point in Content.ACUPOINTS:
			if String(point.branch) != id:
				continue
			total += 1
			if meridian_opened.has(String(point.id)):
				opened += 1
		branch.merge({"id": id, "total": total, "opened": opened})
		rows.append(branch)
	return rows


func meridian_rows() -> Array:
	var rows: Array = []
	var energy := merit if realm == MAX_REALM else qi
	var names := {}
	for point in Content.ACUPOINTS:
		names[String(point.id)] = String(point.name)
	for index in range(Content.ACUPOINTS.size()):
		var row: Dictionary = Content.ACUPOINTS[index].duplicate(true)
		var active: bool = meridian_opened.get(String(row.id), false) == true
		var missing: Array[String] = []
		var prerequisites: Array[String] = []
		for required in row.get("prerequisites", []):
			prerequisites.append(String(names.get(required, required)))
			if not meridian_opened.get(String(required), false) == true:
				missing.append(String(names.get(required, required)))
		var unlocked: bool = not active and missing.is_empty() and realm >= int(row.unlock_realm)
		var affordable := energy + EPSILON >= float(row.cost_qi) and herbs >= int(row.cost_herbs) and dew >= int(row.cost_dew)
		var locked_reason := ""
		if active:
			locked_reason = "已贯通 · 永久生效"
		elif not missing.is_empty():
			locked_reason = "先通 " + "、".join(missing)
		elif realm < int(row.unlock_realm):
			locked_reason = "需达 " + REALM_NAMES[int(row.unlock_realm)]
		elif not affordable:
			locked_reason = ("功德" if realm == MAX_REALM else "灵气") + "或草露不足"
		row.merge({"index": index, "active": active, "unlocked": unlocked,
			"can_unlock": unlocked and affordable, "locked_reason": locked_reason,
			"prerequisite_names": prerequisites, "missing_prerequisites": missing,
			"energy_name": "功德" if realm == MAX_REALM else "灵气"})
		rows.append(row)
	return rows


func unlock_meridian(id: String) -> Dictionary:
	# Resolve all conditions afresh, so stale/duplicate UI callbacks cannot charge.
	for row in meridian_rows():
		if String(row.id) != id:
			continue
		if bool(row.active):
			return {"ok": false, "reason": "already_open"}
		if not bool(row.unlocked):
			return {"ok": false, "reason": "locked"}
		if not bool(row.can_unlock):
			return {"ok": false, "reason": "resources"}
		if realm == MAX_REALM:
			merit = maxf(0.0, merit - float(row.cost_qi))
		else:
			qi = maxf(0.0, qi - float(row.cost_qi))
		herbs -= int(row.cost_herbs)
		dew -= int(row.cost_dew)
		meridian_opened[id] = true
		_record("经络贯通 · " + String(row.name) + "，" + String(row.effect))
		return {"ok": true, "reason": "opened", "id": id, "name": String(row.name),
			"cost": {"qi": float(row.cost_qi), "herbs": int(row.cost_herbs), "dew": int(row.cost_dew)},
			"bonuses": meridian_bonuses()}
	return {"ok": false, "reason": "missing"}


func meridian_bonuses() -> Dictionary:
	var result := {"qi_rate": 0.0, "gather": 0.0, "brew": 0.0, "attack": 0, "defense": 0,
		"combat_haste": 0.0, "poise_bonus": 0, "break_bonus": 0.0, "counter_bonus": 0.0,
		"guard_bonus": 0.0, "dodge_bonus": 0.0, "recovery_bonus": 0.0, "combat_qi_max": 0.0, "combat_qi_regen": 0.0,
		"skill_cost_reduction": 0.0, "skill_cooldown_reduction": 0.0}
	for point in Content.ACUPOINTS:
		if not meridian_opened.get(String(point.id), false) == true:
			continue
		for key in point.bonuses:
			result[key] += point.bonuses[key]
	return result


func _restore_meridians(data: Dictionary) -> void:
	meridian_opened.clear()
	var candidates := {}
	if data.has("meridian_nodes") or data.has("meridian_revision"):
		# Never fall back to a prefix count for a new-format malformed list.
		var saved: Variant = data.get("meridian_nodes")
		if saved is Array:
			for id in saved:
				if id is String:
					candidates[id] = true
	else:
		# A v4 count meant exactly this prefix, never any newly added branch.
		var count := _bounded_saved_int(data.get("meridian_count"), 0, Content.LEGACY_ACUPOINT_IDS.size(), 0)
		for index in range(count):
			candidates[Content.LEGACY_ACUPOINT_IDS[index]] = true
	# Canonical content is topologically ordered. Unknown IDs, duplicated IDs,
	# absent parents and prematurely opened realm gates cannot grant bonuses.
	for point in Content.ACUPOINTS:
		var id := String(point.id)
		if not candidates.has(id) or realm < int(point.unlock_realm):
			continue
		var ready := true
		for required in point.get("prerequisites", []):
			if not meridian_opened.has(String(required)):
				ready = false
		if ready:
			meridian_opened[id] = true


func _restore_adventure(value: Variant) -> void:
	# An interrupted route reloads at the next unclaimed monster, but remains
	# paused until Start is explicitly pressed. Offline time cannot fight.
	if not value is Dictionary:
		return
	var data: Dictionary = value
	var raw_clears: Variant = data.get("stage_clears", {})
	if raw_clears is Dictionary:
		for id in Content.CHAPTER_ORDER:
			var count := _bounded_saved_int(raw_clears.get(id), 0, MAX_RESOURCE, 0)
			if count > 0:
				stage_clears[id] = count
	var legacy := not _valid_integer(data.get("campaign_revision"), Content.CAMPAIGN_REVISION, Content.CAMPAIGN_REVISION)
	var raw_unlocks: Variant = data.get("legacy_unlocked_stages", {})
	for id in ["bamboo_pass", "creek_bridge", "cloud_slope"]:
		if realm >= int(Content.STAGES[id].unlock_realm) and (legacy or (raw_unlocks is Dictionary and raw_unlocks.get(id) is bool and raw_unlocks[id])):
			legacy_unlocked_stages[id] = true
	var raw_claims: Variant = data.get("chapter_reward_claimed", {})
	if raw_claims is Dictionary:
		for id in Content.CHAPTER_ORDER:
			if int(stage_clears.get(id, 0)) > 0 and raw_claims.get(id) is bool and raw_claims[id]:
				chapter_reward_claimed[id] = true
	if _all_chapters_cleared():
		story_resolved_at = float(data.story_resolved_at) if _valid_number(data.get("story_resolved_at"), 0.0, lifetime_seconds) else lifetime_seconds
		if realm == MAX_REALM and _valid_number(data.get("ending_finished_at"), 0.0, lifetime_seconds):
			ending_finished_at = float(data.ending_finished_at)
	var chosen: Variant = data.get("selected_stage")
	if chosen is String and _stage_locked_reason(chosen).is_empty():
		selected_stage = chosen
	_stage_serial = _bounded_saved_int(data.get("stage_serial"), 0, MAX_RESOURCE, 0)
	_restore_meridians(data)
	var raw_run: Variant = data.get("stage_run", {})
	if raw_run is Dictionary and raw_run.get("id") is String and Content.STAGES.has(raw_run.id):
		var id := String(raw_run.id)
		if _stage_locked_reason(id).is_empty() and _valid_integer(raw_run.get("run_id"), 1, MAX_RESOURCE) and _valid_integer(raw_run.get("kills"), 0, Content.STAGES[id].monsters.size() - 1):
			stage_run = {"id": id, "run_id": int(raw_run.run_id), "kills": int(raw_run.kills),
				"travel_checkpoint": int(raw_run.kills), "failed": raw_run.get("failed") is bool and raw_run.failed,
				"opportunity_checked": int(raw_run.kills) == 2 and raw_run.get("opportunity_checked") is bool and raw_run.opportunity_checked,
				"battle_resources": _sanitize_battle_resources(raw_run.get("battle_resources", {}), not raw_run.has("battle_resources"))}
			_restore_stage_corpse(raw_run.get("pending_corpse", {}))
			selected_stage = id
			pending_heart_switch = {} # Invalid simultaneous route wins over an injected adjustment.
			_stage_serial = maxi(_stage_serial, int(raw_run.run_id))
	_stage_active = false
	var raw_choice: Variant = data.get("pending_opportunity", {})
	if raw_choice is Dictionary and raw_choice.get("id") is String and raw_choice.id == "quiet_cairn" and raw_choice.get("stage_id") is String and Content.STAGES.has(raw_choice.stage_id):
		var stage_id := String(raw_choice.stage_id)
		if realm >= int(Content.STAGES[stage_id].unlock_realm) and _valid_integer(raw_choice.get("run_id"), 1, MAX_RESOURCE):
			pending_opportunity = {"id": "quiet_cairn", "stage_id": stage_id, "run_id": int(raw_choice.run_id)}
			_stage_serial = maxi(_stage_serial, int(raw_choice.run_id))
	# An interrupted choice must remain before the boss, even if an older
	# v4 snapshot predates the explicit checkpoint marker.
	if not stage_run.is_empty() and int(stage_run.kills) == 2 and _route_opportunity_pending():
		stage_run.opportunity_checked = true
	_restore_meridians(data)
	for key in ["rng_seed", "rng_state"]:
		if data.get(key) is String and data[key].is_valid_int() and data[key].length() <= 20:
			if key == "rng_seed":
				_adventure_rng.seed = int(data[key])
			else:
				_adventure_rng.state = int(data[key])


func _finite_bounded(value: Variant, minimum: float, maximum: float, fallback: float) -> float:
	if not (value is int or value is float) or not is_finite(float(value)):
		return fallback
	return clampf(float(value), minimum, maximum)


func _invalidate_heart_quote() -> void:
	_heart_quote = {}


func _heart_quote_fingerprint() -> String:
	return JSON.stringify([realm, technique_levels, attuned_techniques, equipped_heart,
		equipped_weapon_art, equipped_actives, equipped_passives, heart_equipped_once, last_equipped_heart,
		_heart_switch_serial, stage_run.get("run_id", 0)]).sha256_text()


func quote_heart_switch(id: String) -> Dictionary:
	if not stage_run.is_empty(): return {"ok": false, "reason": "courtyard_only"}
	if not pending_heart_switch.is_empty(): return {"ok": false, "reason": "heart_adjusting"}
	if not _manual_eligible(id) or not "heart" in Content.TECHNIQUES[id].slots:
		return {"ok": false, "reason": "not_attuned_or_learned"}
	if id == equipped_heart: return {"ok": false, "reason": "already_equipped"}
	if equipped_passives.has(id): return {"ok": false, "reason": "already_passive"}
	if not _training_for(id).is_empty(): return {"ok": false, "reason": "training"}
	if _heart_switch_serial >= MAX_RESOURCE: return {"ok": false, "reason": "switch_limit"}
	var first := not heart_equipped_once
	var level := int(technique_levels[id])
	var origin := equipped_heart if not equipped_heart.is_empty() else last_equipped_heart
	var origin_level := int(technique_levels.get(origin, level))
	var target_tier := int(Content.TECHNIQUES[id].get("switch_tier", 1))
	var tier_steps := maxi(0, target_tier - 1)
	var style_gap := 0
	if not first:
		# A used-but-empty legacy heart slot has no reliable origin. Retain the
		# modest style surcharge instead of making removal a cheaper switch.
		style_gap = 1 if origin.is_empty() or String(Content.TECHNIQUES[origin].get("switch_style", "")) != String(Content.TECHNIQUES[id].get("switch_style", "")) else 0
	var rank_gap := 0 if first else absi(level - origin_level)
	var cost := {"qi": 0.0 if first else float(40 + level * 15 + realm * 8 + tier_steps * 12 + style_gap * 10 + rank_gap * 3),
		"herbs": 0 if first else 4 + level * 2 + tier_steps,
		"dew": 0 if first else 1 + int(level / 2.0) + style_gap}
	var duration := 0.0 if first else float(12 + level * 4 + style_gap * 2 + mini(rank_gap, 3))
	var pricing := {"target_tier": target_tier, "tier_steps": tier_steps, "style_gap": style_gap, "rank_gap": rank_gap,
		"origin_id": origin, "origin_level": origin_level, "target_level": level}
	var cost_reason := "首次选定心法，免材料与调息。" if first else "目标阶次%d：加%d灵气/%d草；行气差异%d：加%d灵气/%d露/%d秒；相差%d重：加%d灵气/%d秒。" % [target_tier, tier_steps * 12, tier_steps, style_gap, style_gap * 10, style_gap, style_gap * 2, rank_gap, rank_gap * 3, mini(rank_gap, 3)]
	var from := equipped_heart
	var before := stats()
	equipped_heart = id
	var after := stats()
	equipped_heart = from
	var changes := {}
	for key in ["max_hp", "combat_qi_max", "combat_qi_regen", "poise_bonus"]:
		changes[key] = float(after[key]) - float(before[key])
	_heart_quote_serial += 1
	var token := "%d:%d:%s" % [_heart_switch_serial, _heart_quote_serial, _heart_quote_fingerprint()]
	_heart_quote = {"ok": true, "reason": "quoted", "token": token,
		"fingerprint": _heart_quote_fingerprint(), "from_id": from, "to_id": id,
		"from_name": String(Content.TECHNIQUES[from].name) if Content.TECHNIQUES.has(from) else "未运心法",
		"to_name": String(Content.TECHNIQUES[id].name), "cost": cost, "duration": duration,
		"first_choice": first, "energy_name": "功德" if realm == MAX_REALM else "灵气",
		"pricing": pricing, "cost_reason": cost_reason.replace("灵气", "功德") if realm == MAX_REALM else cost_reason,
		"old_effect": String(technique_descriptor(from).effect) if Content.TECHNIQUES.has(from) else "无",
		"new_effect": String(technique_descriptor(id).effect), "stat_delta": changes}
	return _heart_quote.duplicate(true)


func confirm_heart_switch(value: Variant) -> Dictionary:
	var token: String = String(value.get("token", "")) if value is Dictionary else (value if value is String else "")
	if _heart_quote.is_empty() or token.is_empty() or token != String(_heart_quote.token):
		return {"ok": false, "reason": "stale_quote"}
	if not stage_run.is_empty(): return {"ok": false, "reason": "courtyard_only"}
	if not pending_heart_switch.is_empty(): return {"ok": false, "reason": "heart_adjusting"}
	if String(_heart_quote.fingerprint) != _heart_quote_fingerprint():
		_invalidate_heart_quote()
		return {"ok": false, "reason": "stale_quote"}
	var cost: Dictionary = _heart_quote.cost
	var energy := merit if realm == MAX_REALM else qi
	if energy + EPSILON < float(cost.qi) or herbs < int(cost.herbs) or dew < int(cost.dew):
		return {"ok": false, "reason": "resources"}
	if realm == MAX_REALM: merit = maxf(0.0, merit - float(cost.qi))
	else: qi = maxf(0.0, qi - float(cost.qi))
	herbs -= int(cost.herbs)
	dew -= int(cost.dew)
	_heart_switch_serial += 1
	heart_equipped_once = true
	var from := equipped_heart
	var to := String(_heart_quote.to_id)
	var duration := float(_heart_quote.duration)
	var pricing: Dictionary = _heart_quote.pricing.duplicate(true)
	_invalidate_heart_quote()
	if duration <= 0.0:
		equipped_heart = to
		last_equipped_heart = to
		technique = to
		_record("初定心法 · " + String(Content.TECHNIQUES[to].name))
		return {"ok": true, "reason": "equipped", "pending": {}, "cost": cost.duplicate(true)}
	pending_heart_switch = {"from_id": from, "to_id": to, "duration": duration,
		"remaining": duration, "cost": cost.duplicate(true), "serial": _heart_switch_serial, "pricing": pricing}
	_record("易转心法 · 调息后转入" + String(Content.TECHNIQUES[to].name) + "，旧心法在完成前仍生效。")
	return {"ok": true, "reason": "heart_adjusting", "pending": pending_heart_switch.duplicate(true), "cost": cost.duplicate(true)}


func _advance_heart_switch(delta: float, events: Array[String]) -> void:
	if pending_heart_switch.is_empty(): return
	pending_heart_switch.remaining = maxf(0.0, float(pending_heart_switch.remaining) - delta)
	if float(pending_heart_switch.remaining) > EPSILON: return
	var id := String(pending_heart_switch.to_id)
	# Target was paid for once and held attuned; never re-charge on completion.
	if _manual_eligible(id):
		equipped_heart = id
		last_equipped_heart = id
		technique = id
		var text := "调息完成 · " + String(Content.TECHNIQUES[id].name)
		_record(text)
		events.append(text)
	pending_heart_switch = {}
	_invalidate_heart_quote()


func _restore_heart_switch(value: Variant) -> void:
	if not value is Dictionary or value.is_empty(): return
	if not value.get("from_id") is String or value.from_id != equipped_heart: return
	if not value.get("to_id") is String or not _manual_eligible(value.to_id): return
	var id := String(value.to_id)
	if not "heart" in Content.TECHNIQUES[id].slots or id == equipped_heart or equipped_passives.has(id): return
	if not _valid_integer(value.get("serial"), 1, MAX_RESOURCE): return
	# A paid accepted quote is immutable: preserve its bounded saved duration,
	# including pre-surcharge saves and an origin book trained during adjustment.
	var duration := _finite_bounded(value.get("duration"), 16.0, 41.0, float(12 + int(technique_levels[id]) * 4))
	var remaining := _finite_bounded(value.get("remaining"), 0.0, duration, duration)
	var cost := {"qi": 0.0, "herbs": 0, "dew": 0}
	var raw_cost: Variant = value.get("cost", {})
	if raw_cost is Dictionary:
		cost.qi = _finite_bounded(raw_cost.get("qi"), 0.0, 1000.0, 0.0)
		cost.herbs = _bounded_saved_int(raw_cost.get("herbs"), 0, 100, 0)
		cost.dew = _bounded_saved_int(raw_cost.get("dew"), 0, 100, 0)
	pending_heart_switch = {"from_id": equipped_heart, "to_id": id, "duration": duration,
		"remaining": remaining, "cost": cost, "serial": int(value.serial)}
	heart_equipped_once = true
	_heart_switch_serial = maxi(_heart_switch_serial, int(value.serial))


func battle_cooldown_limits() -> Dictionary:
	var result := {}
	for id in Content.TECHNIQUES:
		var definition: Dictionary = Content.TECHNIQUES[id]
		if float(definition.get("cooldown", 0.0)) > 0.0:
			result[id] = float(definition.cooldown)
	for template in Equipment.TEMPLATES.values():
		var skill: Dictionary = template.get("weapon_skill", {})
		if not skill.is_empty(): result[String(skill.id)] = float(skill.cooldown)
	return result


func _sanitize_battle_resources(value: Variant, fresh: bool = false, previous: Dictionary = {}) -> Dictionary:
	var max_qi := float(stats().combat_qi_max)
	var source: Dictionary = value if value is Dictionary else ({"qi": 0.0, "cooldowns": null} if not fresh else {})
	var limits := battle_cooldown_limits()
	var cooldowns := {}
	var old: Dictionary = previous.get("cooldowns", {})
	var raw: Variant = source.get("cooldowns", {})
	for id in limits:
		var fallback := _finite_bounded(old.get(id, 0.0), 0.0, float(limits[id]), float(limits[id]))
		if source.has("cooldowns") and not raw is Dictionary:
			cooldowns[id] = float(limits[id])
		elif raw is Dictionary and raw.has(id):
			cooldowns[id] = _finite_bounded(raw[id], 0.0, float(limits[id]), float(limits[id]))
		else:
			cooldowns[id] = fallback
	# Legacy short-lived lane schema migrates to the actual old ability once.
	# New per-ID maps are authoritative and never collapse after switching gear.
	if not source.has("cooldowns"):
		var old_technique := String(source.get("technique_id", technique)).trim_prefix("technique_")
		if limits.has(old_technique) and source.has("technique_cd"):
			cooldowns[old_technique] = _finite_bounded(source.technique_cd, 0.0, float(limits[old_technique]), float(limits[old_technique]))
		var old_weapon := String(source.get("weapon_skill_id", gear.equipped_weapon_skill().get("id", "")))
		if old_weapon in ["sword_pierce", "fan_return"]: old_weapon = "weapon_" + old_weapon
		if limits.has(old_weapon) and source.has("weapon_cd"):
			cooldowns[old_weapon] = _finite_bounded(source.weapon_cd, 0.0, float(limits[old_weapon]), float(limits[old_weapon]))
	var default_qi := max_qi if fresh else _finite_bounded(previous.get("qi", 0.0), 0.0, max_qi, 0.0)
	var qi_value := _finite_bounded(source.get("qi", default_qi), 0.0, max_qi, 0.0)
	var weapon_id := String(gear.equipped_weapon_skill().get("id", ""))
	return {"qi": qi_value, "cooldowns": cooldowns,
		"module_revision": 1, "attack_modules": _saved_attack_module_ids(),
		"weapon_art_id": equipped_weapon_art, "spell_id": equipped_spell, "weapon_skill_id": weapon_id,
		"weapon_art_cd": float(cooldowns.get(equipped_weapon_art, 0.0)),
		"spell_cd": float(cooldowns.get(equipped_spell, 0.0)), "weapon_cd": float(cooldowns.get(weapon_id, 0.0))}


func _saved_attack_module_ids() -> Dictionary:
	# Rebind from validated owned equipment/manual IDs after loading. A stale or
	# unknown serialized module can never substitute an unowned attack provider.
	var active := {}
	for skill in active_skill_descriptors():
		active[str(skill.id)] = str(skill.get("attack_module_id", ""))
	var weapon := gear.equipped_weapon_skill()
	if not weapon.is_empty(): active[str(weapon.id)] = str(weapon.get("attack_module_id", ""))
	var result := {"basic": gear.equipped_attack_module_id(), "active": active}
	var form := technique_descriptor(equipped_weapon_art)
	if not form.is_empty(): result.form = str(form.get("attack_module_id", ""))
	return result


func stage_battle_resources() -> Dictionary:
	if stage_run.is_empty(): return {}
	var fresh := not stage_run.has("battle_resources")
	stage_run.battle_resources = _sanitize_battle_resources(stage_run.get("battle_resources", {}), fresh)
	return stage_run.battle_resources.duplicate(true)


func update_stage_battle_resources(run_id: int, resources: Dictionary) -> Dictionary:
	if stage_run.is_empty(): return {"ok": false, "reason": "idle"}
	if run_id != int(stage_run.run_id): return {"ok": false, "reason": "stale_encounter"}
	if not _stage_active: return {"ok": false, "reason": "inactive"}
	# A host can flush the just-observed snapshot while globally paused; it
	# cannot ask this state to advance time. Offline step() never calls this API.
	var previous := stage_battle_resources()
	stage_run.battle_resources = _sanitize_battle_resources(resources, false, previous)
	return {"ok": true, "reason": "updated", "battle_resources": stage_run.battle_resources.duplicate(true)}
