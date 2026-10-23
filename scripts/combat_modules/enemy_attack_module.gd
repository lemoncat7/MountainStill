extends "res://scripts/combat_modules/attack_module.gd"
## Registered creature behavior. Selection and sampling are pure; only the host
## spends stamina, advances RNG/history, authorizes contacts, and changes HP.
## A species profile is selected once at bind, not switched on by the simulator.
const MonsterMoves = preload("res://scripts/monster_move_library.gd")
const MODULE_IDS := ["enemy.moss_beast", "enemy.river_stone", "enemy.cloud_crane", "enemy.ember_guardian", "enemy.moon_wisp", "enemy.summit_keeper"]
const PROFILES := {
	"moss_beast": {"weighted":true,"opening":"charge","sequence":["charge","sweep"],"effect":"moss_stomp","mechanic":"moss_rooted_charge",
		"labels":{"charge":"伏身蓄势 · 苔角冲撞","sweep":"侧身扬爪 · 横扫","burst":"双足踏地 · 连震"}},
	"river_stone": {"opening":"sweep","sequence":["sweep","burst"],"effect":"river_tide","mechanic":"river_shell","shell_cycle":true,"guard_chance":0.22,
		"visual":{"wind_x":2.0,"sweep_wind_rotation":0.035,"sweep_impact_rotation":-0.045},
		"labels":{"charge":"石臂后撤 · 重拳","sweep":"盘身卷水 · 石环横扫","burst":"石纹聚亮 · 飞石连发"}},
	"cloud_crane": {"weighted":true,"opening":"burst","sequence":["charge","sweep"],"effect":"crane_feathers","mechanic":"crane_aerial","landing_vulnerable":true,"dodge_chance":0.12,"air_dodge":true,
		"labels":{"charge":"收翅俯身 · 掠空啄击","sweep":"展翅蓄风 · 风羽横扫","burst":"云羽悬起 · 羽刃连发"}},
	"ember_guardian": {"opening":"sweep","sequence":["sweep","burst","charge"],"effect":"ember_heat","mechanic":"ember_afterburn","awakens":true,
		"windup_add":0.16,"recovery_add":0.08,"short_lunge":9.0,"visual":{"wind_x":5.0},"contact_rules":{"burst_last":{"armor_factor":0.75,"mechanic":"ember_afterburn"}},
		"tuning":{"burst":{"hits":[0.42,0.64],"boss_hits":[0.40,0.46,0.80],"gap":0.34},"sweep":{"hits":[0.88],"boss_hits":[1.28]}},
		"labels":{"charge":"炉心压低 · 炎角突进","sweep":"双爪落地 · 炉火裂环","burst":"三息蓄炉 · 余烬连爆"}},
	"moon_wisp": {"opening":"burst","sequence":["burst","sweep","charge"],"effect":"moon_veil","mechanic":"moon_crescendo","awakens":true,"air_dodge":true,"rest_y":-8.0,
		"windup_add":0.12,"short_lunge":7.0,"visual":{"rest_y":-8.0,"wind_y":-15.0,"impact_y":-15.0,"strike_y":-23.0,"strike_arc":9.0},"contact_rules":{"burst":{"mechanic":"moon_crescendo"}},
		"tuning":{"burst":{"hits":[0.38,0.72],"boss_hits":[0.34,0.52,0.86],"gap":0.29},"sweep":{"hits":[0.35,0.52],"boss_hits":[0.44,0.70],"gap":0.38}},
		"labels":{"charge":"月影缩身 · 掠月突袭","sweep":"双月错落 · 回弦追击","burst":"月珠聚光 · 三弦递响"}},
	"summit_keeper": {"opening":"charge","sequence":["charge","burst","sweep"],"effect":"summit_seal","mechanic":"summit_guard_break","awakens":true,
		"windup_add":0.20,"recovery_add":0.12,"visual":{"wind_x":3.0,"charge_strike_arc":10.0},"contact_rules":{"sweep":{"mechanic":"summit_guard_break","guard_min":0.65}},
		"tuning":{"burst":{"hits":[0.42,0.62],"boss_hits":[0.52,0.52,0.70],"gap":0.40},"sweep":{"hits":[0.72],"boss_hits":[1.02]},"charge":{"hits":[1.05],"boss_hits":[1.58]}},
		"labels":{"charge":"松冠俯伏 · 镇山重踏","sweep":"金印凝成 · 破守镇击","burst":"三印悬空 · 天门连诀"}},
}
const BODY_GEOMETRY := {
	"moss_pounce":{"mode":"enemy_body","reach":13.0,"area":false},"moss_rush":{"mode":"enemy_body","reach":9.0,"area":false},"moss_slam":{"mode":"enemy_body","reach":65.0,"area":true},
	"crane_peck":{"mode":"enemy_body","reach":12.0,"area":false},"crane_sweep":{"mode":"enemy_body","reach":48.0,"area":false},"crane_dive":{"mode":"enemy_body","reach":16.0,"area":false},
}
# Presentation-only rigid-body anticipation. It is zero at every contact and
# returns continuously at phase joins; no scaling or painted-anatomy warping.
const ANTICIPATION := {"crane_peck":{"rotation":0.028,"settle_y":2.0,"withdraw_x":1.5}}
const MOVEMENT := {
	"moss_pounce":{"travel_begin_fraction":1.0,"release":"smooth"},"crane_dive":{"travel_begin_fraction":1.0,"release":"smooth"},
	"moss_rush":{"travel_begin_fraction":0.92,"release":"two_step"},"moss_slam":{"travel_begin_fraction":0.65,"release":"two_step"},
}
var _species: String = "moss_beast"
var _behavior: Dictionary = {}

