extends SceneTree
## Registered enemy behaviors stay pure, isolated, and authoritative only over
## authored inputs. Core combat owns resources, random rolls and hit outcomes.
const Registry = preload("res://scripts/attack_module_registry.gd")
const EnemyModule = preload("res://scripts/combat_modules/enemy_attack_module.gd")
const Moves = preload("res://scripts/monster_move_library.gd")
const Renderer = preload("res://scripts/monster_pose_renderer.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _initialize() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	for id in EnemyModule.MODULE_IDS:
		check(registry.has_module(id),"registered enemy behavior " + id)
		var normal = registry.bind(id,{"enemy":{"boss":false}})
		var boss = registry.bind(id,{"enemy":{"boss":true,"phase_threshold":0.5}})
		check(normal != boss,"fresh per-encounter module instance " + id)
		check(normal.definition().id == id and boss.definition().id == id,"binding retains registered identity " + id)
		var description: Dictionary = normal.definition()
		description.moves.charge.hits[0] = 9999.0
		check(normal.definition().moves.charge.hits[0] != 9999.0,"definition is a deep snapshot " + id)
		var species: String = str(id).trim_prefix("enemy.")
		var weighted: bool = species in ["moss_beast","cloud_crane"]
		check(normal.supports_body_contact() == weighted,"geometry capability is explicit " + id)
		check(not normal.is_awakened(0.1),"ordinary encounter does not awaken " + id)
		check(boss.is_awakened(0.5) == (species in ["ember_guardian","moon_wisp","summit_keeper"]),"only authored bosses awaken at boundary " + id)
		check(not boss.is_awakened(0.5001),"awakening threshold remains exact " + id)
		for is_boss in [false,true]:
			var module = boss if is_boss else normal
			for turn in range(9):
				var choice := {"distance":40.0,"stamina":80.0,"history":["charge"],"hero_phase":"recovery","hp_fraction":0.4,"chase":true}
				var state := {"enemy":{"boss":is_boss,"boss_move":"burst"},"choice_state":choice,"candidate_roll":0.36,"action_index":turn,"charge_reach":61.0,"awakened":false}
				var before := state.duplicate(true)
				var action: Dictionary = module.select_action(state)
				check(action == module.select_action(state),"selection is pure under repeated preview " + id)
				check(state == before and module.selection_count == 0,"selection consumes no caller data or module counter " + id)
				check(action.module_id == id and action.weighted_choice == weighted,"action carries binding identity/capability " + id)
				check(action.strike_geometry.mode == ("enemy_body" if weighted else "legacy_contact"),"geometry descriptor stays with action " + id)
				if weighted:
					check(action.stamina_cost == Moves.cost(species,action.kind),"module returns authored stamina cost only " + id)
					if turn > 0: check(action.kind != "charge","provided history suppresses immediate repeat " + id)
				else:
					var sequence: Array = ["burst","charge","sweep"] if is_boss else EnemyModule.PROFILES[species].sequence
					check(action.kind == sequence[turn%sequence.size()],"legacy chapter order remains exact " + id)
					check(action.stamina_cost == 0.0 and action.choice_weights.is_empty(),"legacy behavior retains no stamina spending " + id)
				var awake := state.duplicate(true)
				awake.awakened = true
				var shortened: Dictionary = module.select_action(awake)
				check(shortened.hits == action.hits and shortened.lunge == action.lunge,"awakened tell does not add damage or reach " + id)
				check(is_equal_approx(shortened.windup,maxf(0.64,action.windup-0.09)) and is_equal_approx(shortened.recovery,action.recovery+0.16),"awakened timing trade remains exact " + id)
				var phase := {"name":"contact","index":0,"progress":0.5}
				action.start = 0.0
				var motion_state := {"motion":{"actor_lunge":13.0,"defense_action":"ready","reaction_amount":0.0},"hero_lunge":0.0,"finished":false,"enemy_turns":turn,"enemy":state.enemy}
				var pose_before := motion_state.duplicate(true)
				var visual: Dictionary = module.sample_enemy_motion(action,phase,1.0,motion_state)
				check(visual == module.sample_enemy_motion(action,phase,1.0,motion_state) and pose_before == motion_state,"pose preview is pure " + id)
				check(visual.visual_scale == Vector2.ONE and visual.visual_offset.is_finite(),"fixed creature anatomy and finite root " + id)
	_test_contact_rules(registry)
	_test_visual_joins(registry)
	print("Registered enemy attack modules: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)

func _test_contact_rules(registry) -> void:
	var river = registry.bind("enemy.river_stone")
	check(river.defense_modifier(0) == {"multiplier":0.90,"mechanic":"river_shell"},"river closed shell multiplier")
	check(river.defense_modifier(1) == {"multiplier":1.12,"mechanic":"river_exposed"},"river exposed multiplier")
	var crane = registry.bind("enemy.cloud_crane")
	check(crane.defense_modifier(0).multiplier == 1.0 and crane.defense_modifier(1).multiplier == 1.08,"crane landing window")
	var ember = registry.bind("enemy.ember_guardian")
	var burst := {"kind":"burst","hits":[0.4,0.46,0.8]}
	check(ember.contact_metadata(burst,1).armor_factor == 1.0 and ember.contact_metadata(burst,2).armor_factor == 0.75,"only final ember burst contact ignores armor")
	var summit = registry.bind("enemy.summit_keeper")
	check(summit.contact_metadata({"kind":"sweep","hits":[1.02]},0).guard_min == 0.65,"summit guard break minimum is a descriptor")
	var moss = registry.bind("enemy.moss_beast")
	var slam := {"kind":"burst","move_family":"moss_slam","hits":[1.12,0.3,0.38]}
	check(moss.contact_metadata(slam,0).contact_role == "strike" and not moss.contact_metadata(slam,0).has("impact_weight"),"ground slam begins with a real heavy strike")
	for index in [1,2]:
		var metadata: Dictionary = moss.contact_metadata(slam,index)
		check(metadata.contact_role == "aftershock" and metadata.impact_weight == 0.62,"ground echo stays a light aftershock")
	for family in EnemyModule.BODY_GEOMETRY:
		check(EnemyModule.BODY_GEOMETRY[family].area == (family == "moss_slam"),"only planted slam is area geometry " + family)
	check(EnemyModule.MOVEMENT.moss_rush.travel_begin_fraction == 0.92 and EnemyModule.MOVEMENT.moss_rush.release == "two_step","rush preserves committed planted backsteps")

func _test_visual_joins(registry) -> void:
	var crane = registry.bind("enemy.cloud_crane",{"enemy":{"boss":true}})
	var peck: Dictionary = crane.select_action({"enemy":{"boss":true,"boss_move":"burst"},"action_index":0,"charge_reach":66.0})
	peck.start = 0.0
	var state := {"motion":{"actor_lunge":0.0,"defense_action":"ready","reaction_amount":0.0},"hero_lunge":0.0,"enemy":{"boss":true}}
	var wind: Dictionary = crane.sample_enemy_motion(peck,{"name":"windup","index":0,"progress":1.0},peck.windup,state)
	var strike: Dictionary = crane.sample_enemy_motion(peck,{"name":"strike","index":0,"progress":0.0},peck.windup,state)
	check(wind.visual_offset == strike.visual_offset and wind.visual_rotation == strike.visual_rotation,"peck anticipation joins the committed strike continuously")
	check(is_equal_approx(wind.visual_rotation,0.028) and is_equal_approx(wind.visual_offset.y,-2.0),"peck has a small rigid grounded anticipation cue")
	for index in [0,1,2]:
		var end: Dictionary = crane.sample_enemy_motion(peck,{"name":"strike","index":index,"progress":1.0},1.0,state)
		var contact: Dictionary = crane.sample_enemy_motion(peck,{"name":"contact","index":index,"progress":0.0},1.0,state)
		check(end.visual_offset.distance_to(contact.visual_offset)<0.00001 and absf(end.visual_rotation-contact.visual_rotation)<0.00001,"peck rigid anticipation vanishes continuously at each contact")
		check(contact.visual_rotation == 0.0 and contact.visual_offset == Vector2(0.0,-4.0),"peck retains exact authored contact root and angle")
	for p in [0.0,0.12,0.3,0.5,0.8,1.0]:
		var visual: Dictionary = crane.sample_enemy_motion(peck,{"name":"windup","index":0,"progress":p},p*peck.windup,state)
		check(visual.visual_scale == Vector2.ONE and absf(visual.visual_rotation)<=0.028001,"anticipation never scales or warps the painted creature")
	var dive: Dictionary = crane.select_action({"enemy":{"boss":true,"boss_move":"charge"},"action_index":0,"charge_reach":66.0})
	dive.start = 0.0
	var contact: Dictionary = crane.sample_enemy_motion(dive,{"name":"contact","index":0,"progress":1.0},1.0,state)
	var recover: Dictionary = crane.sample_enemy_motion(dive,{"name":"recovery","index":0,"progress":0.0},1.0,state)
	check(contact.visual_offset == recover.visual_offset and contact.visual_rotation == recover.visual_rotation,"dive contact joins recovery root without a pop")
	check(Renderer.source_pose("cloud_slope_boss",contact)=="authored_dive" and Renderer.source_pose("cloud_slope_boss",recover)=="authored_dive","dive silhouette spans contact-to-recovery boundary")
	recover.phase_progress = 0.159
	check(Renderer.source_pose("cloud_slope_boss",recover)=="authored_dive","dive landing retains a short planted recovery beat")
	recover.phase_progress = 0.16
	check(Renderer.source_pose("cloud_slope_boss",recover)=="authored_lift","dive rebound still follows its brief landing beat")
