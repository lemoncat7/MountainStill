extends SceneTree
const Service = preload("res://tests/update_fixture_service.gd")
var failures = 0
var checks = 0
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize() -> void:
	run.call_deferred()
func settle(service: Node) -> void:
	var deadline = Time.get_ticks_msec() + 5000
	while service.busy and Time.get_ticks_msec() < deadline:
		await process_frame
	check(not service.busy, "request completes within fixture deadline")
func run() -> void:
	var service = Service.new()
	root.add_child(service)
	service.set_channel("testing")
	service.check_updates()
	var generation = service._generation
	service.check_updates()
	check(generation == service._generation, "concurrent check ignored")
	await settle(service)
	check(not service.candidate.is_empty(), "release + manifest HTTP integration")
	service.download_update()
	var download_generation = service._generation
	service.download_update()
	check(service._generation == download_generation, "concurrent download ignored")
	await settle(service)
	check(service.downloaded, "verified download staged")
	check(FileAccess.file_exists(service.PENDING), "pending exists")
	var staged = FileAccess.get_file_as_string(service.PENDING)
	for mode in ["corrupt","oversize"]:
		service.fixture_mode = mode
		service.download_update()
		await settle(service)
		check(FileAccess.get_file_as_string(service.PENDING) == staged, mode + " preserves pending")
		check(not FileAccess.file_exists(service.PART), mode + " cleans partial")
	service.fixture_mode = "slow"
	service.download_update()
	await create_timer(0.06).timeout
	service.cancel()
	check(not service.busy and not FileAccess.file_exists(service.PART), "cancel stops and removes partial")
	await create_timer(0.08).timeout
	check(FileAccess.get_file_as_string(service.PENDING) == staged, "cancel cannot commit stale callback")
	for mode in ["badjson","rate","redirect","disconnect"]:
		service.fixture_mode = mode
		service.check_updates()
		await settle(service)
		check(service.candidate.is_empty(), mode + " rejected")
	service.fixture_mode = "valid"
	service.check_updates()
	service.set_channel("stable")
	await create_timer(0.08).timeout
	check(not service.busy and service.candidate.is_empty(), "channel switch cancels stale request")
	service.set_channel("testing")
	service.check_updates()
	await settle(service)
	check(not service.candidate.is_empty(), "retry after cancellation succeeds")
	service.fixture_mode = "cdn"
	service.check_updates()
	await settle(service)
	check(not service.candidate.is_empty(), "trusted CDN redirect manifest")
	service.download_update()
	await settle(service)
	check(service.status.begins_with("下载校验完成"), "trusted CDN redirect pack")
	service.fixture_mode = "badhot"
	service.check_updates()
	await settle(service)
	service.download_update()
	await settle(service)
	check(service.status.contains("格式无效"), "hot payload refuses script key")
	service.fixture_mode = "hot"
	service.check_updates()
	await settle(service)
	service.download_update()
	await settle(service)
	check(service.apply_hot_content(), "explicit hot content apply")
	check(service.content_data().get("accent") == "#843927", "hot content active")
	check(service.current_version == service.CURRENT_VERSION, "hot content does not fake game version")
	check(not FileAccess.file_exists(service.PENDING), "hot apply clears pending")
	check(not service.apply_hot_content(), "second hot apply rejected")
	service.check_updates()
	await settle(service)
	check(service.candidate.is_empty(), "already applied content not offered again")
	var interrupted = FileAccess.open(service.PART, FileAccess.WRITE)
	interrupted.store_string("interrupted partial")
	interrupted.close()
	var resumed = Service.new()
	root.add_child(resumed)
	check(not FileAccess.file_exists(service.PART), "interrupted partial cleaned on startup")
	check(resumed.content_data().get("accent") == "#843927", "hot content restored on next launch")
	resumed.queue_free()
	service.set_auto_check(false)
	var before = service._generation
	service._automatic_check()
	check(service._generation == before, "disabled monitoring makes no network request")
	service.set_auto_check(true)
	check(not service._auto_timer.is_stopped(), "enabled monitoring schedules timer")
	service.busy = true
	var monitoring_generation = service._generation
	service._automatic_check()
	check(service._generation == monitoring_generation, "monitor skips concurrent operation")
	check(service._auto_timer.time_left > 21590, "monitor reschedules six hours")
	service.busy = false
	service.set_auto_check(false)
	check(service._auto_timer.is_stopped(), "disabled monitoring stops timer")
	service.queue_free()
	await process_frame
	print("update_service: %d checks; %d failures" % [checks, failures])
	quit(1 if failures else 0)