static func register_modules(registry) -> void:
	var factory: Script = load("res://scripts/combat_modules/enemy_attack_module.gd")
	for id in MODULE_IDS:
		registry.register_module(id, factory)

func configure(context: Dictionary = {}) -> void:
	_species = _species_from_context(context)
	_behavior = PROFILES[_species].duplicate(true)
	super.configure(context)

static func _species_from_context(context: Dictionary) -> String:
	var id := str(context.get("module_id", ""))
	var species := id.trim_prefix("enemy.") if id.begins_with("enemy.") else str(context.get("species", "moss_beast"))
	return species if PROFILES.has(species) else "moss_beast"

func _build_definition(context: Dictionary) -> Dictionary:
	var species := _species_from_context(context)
	var profile: Dictionary = PROFILES[species]
	var moves := {}
	var enemy: Dictionary = context.get("enemy", {})
	var boss := bool(enemy.get("boss", false))
	var reach := clampf(float(enemy.get("engagement_distance",128.0))-float(enemy.get("enemy_front_extent",42.0))-20.0,8.0,100.0)
	for kind in ["charge", "sweep", "burst"]:
		var action := _base_action(kind,boss,reach)
		action.merge(MonsterMoves.authored(species,kind,boss,reach),true)
		action.windup += float(profile.get("windup_add",0.0))
		action.recovery += float(profile.get("recovery_add",0.0))
		var tuning: Dictionary = profile.get("tuning",{}).get(kind,{})
		if tuning.has("hits"): action.hits = tuning.get("boss_hits",tuning.hits).duplicate() if boss else tuning.hits.duplicate()
		if tuning.has("gap"): action.gap = float(tuning.gap)
		if profile.has("short_lunge"): action.lunge = reach if kind == "charge" else float(profile.short_lunge)
		action.move_family = MonsterMoves.family(species,kind)
		action.label = str(action.get("label",profile.labels[kind]))
		action.strike_geometry = BODY_GEOMETRY.get(action.move_family,{"mode":"legacy_contact","reach":24.0,"area":false}).duplicate(true)
		action.movement = MOVEMENT.get(action.move_family,{"travel_begin_fraction":0.65,"release":"smooth"}).duplicate(true)
		moves[kind] = action
	return {"id":"enemy." + species,"kind":"enemy","style":species,"species":species,"moves":moves,
		"sequence":profile.sequence.duplicate(),"default_move":profile.opening,"resources":{},
		"action_cues":{"effect_kind":profile.effect},"strike_geometry":{"mode":"enemy_body" if bool(profile.get("weighted",false)) else "legacy_contact"},
		"weighted_choice":bool(profile.get("weighted",false)),"preview_clearance":bool(profile.get("weighted",false)),
		"dodge_chance":float(profile.get("dodge_chance",0.025)),"guard_chance":float(profile.get("guard_chance",0.06)),"mechanic":profile.mechanic}

func _ensure_configured() -> void:
	if _behavior.is_empty(): configure(_context)

func supports_body_contact() -> bool:
	_ensure_configured()
	return bool(_behavior.get("weighted", false))

func is_awakened(hp_fraction: float) -> bool:
	_ensure_configured()
	var enemy: Dictionary = _context.get("enemy", {})
	return bool(enemy.get("boss", false)) and bool(_behavior.get("awakens", false)) and hp_fraction <= float(enemy.get("phase_threshold", 0.5))

