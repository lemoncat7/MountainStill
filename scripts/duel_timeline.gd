extends RefCounted
## Deterministic encounter-only simulation. The host owns rewards and persistence.
## Pass EFFECTIVE attack/defense (already including equipment and meridians).
## Effective speed uses baseline 100; combat_haste is a legacy fallback only.
## Optional meridian stats: recovery_bonus, poise_bonus,
## break_bonus, counter_bonus, dodge_bonus, guard_bonus. No rewards live here.
## Pausing means not calling advance(); cancel() never awards a victory.
const Content = preload("res://scripts/cultivation_content.gd")
const MeleeGeometry = preload("res://scripts/melee_contact_geometry.gd")
const SideRig = preload("res://scripts/character_sidewalk.gd")
const MonsterMoves = preload("res://scripts/monster_move_library.gd")
const Impact = preload("res://scripts/combat_impact.gd")
const ResponseCues = preload("res://scripts/combat_response_cues.gd")
const AttackRegistry = preload("res://scripts/attack_module_registry.gd")
const CombatTiming = preload("res://scripts/combat_timing.gd")
const EPSILON := 0.0000001
const DEFAULT_PROFILES := {
	"mist": {"name": "云岚剑诀", "attack_scale": 1.0, "dodge_chance": 0.05, "guard_chance": 0.12, "guard_multiplier": 0.55, "moves": ["mist_thrust", "mist_lift", "mist_combo"]},
	"petal": {"name": "落英身法", "attack_scale": 0.92, "dodge_chance": 0.46, "guard_chance": 0.05, "guard_multiplier": 0.65, "moves": ["petal_step", "petal_counter"]},
	"ember": {"name": "照炉心法", "attack_scale": 1.13, "dodge_chance": 0.04, "guard_chance": 0.08, "guard_multiplier": 0.65, "moves": ["ember_palm", "ember_pulse"]},
	"stillness": {"name": "止水内功", "attack_scale": 0.98, "dodge_chance": 0.04, "guard_chance": 0.68, "guard_multiplier": 0.42, "moves": ["stillness_palm", "stillness_push"]},
}
# Contact times are authored relative to each independent action lane. Damage occurs only there.
# The gaps between multi-hit contacts are additional strike/contact segments.
const HERO_MOVES := {
	"mist_thrust": {"label": "云起 · 直刺", "windup": 0.48, "strike": 0.22, "hold": 0.13, "recovery": 0.36, "hits": [1.0], "gap": 0.0, "lunge": 19.0},
	"mist_lift": {"label": "岚回 · 挑锋", "windup": 0.57, "strike": 0.25, "hold": 0.14, "recovery": 0.34, "hits": [1.12], "gap": 0.0, "lunge": 14.0},
	"mist_combo": {"label": "云岚 · 三叠", "windup": 0.40, "strike": 0.20, "hold": 0.09, "recovery": 0.29, "hits": [0.43, 0.43, 0.52], "gap": 0.24, "lunge": 22.0},
	"petal_step": {"label": "落英 · 游身", "windup": 0.42, "strike": 0.24, "hold": 0.13, "recovery": 0.34, "hits": [1.0], "gap": 0.0, "lunge": 15.0},
	"petal_counter": {"label": "落英 · 闪身回锋", "windup": 0.32, "strike": 0.22, "hold": 0.15, "recovery": 0.36, "hits": [1.42], "gap": 0.0, "lunge": 27.0},
	"ember_palm": {"label": "照炉 · 吐焰掌", "windup": 0.68, "strike": 0.23, "hold": 0.16, "recovery": 0.40, "hits": [1.03], "gap": 0.0, "lunge": 12.0},
	"ember_pulse": {"label": "照炉 · 双重炎息", "windup": 0.61, "strike": 0.24, "hold": 0.12, "recovery": 0.36, "hits": [0.66, 0.64], "gap": 0.30, "lunge": 16.0},
	"stillness_palm": {"label": "止水 · 沉息掌", "windup": 0.63, "strike": 0.25, "hold": 0.16, "recovery": 0.38, "hits": [1.0], "gap": 0.0, "lunge": 10.0},
	"barrier_guard": {"label": "护元 · 结障", "windup": 0.56, "strike": 0.20, "hold": 0.18, "recovery": 0.34, "hits": [0.0], "gap": 0.0, "lunge": 0.0},
	"mending_bloom": {"label": "回春 · 清息", "windup": 0.66, "strike": 0.22, "hold": 0.19, "recovery": 0.36, "hits": [0.0], "gap": 0.0, "lunge": 0.0},
	"frost_seal": {"label": "凝霜 · 缓行印", "windup": 0.64, "strike": 0.23, "hold": 0.17, "recovery": 0.41, "hits": [1.10], "gap": 0.0, "lunge": 8.0},
	"thunder_strike": {"label": "惊雷 · 破势指", "windup": 0.78, "strike": 0.17, "hold": 0.13, "recovery": 0.44, "hits": [1.48], "gap": 0.0, "lunge": 11.0},
	"stillness_push": {"label": "止水 · 回澜推掌", "windup": 0.71, "strike": 0.25, "hold": 0.16, "recovery": 0.40, "hits": [1.16], "gap": 0.0, "lunge": 13.0},
}

# Ordinary weapon forms stay usable at zero qi. Their timing, reach and contact
# budgets belong to the equipped weapon, not the selected cultivation technique.
const BASIC_MOVES := {
	"basic_sword_cut": {"label": "平斩", "windup": 0.38, "strike": 0.20, "hold": 0.11, "recovery": 0.40, "hits": [0.96], "gap": 0.0, "lunge": 17.0, "basic_range": 62.0, "trail_kind": "sword_cut", "sound_kind": "sword_cut"},
	"basic_sword_thrust": {"label": "直刺", "windup": 0.43, "strike": 0.18, "hold": 0.10, "recovery": 0.38, "hits": [1.0], "gap": 0.0, "lunge": 23.0, "basic_range": 70.0, "trail_kind": "sword_thrust", "sound_kind": "sword_thrust"},
	"basic_sword_lift": {"label": "回腕挑锋", "windup": 0.47, "strike": 0.23, "hold": 0.12, "recovery": 0.35, "hits": [1.04], "gap": 0.0, "lunge": 18.0, "basic_range": 58.0, "trail_kind": "sword_lift", "sound_kind": "sword_lift"},
	"basic_fan_sweep": {"label": "展扇横拂", "windup": 0.43, "strike": 0.27, "hold": 0.13, "recovery": 0.36, "hits": [1.02], "gap": 0.0, "lunge": 12.0, "basic_range": 53.0, "trail_kind": "fan_sweep", "sound_kind": "fan_sweep"},
	"basic_fan_flick": {"label": "收扇点打", "windup": 0.34, "strike": 0.21, "hold": 0.10, "recovery": 0.39, "hits": [0.88], "gap": 0.0, "lunge": 17.0, "basic_range": 48.0, "trail_kind": "fan_flick", "sound_kind": "fan_flick"},
	"basic_fan_return": {"label": "回扇反拂", "windup": 0.46, "strike": 0.25, "hold": 0.12, "recovery": 0.38, "hits": [1.05], "gap": 0.0, "lunge": 11.0, "basic_range": 56.0, "trail_kind": "fan_return_basic", "sound_kind": "fan_return_basic"},
	"basic_unarmed_jab": {"label": "探身冲拳", "windup": 0.30, "strike": 0.16, "hold": 0.09, "recovery": 0.38, "hits": [0.82], "gap": 0.0, "lunge": 25.0, "basic_range": 36.0, "trail_kind": "unarmed_jab", "sound_kind": "unarmed_jab"},
	"basic_unarmed_palm": {"label": "沉肩推掌", "windup": 0.46, "strike": 0.22, "hold": 0.13, "recovery": 0.41, "hits": [1.06], "gap": 0.0, "lunge": 22.0, "basic_range": 39.0, "trail_kind": "unarmed_palm", "sound_kind": "unarmed_palm"},
}
const BASIC_SEQUENCES := {
	"sword": ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift"],
	"fan": ["basic_fan_sweep", "basic_fan_flick", "basic_fan_return"],
	"unarmed": ["basic_unarmed_jab", "basic_unarmed_palm"],
}
const WEAPON_MOVES := {
	"weapon_sword_pierce": {"label": "青锋 · 破风刺", "windup": 0.53, "strike": 0.20, "hold": 0.16, "recovery": 0.46, "hits": [1.58], "gap": 0.0, "lunge": 30.0, "basic_range": 78.0, "trail_kind": "sword_pierce", "sound_kind": "sword_pierce", "armor_factor": 0.55},
	"weapon_fan_return": {"label": "流云 · 回风扇", "windup": 0.48, "strike": 0.27, "hold": 0.13, "recovery": 0.43, "hits": [0.74, 0.86], "gap": 0.38, "lunge": 18.0, "basic_range": 64.0, "trail_kind": "fan_return", "sound_kind": "fan_return"},
}
const TECHNIQUE_RESOURCES := {
	"mist": {"qi_cost": 12.0, "cooldown": 6.0}, "petal": {"qi_cost": 14.0, "cooldown": 8.0},
	"ember": {"qi_cost": 18.0, "cooldown": 7.0}, "stillness": {"qi_cost": 16.0, "cooldown": 9.0},
	"frost": {"qi_cost": 16.0, "cooldown": 10.0}, "thunder": {"qi_cost": 20.0, "cooldown": 12.0},
	"barrier": {"qi_cost": 16.0, "cooldown": 12.0}, "mending": {"qi_cost": 18.0, "cooldown": 14.0},
}

const SPECIES_BY_ROUTE := {
	"bamboo_pass": "moss_beast", "creek_bridge": "river_stone", "cloud_slope": "cloud_crane",
	"ember_ruins": "ember_guardian", "moon_marsh": "moon_wisp", "summit_gate": "summit_keeper",
}
const SPECIES_EFFECTS := {"moss_beast": "moss_stomp", "river_stone": "river_tide", "cloud_crane": "crane_feathers", "ember_guardian": "ember_heat", "moon_wisp": "moon_veil", "summit_keeper": "summit_seal"}

const MIST_GRIP_LABELS := {
	"unarmed": {"mist_thrust": "云起 · 点指", "mist_lift": "岚回 · 挑掌", "mist_combo": "云岚 · 三叠指"},
	"fan": {"mist_thrust": "云起 · 直刺", "mist_lift": "岚回 · 挑扇", "mist_combo": "云岚 · 三叠扇"},
}

