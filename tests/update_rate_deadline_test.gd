extends SceneTree
## Deterministic early-wake boundaries plus actual real-time timer behavior.
class ClockService:
	extends "res://scripts/update_service.gd"
	var fake_ticks = -1
	var wall_offset = 0.0
	func _ticks_msec() -> int:
		return fake_ticks if fake_ticks >= 0 else Time.get_ticks_msec()
	func _wall_seconds() -> float:
		return Time.get_unix_time_from_system() + wall_offset
	func _ready() -> void:
		super._ready()
		set_auto_check(false)
var checks = 0
var failures = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void: run.call_deferred()
func run() -> void:
	var service = ClockService.new()
	root.add_child(service)
	service.fake_ticks = 1000
	service._begin_cooldown(1, false)
	service.status = service.rate_limit_message()
	var generation = service._generation
	service.fake_ticks = 1993
	service._cooldown_expired()
	check(is_equal_approx(service._cooldown_timer.wait_time, 0.007), "early wake schedules seven milliseconds, not ceil second")
	check(service.rate_limit_remaining() == 1 and service._blocked_by_cooldown(), "seven milliseconds still blocks requests")
	service.fake_ticks = 1999
	service._cooldown_expired()
	check(is_equal_approx(service._cooldown_timer.wait_time, 0.001), "one millisecond boundary is not rounded into a second")
	check(service.rate_limit_remaining() == 1 and service._blocked_by_cooldown(), "one millisecond still blocks requests")
	service.wall_offset = 86400.0
	check(service.rate_limit_remaining() == 1, "forward wall clock cannot expire monotonic deadline")
	service.wall_offset = -86400.0
	check(service.rate_limit_remaining() == 1, "backward wall clock cannot extend monotonic deadline")
	service.fake_ticks = 2000
	service._cooldown_expired()
	check(service.rate_limit_remaining() == 0 and service.status.contains("等待已结束"), "exact monotonic deadline releases UI")
	check(service._generation == generation, "injected expiry never sends a request")
	service._cooldown_timer.stop()
	service.fake_ticks = -1
	service.wall_offset = 0.0
	check(service._cooldown_timer.ignore_time_scale, "timer ignores gameplay speed")
	check(service._cooldown_timer.process_mode == Node.PROCESS_MODE_ALWAYS, "timer progresses during gameplay pause")
	for mode in ["natural", "paused", "slow"]:
		service._begin_cooldown(1, false)
		service.status = service.rate_limit_message()
		var target = service._cooldown_until_msec
		if mode == "paused": paused = true
		if mode == "slow": Engine.time_scale = 0.1
		while not service.status.contains("等待已结束") and Time.get_ticks_msec() < target + 3000:
			await process_frame
		var lag = Time.get_ticks_msec() - target
		paused = false
		Engine.time_scale = 1.0
		check(service.status.contains("等待已结束") and service.rate_limit_remaining() == 0, mode + " expires within bounded observation")
		check(lag >= 0, mode + " never expires before protected deadline")
		check(service._generation == generation, mode + " expiry sends no request")
		print("RATE_DEADLINE mode=", mode, " observed_lag_ms=", lag)
	service.queue_free()
	await process_frame
	print("UPDATE_RATE_DEADLINE: ", checks, " checks, ", failures, " failures")
	quit(1 if failures else 0)