func mechanic(enemy_turns: int = 0) -> String:
	_ensure_configured()
	if bool(_behavior.get("shell_cycle",false)):
		return "river_shell" if enemy_turns % 2 == 0 else "river_exposed"
	return str(_behavior.mechanic)

func defense_modifier(enemy_turns: int = 0) -> Dictionary:
	_ensure_configured()
	if bool(_behavior.get("shell_cycle",false)):
		return {"multiplier":0.90 if enemy_turns % 2 == 0 else 1.12,"mechanic":mechanic(enemy_turns)}
	if bool(_behavior.get("landing_vulnerable",false)) and enemy_turns > 0:
		return {"multiplier":1.08,"mechanic":"crane_landing"}
	return {"multiplier":1.0,"mechanic":""}

func contact_metadata(action: Dictionary, hit_index: int) -> Dictionary:
	_ensure_configured()
	var result := {"armor_factor":float(action.get("armor_factor",1.0)),"mechanic":"","guard_min":0.0,"contact_role":"strike"}
	if str(action.get("move_family","")) == "moss_slam" and hit_index > 0:
		result.contact_role = "aftershock"
		result.impact_weight = 0.62
	var rules: Dictionary = _behavior.get("contact_rules", {})
	var kind := str(action.get("kind", "charge"))
	result.merge(rules.get(kind, {}), true)
	if hit_index == action.get("hits", []).size() - 1:
		result.merge(rules.get(kind + "_last", {}), true)
	return result

func select_action(state: Dictionary = {}) -> Dictionary:
	_ensure_configured()
	var enemy: Dictionary = state.get("enemy", _context.get("enemy", {}))
	var choice: Dictionary = state.get("choice_state", state)
	var boss := bool(enemy.get("boss",false))
	var action_index := int(state.get("action_index",state.get("enemy_turns",0)))
	var weights := MonsterMoves.choice_weights(_species, choice)
	var kind := MonsterMoves.choose(weights,float(state.get("candidate_roll",state.get("roll",0.0))))
	if action_index == 0:
		kind = str(enemy.get("boss_move","charge")) if boss else str(_behavior.opening)
		if kind not in ["charge","sweep","burst"]: kind = "charge"
	var weighted := bool(_behavior.get("weighted", false))
	if not weighted:
		var sequence: Array = _behavior.sequence.duplicate()
		if boss:
			sequence = ["charge", "sweep", "burst"]
			var preferred := str(enemy.get("boss_move",sequence[0]))
			if preferred in sequence:
				while str(sequence[0]) != preferred: sequence.append(sequence.pop_front())
		var pattern_offset := 1 if str(enemy.get("id","")) in ["kiln_keeper","mist_reflection","cloud_sentinel"] else 0
		kind = str(sequence[(action_index + (0 if boss else pattern_offset)) % sequence.size()])
		weights = {}
	var reach := float(state.get("charge_reach",clampf(float(enemy.get("engagement_distance",128.0))-float(enemy.get("enemy_front_extent",42.0))-20.0,8.0,100.0)))
	var action := _base_action(kind,boss,reach)
	var choreography := MonsterMoves.authored(_species,kind,boss,reach)
	if not choreography.is_empty(): action.merge(choreography,true)
	action.move_family = MonsterMoves.family(_species,kind)
	action.stamina_cost = MonsterMoves.cost(_species,kind) if weighted else 0.0
	action.choice_weights = weights
	action.choice_distance = float(choice.get("distance",50.0))
	action.windup += float(_behavior.get("windup_add",0.0))
	action.recovery += float(_behavior.get("recovery_add",0.0))
	var tuning: Dictionary = _behavior.get("tuning",{}).get(kind,{})
	if tuning.has("hits"): action.hits = tuning.get("boss_hits",tuning.hits).duplicate() if boss else tuning.hits.duplicate()
	if tuning.has("gap"): action.gap = float(tuning.gap)
	if _behavior.has("short_lunge"): action.lunge = reach if kind == "charge" else float(_behavior.short_lunge)
	var awakened := bool(state.get("awakened",bool(enemy.get("boss",false)) and bool(_behavior.get("awakens",false)) and float(choice.get("hp_fraction",1.0)) <= float(enemy.get("phase_threshold",0.5))))
	if awakened:
		action.windup = maxf(0.64,float(action.windup)-0.09)
		action.recovery += 0.16
	action.label = ("觉醒 · " if awakened else "") + ("守灵强招 · " if boss else "") + str(choreography.get("label",_behavior.labels[kind]))
	action.move = _species + ("_boss_" if boss else "_") + kind
	action.kind = kind
	action.module_id = "enemy." + _species
	action.weighted_choice = weighted
	action.strike_geometry = BODY_GEOMETRY.get(action.move_family,{"mode":"legacy_contact","reach":24.0,"area":false}).duplicate(true)
	action.movement = MOVEMENT.get(action.move_family,{"travel_begin_fraction":0.65,"release":"smooth"}).duplicate(true)
	action.action_cues = {"effect_kind":str(_behavior.effect)}
	return action

