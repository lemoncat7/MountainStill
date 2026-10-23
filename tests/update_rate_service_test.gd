extends SceneTree
const Service = preload("res://tests/update_fixture_service.gd")
var checks = 0
var failures = 0
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize(): run.call_deferred()
func settle(service):
	var deadline = Time.get_ticks_msec() + 5000
	while service.busy and Time.get_ticks_msec() < deadline: await process_frame
	check(not service.busy, "fixture completes")
func clear(service):
	service._cooldown_until_msec = 0
	service._cooldown_expired()
func run():
	var service = Service.new()
	root.add_child(service)
	clear(service)
	service.set_channel("testing")
	for mode in ["primary", "retry", "past", "future", "rate", "bodylimit", "forbidden"]:
		service.fixture_mode = mode
		service.check_updates()
		await settle(service)
		if mode == "forbidden":
			check(service.rate_limit_remaining() == 0, "ordinary 403 not misclassified")
			check(service.status.contains("未确认限流"), "ordinary 403 actionable and distinct")
		else:
			check(service.rate_limit_remaining() > 0, mode + " starts cooldown")
			check(service.status.contains("限流") and not service.status.contains("最新版本"), mode + " truthful state")
			var expected = {"primary":120,"retry":2,"past":1,"future":3600,"rate":60,"bodylimit":60}[mode]
			check(absi(service.rate_limit_remaining() - expected) <= 1, mode + " delay")
			var generation = service._generation
			for click in range(20): service.check_updates()
			service.auto_check = true
			service._automatic_check()
			service.auto_check = false
			check(service._generation == generation, mode + " rapid clicks and auto suppressed")
			service.candidate = {"url":"https://github.com/lemoncat7/MountainStill/releases/download/v1/x.pck", "size":4}
			service.download_update()
			check(service._generation == generation and not service.busy, "download entry suppressed")
			clear(service)
	service.fixture_mode = "primary"
	service.check_updates()
	await settle(service)
	var remaining = service.rate_limit_remaining()
	service.set_channel("stable")
	check(service.rate_limit_remaining() > 0, "channel switch cannot reset public quota")
	service.queue_free()
	await process_frame
	service = Service.new()
	root.add_child(service)
	check(service.rate_limit_remaining() > 0 and service.rate_limit_remaining() <= remaining, "restart restores bounded cooldown")
	clear(service)
	# Expiration is a UI event only, not a hidden request.
	service.fixture_mode = "retry"
	service.check_updates()
	await settle(service)
	var before = service._generation
	await create_timer(2.15).timeout
	check(service.rate_limit_remaining() == 0 and service._generation == before, "expiry never auto requests")
	check(service.status.contains("等待已结束"), "expiry makes retry understandable")
	service.fixture_mode = "valid"
	service.set_channel("testing")
	service.check_updates()
	await settle(service)
	check(not service.candidate.is_empty(), "manual retry after expiry works")
	service.download_update()
	service.cancel()
	check(not service.busy and not FileAccess.file_exists(service.PART), "cancel unaffected")
	# A rate-limited pack cannot consume an already verified pending record or save.
	var save = FileAccess.open("user://cultivation_save.json", FileAccess.WRITE)
	save.store_string("fixture-save-sentinel"); save.close()
	var pending = FileAccess.open(service.PENDING, FileAccess.WRITE)
	pending.store_string("fixture-pending-sentinel"); pending.close()
	for mode in ["primary", "bodylimit", "secondary"]:
		service.fixture_mode = mode
		service.download_update()
		await settle(service)
		check(service.rate_limit_remaining() > 0, mode + " pack rate limit enters shared cooldown")
		check(not FileAccess.file_exists(service.PART), mode + " error body removed")
		clear(service)
	service._begin_cooldown(60)
	check(FileAccess.get_file_as_string(service.PENDING) == "fixture-pending-sentinel", "pack refusal preserves pending")
	check(FileAccess.get_file_as_string("user://cultivation_save.json") == "fixture-save-sentinel", "rate handling never touches save")
	check(not FileAccess.file_exists(service.PART), "pack refusal removes only partial")
	service.cancel()
	check(not service.busy and service.rate_limit_remaining() > 0, "cancel allowed without erasing quota")
	clear(service)
	DirAccess.remove_absolute(ProjectSettings.globalize_path(service.PENDING))
	# Restart with a backwards clock record is conservative but capped at one minute.
	var record = ConfigFile.new()
	record.set_value("limit", "recorded", Time.get_unix_time_from_system() + 86400)
	record.set_value("limit", "seconds", 3600)
	record.save(service.COOLDOWN)
	service._restore_cooldown()
	check(service.rate_limit_remaining() > 0 and service.rate_limit_remaining() <= 60, "backwards clock bounded")
	clear(service)
	record.set_value("limit", "recorded", Time.get_unix_time_from_system() - 7200)
	record.save(service.COOLDOWN)
	service._restore_cooldown()
	check(service.rate_limit_remaining() == 0, "expired persisted record permits retry")
	for bad in ["string", -10, INF, 3601]:
		record.set_value("limit", "seconds", bad)
		record.save(service.COOLDOWN)
		service._restore_cooldown()
		check(service.rate_limit_remaining() == 0, "invalid persisted delay ignored")
	clear(service)
	service.queue_free()
	await process_frame
	print("UPDATE_RATE_SERVICE: ", checks, " checks, ", failures, " failures")
	quit(failures)
