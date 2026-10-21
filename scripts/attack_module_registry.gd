extends RefCounted
## Trusted factory registry; resolve IDs at loadout start, never evaluate a
## saved script path. Register preloaded project Scripts only. A live binding
## is a fresh RefCounted with isolated selection state. Cached providers below
## are exclusively for pure pose sampling, never live action selection.
const AttackModule = preload("res://scripts/combat_modules/attack_module.gd")
const BUILTINS := {
	"weapon.unarmed": preload("res://scripts/combat_modules/weapon_unarmed.gd"),
	"weapon.sword": preload("res://scripts/combat_modules/weapon_sword.gd"),
	"weapon.fan": preload("res://scripts/combat_modules/weapon_fan.gd"),
	"technique.mist": preload("res://scripts/combat_modules/technique_mist.gd"),
	"technique.petal": preload("res://scripts/combat_modules/technique_petal.gd"),
	"technique.ember": preload("res://scripts/combat_modules/technique_ember.gd"),
	"technique.stillness": preload("res://scripts/combat_modules/technique_stillness.gd"),
	"technique.frost": preload("res://scripts/combat_modules/technique_frost.gd"),
	"technique.thunder": preload("res://scripts/combat_modules/technique_thunder.gd"),
	"technique.barrier": preload("res://scripts/combat_modules/technique_barrier.gd"),
	"technique.mending": preload("res://scripts/combat_modules/technique_mending.gd"),
}
const EnemyModules = preload("res://scripts/combat_modules/enemy_attack_module.gd")
const FALLBACK_ID := "weapon.unarmed"
const POSE_FIELDS := ["upper", "lower", "hand", "tilt", "shift_x", "shift_y", "far_upper", "far_lower", "far_hand", "fan_open", "lead_stance", "rear_stance"]
static var _shared: RefCounted
var _factories: Dictionary = {}
var _definitions: Dictionary = {}
var _move_owners: Dictionary = {}
var _pose_providers: Dictionary = {}
var _bootstrapped := false
var diagnostics: Array[String] = []

static func default_registry() -> RefCounted:
	if _shared == null:
		# This is a fixed project-owned path, never a path supplied by save data.
		_shared = load("res://scripts/attack_module_registry.gd").new()
		_shared.bootstrap()
	return _shared

func bootstrap() -> void:
	if _bootstrapped:
		return
	_bootstrapped = true
	for id in BUILTINS:
		register_module(str(id), BUILTINS[id])
	EnemyModules.register_modules(self)

func register_module(id: String, factory: Script) -> bool:
	if not _valid_id(id):
		return _reject("Invalid attack module ID: " + id)
	if _factories.has(id):
		return _reject("Duplicate attack module ID: " + id)
	if factory == null or not factory.can_instantiate() or not _extends_contract(factory):
		return _reject("Attack module must extend the RefCounted contract: " + id)
	var probe = factory.new()
	probe.configure({"module_id": id})
	var descriptor: Dictionary = probe.definition()
	var error := _definition_error(id, descriptor)
	if not error.is_empty():
		return _reject(error)
	var pose: Dictionary = probe.pose_track({}, 0.0, 0.0, 0.0)
	if not _valid_pose(pose):
		return _reject("Incomplete or non-finite pose contract: " + id)
	_factories[id] = factory
	_definitions[id] = descriptor.duplicate(true)
	# A shared move name never silently changes an existing legacy mapping.
	for move in descriptor.get("moves", {}):
		if not _move_owners.has(move):
			_move_owners[move] = id
	return true

func has_module(id: String) -> bool:
	return _factories.has(id)

func module_ids() -> Array:
	return _factories.keys().duplicate()

func module_definition(id: String) -> Dictionary:
	return _definitions.get(id, {}).duplicate(true)

func bind(id: String, context: Dictionary = {}) -> RefCounted:
	bootstrap()
	var resolved := id
	if not has_module(resolved):
		_reject("Unknown attack module ID '%s'; using %s" % [id, FALLBACK_ID])
		resolved = FALLBACK_ID
	var instance = _factories[resolved].new()
	var loadout := context.duplicate(true)
	loadout.module_id = resolved
	loadout.requested_module_id = id
	instance.configure(loadout)
	# Context-driven definitions must obey the same contract as registration.
	var error := _definition_error(resolved, instance.definition())
	if not error.is_empty():
		_reject(error + "; using " + FALLBACK_ID)
		instance = BUILTINS[FALLBACK_ID].new()
		instance.configure({"module_id": FALLBACK_ID, "requested_module_id": id})
	return instance

func bind_weapon(weapon: String, config: Dictionary = {}) -> RefCounted:
	return bind(weapon_module_id(weapon, config), config)

func bind_technique(skill: Dictionary) -> RefCounted:
	return bind(technique_module_id(skill), skill)

func weapon_module_id(weapon: String, config: Dictionary = {}) -> String:
	var explicit := str(config.get("attack_module_id", config.get("module_id", "")))
	if not explicit.is_empty():
		return explicit
	var key := weapon.to_lower()
	# Legacy save normalization runs at equip/start, outside action/pose loops.
	if "sword" in key:
		return "weapon.sword"
	if "fan" in key:
		return "weapon.fan"
	return FALLBACK_ID

