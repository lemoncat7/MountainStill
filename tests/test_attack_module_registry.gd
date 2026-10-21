extends SceneTree
## Isolated contract/registration tests, including a genuinely new module ID.
const Registry = preload("res://scripts/attack_module_registry.gd")
const Base = preload("res://scripts/combat_modules/attack_module.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
var checks := 0
var failures := 0

class CustomBlade extends "res://scripts/combat_modules/weapon_sword.gd":
	func _build_definition(_loadout: Dictionary) -> Dictionary:
		return {"id":"test.custom_blade", "kind":"weapon", "action_kind":"weapon", "style":"sword",
			"moves":{"test_a":{"label":"A", "windup":0.31,"strike":0.19,"hold":0.10,"recovery":0.39,"gap":0.0,"hits":[0.8],"lunge":9.0},
			"test_b":{"label":"B", "windup":0.33,"strike":0.17,"hold":0.11,"recovery":0.37,"gap":0.0,"hits":[1.2],"lunge":11.0}},
			"sequence":["test_a","test_b"], "default_move":"test_a", "resources":{},
			"action_cues":{"trail_kind":"test_trail","sound_kind":"test_sound"},
			"strike_geometry":{"kind":"blade_segment","range":41.0}}
	func pose_track(_motion: Dictionary, g: float, e: float, stance: float) -> Dictionary:
		var result := standard_track(g,e,stance)
		result.upper = -0.72*e+0.25*g
		result.form = "test_custom_pose"
		return result

class CustomActive extends CustomBlade:
	func _build_definition(loadout: Dictionary) -> Dictionary:
		var result := super._build_definition(loadout)
		result.id = "test.custom_active"
		result.kind = "technique"
		result.action_kind = "spell"
		result.resources = {"qi_cost":7.5,"cooldown":4.25}
		return result

class InvalidModule extends "res://scripts/combat_modules/attack_module.gd":
	func _build_definition(_loadout: Dictionary) -> Dictionary:
		return {"id":"test.invalid", "kind":"weapon", "style":"sword", "moves":{"bad":{"windup":NAN,"strike":0.2,"hold":0.1,"recovery":0.3,"gap":0.0,"hits":[1.0]}},
			"sequence":["bad"],"default_move":"bad","resources":{},"action_cues":{},"strike_geometry":{}}

class InvalidPose extends CustomBlade:
	func _build_definition(loadout: Dictionary) -> Dictionary:
		var result := super._build_definition(loadout)
		result.id = "test.invalid_pose"
		return result
	func pose_track(_motion: Dictionary, _g: float, _e: float, _stance: float) -> Dictionary:
		return {"upper": INF}

func _initialize() -> void:
	_test_registration()
	_test_bindings()
	_test_builtin_contracts()
	_test_geometry()
	_test_basic_modifiers()
	_test_live_binding()
	_test_active_resource_defaults()
	_test_explicit_heart_override()
	_test_restart_pause_and_roundtrip()
	_test_legacy_bindings()
	if OS.get_cmdline_user_args().has("--enemy-fallback"):
		_test_enemy_fallback()
	print("Attack module registry: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error(label)

func _test_registration() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	check(registry.module_ids().size() == 17, "bootstrap registers three weapons, eight techniques, six enemies")
	registry.bootstrap()
	check(registry.module_ids().size() == 17, "bootstrap is idempotent")
	check(not registry.register_module("weapon.sword", preload("res://scripts/combat_modules/weapon_fan.gd")), "duplicate cannot replace existing factory")
	check(registry.bind("weapon.sword").definition().style == "sword", "duplicate leaves original behavior intact")
	check(not registry.register_module("res://untrusted.gd", CustomBlade), "script paths are never module IDs")
	check(not registry.register_module("test.not_a_module", preload("res://scripts/monster_move_library.gd")), "non-contract scripts rejected")
	check(not registry.register_module("test.invalid", InvalidModule), "non-finite action data rejected")
	check(not registry.register_module("test.invalid_pose", InvalidPose), "incomplete pose tracks rejected")
	check(registry.register_module("test.custom_blade", CustomBlade), "new trusted module registers without core modification")
	var custom = registry.bind("test.custom_blade")
	var selected: Dictionary = custom.select_action()
	check(selected.move == "test_a" and selected.module_id == "test.custom_blade", "registered extension provides its move")
	check(selected.trail_kind == "test_trail" and selected.sound_kind == "test_sound", "registered extension provides VFX/audio cues")
	check(float(selected.strike_geometry.range) == 41.0, "registered extension provides geometry descriptor")
	check(registry.sample_pose_track("test.custom_blade", {}, 0.0, 1.0, 1.0).form == "test_custom_pose", "registered extension provides pure pose track")
	check(registry.module_id_for_motion({"module_id":"test.custom_blade"}) == "test.custom_blade", "explicit module ID bypasses legacy inference")

func _test_bindings() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	var a = registry.bind("weapon.sword")
	var b = registry.bind("weapon.sword")
	check(a != b, "every combat slot receives a fresh instance")
	a.select_action()
	a.select_action()
	check(b.select_action().move == "basic_sword_cut", "selection state does not leak between duels")
	check(a.select_action().move == "basic_sword_lift", "selection state persists inside one binding")
	var definition: Dictionary = a.definition()
	definition.moves.basic_sword_cut.hits[0] = 90.0
	definition.sequence.clear()
	check(a.definition().sequence.size() == 3 and float(b.definition().moves.basic_sword_cut.hits[0]) == 0.96, "returned definitions cannot mutate module or sibling")
	var action: Dictionary = a.select_action({"move":"basic_sword_cut"})
	action.hits[0] = 50.0
	check(float(a.select_action({"move":"basic_sword_cut"}).hits[0]) == 0.96, "returned actions cannot mutate authored data")
	check(a.select_action({"move":"unknown", "use_count":1}).move == "basic_sword_thrust", "unknown move safely uses current sequence")
	check(a.select_action({"kind":"weapon"}).move == "weapon_sword_pierce", "same weapon module supplies innate art")
	var unknown = registry.bind("missing.user.module", {"module_id":"weapon.fan"})
	check(unknown.definition().id == "weapon.unarmed", "unknown module uses validated unarmed fallback; context cannot spoof ID")
	check(not registry.diagnostics.is_empty(), "fallback is observable in bounded diagnostics")
	check(registry.bind_weapon("starter_sword").definition().id == "weapon.sword", "legacy loadout adapter resolves sword once")
	check(registry.bind_technique({"id":"petal"}).definition().id == "technique.petal", "legacy manual adapter resolves once")
	check(registry.bind_technique({"id":"mist","attack_module_id":"technique.ember"}).definition().id == "technique.ember", "explicit config module ID takes precedence")
	var count: int = b.selection_count
	for index in range(10): registry.sample_pose_track("weapon.sword", {}, .3, .7, 1.0)
	check(b.selection_count == count, "preview sampling cannot advance a live binding")

func _test_builtin_contracts() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	for id in registry.module_ids():
		var module = registry.bind(id)
		var definition: Dictionary = module.definition()
		check(definition.id == id, "definition identity " + id)
		check(Registry._definition_error(id, definition).is_empty(), "finite definition " + id)
		for move in definition.moves:
			for index in range(21):
				var phase := float(index)/20.0
				var motion := {"combat_move":move,"attack_style":definition.style,"combat_phase":"strike","phase_progress":phase,"strike_index":1,"attack_phase":phase}
				check(Registry._valid_pose(module.pose_track(motion, 1.0-phase, phase, 1.0)), "finite complete pose " + id + "/" + move)
	var petal = registry.bind("technique.petal")
	check(petal.select_action({"counter":true}).move == "petal_counter", "petal counter choreography stays module-owned")
	check(petal.select_action({"counter":false}).move == "petal_step", "petal ordinary selection does not rotate into counter")
	check(registry.bind("technique.barrier").definition().action_kind == "defense", "support action category is explicit data")
	check(registry.bind("technique.mending").definition().action_kind == "utility", "utility action category is explicit data")

func _test_geometry() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	for style in ["sword", "fan", "unarmed"]:
		var module = registry.bind("weapon." + style)
		for move in module.definition().sequence:
			for index in range(21):
				var motion := {"action_kind":"basic","combat_move":move,"basic_style":style,"attack_style":style,"combat_phase":"strike","phase_progress":float(index)/20.0,"combat_stance":1.0,"attack_amount":1.0,"clock":0.0,"facing":1.0}
				var pose := Rig.sample_pose(motion)
				var grip := Rig.weapon_pose(motion, 1.0, 0.0, style)
				var points: PackedVector2Array = module.geometry_points(motion, pose, grip)
				var old := _legacy_geometry(style, pose, grip)
				check(points.size() == old.size(), "geometry cardinality " + str(move))
				for point in range(old.size()):
					check(points[point].distance_to(old[point]) < 0.00002, "preserved painted geometry " + str(move))

func _legacy_geometry(style: String, pose: Dictionary, grip: Dictionary) -> PackedVector2Array:
	var result := PackedVector2Array()
	if style == "sword":
		for index in range(11): result.append(Vector2(grip.offset)+Vector2(0.0,lerpf(-12.0,-49.76,float(index)/10.0)).rotated(float(grip.rotation)+0.22))
	elif style == "fan":
		for source in [Vector2(16,218),Vector2(63,144),Vector2(124,91),Vector2(220,28),Vector2(310,17),Vector2(421,53),Vector2(511,111),Vector2(625,240)]:
			var local: Vector2 = Vector2(-23.3,-25.6)+source/Vector2(640,560)*Vector2(48,40)
			local.x *= float(grip.fan_open)
			result.append(Vector2(grip.offset)+local.rotated(float(grip.rotation)))
	else:
		var arm: Dictionary = pose.far_arm if str(pose.combat.attack_hand) == "far" else pose.near_arm
		var tip := (Vector2(arm.wrist)+Vector2(0,16 if str(arm.hand_form) == "palm" else 10).rotated(float(arm.hand_angle)))*Rig.PIXEL_SCALE
		result = PackedVector2Array([tip,tip+Vector2(1.7,0),tip+Vector2(0,-1.7),tip+Vector2(0,1.7)])
	return result

func _test_basic_modifiers() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	var action: Dictionary = registry.bind("weapon.sword").select_action()
	var modified: Dictionary = registry.bind("technique.mist").modify_basic(action)
	check(is_equal_approx(float(modified.strike), float(action.strike)*0.94), "mist timing modifier is module-owned")
	check(not action.has("basic_form") and modified.basic_form == "mist", "modifier does not mutate source action")
	modified = registry.bind("technique.petal").modify_basic(action)
	check(is_equal_approx(float(modified.recovery), float(action.recovery)*0.92), "petal recovery modifier is module-owned")

func _test_live_binding() -> void:
	var registry := Registry.new()
	registry.bootstrap()
	check(registry.register_module("test.custom_blade", CustomBlade), "isolated live registry accepts extension")
	var duel = preload("res://scripts/duel_timeline.gd").new()
	duel.module_registry = registry
	duel.start({"attack":12,"defense":9,"max_hp":1000,"hp":1000,"active_skills":[],"attack_module_id":"test.custom_blade"},
		{"id":"module_dummy","route_id":"bamboo_pass","hp":1000,"attack":1,"defense":1}, "mist", "sword", 891)
	var events: Array = duel.advance(0.0)
	var started: Dictionary = events[0]
	check(started.move == "test_a" and started.module_id == "test.custom_blade", "equipped module ID drives real timeline action")
	check(started.trail_kind == "test_trail" and started.sound_kind == "test_sound", "real timeline preserves module cues")
	var motion: Dictionary = duel.pose().hero
	check(motion.get("pose_provider") is RefCounted and motion.get("strike_provider") is RefCounted, "live motion binds direct pose and geometry providers")
	check(motion.pose_provider == motion.strike_provider, "basic attack uses one bound module for pose and geometry")
	check(Rig.sample_pose(motion).combat.basic_form == "test_custom_pose", "rig consumes custom direct provider")
	check(not _contains_object(events), "turn events contain no provider objects")
	check(not _contains_object(duel.battle_resource_snapshot()), "persistable resource snapshot contains IDs, not providers")
	for index in range(12):
		events = duel.advance(0.25)
		check(not _contains_object(events), "all contact/resource events remain object-free")
	check(duel.battle_resource_snapshot().attack_modules.basic == "test.custom_blade", "resource snapshot describes bound module identity")

func _contains_object(value: Variant) -> bool:
	if value is Object:
		return true
	if value is Array:
		for item in value:
			if _contains_object(item): return true
	if value is Dictionary:
		for key in value:
			if _contains_object(value[key]): return true
	return false

func _extension_registry():
	var registry := Registry.new()
	registry.bootstrap()
	registry.register_module("test.custom_blade", CustomBlade)
	registry.register_module("test.custom_active", CustomActive)
	return registry

func _extension_hero() -> Dictionary:
	return {"hp":1000,"max_hp":1000,"attack":12,"defense":9,"poise_bonus":10.0,
		"combat_qi_max":40.0,"combat_qi_regen":0.0,"heart_method":{},"weapon_art":{},"weapon_skill":{},
		"attack_module_id":"test.custom_blade", "active_skills":[{"id":"custom_active","attack_module_id":"test.custom_active","active":true}]}

func _extension_enemy() -> Dictionary:
	return {"id":"extension_dummy","route_id":"creek_bridge","hp":1000,"max_hp":1000,"attack":1,"defense":1,"dodge_chance":0.0,"guard_chance":0.0}

func _extension_duel(registry, hero: Dictionary = {}):
	var duel = preload("res://scripts/duel_timeline.gd").new()
	duel.module_registry = registry
	duel.start(_extension_hero() if hero.is_empty() else hero, _extension_enemy(), "mist", "sword", 910)
	return duel

func _test_active_resource_defaults() -> void:
	var registry = _extension_registry()
	check(not Registry.default_registry().has_module("test.custom_active"), "custom active exists only in injected registry")
	var hero := _extension_hero()
	check(not hero.active_skills[0].has("qi_cost") and not hero.active_skills[0].has("cooldown"), "loadout deliberately omits custom resource defaults")
	var duel = _extension_duel(registry, hero)
	var resources: Dictionary = duel.battle_resource_snapshot()
	check(resources.active_skills.size() == 1 and resources.active_skills[0].available, "injected registry admits new active ability ID")
	check(is_equal_approx(float(resources.active_skills[0].qi_cost), 7.5), "new active module supplies default qi cost")
	check(is_equal_approx(float(resources.active_skills[0].cooldown), 4.25), "new active module supplies default cooldown")
	var paid: Array = []
	for event in duel.advance(3.0):
		if event.type == "turn_started" and event.actor == "hero" and event.skill_id == "custom_active":
			paid.append(event)
	check(paid.size() == 1, "new active ability actually commits in unchanged scheduler")
	if not paid.is_empty():
		check(paid[0].module_id == "test.custom_active" and paid[0].action_kind == "spell", "committed active uses registered module and category")
		check(is_equal_approx(float(paid[0].qi_cost), 7.5) and is_equal_approx(float(paid[0].spell_cd), 4.25), "committed action carries module resource defaults")
		resources = duel.battle_resource_snapshot()
		check(is_equal_approx(float(resources.qi), 32.5), "core spends custom module cost exactly once")
		check(is_equal_approx(float(resources.cooldowns.custom_active), float(paid[0].time)+4.25-float(duel.elapsed)), "core enforces custom cooldown deadline")
		check(not _contains_object(paid), "new active events remain serializable data")

func _test_explicit_heart_override() -> void:
	var registry = _extension_registry()
	var hero := _extension_hero()
	hero.erase("attack_module_id")
	hero.active_skills = []
	hero.heart_method = {"id":"test_heart","active":true,"required_weapon":"sword","attack_module_id":"test.custom_blade"}
	var passive = _extension_duel(registry, hero)
	check(passive.battle_resource_snapshot().attack_modules.basic == "weapon.sword", "ordinary heart.attack_module_id does not replace weapon basics")
	check(passive.pose().hero.combat_move == "basic_sword_cut", "ordinary heart remains passive in real action selection")
	hero.heart_method.basic_attack_module_id = "test.custom_blade"
	var explicit = _extension_duel(registry, hero)
	check(explicit.battle_resource_snapshot().attack_modules.basic == "test.custom_blade", "explicit compatible heart override binds its base module")
	check(explicit.pose().hero.combat_move == "test_a", "explicit heart override drives actual free basic")
	check(explicit.pose().hero.action_kind == "basic" and float(explicit.pose().hero.qi_cost) == 0.0, "heart override remains a free basic action")
	hero.heart_method.required_weapon = "fan"
	var incompatible = _extension_duel(registry, hero)
	check(incompatible.battle_resource_snapshot().attack_modules.basic == "weapon.sword", "incompatible heart override cannot replace base")
	hero.heart_method.required_weapon = "sword"
	hero.heart_method.active = false
	var inactive = _extension_duel(registry, hero)
	check(inactive.battle_resource_snapshot().attack_modules.basic == "weapon.sword", "inactive heart override cannot replace base")

func _test_restart_pause_and_roundtrip() -> void:
	var registry = _extension_registry()
	var hero := _extension_hero()
	var original = _extension_duel(registry, hero)
	original.advance(3.0)
	var saved: Dictionary = original.battle_resource_snapshot()
	var before_clock: float = original.elapsed
	for index in range(5):
		original.pose()
		original.advance(0.0)
		original.advance(-1.0)
	check(original.battle_resource_snapshot() == saved and float(original.elapsed) == before_clock, "pause/read-only samples do not spend qi or reduce cooldown")
	var encoded := JSON.stringify(saved)
	var decoded: Dictionary = JSON.parse_string(encoded)
	check(not _contains_object(decoded), "snapshot JSON roundtrip is provider-free")
	var restored_hero := hero.duplicate(true)
	restored_hero.battle_resources = decoded
	var restored = _extension_duel(registry, restored_hero)
	var restored_snapshot: Dictionary = restored.battle_resource_snapshot()
	check(restored_snapshot.attack_modules == saved.attack_modules, "selected module identities survive snapshot roundtrip")
	check(is_equal_approx(float(restored_snapshot.qi),float(saved.qi)), "roundtrip restores committed custom qi")
	check(is_equal_approx(float(restored_snapshot.cooldowns.custom_active),float(saved.cooldowns.custom_active)), "roundtrip restores custom keyed cooldown")
	check(restored.pose().hero.combat_move == "test_a", "new encounter starts fresh selection while retaining battle resources")
	check(restored.pose().hero.pose_provider != original.pose().hero.pose_provider, "restored encounter receives fresh provider instances")
	var untouched = _extension_duel(registry, hero)
	check(float(untouched.battle_resource_snapshot().qi) == 40.0 and float(untouched.battle_resource_snapshot().cooldowns.custom_active) == 0.0, "sibling encounter shares neither qi nor cooldown")
	check(untouched.pose().hero.combat_move == "test_a", "sibling selection begins at first move")
	var sibling_before: Dictionary = untouched.battle_resource_snapshot()
	restored.advance(0.5)
	check(untouched.battle_resource_snapshot() == sibling_before, "advancing restored duel cannot mutate sibling resources")
	var old_provider = original.pose().hero.pose_provider
	original.start(hero, _extension_enemy(), "mist", "sword", 910)
	check(original.pose().hero.pose_provider != old_provider, "restart rebinds fresh provider")
	check(original.pose().hero.combat_move == "test_a" and float(original.elapsed) == 0.0, "restart resets timeline and module selection")
	check(float(original.battle_resource_snapshot().qi) == 40.0 and float(original.battle_resource_snapshot().cooldowns.custom_active) == 0.0, "restart without saved resources resets custom cooldown")
	check(original.battle_resource_snapshot().attack_modules == saved.attack_modules, "restart keeps stable selected module IDs")

func _test_legacy_bindings() -> void:
	for style in ["sword","fan","unarmed"]:
		var hero := _extension_hero()
		hero.erase("attack_module_id")
		hero.active_skills = []
		var duel = preload("res://scripts/duel_timeline.gd").new()
		duel.start(hero,_extension_enemy(),"mist",style,910)
		check(duel.battle_resource_snapshot().attack_modules.basic == "weapon." + style, "legacy weapon resolves same builtin " + style)
		check(str(duel.pose().hero.combat_move).begins_with("basic_"+style+"_"), "legacy weapon selects original move family " + style)
		check(duel.battle_resource_snapshot().attack_modules.enemy == "enemy.river_stone", "legacy route resolves same enemy builtin")
	var legacy = preload("res://scripts/duel_timeline.gd").new()
	legacy.start({"hp":1000,"max_hp":1000,"attack":12,"defense":9},_extension_enemy(),"mist","sword",910)
	check(legacy.battle_resource_snapshot().attack_modules.active.mist == "technique.mist", "legacy selected manual resolves builtin without explicit module ID")

func _test_enemy_fallback() -> void:
	# Enable after the category-aware enemy fallback is installed. A missing or
	# wrong-category enemy module must never be bound as a weapon provider.
	for malformed in ["enemy.does_not_exist", "weapon.sword"]:
		var enemy := _extension_enemy()
		enemy.attack_module_id = malformed
		var duel = preload("res://scripts/duel_timeline.gd").new()
		duel.start({"hp":1000,"max_hp":1000,"attack":1,"defense":9,"active_skills":[]}, enemy, "mist", "sword", 910)
		check(str(duel.battle_resource_snapshot().attack_modules.enemy).begins_with("enemy."), "malformed enemy module binds a valid enemy fallback " + malformed)
		var enemy_starts := 0
		for event in duel.advance(1.0):
			if event.type == "turn_started" and event.actor == "enemy":
				enemy_starts += 1
		check(enemy_starts > 0, "enemy fallback still executes valid enemy actions " + malformed)
