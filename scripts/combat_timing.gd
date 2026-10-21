extends RefCounted
## One setup-time conversion from effective speed to authored action seconds.
## This never scales the simulation clock, cooldowns, hitstop or status durations.
const POLICY := {
	"baseline_speed": 100.0, "minimum_rate": 0.65, "maximum_rate": 1.60,
	"legacy_haste_cap": 0.35, "recovery_bonus_cap": 0.40,
	"phase_keys": ["windup", "strike", "hold", "gap", "recovery"],
	"ready_intervals": {"hero": 0.07, "enemy": 0.12},
	"counter_interval": 0.025, "enemy_opening_delay": 0.18,
}

static func _number(value: Variant, fallback: float) -> float:
	if not value is int and not value is float: return fallback
	var result := float(value)
	return result if is_finite(result) else fallback

static func from_stats(stats: Dictionary) -> Dictionary:
	var baseline := float(POLICY.baseline_speed)
	var legacy_haste := clampf(_number(stats.get("combat_haste", 0.0), 0.0), 0.0, float(POLICY.legacy_haste_cap))
	# `speed` is the complete effective stat, including earned haste. Legacy
	# encounters/saves without it keep their haste; the two are never multiplied.
	var speed := _number(stats.get("speed", baseline * (1.0 + legacy_haste)), baseline * (1.0 + legacy_haste))
	var rate := clampf(speed / baseline, float(POLICY.minimum_rate), float(POLICY.maximum_rate))
	return {"speed": rate * baseline, "rate": rate, "scale": 1.0 / rate,
		"recovery_scale": 1.0 - clampf(_number(stats.get("recovery_bonus", 0.0), 0.0), 0.0, float(POLICY.recovery_bonus_cap))}

static func apply(action: Dictionary, timing: Dictionary) -> void:
	for key in POLICY.phase_keys:
		action[key] = float(action[key]) * float(timing.scale)
	action.recovery = float(action.recovery) * float(timing.recovery_scale)
	action.speed = float(timing.speed)
	action.action_rate = float(timing.rate)

static func ready_interval(actor: String, timing: Dictionary, counter: bool = false) -> float:
	var base := float(POLICY.counter_interval) if counter else float(POLICY.ready_intervals.get(actor, 0.12))
	return base * float(timing.scale)