static func _base_action(kind: String, boss: bool, reach: float) -> Dictionary:
	match kind:
		"sweep":
			return {"windup":0.72 if boss else 0.49,"strike":0.24,"hold":0.15,"recovery":0.60,"hits":[1.42 if boss else 0.93],"gap":0.0,"lunge":19.0}
		"burst":
			return {"windup":0.76 if boss else 0.56,"strike":0.22,"hold":0.12,"recovery":0.57,"hits":[0.68,0.68,0.78] if boss else [0.57,0.63],"gap":0.22,"lunge":13.0}
	return {"windup":0.91 if boss else 0.62,"strike":0.25,"hold":0.15,"recovery":0.60,"hits":[1.76 if boss else 1.12],"gap":0.0,"lunge":reach}

func sample_body_pose(action: Dictionary, phase: Dictionary, clock: float) -> Dictionary:
	return MonsterMoves.sample(action,phase,clock)

func sample_enemy_motion(action: Dictionary, phase: Dictionary, clock: float, motion_state: Dictionary = {}) -> Dictionary:
	_ensure_configured()
	var motion: Dictionary = motion_state.get("motion", {}).duplicate(true)
	var enemy: Dictionary = motion_state.get("enemy",_context.get("enemy",{}))
	var p := clampf(float(phase.get("progress",0.0)),0.0,1.0)
	var name := str(phase.get("name","idle"))
	var index := int(phase.get("index",0))
	var interrupted := bool(action.get("interrupted",false))
	var authored := bool(_behavior.get("weighted",false))
	motion.combat_phase = name
	motion.phase_progress = p
	motion.strike_index = index
	motion.move_family = str(action.get("move_family",""))
	motion.combat_move = str(action.get("move",""))
	if interrupted: motion.interrupted_phase = str(action.frozen_phase.name)
	var offset := Vector2.ZERO
	var rotation := 0.0
	var pose_key := "idle"
	var effect := ""
	var amount := 0.0
	if not action.is_empty() and not interrupted and not bool(motion_state.get("finished",false)):
		var kind := str(action.get("kind","charge"))
		var wind := smoothstep(0.0,1.0,p) if name == "windup" else 0.0
		if name == "strike" and index == 0: wind = 1.0-smoothstep(0.0,0.65,p)
		var impact := 0.0
		if name == "strike": impact = 1.0-sin(p*PI)*0.28 if index > 0 else smoothstep(0.0,1.0,p)
		elif name == "contact": impact = 1.0
		elif name == "recovery": impact = 1.0-smoothstep(0.0,1.0,p)
		pose_key = "windup" if name == "windup" else ("attack" if name in ["strike","contact"] or (name == "recovery" and p < 0.34) else "idle")
		# A painted bent-elbow beat before lowering the arm. The same source
		# key is consumed by drawing AND pixel-exact contact geometry. This is
		# discrete keypose recovery, not a renderer-only blend or a new clock.
		if _species == "river_stone" and bool(enemy.get("boss",false)) and name == "recovery" and p >= 0.34 and p < 0.78:
			pose_key = "settle"
		offset.x = -maxf(0.0,float(motion.get("actor_lunge",0.0))-float(motion_state.get("hero_lunge",0.0))*0.42)
		if authored:
			var sampled := sample_body_pose(action,phase,clock)
			offset += Vector2(sampled.root_offset)
			motion.monster_pose = sampled.monster_pose
			motion.move_family = sampled.move_family
			effect = "moss_stomp" if str(action.move_family) == "moss_slam" else (str(_behavior.effect) if bool(_behavior.get("air_dodge",false)) else "")
		else:
			var visual: Dictionary = _behavior.get("visual",{})
			offset.x += float(visual.get("wind_x",0.0))*wind
			offset.y = float(visual.get("rest_y",0.0)) + float(visual.get("wind_y",0.0))*wind if name == "windup" else float(visual.get("rest_y",0.0)) + float(visual.get("impact_y",0.0))*impact
			if name == "strike":
				if visual.has("strike_y"): offset.y = float(visual.strike_y)-sin(p*PI)*float(visual.get("strike_arc",0.0))
				if kind == "charge" and visual.has("charge_strike_arc"): offset.y = -sin(p*PI)*float(visual.charge_strike_arc)
			if kind == "sweep": rotation = float(visual.get("sweep_wind_rotation",0.0))*wind + float(visual.get("sweep_impact_rotation",0.0))*impact
			effect = str(_behavior.effect)
		var anticipation: Dictionary = ANTICIPATION.get(str(action.get("move_family","")),{})
		if not anticipation.is_empty():
			var gather := 0.0
			if name == "windup": gather = smoothstep(0.0,1.0,p)
			elif name == "strike":
				gather = 1.0-smoothstep(0.0,0.65,p) if index == 0 else pow(sin(p*PI),2.0)
			offset += Vector2(float(anticipation.withdraw_x),float(anticipation.settle_y))*gather
			rotation += float(anticipation.rotation)*gather
		amount = maxf(wind,impact)
	elif interrupted:
		var settle := smoothstep(0.0,1.0,p)
		var rest := Vector2(0.0,float(_behavior.get("rest_y",0.0)))
		offset = Vector2(action.get("frozen_offset",rest)).lerp(rest,settle)
		rotation = lerpf(float(action.get("frozen_rotation",0.0)),0.0,settle)
		pose_key = str(action.get("frozen_pose_key","idle")) if p < 0.34 else "idle"
		motion.monster_pose = MonsterMoves._blend(action.get("frozen_monster_pose",MonsterMoves.neutral_pose()),MonsterMoves.neutral_pose(),settle)
		motion.move_family = str(action.get("move_family",""))
	var react := float(motion.get("reaction_amount",0.0))
	if react > 0.0 or interrupted or action.is_empty():
		match str(motion.get("defense_action","ready")):
			"hit":
				offset.x += float(motion.get("recoil_distance",5.0))*react
				rotation += 0.035*react*float(motion.get("reaction_strength",0.75))
			"dodge": offset += Vector2(15.0*react,-8.0*react if bool(_behavior.get("air_dodge",false)) else 0.0)
			"guard": pose_key = "windup"
		if action.is_empty(): offset.y += float(_behavior.get("rest_y",0.0))
		if bool(_behavior.get("shell_cycle",false)) and int(motion_state.get("enemy_turns",0)) % 2 == 0:
			effect = str(_behavior.effect)
			amount = 0.25
	if authored:
		var anatomy: Dictionary = motion.get("monster_pose",MonsterMoves.neutral_pose()).duplicate()
		if str(motion.get("defense_action","ready")) in ["hit","guard"]:
			var strength := react*float(motion.get("reaction_strength",0.75))
			anatomy.head_pitch -= 0.18*strength
			anatomy.head_thrust -= 0.24*strength
			anatomy.body_pitch -= 0.045*strength
			if bool(motion.get("guard_broken",false)):
				anatomy.crouch += 0.38*strength
				anatomy.wing_open += 0.20*strength
		motion.monster_pose = anatomy
	var clearance_weights := {pose_key:1.0}
	if name == "windup":
		clearance_weights["idle"] = 1.0-smoothstep(0.0,0.15,p)
		clearance_weights["attack"] = smoothstep(0.65,1.0,p)
	elif name == "strike": clearance_weights["windup"] = 1.0-smoothstep(0.0,0.20,p)
	elif name == "recovery":
		clearance_weights["attack"] = 1.0-smoothstep(0.34,0.60,p)
		clearance_weights["idle"] = smoothstep(0.12,0.34,p)
		if _species == "river_stone" and bool(enemy.get("boss",false)) and not interrupted and not action.is_empty() and not bool(motion_state.get("finished",false)):
			# Reserve the adjacent painted stance, while the visible/current
			# settle key itself always has full weight throughout its hold.
			clearance_weights["settle"] = smoothstep(0.20,0.34,p) if p < 0.34 else 1.0-smoothstep(0.78,0.92,p)
	motion.clearance_weights = clearance_weights
	motion.merge({"visual_offset":offset,"visual_rotation":rotation,"visual_scale":Vector2.ONE,"pose_key":pose_key,
		"effect_kind":effect,"effect_progress":amount,"effect_radius":34.0 if bool(enemy.get("boss",false)) else 22.0},true)
	return motion