# There is no global turn clock: each combatant owns an action, recovery and
# ready time. Only exact event boundaries mutate combat. pose() is a pure sample.
const ACTORS := ["hero", "enemy"]
const DEFENSE_LEAD := 0.16
var hero_hp: int = 100
var hero_max_hp: int = 100
var enemy_hp: int = 0
var enemy_max_hp: int = 0
var finished: bool = false
var victory: bool = false
var cancelled: bool = false
var technique: String = "mist"
var weapon_style: String = "unarmed"
var turn_index: int = 0
var elapsed: float = 0.0
var _hero: Dictionary = {}
var _enemy: Dictionary = {}
var _profile: Dictionary = {}
var _rng := RandomNumberGenerator.new()
var _enemy_rng := RandomNumberGenerator.new()
var _enemy_history: Array[String] = []
var _enemy_stamina_base: float = 100.0
var _enemy_stamina_anchor: float = 0.0
var _lanes: Dictionary = {}
var _pending: Array[Dictionary] = []
var _hero_turns: int = 0
var _enemy_turns: int = 0
var _counter_ready: bool = false
var _counter_kind: String = ""
var _counter_source: String = ""
var _counter_earned_at: float = -1.0
var _last_contact: Dictionary = {}
var _reactions: Dictionary = {}
var _defense_releases: Dictionary = {}
var _pressure: Dictionary = {}
var _pressure_time: Dictionary = {}
var _break_immunity: Dictionary = {}
var _chase: Dictionary = {}
var _finish_at: float = -1.0
var _finish_started: float = -1.0
var _finish_approach: Dictionary = {}
var _hero_stance: float = 0.0
var _started: bool = false
# Resource state is anchored at commits, so small and large delta partitions
# integrate exactly the same continuous regeneration and cooldown deadlines.
var _qi_max: float = 40.0
var _qi_regen: float = 2.0
var _qi_base: float = 40.0
var _qi_anchor: float = 0.0
var _skill_lanes: Array[String] = []
const ABILITY_IDS := ["mist", "petal", "ember", "frost", "thunder", "barrier", "mending", "weapon_sword_pierce", "weapon_fan_return"]
var _skills: Dictionary = {}
var _cooldowns: Dictionary = {}
var _heart: Dictionary = {}
var _weapon_art_form: Dictionary = {}
var _passive_methods: Array = []
var _skill_uses: Dictionary = {}
var _enemy_slow_until: float = 0.0
var _hero_slow_until: float = 0.0
var _slow_fractions: Dictionary = {"hero": 0.22, "enemy": 0.22}
var _shield: int = 0
var _shield_until: float = 0.0
var _cost_reduction: float = 0.0
var _cooldown_reduction: float = 0.0
var _basic_turns: int = 0
var _technique_uses: int = 0
var _must_basic: bool = true
var _next_skill_index: int = 0
# Resolve trusted module factories once per encounter/loadout. Runtime dispatch
# uses these direct providers; saved resources contain only stable module IDs.
var module_registry: RefCounted
var _base_module: RefCounted
var _form_module: RefCounted
var _enemy_module: RefCounted
var _enemy_module_definition: Dictionary = {}
var _skill_modules: Dictionary = {}
var _module_definitions: Dictionary = {}
var _module_ids: Dictionary = {}
var _hero_join: Dictionary = {}
var _action_timing: Dictionary = {}



func start(hero_stats: Dictionary, enemy_definition: Dictionary, selected_technique: String = "mist", weapon: String = "unarmed", run_seed: int = 1) -> void:
	if module_registry == null: module_registry = AttackRegistry.default_registry()
	module_registry.bootstrap()
	_module_definitions.clear()
	_hero = hero_stats.duplicate(true)
	_enemy = enemy_definition.duplicate(true)
	# Freeze effective loadout timing for this encounter. Sampling and later
	# mutations of input dictionaries cannot retime an already committed action.
	_action_timing = {"hero": CombatTiming.from_stats(_hero), "enemy": CombatTiming.from_stats(_enemy)}
	technique = selected_technique if selected_technique in ["mist", "petal", "ember", "stillness", "breath", "frost", "thunder", "barrier", "mending"] else "mist"
	_profile = DEFAULT_PROFILES.get(technique, DEFAULT_PROFILES.mist).duplicate(true)
	_profile.merge(Content.COMBAT_PROFILES.get(technique, {}), true)
	weapon_style = _weapon_style(weapon)
	hero_max_hp = clampi(int(_hero.get("max_hp", 100)), 1, 100000)
	hero_hp = clampi(int(_hero.get("hp", _hero.get("vitality", hero_max_hp))), 0, hero_max_hp)
	enemy_max_hp = clampi(int(_enemy.get("max_hp", _enemy.get("hp", 24))), 1, 100000)
	enemy_hp = clampi(int(_enemy.get("hp", enemy_max_hp)), 0, enemy_max_hp)
	_rng.seed = run_seed
	_enemy_rng.seed = run_seed ^ 0x6D6F7373
	_enemy_history.clear()
	_enemy_stamina_base = 100.0
	_enemy_stamina_anchor = 0.0
	finished = false
	victory = false
	cancelled = false
	turn_index = 0
	elapsed = 0.0
	_hero_turns = 0
	_enemy_turns = 0
	_counter_ready = false
	_counter_kind = ""
	_counter_source = ""
	_counter_earned_at = -1.0
	_last_contact = {}
	_reactions = {}
	_defense_releases = {}
	_pressure = {"hero": 0.0, "enemy": 0.0}
	_pressure_time = {"hero": 0.0, "enemy": 0.0}
	_break_immunity = {"hero": -1.0, "enemy": -1.0}
	_chase = {"hero": false, "enemy": false}
	# The opening AI wait is not an authored attack interval.
	_lanes = {"hero": {"action": {}, "ready_at": 0.0}, "enemy": {"action": {}, "ready_at": float(CombatTiming.POLICY.enemy_opening_delay)}}
	_finish_at = -1.0
	_finish_started = -1.0
	_finish_approach = {}
	_hero_stance = 0.0
	MeleeGeometry.prewarm(_enemy)
	_pending.clear()
	_reset_battle_resources()
	_bind_attack_modules()
	_hero_join.clear()
	_started = true
	if hero_hp <= 0 or enemy_hp <= 0:
		finished = true
		_pending.append({"type": "finished", "victory": false, "reason": "invalid_start", "hero_hp": hero_hp, "enemy_hp": enemy_hp, "time": 0.0})
		return
	_begin_action("hero")


func cancel() -> void:
	if not _started or finished:
		return
	cancelled = true
	finished = true
	victory = false
	_pending.clear()
	_pending.append({"type": "cancelled", "victory": false, "hero_hp": hero_hp, "enemy_hp": enemy_hp, "time": _event_time(elapsed)})


func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _started:
		return events
	events.assign(_pending)
	_pending.clear()
	if finished or not is_finite(delta) or delta <= 0.0:
		return events
	var destination := elapsed + delta
	while not finished:
		if _finish_at >= 0.0:
			if _finish_at > destination + EPSILON:
				elapsed = destination
				break
			elapsed = _finish_at
			finished = true
			victory = enemy_hp <= 0 and hero_hp > 0
			events.append({"type": "finished", "victory": victory, "reason": "defeated", "hero_hp": hero_hp, "enemy_hp": enemy_hp, "time": _event_time(elapsed)})
			break
		var actor := "hero"
		var next_time := _next_boundary("hero")
		var enemy_time := _next_boundary("enemy")
		if enemy_time < next_time - EPSILON:
			actor = "enemy"
			next_time = enemy_time
		if next_time > destination + EPSILON:
			elapsed = destination
			break
		elapsed = next_time
		_process_boundary(actor, events)
		events.append_array(_pending)
		_pending.clear()
	return events


func _next_boundary(actor: String) -> float:
	var lane: Dictionary = _lanes[actor]
	var action: Dictionary = lane.action
	if action.is_empty():
		return float(lane.ready_at)
	if bool(action.get("interrupted", false)):
		return float(action.end)
	var cursor := int(action.cursor)
	if cursor < action.contacts.size():
		var contact: Dictionary = action.contacts[cursor]
		return float(action.start) + float(contact.time) - (0.0 if bool(contact.prepared) else _contact_defense_lead(action, cursor))
	return float(action.end)


func _contact_defense_lead(action: Dictionary, index: int) -> float:
	# A fast combo may have less than the normal defensive lead between hits.
	# Preparation must never take the event clock behind the preceding contact.
	var previous := 0.0 if index == 0 else float(action.contacts[index - 1].time)
	return minf(DEFENSE_LEAD, maxf(0.0, float(action.contacts[index].time) - previous))


func _process_boundary(actor: String, events: Array[Dictionary]) -> void:
	var lane: Dictionary = _lanes[actor]
	var action: Dictionary = lane.action
	if action.is_empty():
		_begin_action(actor)
		return
	var cursor := int(action.cursor)
	if not bool(action.get("interrupted", false)) and cursor < action.contacts.size():
		var contact: Dictionary = action.contacts[cursor]
		if not bool(contact.prepared):
			contact.resolution = "support" if str(action.get("action_kind", "")) in ["defense", "utility"] else _roll_resolution(actor, contact)
			contact.prepared = true
			return
		var event := _resolve_contact(actor, action, contact)
		events.append(event)
		action.cursor = cursor + 1
		if hero_hp <= 0 or enemy_hp <= 0:
			_finalize_contact(event)
			# Both lanes stop issuing contacts immediately; a short true finishing
			# follow-through remains visible before the host may grant the reward.
			_finish_approach = SideRig.approach_footwork(_approach_motion(_lanes.hero.action))
			_finish_started = elapsed
			_finish_at = elapsed + float(action.hold) + minf(0.40, float(action.recovery))
			action.carry_exit = 0.0
			action.contacts.resize(cursor + 1)
			action.end = _finish_at
			var receiver: Dictionary = _lanes[_other(actor)].action
			if not receiver.is_empty():
				_freeze_action(_other(actor), 0.40, true)
			return
		if str(event.get("action_kind", "")) not in ["defense", "utility"]:
			_apply_pressure(actor, event)
		_finalize_contact(event)
		return
	# Keep the established close stance between contiguous actions. Only the
	# next reach correction steps again; recovery is not a repeated retreat.
	if actor == "hero":
		_hero_stance = float(SideRig.approach_footwork(_approach_motion(action)).root)
		_hero_join = SideRig._combat(_hero_motion_at())
	# Only this combatant's recovery ended. The opponent keeps its own clock.
	lane.action = {}
	lane.ready_at = elapsed + CombatTiming.ready_interval(actor, _action_timing[actor], actor == "hero" and _counter_ready)


func _begin_action(actor: String) -> void:
	turn_index += 1
	var action: Dictionary = _hero_action() if actor == "hero" else _enemy_action(true)
	if actor == "hero":
		_hero_turns += 1
		_commit_hero_resources(action)
	else:
		_enemy_turns += 1
	_prepare_action_timing(actor, action, elapsed)
	_chase[actor] = false
	action.merge({"actor": actor, "id": turn_index, "start": elapsed, "cursor": 0, "interrupted": false, "contacts": []}, true)
	for index in range(action.hits.size()):
		action.contacts.append({"index": index, "time": float(action.windup) + float(action.strike) + float(action.gap) * index,
			"coefficient": float(action.hits[index]), "prepared": false, "resolution": "hit"})
	action.duration = float(action.contacts[-1].time) + float(action.hold) + float(action.recovery)
	action.end = elapsed + float(action.duration)
	_lanes[actor].action = action
	if actor == "hero":
		action.entry_pose = _hero_join.duplicate(true)
		action.carry_exit = 0.18 if MeleeGeometry.is_melee(action) else 0.0
		action.approach_origin = _hero_stance
		action.approach_target = _hero_stance
	if actor=="hero" and MeleeGeometry.is_melee(action):
		_plan_melee_approach(action)
	_pending.append({"type": "turn_started", "actor": actor, "turn_index": turn_index, "action_id": turn_index,
		"move": action.move, "telegraph": action.label, "duration": action.duration, "windup": action.windup,
		"speed": action.speed, "action_rate": action.action_rate,
		"contacts": action.hits.size(), "counter": bool(action.get("counter", false)), "counter_kind": str(action.get("counter_kind", "")), "counter_source": str(action.get("counter_source","")), "counter_earned_at": float(action.get("counter_earned_at",-1.0)),
		"chase": bool(action.get("chase", false)), "slowed": bool(action.get("slowed", false)), "boss": bool(_enemy.get("boss", false)),
		"mechanic": _mechanic(), "enemy_phase": "awakened" if _awakened() else "calm", "time": _event_time(elapsed)})
	_pending[-1].merge(_action_resource_fields(action), true)