func technique_module_id(skill: Dictionary) -> String:
	var explicit := str(skill.get("attack_module_id", skill.get("module_id", "")))
	if not explicit.is_empty():
		return explicit
	var id := str(skill.get("id", ""))
	return str({"weapon_sword_pierce": "weapon.sword", "weapon_fan_return": "weapon.fan"}.get(id, "technique." + id))

func module_id_for_motion(motion: Dictionary) -> String:
	var explicit := str(motion.get("module_id", motion.get("attack_module_id", "")))
	if not explicit.is_empty():
		return explicit
	bootstrap()
	# Compatibility for old practice/preview callers only. Live motion carries
	# the module ID chosen when its action was committed.
	var move := str(motion.get("combat_move", ""))
	if str(motion.get("action_kind", "")) == "basic" or move.begins_with("basic_"):
		return weapon_module_id(str(motion.get("basic_style", motion.get("attack_style", "unarmed"))))
	return str(_move_owners.get(move, weapon_module_id(str(motion.get("attack_style", "unarmed")))))

func pose_provider(id: String) -> RefCounted:
	bootstrap()
	var resolved := id if has_module(id) else FALLBACK_ID
	if not _pose_providers.has(resolved): _pose_providers[resolved] = bind(resolved)
	return _pose_providers[resolved]

func sample_pose_track(id: String, motion: Dictionary, gather: float, extend: float, stance: float) -> Dictionary:
	bootstrap()
	var resolved := id if has_module(id) else FALLBACK_ID
	if not _pose_providers.has(resolved):
		_pose_providers[resolved] = bind(resolved)
	var g := clampf(gather if is_finite(gather) else 0.0, 0.0, 1.0)
	var e := clampf(extend if is_finite(extend) else 0.0, 0.0, 1.0)
	var s := clampf(stance if is_finite(stance) else 0.0, 0.0, 1.0)
	var result: Dictionary = _pose_providers[resolved].pose_track(motion, g, e, s)
	if not _valid_pose(result):
		return AttackModule.standard_track(g, e, s)
	return result

static func _valid_id(id: String) -> bool:
	if id.is_empty() or id.length() > 96:
		return false
	for character in id:
		if not (character >= "a" and character <= "z") and not (character >= "0" and character <= "9") and character not in [".", "_", "-"]:
			return false
	return true

static func _extends_contract(factory: Script) -> bool:
	var current: Script = factory
	while current != null:
		if current == AttackModule:
			return true
		current = current.get_base_script()
	return false

static func _definition_error(id: String, descriptor: Dictionary) -> String:
	if str(descriptor.get("id", "")) != id:
		return "Attack module definition ID differs from registration: " + id
	if str(descriptor.get("kind", "")) not in ["weapon", "technique", "enemy"]:
		return "Invalid attack module kind: " + id
	for key in ["moves", "resources", "action_cues", "strike_geometry"]:
		if not descriptor.get(key) is Dictionary:
			return "Missing dictionary %s in attack module %s" % [key, id]
	if not descriptor.get("sequence") is Array:
		return "Missing action sequence in attack module " + id
	if not _finite_data(descriptor):
		return "Non-finite or non-data value in attack module " + id
	var moves: Dictionary = descriptor.moves
	for move in moves:
		if not moves[move] is Dictionary:
			return "Invalid move dictionary in attack module " + id
		var action: Dictionary = moves[move]
		for phase in ["windup", "strike", "hold", "recovery", "gap"]:
			if not action.get(phase) is float and not action.get(phase) is int:
				return "Missing numeric phase %s in %s" % [phase, id]
			if float(action[phase]) < 0.0 or float(action[phase]) > 60.0:
				return "Out-of-range phase %s in %s" % [phase, id]
		if float(action.windup) + float(action.strike) + float(action.hold) + float(action.recovery) <= 0.0:
			return "Zero-length action in attack module " + id
		if not action.get("hits") is Array or action.hits.is_empty() or action.hits.size() > 32:
			return "Invalid contacts in attack module " + id
		for hit in action.hits:
			if not hit is float and not hit is int:
				return "Non-numeric contact in attack module " + id
			if float(hit) < 0.0 or float(hit) > 100.0:
				return "Out-of-range contact in attack module " + id
	for move in descriptor.sequence:
		if not moves.has(str(move)):
			return "Unknown sequence move in attack module " + id
	if str(descriptor.kind) != "enemy" and descriptor.sequence.is_empty():
		return "Empty action sequence in attack module " + id
	return ""

static func _valid_pose(pose: Dictionary) -> bool:
	for key in POSE_FIELDS:
		if not pose.get(key) is float and not pose.get(key) is int:
			return false
		if not is_finite(float(pose[key])):
			return false
	return str(pose.get("attack_hand", "")) in ["near", "far"] and str(pose.get("hand_form", "")) in ["fist", "palm", "finger"] and pose.get("form") is String

static func _finite_data(value: Variant, depth: int = 0) -> bool:
	if depth > 12:
		return false
	if value is float:
		return is_finite(value)
	if value is int or value is bool or value is String or value is StringName or value == null:
		return true
	if value is Vector2:
		return value.is_finite()
	if value is Array:
		for item in value:
			if not _finite_data(item, depth + 1):
				return false
		return true
	if value is Dictionary:
		for key in value:
			if not (key is String or key is StringName or key is int) or not _finite_data(value[key], depth + 1):
				return false
		return true
	return false

func _reject(message: String) -> bool:
	if diagnostics.size() >= 64:
		diagnostics.pop_front()
	diagnostics.append(message)
	return false
