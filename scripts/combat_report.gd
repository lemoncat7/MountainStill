extends RefCounted
## Read-only observer of committed turns and resolved contacts, never rewards/RNG.
var _values: Dictionary = {}
var _actions: Dictionary = {}
var _contacts: Dictionary = {}

func begin(tactic: String) -> void:
	_actions.clear(); _contacts.clear()
	_values = {"tactic": tactic, "damage_dealt": 0, "damage_taken": 0, "healing": 0,
		"shield_added": 0, "shield_absorbed": 0, "dodges": 0, "guards": 0, "breaks": 0,
		"hits": 0, "misses": 0, "enemy_dodges": 0, "enemy_guards": 0,
		"incoming_hits": 0, "incoming_misses": 0, "qi_spent": 0.0, "skill_casts": {}}

func observe(event: Dictionary) -> void:
	if _values.is_empty(): return
	var actor := str(event.get("actor", ""))
	if str(event.get("type", "")) == "turn_started":
		if actor != "hero": return
		var id := str(event.get("action_id", event.get("turn_index", -1)))
		if id == "-1" or _actions.has(id): return
		_actions[id] = true
		_values.qi_spent += maxf(0.0, float(event.get("qi_cost", 0.0)))
		var skill := str(event.get("skill_id", ""))
		if not skill.is_empty():
			var label := str(event.get("telegraph", skill))
			_values.skill_casts[label] = int(_values.skill_casts.get(label, 0)) + 1
		return
	if str(event.get("type", "")) != "contact": return
	var id := str(event.get("contact_id", ""))
	if id.is_empty() or _contacts.has(id): return
	_contacts[id] = true
	var target := str(event.get("target", ""))
	var resolution := str(event.get("resolution", ""))
	if actor == "hero" and target == "hero":
		_values.healing += maxi(0, int(event.get("heal", 0)))
		_values.shield_added += maxi(0, int(event.get("shield_added", 0)))
	elif actor == "hero" and target == "enemy":
		_values.damage_dealt += maxi(0, int(event.get("damage", 0)))
		if resolution in ["hit", "guard"]: _values.hits += 1
		elif resolution == "whiff": _values.misses += 1
		if resolution == "dodge": _values.enemy_dodges += 1
		if resolution == "guard": _values.enemy_guards += 1
		if bool(event.get("poise_broken", false)): _values.breaks += 1
	elif actor == "enemy" and target == "hero":
		_values.damage_taken += maxi(0, int(event.get("damage", 0)))
		_values.shield_absorbed += maxi(0, int(event.get("shield_absorbed", 0)))
		if resolution in ["hit", "guard"]: _values.incoming_hits += 1
		elif resolution == "whiff": _values.incoming_misses += 1
		if resolution == "dodge": _values.dodges += 1
		if resolution == "guard": _values.guards += 1

func snapshot(seconds: float, hp: int, max_hp: int) -> Dictionary:
	var result := _values.duplicate(true)
	result.merge({"elapsed": maxf(0.0, seconds), "hero_hp": hp, "hero_max_hp": max_hp}, true)
	return result