func _prepare_action_timing(actor: String, action: Dictionary, at: float) -> void:
	# Author-time modifiers are applied before the one speed conversion. Both
	# committed actions and predicted monster motion use this exact path.
	if at < (_hero_slow_until if actor == "hero" else _enemy_slow_until):
		var slow_scale := 1.0 / (1.0 - float(_slow_fractions[actor]))
		action.windup *= slow_scale
		action.recovery *= slow_scale
		action.slowed = true
		if actor == "enemy": action.label = "霜滞 · " + str(action.label)
	if actor == "enemy" and bool(_chase.enemy):
		action.windup = maxf(0.34, float(action.windup) - 0.12)
		action.label = "追身 · " + str(action.label)
		action.chase = true
	CombatTiming.apply(action, _action_timing[actor])


func _bind_attack_modules() -> void:
	if module_registry == null:
		module_registry = AttackRegistry.default_registry()
	var base_id := str(_hero.get("attack_module_id", "weapon." + weapon_style))
	var heart_override := str(_heart.get("basic_attack_module_id",""))
	if not heart_override.is_empty() and bool(_heart.get("active",true)) and _compatible(_heart):
		base_id = heart_override
	_base_module = module_registry.bind(base_id, {"style": weapon_style})
	_module_definitions = {"basic": _base_module.definition()}
	_module_ids = {"basic": str(_module_definitions.basic.id), "active": {}}
	_form_module = null
	if _form_available():
		_form_module = module_registry.bind(str(_weapon_art_form.get("attack_module_id", "technique." + str(_weapon_art_form.id))), _weapon_art_form)
		_module_ids.form = str(_form_module.definition().id)
	_skill_modules.clear()
	for lane in _skill_lanes:
		var skill: Dictionary = _skills[lane]
		if skill.is_empty(): continue
		var default_id := "weapon." + weapon_style if lane == "weapon" else "technique." + str(skill.id)
		var provider: RefCounted = module_registry.bind(str(skill.get("attack_module_id", default_id)), skill)
		_skill_modules[lane] = provider
		_module_definitions[lane] = provider.definition()
		_module_ids.active[str(skill.id)] = str(_module_definitions[lane].id)
		# Category/resource defaults belong to the bound module, not a growing
		# switch statement in the attack scheduler.
		skill.action_kind = str(skill.get("action_kind", _module_definitions[lane].get("action_kind", _action_kind(skill))))
	_enemy_module = module_registry.bind(str(_enemy.get("attack_module_id", "enemy." + _species())), {"enemy": _enemy})
	_enemy_module_definition = _enemy_module.definition()
	if str(_enemy_module_definition.get("kind",""))!="enemy":
		# A malformed save/config cannot place a weapon fallback in an enemy
		# slot. Resolve the validated route species before any enemy callback.
		_enemy_module = module_registry.bind("enemy."+_species(),{"enemy":_enemy})
		_enemy_module_definition = _enemy_module.definition()
	_module_ids.enemy = str(_enemy_module_definition.id)


func _hero_action() -> Dictionary:
	var kind := "basic"
	if not _must_basic:
		for offset in range(_skill_lanes.size()):
			var candidate := str(_skill_lanes[(_next_skill_index + offset) % _skill_lanes.size()])
			if _skill_eligible(candidate):
				if _current_qi() + EPSILON >= _skill_cost(candidate): kind = candidate
				break
	var skill: Dictionary = _skills.get(kind, {})
	var skill_id := str(skill.get("id", ""))
	var counter := _counter_ready and str(skill.get("action_kind", "")) not in ["defense", "utility"]
	var provider: RefCounted = _base_module if kind == "basic" else _skill_modules.get(kind, _base_module)
	var selection := {"use_count": _basic_turns if kind == "basic" else int(_skill_uses.get(skill_id, 0)), "counter": counter, "kind": "weapon" if kind == "weapon" else "basic"}
	if kind != "basic" and skill.has("move") and not str(skill.move).is_empty(): selection.move = str(skill.move)
	var action: Dictionary = provider.select_action(selection)
	if kind == "basic":
		_basic_turns += 1
		if _form_module != null: action = _form_module.modify_basic(action, _weapon_art_form)
	else:
		_skill_uses[skill_id] = int(_skill_uses.get(skill_id, 0)) + 1
		if skill.has("name") and kind == "weapon": action.label = str(skill.name)
		action.power_scale = clampf(_finite_number(skill.get("power_scale", 1.0), 1.0), 1.0, 1.20)
		action.attack_scale = float(action.get("attack_scale", 1.0)) * float(action.power_scale)
		action.skill_definition = skill.duplicate(true)
	action.skill_id = skill_id
	action.kind = kind
	action.skill_lane = kind
	action.action_kind = str(skill.get("action_kind", "spell")) if kind != "basic" else "basic"
	action.basic_style = weapon_style
	action.qi_cost = 0.0 if kind == "basic" else _skill_cost(kind)
	action.cooldown = 0.0 if kind == "basic" else _skill_cooldown(kind)
	action.counter = counter
	action.counter_kind = _counter_kind if counter else ""
	action.counter_source = _counter_source if counter else ""
	action.counter_earned_at = _counter_earned_at if counter else -1.0
	action.pose_provider = provider
	action.strike_provider = _base_module
	if counter:
		action.windup *= 0.68
		action.recovery *= 0.84
		if kind == "basic": action.label = "借隙 · " + str(action.label)
		_counter_ready = false
		_counter_kind = ""
	return action


func _reset_battle_resources() -> void:
	_qi_max = clampf(_finite_number(_hero.get("combat_qi_max", 40.0 + clampi(int(_hero.get("realm", 0)), 0, 15) * 2.0), 40.0), 1.0, Content.COMBAT_QI_LIMIT)
	_qi_regen = clampf(_finite_number(_hero.get("combat_qi_regen", 2.0), 2.0), 0.0, Content.COMBAT_QI_REGEN_LIMIT)
	_cost_reduction = clampf(_finite_number(_hero.get("skill_cost_reduction", 0.0), 0.0), 0.0, 0.35)
	_cooldown_reduction = clampf(_finite_number(_hero.get("skill_cooldown_reduction", 0.0), 0.0), 0.0, 0.30)
	_skills = {"weapon_art": {}, "spell": {}, "weapon": {}}
	_heart = {}
	var modern := _hero.has("active_skills") or _hero.has("heart_method") or _hero.has("weapon_art") or _hero.has("spell")
	if modern:
		for lane in ["weapon_art", "spell"]:
			var supplied: Variant = _hero.get(lane, {})
			if supplied is Dictionary:
				_skills[lane] = supplied.duplicate(true)
		var supplied_heart: Variant = _hero.get("heart_method", {})
		if supplied_heart is Dictionary:
			_heart = supplied_heart.duplicate(true)
	else:
		# Old callers retain their selected manual, but category/compatibility
		# are still enforced. A heart method never becomes a queued spell.
		var manual: Dictionary = Content.TECHNIQUES.get(technique, {}).duplicate(true)
		manual.id = technique
		manual.active = true
		if technique in ["mist", "petal"]:
			manual.required_weapon = "sword" if technique == "mist" else "fan"
			_skills.weapon_art = manual
		elif technique in ["ember", "frost", "thunder", "barrier", "mending"]:
			_skills.spell = manual
		elif technique in ["stillness", "breath"]:
			_heart = manual
	var supplied_weapon: Variant = _hero.get("weapon_skill", {})
	if supplied_weapon is Dictionary and not supplied_weapon.is_empty() and weapon_style in ["sword", "fan"]:
		var expected := "weapon_sword_pierce" if weapon_style == "sword" else "weapon_fan_return"
		if str(supplied_weapon.get("move", expected)) == expected:
			_skills.weapon = supplied_weapon.duplicate(true)
			_skills.weapon.move = expected
			_skills.weapon.id = expected
			_skills.weapon.required_weapon = weapon_style
	_weapon_art_form = _skills.weapon_art.duplicate(true)
	var active: Array = []
	if _hero.get("active_skills", null) is Array:
		active = _hero.active_skills
	else:
		for legacy_lane in ["weapon_art", "spell"]:
			if not _skills[legacy_lane].is_empty():
				active.append(_skills[legacy_lane])
	var innate: Dictionary = _skills.weapon
	_skills = {}
	_skill_lanes = []
	var seen := {}
	for index in range(mini(2, active.size())):
		if not active[index] is Dictionary:
			continue
		var skill: Dictionary = active[index].duplicate(true)
		var id := str(skill.get("id", ""))
		if (id not in ABILITY_IDS and not module_registry.has_module(str(skill.get("attack_module_id", "")))) or seen.has(id):
			continue
		var lane := "active_%d" % index
		_skills[lane] = skill
		_skill_lanes.append(lane)
		seen[id] = true
	_skills.weapon = innate
	_skill_lanes.append("weapon")
	_passive_methods = _hero.get("passive_methods", []) if _hero.get("passive_methods", []) is Array else []
	# Effective stats already include passive qi/health/poise bonuses. Defense
	# profiles still belong here, including a secondary equipped stillness.
	_profile = {"name": str(_heart.get("name", "平心守势")), "attack_scale": 1.0, "dodge_chance": 0.05, "guard_chance": 0.12, "guard_multiplier": 0.55}
	if _stillness_equipped():
		_profile.merge({"dodge_chance": 0.04, "guard_chance": 0.68, "guard_multiplier": 0.42}, true)
	elif bool(_heart.get("active", true)):
		for field in ["dodge_chance", "guard_chance", "guard_multiplier"]:
			if _heart.has(field):
				_profile[field] = _heart[field]
	if _petal_equipped():
		_profile.dodge_chance = float(_weapon_art_form.get("dodge_chance", 0.40))
	var saved: Variant = _hero.get("battle_resources", {})
	if not saved is Dictionary:
		saved = {}
	_qi_base = clampf(_finite_number(saved.get("qi", _qi_max), _qi_max), 0.0, _qi_max)
	_qi_anchor = elapsed
	_cooldowns = {}
	var saved_cooldowns: Variant = saved.get("cooldowns", {})
	if not saved_cooldowns is Dictionary:
		saved_cooldowns = {}
	var ability_ids: Array = ABILITY_IDS.duplicate()
	for lane in _skill_lanes:
		if not _skill_id(lane).is_empty() and not ability_ids.has(_skill_id(lane)): ability_ids.append(_skill_id(lane))
	for ability_id in ability_ids:
		_cooldowns[ability_id] = elapsed + clampf(_finite_number(saved_cooldowns.get(ability_id, 0.0), 0.0), 0.0, 600.0)
	# Legacy lane saves migrate only when the keyed map is absent.
	if saved_cooldowns.is_empty():
		for lane in _skill_lanes:
			var skill_id := _skill_id(lane)
			if skill_id.is_empty():
				continue
			var legacy: Variant = saved.get(str(lane) + "_cd", saved.get("technique_cd", 0.0) if lane != "weapon" else saved.get("weapon_cd", 0.0))
			_cooldowns[skill_id] = elapsed + clampf(_finite_number(legacy, 0.0), 0.0, 600.0)
	_basic_turns = 0
	_technique_uses = 0
	_skill_uses = {}
	_must_basic = true
	_next_skill_index = 0
	_enemy_slow_until = 0.0
	_hero_slow_until = 0.0
	_shield = 0
	_shield_until = 0.0


func _current_qi() -> float:
	return clampf(_qi_base + maxf(0.0, elapsed - _qi_anchor) * _qi_regen, 0.0, _qi_max)


func _skill_id(kind: String) -> String:
	return str(_skills.get(kind, {}).get("id", ""))


func _skill_available(kind: String) -> bool:
	var skill: Dictionary = _skills.get(kind, {})
	if skill.is_empty() or not bool(skill.get("active", true)) or (_skill_id(kind) not in ABILITY_IDS and not _skill_modules.has(kind)):
		return false
	return _compatible(skill)


