extends RefCounted
## Pure ordering policy; caller supplies eligible, equipped, cooldown-ready skills.
const IDS := ["balanced", "assault", "guarded", "frugal"]
const EPSILON := 0.0000001

static func sanitize(value: Variant) -> String:
	return value if value is String and value in IDS else "balanced"

static func choose(mode: String, candidates: Array, qi: float, capacity: float, hp: int, max_hp: int) -> String:
	if candidates.is_empty(): return "basic"
	mode = sanitize(mode)
	var ordered := candidates.duplicate()
	if mode in ["assault", "guarded"]:
		# Stable buckets retain the old rotation within each priority class.
		ordered.clear()
		for priority in range(3):
			for candidate in candidates:
				if _priority(mode, candidate, hp, max_hp) == priority: ordered.append(candidate)
	if mode == "frugal":
		for candidate in ordered:
			var cost := float(candidate.cost)
			var reserve := minf(capacity * 0.25, maxf(0.0, capacity - cost))
			if str(candidate.id) == "mending" and hp <= max_hp * 0.65: reserve = 0.0
			if qi + EPSILON >= cost + reserve: return str(candidate.lane)
		return "basic"
	# Balanced deliberately does NOT skip an unaffordable first eligible skill.
	var first: Dictionary = ordered[0]
	return str(first.lane) if qi + EPSILON >= float(first.cost) else "basic"

static func _priority(mode: String, candidate: Dictionary, hp: int, max_hp: int) -> int:
	var healing := str(candidate.id) == "mending"
	var support := str(candidate.get("action_kind", "")) in ["defense", "utility"]
	if mode == "guarded": return 0 if healing else (1 if support else 2)
	if healing and hp <= max_hp * 0.65: return 0
	return 2 if support else 1
