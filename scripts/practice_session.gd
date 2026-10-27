extends RefCounted
## Isolated, bounded training simulation. No State, save, reward or world clock.
## The host validates ownership and unlocked canonical enemy BEFORE calling start.
const Duel = preload("res://scripts/duel_timeline.gd")
const DEFAULT_SEED := 17
const MAX_SECONDS := 120.0
var duel = Duel.new()
var _started := false
var _paused := false
var _outcome := ""
var _seed := DEFAULT_SEED
var _enemy_name := ""
var _report: Dictionary = {}
var _loadout: Dictionary = {}
# Practice-only observers. These never alter engine events, state or RNG.
var _slowed_enemy_actions: Dictionary = {}
var _interrupted_enemy_contacts: Dictionary = {}

func start(hero: Dictionary, enemy: Dictionary, technique: String = "mist", style: String = "unarmed", run_seed: int = DEFAULT_SEED, loadout: Dictionary = {}) -> Dictionary:
	# Drop the old simulation wholesale, including its RNG, report and callbacks.
	duel = Duel.new()
	_started = false; _paused = false; _outcome = ""; _report = {}
	_slowed_enemy_actions.clear(); _interrupted_enemy_contacts.clear()
	_loadout = {}
	if hero.is_empty() or enemy.is_empty():
		return {"ok": false, "reason": "invalid_snapshot"}
	var snapshot := hero.duplicate(true)
	var foe := enemy.duplicate(true)
	var maximum: Variant = snapshot.get("max_hp", 100)
	if not (maximum is int or maximum is float) or not is_finite(float(maximum)):
		return {"ok": false, "reason": "invalid_snapshot"}
	snapshot.max_hp = clampi(int(maximum), 1, 100000)
	snapshot.hp = snapshot.max_hp
	# Absence selects the engine's full qi / zero cooldown initial condition.
	# Never reuse the formal route's resource ledger, even by alias.
	snapshot.erase("battle_resources")
	_seed = run_seed
	_enemy_name = str(foe.get("name", "守灵")).left(80)
	_loadout = loadout.duplicate(true)
	duel.start(snapshot, foe, technique, style, _seed)
	_started = true
	if duel.finished: _finish("invalid")
	return {"ok": _outcome != "invalid", "reason": _outcome, "seed": _seed}

func advance(delta: float) -> Array[Dictionary]:
	var events: Array[Dictionary] = []
	if not _started or _paused or not _outcome.is_empty() or not is_finite(delta) or delta <= 0.0: return events
	var allowed := minf(delta, maxf(0.0, MAX_SECONDS - duel.elapsed))
	events = duel.advance(allowed)
	_observe_control_events(events)
	if duel.finished:
		_finish("victory" if duel.victory else "defeat")
	elif duel.elapsed >= MAX_SECONDS - .0000001:
		_finish("timeout")
		duel.cancel()
		events.append({"type": "practice_timeout", "time": MAX_SECONDS})
	return events

func _observe_control_events(events: Array) -> void:
	if not _started or not _outcome.is_empty(): return
	for event in events:
		if not event is Dictionary: continue
		if str(event.get("type", "")) == "turn_started" and str(event.get("actor", "")) == "enemy" and bool(event.get("slowed", false)):
			var action_id := str(event.get("action_id", ""))
			if not action_id.is_empty(): _slowed_enemy_actions[action_id] = true
		elif str(event.get("type", "")) == "poise_break" and str(event.get("actor", "")) == "hero" and str(event.get("target", "")) == "enemy" and bool(event.get("interrupted", false)):
			var contact_id := str(event.get("contact_id", ""))
			if not contact_id.is_empty(): _interrupted_enemy_contacts[contact_id] = true

func pause() -> void:
	if _started and _outcome.is_empty(): _paused = true

func resume() -> void:
	if _started and _outcome.is_empty(): _paused = false

func cancel() -> void:
	if not _started or not _outcome.is_empty(): return
	_finish("cancelled")
	duel.cancel()

func _finish(outcome: String) -> void:
	if not _outcome.is_empty(): return
	_outcome = outcome
	_paused = false
	_report = _snapshot_report()

func _snapshot_report() -> Dictionary:
	var result: Dictionary = duel.combat_report()
	result.merge({"outcome": _outcome, "practice": true, "seed": _seed,
		"practice_loadout": _loadout.duplicate(true),
		"control_metrics_version": 1, "slowed_enemy_starts": _slowed_enemy_actions.size(),
		"enemy_action_interrupts": _interrupted_enemy_contacts.size(),
		"enemy_name": _enemy_name, "stage_name": "镜中试招", "rewarded": false,
		"notice": "固定种子单次试招，不代表胜率；不消耗历练资源，不获得奖励。"}, true)
	return result

func report() -> Dictionary:
	if not _started: return {}
	return _snapshot_report() if _outcome.is_empty() else _report.duplicate(true)

func pose() -> Dictionary:
	return duel.pose().duplicate(true) if _started else {}

func status() -> Dictionary:
	return {"started": _started, "active": _started and _outcome.is_empty(),
		"running": _started and _outcome.is_empty() and not _paused, "paused": _paused, "finished": _started and not _outcome.is_empty(),
		"outcome": _outcome, "seed": _seed, "elapsed": duel.elapsed if _started else 0.0,
		"hero_hp": duel.hero_hp if _started else 0, "hero_max_hp": duel.hero_max_hp if _started else 0,
		"enemy_hp": duel.enemy_hp if _started else 0, "enemy_max_hp": duel.enemy_max_hp if _started else 0}