func _skill_cost(kind: String) -> float:
	var skill: Dictionary = _skills.get(kind, {})
	var id := _skill_id(kind)
	var fallback := float(_module_definitions.get(kind,{}).get("resources",{}).get("qi_cost",TECHNIQUE_RESOURCES.get(id, {}).get("qi_cost", 10.0 if id == "weapon_sword_pierce" else 12.0)))
	return 0.0 if skill.is_empty() else maxf(0.1, _finite_number(skill.get("qi_cost", fallback), fallback)) * (1.0 - _cost_reduction)


func _skill_cooldown(kind: String) -> float:
	var skill: Dictionary = _skills.get(kind, {})
	var id := _skill_id(kind)
	var fallback := float(_module_definitions.get(kind,{}).get("resources",{}).get("cooldown",TECHNIQUE_RESOURCES.get(id, {}).get("cooldown", 9.0 if id == "weapon_sword_pierce" else 10.0)))
	return 0.0 if skill.is_empty() else maxf(0.1, _finite_number(skill.get("cooldown", fallback), fallback)) * (1.0 - _cooldown_reduction)


func _skill_ready(kind: String) -> bool:
	return _skill_eligible(kind) and _current_qi() + EPSILON >= _skill_cost(kind)


func _skill_eligible(kind: String) -> bool:
	if not _skill_available(kind) or _skill_cost(kind) > _qi_max + EPSILON or elapsed + EPSILON < float(_cooldowns.get(_skill_id(kind), 0.0)):
		return false
	if _skill_id(kind) == "mending":
		return float(hero_max_hp - hero_hp) >= float(hero_max_hp) * 0.12 or elapsed < _hero_slow_until
	if _skill_id(kind) == "barrier":
		return _current_shield() <= 0
	return true


func _commit_hero_resources(action: Dictionary) -> void:
	var kind := str(action.skill_lane)
	_must_basic = kind != "basic"
	if kind == "basic":
		return
	# Commit once at anticipation start. Interrupts, misses and cancelled later
	# contacts do not refund this already spent qi or shorten its cooldown.
	_qi_base = maxf(0.0, _current_qi() - float(action.qi_cost))
	_qi_anchor = elapsed
	_cooldowns[str(action.skill_id)] = elapsed + float(action.cooldown)
	_next_skill_index = (_skill_lanes.find(kind) + 1) % _skill_lanes.size()


func battle_resource_snapshot() -> Dictionary:
	var cooldowns := {}
	for id in _cooldowns:
		cooldowns[id] = _event_time(maxf(0.0, float(_cooldowns[id]) - elapsed))
	var result := {"qi": _event_time(_current_qi()), "max_qi": _qi_max, "qi_regen": _qi_regen, "cooldowns": cooldowns,
		"heart_method_id": str(_heart.get("id", "")), "technique_id": technique, "active_skills": [], "attack_modules": _module_ids.duplicate(true), "module_revision": 1,
		"weapon_art_id": "", "weapon_art_cd": 0.0, "weapon_art_cost": 0.0, "weapon_art_ready": false, "weapon_art_available": false,
		"spell_id": "", "spell_cd": 0.0, "spell_cost": 0.0, "spell_ready": false, "spell_available": false,
		"weapon_id": "", "weapon_cd": 0.0, "weapon_cost": 0.0, "weapon_ready": false, "weapon_available": false}
	for lane in _skill_lanes:
		var skill: Dictionary = _skills.get(lane, {})
		var descriptor := {"id": _skill_id(lane), "name": str(skill.get("name", "")), "category": str(skill.get("category", "weapon" if lane == "weapon" else "spell")),
			"action_kind": _action_kind(skill), "qi_cost": _skill_cost(lane), "cooldown": _skill_cooldown(lane),
			"remaining": float(cooldowns.get(_skill_id(lane), 0.0)), "ready": _skill_ready(lane), "available": _skill_available(lane)}
		var alias := "weapon" if lane == "weapon" else str(descriptor.action_kind)
		if alias in ["weapon", "weapon_art", "spell"]:
			for field in ["id", "ready", "available"]:
				result[alias + "_" + field] = descriptor[field]
			result[alias + "_cd"] = descriptor.remaining
			result[alias + "_cost"] = descriptor.qi_cost
		if lane == "weapon":
			result.weapon_skill = descriptor
			result.weapon_name = descriptor.name
		else:
			result.active_skills.append(descriptor)
	# Compatibility aliases are not used for scheduling or keyed persistence.
	var selected_lane := "spell" if technique in ["ember", "frost", "thunder", "barrier", "mending"] else "weapon_art"
	for suffix in ["cd", "cost", "ready", "available"]:
		result["technique_" + suffix] = result[selected_lane + "_" + suffix]
	result.weapon_skill_id = result.get("weapon_id", "")
	result.shield = _current_shield()
	result.shield_remaining = _event_time(maxf(0.0, _shield_until - elapsed)) if _current_shield() > 0 else 0.0
	return result


static func rest_resource_snapshot(resources: Dictionary, delta: float, max_qi: float, regen: float) -> Dictionary:
	# Call only for real, unpaused travel/rest time, never offline wall time.
	var result := resources.duplicate(true)
	if not is_finite(delta) or delta <= 0.0:
		return result
	var ceiling := clampf(_finite_number(max_qi, 40.0), 1.0, Content.COMBAT_QI_LIMIT)
	var rate := clampf(_finite_number(regen, 2.0), 0.0, Content.COMBAT_QI_REGEN_LIMIT)
	result.qi = clampf(_finite_number(result.get("qi", ceiling), ceiling) + delta * rate, 0.0, ceiling)
	var cooldowns: Variant = result.get("cooldowns", {})
	if not cooldowns is Dictionary:
		cooldowns = {}
	for id in cooldowns:
		cooldowns[id] = maxf(0.0, _finite_number(cooldowns[id], 0.0) - delta)
	result.cooldowns = cooldowns
	for lane in ["technique", "weapon_art", "spell", "weapon"]:
		var key := str(lane) + "_cd"
		if result.has(key):
			result[key] = maxf(0.0, _finite_number(result[key], 0.0) - delta)
	return result


func _action_resource_fields(action: Dictionary, include_resources: bool = true) -> Dictionary:
	var fields := {"action_kind": str(action.get("action_kind", "enemy")), "qi_cost": float(action.get("qi_cost", 0.0)),
		"module_id": str(action.get("module_id", "")), "strike_geometry": action.get("strike_geometry", {}),
		"skill_id": str(action.get("skill_id", "")), "basic_style": str(action.get("basic_style", "")), "basic_form": str(action.get("basic_form", "")),
		"strike_aim":float(action.get("strike_aim",0.0)),"aim_crouch":float(action.get("aim_crouch",0.0)), "basic_range": float(action.get("basic_range", 0.0)), "trail_kind": str(action.get("trail_kind", "")),
		"sound_kind": str(action.get("sound_kind", "")),
		"move_family":str(action.get("move_family","")), "monster_range":float(action.get("monster_range",0.0)),
		"impact_weight":float(action.get("impact_weight",Impact._authored_weight(str(action.get("move_family","")),str(action.get("move","")),str(action.get("skill_id","")),str(action.get("action_kind",""))))), "impact_direction":action.get("impact_direction",Vector2.ZERO),
		"enemy_stamina":_event_time(_enemy_stamina()), "stamina_cost":float(action.get("stamina_cost",0.0))}
	if include_resources:
		var resources := battle_resource_snapshot()
		fields.merge({"qi":resources.qi,"technique_cd":resources.technique_cd,"weapon_art_cd":resources.weapon_art_cd,"spell_cd":resources.spell_cd,"weapon_cd":resources.weapon_cd},true)
	return fields


static func _finite_number(value: Variant, fallback: float) -> float:
	if not value is int and not value is float:
		return fallback
	var number := float(value)
	return number if is_finite(number) else fallback


func _compatible(definition: Dictionary) -> bool:
	var required := str(definition.get("required_weapon", ""))
	return required in ["", "any", "none"] or _weapon_style(required) == weapon_style


func _form_available() -> bool:
	return not _weapon_art_form.is_empty() and bool(_weapon_art_form.get("active", true)) and _compatible(_weapon_art_form)


func _petal_equipped() -> bool:
	return _form_available() and str(_weapon_art_form.get("id", "")) == "petal"


func _stillness_equipped() -> bool:
	if str(_heart.get("id", "")) == "stillness" and bool(_heart.get("active", true)):
		return true
	for method in _passive_methods:
		if method is Dictionary and str(method.get("id", "")) == "stillness" and bool(method.get("active", true)):
			return true
	return false


func _offensive_followups_enabled() -> bool:
	if _form_available() and str(_weapon_art_form.get("id", "")) == "mist":
		return true
	for lane in _skill_lanes:
		if _skill_available(lane) and _skill_id(lane) in ["mist", "ember", "thunder"]:
			return true
	return false


static func _action_kind(skill: Dictionary) -> String:
	var id := str(skill.get("id", ""))
	if id in ["weapon_sword_pierce", "weapon_fan_return"]:
		return "weapon"
	if id in ["mist", "petal"]:
		return "weapon_art"
	if id == "barrier":
		return "defense"
	if id == "mending":
		return "utility"
	return "spell"


func _current_shield() -> int:
	return _shield if elapsed + EPSILON < _shield_until else 0


func apply_slow(actor: String, seconds: float, fraction: float = 0.22) -> void:
	if actor not in ACTORS or not is_finite(seconds) or seconds <= 0.0:
		return
	_slow_fractions[actor] = clampf(_finite_number(fraction, 0.22), 0.0, 0.50)
	if actor == "hero":
		_hero_slow_until = maxf(_hero_slow_until, elapsed + minf(seconds, 10.0))
	else:
		_enemy_slow_until = maxf(_enemy_slow_until, elapsed + minf(seconds, 10.0))


func combat_profile() -> Dictionary:
	return _profile.duplicate(true)


func defense_chances(actor: String) -> Dictionary:
	# actor is the attacker. A sheet-provided chance is already the full total;
	# never add the old dodge_bonus again or roll a second defensive check.
	var dodge: float
	var guard: float
	var receiver := _other(actor)
	if actor == "enemy":
		if _hero.has("evasion_chance"):
			dodge = _finite_number(_hero.evasion_chance, Content.EVASION_BASE)
		else:
			var level := clampi(int(_weapon_art_form.get("level", _hero.get("technique_level", 1))), 1, 5)
			var movement_rate := float(_profile.dodge_chance) + (level - 1) * Content.PETAL_EVASION_PER_RANK if _petal_equipped() else 0.0
			dodge = float(Content.evasion_breakdown(float(_profile.dodge_chance), movement_rate, _finite_number(_hero.get("equipment_evasion_bonus", 0.0), 0.0), _finite_number(_hero.get("dodge_bonus", 0.0), 0.0)).chance)
		var heart_level := clampi(int(_heart.get("level", _hero.get("technique_level", 1))), 1, 5)
		for method in _passive_methods:
			if method is Dictionary and str(method.get("id", "")) == "stillness" and bool(method.get("active", true)):
				heart_level = clampi(int(method.get("level", 1)), 1, 5)
		guard = float(_profile.guard_chance) + (heart_level - 1) * (0.018 if _stillness_equipped() else 0.0) + _finite_number(_hero.get("guard_bonus", 0.0), 0.0)
	else:
		dodge = _finite_number(_enemy.get("dodge_chance", float(_enemy_module_definition.get("dodge_chance",0.025))), 0.0)
		guard = _finite_number(_enemy.get("guard_chance", float(_enemy_module_definition.get("guard_chance",0.06))), 0.0)
	var phase := str(_sample_lane(receiver).name)
	var ready := Content.evasion_for_phase(dodge, "ready")
	dodge = Content.evasion_for_phase(ready, phase)
	if phase in ["strike", "contact"]:
		guard *= 0.60 if receiver == "hero" and _stillness_equipped() else 0.25
	elif phase == "stagger":
		guard = 0.0
	return {"evasion_chance": dodge, "ready_evasion_chance": ready, "guard_chance": clampf(guard, 0.0, 0.88), "defense_phase": phase}


static func defense_result(roll: float, dodge: float, guard: float) -> String:
	# Pure threshold function allows exact 0/1 and boundary tests without RNG.
	dodge = clampf(dodge if is_finite(dodge) else 0.0, 0.0, 1.0)
	guard = clampf(guard if is_finite(guard) else 0.0, 0.0, 1.0)
	if dodge >= 1.0 or roll < dodge: return "dodge"
	if guard >= 1.0 or roll < dodge + (1.0 - dodge) * guard: return "guard"
	return "hit"


func _roll_resolution(actor: String, contact: Dictionary = {}) -> String:
	var odds := defense_chances(actor)
	var roll := _rng.randf()
	contact.merge(odds, true)
	contact.defense_roll = roll
	return defense_result(roll, float(odds.evasion_chance), float(odds.guard_chance))


func _resolve_contact(actor: String, action: Dictionary, contact: Dictionary) -> Dictionary:
	if actor == "hero" and str(action.get("action_kind", "")) in ["defense", "utility"]:
		return _resolve_support_contact(action, contact)
	var target := _other(actor)
	var before_hero := hero_hp
	var before_enemy := enemy_hp
	var attack := maxf(1.0, float(_hero.get("attack", 8))) if actor == "hero" else maxf(1.0, float(_enemy.get("attack", 4)))
	var defense := maxf(0.0, float(_enemy.get("defense", 0))) if actor == "hero" else maxf(0.0, float(_hero.get("defense", 0)))
	var scale := float(action.get("attack_scale", 1.0)) if actor == "hero" else 1.0
	var armor_factor := float(action.get("armor_factor", 1.0))
	var mechanic_multiplier := 1.0
	var mechanic := ""
	var contact_metadata: Dictionary = _enemy_module.contact_metadata(action,int(contact.index)) if actor=="enemy" else {}
	if actor=="enemy":
		armor_factor = float(contact_metadata.get("armor_factor",armor_factor))
		mechanic = str(contact_metadata.get("mechanic",""))
	else:
		var exposure: Dictionary = _enemy_module.defense_modifier(_enemy_turns)
		mechanic_multiplier = float(exposure.get("multiplier",1.0))
		mechanic = str(exposure.get("mechanic",""))
	var counter_multiplier := 1.0
	if actor == "hero" and bool(action.get("counter", false)):
		counter_multiplier = 1.16 + clampf(float(_hero.get("counter_bonus", 0.0)), 0.0, 0.60)
	var raw := maxf(1.0, attack * scale * float(contact.coefficient) * mechanic_multiplier * counter_multiplier)
	var mitigated := maxf(raw * 0.25, raw - defense * armor_factor)
	var unguarded_damage := maxi(1, roundi(mitigated))
	var resolution := str(contact.resolution)
	var geometry: Dictionary = {}
	var enemy_geometry: Dictionary = {}
	var planted_geometry: Dictionary = {}
	var contact_region:=""
	if actor == "hero" and MeleeGeometry.is_melee(action):
		var current := pose()
		geometry = _measure_melee_contact(action, current)
		if bool(geometry.get("contact",false)):
			var body:=MeleeGeometry._body_data(current.enemy,_enemy)
			var point:Vector2=(Vector2(geometry.target)-Vector2(body.origin)).rotated(-float(body.rotation))
			var source_point:Vector2=(point-Rect2(body.rect).position)/Rect2(body.rect).size*256.0
			if "_authored_" in str(body.key):source_point-=Vector2(body.registration)
			var skull:Array=body.skull
			contact_region="head" if source_point.x>=float(skull[0]) and source_point.x<=float(skull[2]) and source_point.y>=float(skull[1]) and source_point.y<=float(skull[3]) else "leg" if source_point.y>205.0 else "torso"
		var reaches := bool(geometry.contact)
		if resolution == "dodge":
			# The evasion itself can move a valid target outside blade reach.
			# Test its planted envelope separately; do not credit a dodge for a
			# swing which would already have missed before that movement.
			planted_geometry = _measure_melee_contact(action, _planted_contact_pose(current, target), true)
			reaches = bool(planted_geometry.contact)
		if not reaches: resolution = "whiff"
	if actor == "enemy" and str(action.get("strike_geometry",{}).get("mode","")) == "enemy_body":
		var current := pose()
		enemy_geometry = _measure_enemy_contact(action, current)
		var reaches := bool(enemy_geometry.contact)
		if resolution == "dodge":
			planted_geometry = _measure_enemy_contact(action, _planted_contact_pose(current, target))
			reaches = bool(planted_geometry.contact)
		if not reaches: resolution = "whiff"

	var damage := unguarded_damage
	var guard_multiplier := float(_profile.guard_multiplier) if target == "hero" else float(_enemy.get("guard_multiplier", 0.50))
	guard_multiplier = maxf(guard_multiplier,float(contact_metadata.get("guard_min",0.0)))
	if resolution in ["dodge","whiff"]:
		damage = 0
		_chase[actor] = true
		if resolution == "dodge" and target == "hero" and _petal_equipped():
			_earn_counter("dodge_chase","%d:%d"%[int(action.id),int(contact.index)])
	elif resolution == "guard":
		damage = maxi(0, floori(float(unguarded_damage) * clampf(guard_multiplier, 0.15, 0.85)))
		if target == "hero" and _stillness_equipped():
			_earn_counter("deflect_counter","%d:%d"%[int(action.id),int(contact.index)])
	var shield_absorbed := 0
	var shield_before := _current_shield()
	if target == "hero":
		shield_absorbed = mini(damage, _current_shield())
		_shield = maxi(0, _current_shield() - shield_absorbed)
		damage -= shield_absorbed
		hero_hp = maxi(0, hero_hp - damage)
	else:
		enemy_hp = maxi(0, enemy_hp - damage)
	if actor == "hero" and str(action.get("skill_id", "")) == "frost" and resolution != "dodge":
		var definition: Dictionary = action.get("skill_definition", {})
		apply_slow("enemy", float(definition.get("slow_seconds", 2.8)), float(definition.get("slow_fraction", 0.22)))
		mechanic = "frost_slow"
	elif actor == "hero" and str(action.get("skill_id", "")) == "thunder":
		mechanic = "thunder_poise"
	var applied := before_hero - hero_hp if target == "hero" else before_enemy - enemy_hp
	var event := {"type": "contact", "contact_id": "%d:%d" % [int(action.id), int(contact.index)],
		"actor": actor, "target": target, "move": action.move, "telegraph": action.label,
		"turn_index": int(action.id), "action_id": int(action.id), "hit_index": int(contact.index), "resolution": resolution,
		"prepared_defense": str(contact.resolution),
		"evasion_chance": float(contact.get("evasion_chance", 0.0)), "ready_evasion_chance": float(contact.get("ready_evasion_chance", 0.0)),
		"guard_chance": float(contact.get("guard_chance", 0.0)), "defense_phase": str(contact.get("defense_phase", "")),
		"defense_roll": float(contact.get("defense_roll", -1.0)),
		"raw_damage": raw, "unguarded_damage": unguarded_damage, "damage": applied, "shield_absorbed": shield_absorbed, "shield_before": shield_before, "shield_after": _current_shield(),
		"mechanic": mechanic, "armor_factor": armor_factor, "mechanic_multiplier": mechanic_multiplier,
		"counter": bool(action.get("counter", false)), "counter_multiplier": counter_multiplier,
		"counter_kind": str(action.get("counter_kind", "")), "counter_source": str(action.get("counter_source", "")),
		"counter_earned_at": float(action.get("counter_earned_at", -1.0)),
		"counter_earned": resolution == "guard" and target == "hero" and _stillness_equipped(), "calculated_damage": damage,
		"poise_damage": 0.0, "poise_before": _current_pressure(target), "poise_after": _current_pressure(target),
		"poise_multiplier": clampf(float(action.get("skill_definition", {}).get("break_scale", 1.0)), 1.0, 2.0),
		"poise_threshold": _max_poise(target), "poise_broken": false,
		"guard_multiplier": guard_multiplier if resolution == "guard" else 1.0,
		"hero_hp_before": before_hero, "hero_hp_after": hero_hp, "enemy_hp_before": before_enemy, "enemy_hp_after": enemy_hp,
		"pre_hp": before_hero if target == "hero" else before_enemy, "post_hp": hero_hp if target == "hero" else enemy_hp,
		"hero_hp": hero_hp, "enemy_hp": enemy_hp, "time": _event_time(elapsed)}
	event.merge(_action_resource_fields(action), true)
	event.contact_role = str(contact_metadata.get("contact_role","strike"))
	if contact_metadata.has("impact_weight"): event.impact_weight = float(contact_metadata.impact_weight)
	if not geometry.is_empty():event.melee_contact=geometry
	if not contact_region.is_empty():
		event.contact_region=contact_region;event.contact_region_measured=true
	if not enemy_geometry.is_empty():event.enemy_contact=enemy_geometry
	if not planted_geometry.is_empty():event.planted_contact=planted_geometry
	_last_contact = event.duplicate(true)
	if resolution!="whiff":_reactions[target] = {"event": event.duplicate(true), "time": elapsed}
	return event


func _finalize_contact(event: Dictionary) -> void:
	# Pressure has already resolved, so guardbreak feedback and the reaction
	# snapshot agree with the final HP/posture event received by the host.
	event.enemy_visual_type = _species()
	event.hero_style = weapon_style
	event.impact_profile = Impact.describe(event)
	_last_contact = event.duplicate(true)
	if str(event.get("resolution", "")) in ["hit", "guard", "dodge"]:
		_defense_releases.erase(str(event.target))
		_reactions[str(event.target)] = {"event": event.duplicate(true), "time": elapsed}
	elif str(event.get("resolution", "")) == "whiff" and str(event.get("prepared_defense", "")) in ["guard", "dodge"]:
		# A raised guard still has to lower when the blow falls short. This is
		# visual release only: the genuine event remains an inactive whiff,
		# with no damage, posture pressure, counter reward or impact feedback.
		_defense_releases[str(event.target)] = {"defense": event.prepared_defense, "time": elapsed}


func _resolve_support_contact(action: Dictionary, contact: Dictionary) -> Dictionary:
	var before := hero_hp
	var definition: Dictionary = action.get("skill_definition", {})
	var effect_scale := float(action.get("power_scale", 1.0))
	var healed := 0
	var shield_added := 0
	var cleansed := false
	var resolution := "shield"
	if str(action.skill_id) == "barrier":
		shield_added = maxi(1, roundi(float(definition.get("shield_amount", 18.0)) * effect_scale))
		_shield = shield_added
		_shield_until = elapsed + clampf(float(definition.get("shield_seconds", 5.0)), 0.1, 10.0)
	else:
		healed = mini(hero_max_hp - hero_hp, maxi(1, roundi(float(definition.get("heal_amount", 18.0)) * effect_scale)))
		hero_hp += healed
		cleansed = elapsed < _hero_slow_until
		_hero_slow_until = elapsed
		resolution = "heal"
	var event := {"type": "contact", "contact_id": "%d:%d" % [int(action.id), int(contact.index)], "actor": "hero", "target": "hero",
		"move": action.move, "telegraph": action.label, "turn_index": int(action.id), "action_id": int(action.id), "hit_index": int(contact.index),
		"resolution": resolution, "raw_damage": 0.0, "unguarded_damage": 0, "damage": 0, "calculated_damage": 0,
		"heal": healed, "shield_added": shield_added, "shield_absorbed": 0, "cleansed_slow": cleansed,
		"mechanic": "barrier_absorption" if resolution == "shield" else "mending_restore", "counter": false, "counter_kind": "", "counter_multiplier": 1.0,
		"poise_damage": 0.0, "poise_before": _current_pressure("hero"), "poise_after": _current_pressure("hero"), "poise_threshold": _max_poise("hero"), "poise_broken": false,
		"guard_multiplier": 1.0, "hero_hp_before": before, "hero_hp_after": hero_hp, "enemy_hp_before": enemy_hp, "enemy_hp_after": enemy_hp,
		"pre_hp": before, "post_hp": hero_hp, "hero_hp": hero_hp, "enemy_hp": enemy_hp, "time": _event_time(elapsed)}
	event.merge(_action_resource_fields(action), true)
	_last_contact = event.duplicate(true)
	return event


func _earn_counter(kind: String, source_contact: String = "") -> void:
	_counter_ready = true
	_counter_kind = kind
	_counter_source = source_contact
	_counter_earned_at = elapsed
	var action: Dictionary = _lanes.hero.action
	# Reward a successful defense with a connected follow-up only after its
	# already committed contacts; never erase an attack to manufacture a parry.
	if not action.is_empty() and int(action.cursor) >= action.contacts.size() and not bool(action.get("interrupted", false)):
		var before := _sample_lane("hero")
		var hold_end := float(action.start)+float(action.contacts[-1].time)+float(action.hold)
		var new_end := minf(float(action.end), maxf(hold_end+0.10,elapsed+0.18))
		if str(before.name)=="recovery" and new_end<float(action.end):
			action.recovery_anchor_time = elapsed
			action.recovery_anchor_progress = float(before.progress)
		action.end = new_end


func _max_poise(actor: String) -> float:
	if actor == "hero":
		return 23.0 + minf(12.0, maxf(0.0, float(_hero.get("defense", 0))) * 0.35) + maxf(0.0, float(_hero.get("poise_bonus", 0.0)))
	return (31.0 if bool(_enemy.get("boss", false)) else 21.0) + minf(14.0, maxf(0.0, float(_enemy.get("defense", 0))) * 0.35)


func _current_pressure(actor: String) -> float:
	return maxf(0.0, float(_pressure.get(actor, 0.0)) - maxf(0.0, elapsed - float(_pressure_time.get(actor, 0.0)) - 0.85) * 4.0)


func _apply_pressure(actor: String, event: Dictionary) -> void:
	var target := str(event.target)
	var amount := 0.0
	if event.resolution not in ["dodge","whiff"] and elapsed >= float(_break_immunity[target]):
		amount = 3.0 + sqrt(float(event.raw_damage)) * 1.65
		if actor == "hero":
			amount *= 1.0 + clampf(float(_hero.get("break_bonus", 0.0)), 0.0, 0.75)
		if event.resolution == "guard":
			amount *= 0.90 if event.mechanic == "summit_guard_break" else 0.42
		if actor == "hero":
			amount *= float(event.get("poise_multiplier", 1.0))
		amount = minf(amount, _max_poise(target) * 0.70)
	var before := _current_pressure(target)
	var after := before + amount
	event.poise_damage = amount
	event.poise_before = before
	event.poise_after = minf(after, _max_poise(target))
	event.poise_threshold = _max_poise(target)
	event.poise_broken = amount > 0.0 and after + EPSILON >= _max_poise(target)
	if amount > 0.0:
		_pressure[target] = after
		_pressure_time[target] = elapsed
	if bool(event.poise_broken):
		_pressure[target] = 0.0
		_break_immunity[target] = elapsed + 0.72
		var interrupted := _freeze_action(target, 0.42)
		if actor == "hero" and interrupted and _offensive_followups_enabled():
			_earn_counter("break_followup",str(event.contact_id))
		_pending.append({"type": "poise_break", "actor": actor, "target": target, "contact_id": event.contact_id,
			"threshold": _max_poise(target), "pressure": after, "interrupted": interrupted, "time": _event_time(elapsed)})


func _freeze_action(actor: String, duration: float, force: bool = false) -> bool:
	var lane: Dictionary = _lanes[actor]
	var action: Dictionary = lane.action
	if action.is_empty():
		lane.ready_at = maxf(float(lane.ready_at), elapsed + duration)
		return false
	var phase := _sample_lane(actor)
	# Equal-time contacts trade fairly; a pressure break may not retroactively
	# remove a contact that has already reached its scheduled contact instant.
	if not force and int(action.cursor) < action.contacts.size() and absf(float(action.start) + float(action.contacts[int(action.cursor)].time) - elapsed) <= EPSILON:
		return false
	if actor == "enemy":
		var frozen_visual := _neutral_motion()
		frozen_visual.actor_lunge = _sample_lunge(action)
		_apply_enemy_motion(frozen_visual)
		action.frozen_offset = frozen_visual.visual_offset
		action.frozen_rotation = frozen_visual.visual_rotation
		action.frozen_pose_key = frozen_visual.pose_key
		action.frozen_monster_pose = frozen_visual.get("monster_pose", MonsterMoves.neutral_pose())
	if actor=="hero":action.frozen_approach=SideRig.approach_footwork(_approach_motion(action))
	action.frozen_phase = phase
	action.frozen_lunge = _sample_lunge(action)
	action.interrupted = true
	action.interrupt_start = elapsed
	action.end = elapsed + duration
	return true


func _sample_lane(actor: String, at_time:float=-1.0) -> Dictionary:
	var clock:=elapsed if at_time<0.0 else at_time
	var action: Dictionary = _lanes.get(actor, {}).get("action", {})
	return _sample_action_phase(action, clock)


func _sample_action_phase(action: Dictionary, clock: float) -> Dictionary:
	if action.is_empty():
		return {"name": "idle", "index": 0, "progress": 0.0}
	if bool(action.get("interrupted", false)):
		return {"name": "stagger", "index": int(action.frozen_phase.index), "progress": clampf((clock - float(action.interrupt_start)) / maxf(EPSILON, float(action.end) - float(action.interrupt_start)), 0.0, 1.0)}
	var t := clock - float(action.start)
	# Match the scheduler's absolute boundary and tolerance. Subtracting start
	# from a resolved contact can round a few ulps into the preceding strike.
	if clock + EPSILON < float(action.start) + float(action.windup):
		return {"name": "windup", "index": 0, "progress": clampf(t / float(action.windup), 0.0, 1.0)}
	var previous_end := float(action.windup)
	for index in range(action.contacts.size()):
		var at := float(action.contacts[index].time)
		if clock + EPSILON < float(action.start) + at:
			return {"name": "strike", "index": index, "progress": clampf((t - previous_end) / maxf(EPSILON, at - previous_end), 0.0, 1.0)}
		var end := at + float(action.hold)
		if clock + EPSILON < float(action.start) + end:
			return {"name": "contact", "index": index, "progress": clampf((t - at) / float(action.hold), 0.0, 1.0)}
		previous_end = end
	if action.has("recovery_anchor_time") and clock>=float(action.recovery_anchor_time):
		var progress := lerpf(float(action.recovery_anchor_progress),1.0,clampf((clock-float(action.recovery_anchor_time))/maxf(EPSILON,float(action.end)-float(action.recovery_anchor_time)),0.0,1.0))
		return {"name":"recovery","index":action.contacts.size()-1,"progress":progress}
	var recovery_end := float(action.end) - float(action.start)
	return {"name": "recovery", "index": action.contacts.size() - 1, "progress": clampf((t - previous_end) / maxf(EPSILON, recovery_end - previous_end), 0.0, 1.0)}


func _enemy_clearance_previews(action: Dictionary, clock: float) -> Array:
	var previews: Array = []
	if action.is_empty(): return previews
	# Seven tiny samples on either side preserve continuous pure sampling.
	# They affect spacing only, never contact timing, damage or RNG.
	for step in range(-7, 8):
		if step == 0: continue
		var delta := float(step) / 60.0
		var at := clampf(clock + delta, float(action.start), float(action.end))
		var phase := _sample_action_phase(action, at)
		var authored: Dictionary = _enemy_module.sample_body_pose(action, phase, at)
		var preview := {"combat_phase": phase.name, "phase_progress": phase.progress,
			"strike_index": phase.index, "move_family": action.move_family, "combat_move": action.move,
			"monster_pose": authored.monster_pose, "visual_offset": authored.root_offset,
			"visual_rotation": 0.0}
		if bool(action.get("interrupted", false)):
			preview.interrupted_phase = str(action.frozen_phase.name)
			preview.interrupted_progress = float(action.frozen_phase.progress)
			preview.visual_offset = Vector2(action.get("frozen_offset", Vector2.ZERO)).lerp(Vector2.ZERO, smoothstep(0.0,1.0,float(phase.progress)))
		_sample_defense("enemy", preview, at)
		previews.append({"motion": preview, "weight": 1.0 - smoothstep(0.0, 0.125, absf(delta))})
	return previews


func _sample_lunge(action: Dictionary, at_time:float=-1.0) -> float:
	var clock:=elapsed if at_time<0.0 else at_time
	if action.is_empty():
		return 0.0
	if bool(action.get("interrupted", false)):
		return float(action.frozen_lunge) * (1.0 - smoothstep(float(action.interrupt_start), float(action.end), clock))
	var t := clock - float(action.start)
	var impact_start := float(action.contacts[0].time)
	var impact_end := float(action.contacts[-1].time) + float(action.hold)
	var movement: Dictionary = action.get("movement",{})
	var travel_begin := float(action.windup) * float(movement.get("travel_begin_fraction",0.65))
	var lunge := smoothstep(travel_begin, impact_start, t)
	var recovery_progress := clampf((t - impact_end) / maxf(EPSILON, float(action.end) - float(action.start) - impact_end), 0.0, 1.0)
	var release := smoothstep(0.0, 1.0, recovery_progress)
	if str(movement.get("release","smooth")) == "two_step":
		# Two discrete weight transfers, with a planted beat between them.
		release = 0.5 * smoothstep(0.04, 0.44, recovery_progress) + 0.5 * smoothstep(0.56, 0.96, recovery_progress)
	lunge *= 1.0 - release
	return float(action.lunge) * lunge


func _approach_motion(action:Dictionary,at_time:float=-1.0)->Dictionary:
	var clock:=elapsed if at_time<0.0 else at_time
	if _finish_at >= 0.0 and not _finish_approach.is_empty():
		return {"frozen_approach":_finish_approach,"approach_disengage":true,"approach_release":smoothstep(_finish_started,_finish_at,clock)}
	if action.is_empty():return {"approach_origin":_hero_stance}
	if bool(action.get("interrupted",false)):
		return {"frozen_approach":action.get("frozen_approach",{"root":_hero_stance,"lead":Vector2(_hero_stance,0),"rear":Vector2(_hero_stance,0)}),"approach_release":smoothstep(float(action.interrupt_start),float(action.end),clock)}
	var origin:=float(action.get("approach_origin",_hero_stance))
	var target:=float(action.get("approach_target",origin))
	var begin:=0.0
	var end:=maxf(EPSILON,float(action.windup)*0.90)
	var aim:=float(action.get("strike_aim",0.0));var crouch:=float(action.get("aim_crouch",0.0))
	var t:=clock-float(action.start)
	var profiles:Array=action.get("contact_aims",[])
	for index in range(1,profiles.size()):
		var previous:Dictionary=profiles[index-1];var next:Dictionary=profiles[index]
		var starts:=float(action.contacts[index-1].time)+float(action.hold)
		if t<=starts:break
		origin=float(previous.target);target=float(next.target);begin=starts;end=float(action.contacts[index].time)
		var blend:=smoothstep(begin,end,t)
		aim=lerpf(float(previous.aim),float(next.aim),blend);crouch=lerpf(float(previous.crouch),float(next.crouch),blend)
	return {"approach_origin":origin,"approach_distance":target-origin,"strike_aim":aim,"aim_crouch":crouch,
		"approach_progress":clampf((t-begin)/maxf(EPSILON,end-begin),0.0,1.0)}

func _planted_contact_pose(current: Dictionary, target: String) -> Dictionary:
	# Pure counterfactual: keep both actors' committed motion, timing and
	# approach, removing only the defender's evade offset. Never reroll.
	var planted := current.duplicate(true)
	if str(planted[target].get("defense_action", "")) == "dodge":
		planted[target].defense_action = "ready"
		planted[target].reaction_amount = 0.0
	_apply_enemy_motion(planted.enemy, elapsed, false)
	planted.enemy = MeleeGeometry.separate(planted.enemy, planted.hero, _enemy)
	return planted


func _measure_enemy_contact(action: Dictionary, current: Dictionary) -> Dictionary:
	var geometry: Dictionary = action.get("strike_geometry",{})
	var reach := float(geometry.get("reach",24.0))
	var result := {"gap": INF, "reach": reach, "contact": false, "point": Vector2.ZERO, "target": Vector2.ZERO, "area": bool(geometry.get("area",false)),
		"spacing_correction": float(current.enemy.get("body_separation", 0.0)), "spacing_reservation": float(current.enemy.get("body_reservation", 0.0))}
	for hero_front in MeleeGeometry.hero_body_fronts(current.hero):
		var front := MeleeGeometry.body_front(current.enemy, _enemy, hero_front.y)
		if not bool(front.valid): continue
		var gap := Vector2(front.point).x - hero_front.x
		if gap < float(result.gap):
			result.merge({"gap": gap, "contact": gap <= reach and gap >= -1.0, "point": hero_front, "target": front.point}, true)
	return result


func _measure_melee_contact(action:Dictionary,current:Dictionary,planted_target:bool=false)->Dictionary:
	var result:=MeleeGeometry.measure(current.hero,current.enemy,_enemy)
	if bool(result.contact):return result
	# Test the actual swept strike in the last 70ms, with the enemy at each
	# corresponding clock. A real evasion is still resolved separately.
	var index:=int(action.cursor)
	var start:=float(action.start)+(float(action.windup) if index==0 else float(action.contacts[index-1].time)+float(action.hold))
	for step in range(1,5):
		var at:=maxf(start,elapsed-minf(0.070,(elapsed-start)*0.45)*float(step)/4.0)
		var enemy_action:Dictionary=_lanes.enemy.action
		if enemy_action.is_empty() or at<float(enemy_action.start):continue
		var hero:=_hero_motion_at(at)
		var enemy:=_predicted_enemy_motion(at)
		if planted_target and str(enemy.get("defense_action", "")) == "dodge":
			enemy.defense_action = "ready"
			enemy.reaction_amount = 0.0
			_apply_enemy_motion(enemy, at, false)
		enemy = MeleeGeometry.separate(enemy,hero,_enemy)
		var swept:=MeleeGeometry.measure(hero,enemy,_enemy)
		if bool(swept.contact):
			swept.swept=true;swept.sample_time=at;swept.delay=elapsed-at
			return swept
	return result

func _hero_motion_at(at_time:float=-1.0)->Dictionary:
	var action:Dictionary=_lanes.hero.action
	var motion:=_neutral_motion()
	motion.merge(_approach_motion(action,at_time),true)
	motion.merge(_hero_join_motion(action,at_time),true)
	if action.is_empty():return motion
	var phase:=_sample_lane("hero",at_time)
	motion.merge(_action_resource_fields(action,false),true)
	motion.merge({"combat_move":action.move,"combat_phase":phase.name,"phase_progress":phase.progress,"strike_index":phase.index,"attack_amount":1.0,"attack_style":weapon_style,"actor_lunge":_sample_lunge(action,at_time)},true)
	motion.merge(_approach_motion(action,at_time),true)
	motion.pose_provider = action.get("pose_provider", _base_module)
	motion.strike_provider = action.get("strike_provider", _base_module)
	if bool(action.get("interrupted",false)):
		motion.interrupted_phase=action.frozen_phase.name;motion.interrupted_progress=action.frozen_phase.progress
	_sample_defense("hero",motion,at_time)
	return motion

func _predicted_enemy_motion(at:float)->Dictionary:
	var saved:Dictionary=_lanes.enemy.action
	var starts:=float(_lanes.enemy.ready_at) if saved.is_empty() else float(saved.end)+CombatTiming.ready_interval("enemy",_action_timing.enemy)
	if (saved.is_empty() or at>float(saved.end)) and at>=starts:
		var projected:=_enemy_action(false,starts)
		_prepare_action_timing("enemy", projected, starts)
		projected.merge({"actor":"enemy","start":starts,"interrupted":false,"contacts":[]},true)
		for i in range(projected.hits.size()):projected.contacts.append({"time":float(projected.windup)+float(projected.strike)+float(projected.gap)*i,"index":i})
		projected.duration=float(projected.contacts[-1].time)+float(projected.hold)+float(projected.recovery)
		projected.end=starts+float(projected.duration)
		_lanes.enemy.action=projected
	var enemy:=_neutral_motion()
	enemy.actor_lunge=_sample_lunge(_lanes.enemy.action,at)
	_sample_defense("enemy",enemy,at)
	_apply_enemy_motion(enemy,at,false)
	_lanes.enemy.action=saved
	return enemy

func _plan_melee_approach(action:Dictionary)->void:
	var hero:=_neutral_motion()
	hero.merge(_action_resource_fields(action,false),true)
	hero.pose_provider = action.get("pose_provider", _base_module)
	hero.strike_provider = action.get("strike_provider", _base_module)
	hero.merge({"combat_move":action.move,"combat_phase":"contact","phase_progress":0.0,"attack_amount":1.0,"attack_style":weapon_style,"actor_lunge":float(action.lunge)},true)
	# Approach duration changes the impact clock. Re-predict after each such
	# change; the final approach always targets the final scheduled clock.
	for iteration in range(5):
		var at:=float(action.start)+float(action.contacts[0].time)
		var enemy:=_predicted_enemy_motion(at)
		var fit:=MeleeGeometry.fit_approach(hero,enemy,_enemy,float(action.approach_origin))
		action.approach_target=fit.target;action.strike_aim=fit.aim;action.aim_crouch=fit.crouch
		var old_windup:=float(action.windup)
		var next_windup:=maxf(old_windup,(absf(float(action.approach_target)-float(action.approach_origin))/100.0+0.18)/float(action.action_rate))
		if iteration==4 or next_windup-old_windup<0.00001:break
		action.windup=next_windup
		var added:=next_windup-old_windup
		for contact in action.contacts:contact.time=float(contact.time)+added
		action.duration=float(action.duration)+added;action.end=float(action.end)+added

	# Each authored combo contact has its own blade/palm arc and moving target.
	# Plan the remaining contacts after the final first-contact clock is fixed.
	action.contact_aims=[{"target":action.approach_target,"aim":action.strike_aim,"crouch":action.aim_crouch}]
	for index in range(1,action.contacts.size()):
		hero.strike_index=index
		var previous:Dictionary=action.contact_aims[-1]
		var fit:Dictionary={}
		for iteration in range(4):
			var enemy:=_predicted_enemy_motion(float(action.start)+float(action.contacts[index].time))
			fit=MeleeGeometry.fit_approach(hero,enemy,_enemy,float(previous.target))
			var segment_start:=float(action.contacts[index-1].time)+float(action.hold)
			var needed:=(absf(float(fit.target)-float(previous.target))/100.0+0.10)/float(action.action_rate)
			var added:=maxf(0.0,needed-(float(action.contacts[index].time)-segment_start))
			if added<0.00001 or iteration==3:break
			for later in range(index,action.contacts.size()):action.contacts[later].time=float(action.contacts[later].time)+added
			action.duration=float(action.duration)+added;action.end=float(action.end)+added
		action.contact_aims.append(fit)

func _hero_join_motion(action: Dictionary, at_time: float = -1.0) -> Dictionary:
	var clock := elapsed if at_time < 0.0 else at_time
	if action.is_empty(): return {"entry_pose":_hero_join,"entry_blend":0.0}
	var entry: Dictionary = action.get("entry_pose",{})
	var duration := minf(0.22,float(action.windup)*0.72)
	return {"entry_pose":entry,"entry_blend":smoothstep(0.0,maxf(0.01,duration),clock-float(action.start)),"carry_exit":float(action.get("carry_exit",0.0)) if _finish_at<0.0 else 0.0}


func _neutral_motion() -> Dictionary:
	return {"attack_phase": 0.0, "attack_amount": 0.0, "attack_style": weapon_style,
		"combat_move": "", "combat_phase": "idle", "action_kind": "", "basic_style": weapon_style, "basic_range": 0.0, "trail_kind": "", "sound_kind": "", "phase_progress": 0.0, "strike_index": 0, "contact_index": 0,
		"defense_action": "ready", "reaction_amount": 0.0, "actor_lunge": 0.0, "action_id": 0,
		"stagger_amount": 0.0, "counter_window": false, "combat_stance": 1.0 if _started and not finished else 0.0,
		"technique": technique, "clock": elapsed, "guard_provider": _base_module}


func pose() -> Dictionary:
	var result := {"actor": "", "phase": "idle", "phase_progress": 0.0, "turn_progress": 0.0,
		"move": "", "telegraph": "", "technique": technique, "weapon_style": weapon_style,
		"hero_hp": hero_hp, "hero_max_hp": hero_max_hp, "enemy_hp": enemy_hp, "enemy_max_hp": enemy_max_hp,
		"finished": finished, "victory": victory, "cancelled": cancelled, "turn_index": turn_index,
		"hero_action": "ready", "enemy_action": "ready", "hero": _neutral_motion(), "enemy": _neutral_motion(),
		"contact_id": "", "resolution": "", "actor_lunge": 0.0, "enemy_visual_type": _species(),
		"mechanic": _mechanic(), "enemy_phase": "awakened" if _awakened() else "calm"}
	var resources := battle_resource_snapshot()
	result.merge({"battle_resources": resources, "qi": resources.qi, "max_qi": resources.max_qi,
		"technique_cd": resources.technique_cd, "weapon_art_cd": resources.weapon_art_cd, "spell_cd": resources.spell_cd,
		"weapon_cd": resources.get("weapon_cd", 0.0), "action_kind": "", "enemy_slow_remaining": maxf(0.0, _enemy_slow_until - elapsed),
		"hero_slow_remaining": maxf(0.0, _hero_slow_until - elapsed), "shield": resources.shield, "shield_remaining": resources.shield_remaining}, true)
	result.hero.battle_resources = resources.duplicate(true)
	if not _started or cancelled:
		return result
	for actor in ACTORS:
		var motion: Dictionary = result[actor]
		var action: Dictionary = _lanes[actor].action
		var phase := _sample_lane(actor)
		motion.poise = maxf(0.0, _max_poise(actor) - _current_pressure(actor))
		motion.max_poise = _max_poise(actor)
		motion.counter_window = actor == "hero" and _counter_ready
		motion.attack_style = weapon_style if actor == "hero" else "unarmed"
		if actor=="hero":
			motion.merge(_approach_motion(action),true)
			motion.merge(_hero_join_motion(action),true)
		if not action.is_empty():
			motion.merge(_action_resource_fields(action,false), true)
			motion.merge({"attack_phase": clampf((elapsed - float(action.start)) / float(action.duration), 0.0, 1.0),
				"attack_amount": 0.0 if finished else 1.0, "combat_move": action.move, "combat_phase": phase.name,
				"phase_progress": phase.progress, "strike_index": phase.index, "contact_index": phase.index,
				"combo_index": phase.index, "action_id": action.id, "telegraph": action.label,
				"actor_lunge": _sample_lunge(action), "counter": bool(action.get("counter", false)),
				"counter_kind": str(action.get("counter_kind", "")), "counter_source": str(action.get("counter_source", "")),
				"counter_earned_at": float(action.get("counter_earned_at", -1.0)), "chase": bool(action.get("chase", false))}, true)
			if actor=="hero":
				motion.merge(_approach_motion(action),true)
				motion.pose_provider = action.get("pose_provider", _base_module)
				motion.strike_provider = action.get("strike_provider", _base_module)
			if bool(action.get("interrupted", false)):
				motion.interrupted_phase = action.frozen_phase.name
				motion.interrupted_progress = action.frozen_phase.progress
				motion.stagger_amount = 1.0 - float(phase.progress)
		result[actor + "_action"] = phase.name
		_sample_defense(actor, motion)
		if float(motion.reaction_amount) > 0.0:
			result[actor + "_action"] = motion.defense_action
	var focus := _focus_actor()
	var active: Dictionary = _lanes[focus].action
	if not active.is_empty():
		var phase := _sample_lane(focus)
		result.merge({"actor": focus, "phase": phase.name, "phase_progress": phase.progress,
			"turn_progress": result[focus].attack_phase, "move": active.move, "telegraph": active.label,
			"action_kind": str(active.get("action_kind", "enemy")),
			"actor_lunge": result[focus].actor_lunge,
			"contact_times": active.contacts.map(func(c: Dictionary) -> float: return float(c.time)),
			"turn_duration": active.duration, "windup_duration": active.windup}, true)
	if not _last_contact.is_empty() and elapsed - float(_last_contact.time) < 0.26:
		result.contact_id = _last_contact.contact_id
		result.resolution = _last_contact.resolution
	_apply_enemy_motion(result.enemy)
	_sample_deflection_cue(result.enemy)
	var guard_reaction:Dictionary=_reactions.get("hero",{})
	if not guard_reaction.is_empty():
		var guard_event:Dictionary=guard_reaction.event
		var guard_age:=elapsed-float(guard_reaction.time)
		if str(guard_event.resolution)=="guard" and not bool(guard_event.get("poise_broken",false)) and guard_age>=0.0 and guard_age<.36:
			result.hero.guard_visual={"age":guard_age,"profile":guard_event.impact_profile,"contact_id":guard_event.contact_id}
			if guard_event.has("enemy_contact"):
				var contact_geometry:Dictionary=guard_event.enemy_contact
				result.hero.guard_visual.point=Vector2(contact_geometry.point)+Vector2(clampf(Vector2(contact_geometry.target).x-Vector2(contact_geometry.point).x,0.0,3.0),0)
	if str(result.hero.defense_action)=="guard" and not _lanes.enemy.action.is_empty():
		# Presentation-only incoming line, available during the existing
		# prepared guard. It neither changes the defense roll nor contact.
		var incoming:=_measure_enemy_contact(_lanes.enemy.action,result)
		if is_finite(float(incoming.gap)):
			result.hero.guard_contact_valid=true
			result.hero.guard_contact_point=Vector2(incoming.point)+Vector2(clampf(Vector2(incoming.target).x-Vector2(incoming.point).x,0.0,3.0),0)
	if MeleeGeometry.is_melee(result.hero):result.melee_contact=MeleeGeometry.measure(result.hero,result.enemy,_enemy)
	return result


func _sample_defense(actor: String, motion: Dictionary,at_time:float=-1.0) -> void:
	var clock:=elapsed if at_time<0.0 else at_time
	if _defense_releases.has(actor):
		var release: Dictionary = _defense_releases[actor]
		var release_age := clock - float(release.time)
		if release_age >= -EPSILON and release_age < 0.22:
			motion.defense_action = str(release.defense)
			motion.reaction_amount = 1.0 - smoothstep(0.0, 0.22, release_age)
			motion.defense_release = true
			motion.recoil_distance = 0.0
	if _reactions.has(actor):
		var reaction: Dictionary = _reactions[actor]
		var age := clock - float(reaction.time)
		var profile: Dictionary = reaction.event.get("impact_profile", {})
		var duration := float(profile.get("reaction_duration", 0.34))
		if str(reaction.event.resolution) == "dodge": duration = 0.34
		if age >= -EPSILON and age < duration:
			motion.defense_action = reaction.event.resolution
			motion.reaction_amount = 1.0 - smoothstep(minf(0.05, duration * 0.2), duration, age)
			motion.impact_profile = profile
			motion.reaction_age = maxf(0.0, age)
			motion.reaction_strength = float(profile.get("reaction_magnitude", 0.75))
			motion.recoil_distance = float(profile.get("knockback", 5.0))
			motion.reaction_direction = profile.get("direction", Vector2.RIGHT if actor == "enemy" else Vector2.LEFT)
			motion.guard_broken = bool(reaction.event.get("poise_broken", false))
			motion.contact_id = reaction.event.contact_id
			if age < minf(0.11, duration * 0.5):
				return
	var action: Dictionary = _lanes[_other(actor)].action
	if action.is_empty() or bool(action.get("interrupted", false)) or _finish_at >= 0.0:
		return
	var cursor := int(action.cursor)
	if cursor < action.contacts.size():
		var upcoming: Dictionary = action.contacts[cursor]
		var until := float(action.start) + float(upcoming.time) - clock
		var lead := _contact_defense_lead(action, cursor)
		if bool(upcoming.prepared) and until >= 0.0 and until <= lead and str(upcoming.resolution) in ["guard", "dodge"]:
			motion.defense_action = upcoming.resolution
			motion.reaction_amount = smoothstep(lead, 0.0, until)


func _sample_deflection_cue(motion: Dictionary) -> void:
	# Read the actual defended contact, never the upcoming defense roll. These
	# extra keys are render-only and absent from the bound attack/geometry APIs.
	var reaction: Dictionary = _reactions.get("hero", {})
	if reaction.is_empty(): return
	var event: Dictionary = reaction.event
	if str(event.get("resolution", "")) != "guard" or bool(event.get("poise_broken",false)): return
	var age := elapsed-float(reaction.time)
	var duration := ResponseCues.DEFLECT_SECONDS
	var action: Dictionary = _lanes.enemy.action
	if not action.is_empty() and int(action.cursor)<action.contacts.size():
		var next_at := float(action.start)+float(action.contacts[int(action.cursor)].time)
		duration = minf(duration,maxf(0.01,(next_at-float(reaction.time))*.72))
	if age<0.0 or age>=duration:return
	motion.deflected_contact_id = str(event.contact_id)
	motion.deflection_age = age
	motion.deflection_duration = duration


func _focus_actor() -> String:
	if not _last_contact.is_empty() and elapsed - float(_last_contact.time) < 0.18:
		return str(_last_contact.actor)
	var hero: Dictionary = _lanes.hero.action
	var enemy: Dictionary = _lanes.enemy.action
	if enemy.is_empty():
		return "hero"
	if hero.is_empty():
		return "enemy"
	# Compatibility/UI focus selects the next threat; never use it to gate
	# either actor's animation. Their separate lanes keep moving continuously.
	return "hero" if _next_boundary("hero") <= _next_boundary("enemy") else "enemy"


static func _other(actor: String) -> String:
	return "enemy" if actor == "hero" else "hero"

func _enemy_stamina(at_time: float = -1.0) -> float:
	var clock := elapsed if at_time < 0.0 else at_time
	return clampf(_enemy_stamina_base + maxf(0.0, clock - _enemy_stamina_anchor) * 8.0, 0.0, 100.0)


func _enemy_choice_state(at_time: float = -1.0) -> Dictionary:
	var clock := elapsed if at_time < 0.0 else at_time
	var phase := _sample_lane("hero", clock)
	var hero_root := float(SideRig.approach_footwork(_approach_motion(_lanes.hero.action, clock)).root)
	return {"distance": maxf(0.0, float(_enemy.get("engagement_distance", 128.0)) - float(_enemy.get("enemy_front_extent", 42.0)) - 20.0 - hero_root),
		"stamina": _enemy_stamina(clock), "history": _enemy_history.duplicate(), "hero_phase": str(phase.name),
		"hp_fraction": float(enemy_hp) / maxf(1.0, enemy_max_hp), "chase": bool(_chase.get("enemy", false))}


func _enemy_action(commit: bool = false, at_time: float = -1.0) -> Dictionary:
	var state := _enemy_choice_state(at_time)
	var saved_rng_state := _enemy_rng.state
	var selection := {"enemy":_enemy,"choice_state":state,"candidate_roll":_enemy_rng.randf(),"action_index":_enemy_turns,"awakened":_awakened()}
	var action: Dictionary = _enemy_module.select_action(selection)
	# Shared body geometry may adjust the authored charge reach, never the
	# selected action, its RNG result, damage budget, or a defender's evade.
	if bool(_enemy_module_definition.get("preview_clearance",false)) and str(action.kind)=="charge":
		var contact_pose: Dictionary = _enemy_module.sample_body_pose(action, {"name":"contact","index":0,"progress":0.0}, 0.0)
		var contact_motion := {"move_family":action.move_family,"combat_phase":"contact","phase_progress":0.0,"monster_pose":contact_pose.monster_pose,"visual_offset":contact_pose.root_offset}
		var standing := _neutral_motion()
		standing.combat_stance = 1.0
		var measured_gap := INF
		for hero_front in MeleeGeometry.hero_body_fronts(standing):
			var body_front := MeleeGeometry.body_front(contact_motion, _enemy, hero_front.y)
			if bool(body_front.valid): measured_gap = minf(measured_gap, Vector2(body_front.point).x - hero_front.x)
		if is_finite(measured_gap):
			selection.charge_reach = clampf(measured_gap - 5.0, 8.0, 100.0)
			action = _enemy_module.select_action(selection)
	if commit and bool(action.get("weighted_choice",false)):
		_enemy_stamina_base = maxf(0.0,float(state.stamina)-float(action.stamina_cost))
		_enemy_stamina_anchor = elapsed
		_enemy_history.append(str(action.kind))
		if _enemy_history.size()>3: _enemy_history.pop_front()
	else:
		_enemy_rng.state = saved_rng_state
	return action


func _species() -> String:
	var explicit := str(_enemy.get("visual_type", ""))
	if explicit in SPECIES_BY_ROUTE.values():
		return explicit
	return str(SPECIES_BY_ROUTE.get(str(_enemy.get("route_id", "bamboo_pass")), "moss_beast"))


func _awakened() -> bool:
	return _enemy_module != null and _enemy_module.is_awakened(float(enemy_hp)/maxf(1.0,enemy_max_hp))


func _mechanic() -> String:
	return str(_enemy_module.mechanic(_enemy_turns)) if _enemy_module != null else ""


func _apply_enemy_motion(motion: Dictionary,at_time:float=-1.0,apply_spacing:bool=true) -> void:
	var action: Dictionary = _lanes.enemy.action
	var phase := _sample_lane("enemy",at_time)
	var clock := elapsed if at_time < 0.0 else at_time
	var sampled: Dictionary = _enemy_module.sample_enemy_motion(action,phase,clock,{"motion":motion,"hero_lunge":_sample_lunge(_lanes.hero.action,at_time),"finished":finished,"enemy_turns":_enemy_turns,"enemy":_enemy})
	motion.merge(sampled,true)
	if bool(_enemy_module_definition.get("preview_clearance",false)):
		motion.clearance_previews = _enemy_clearance_previews(action,clock)
	if not apply_spacing:return
	var hero_motion:=_hero_motion_at(at_time)
	motion.merge(MeleeGeometry.separate(motion,hero_motion,_enemy),true)
	motion.erase("clearance_previews")

static func _weapon_style(weapon: String) -> String:
	if "fan" in weapon:
		return "fan"
	if "sword" in weapon or "blade" in weapon:
		return "sword"
	return "unarmed"


static func _event_time(value: float) -> float:
	return snappedf(value, 0.000001)
