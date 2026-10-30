extends SceneTree
const Pages = preload("res://scripts/display_diagnostic_pages.gd")
const Store = preload("res://scripts/update_store.gd")
var checks = 0
var failures = 0
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func saved_state(scene) -> String:
	var snapshot = scene.state._snapshot()
	snapshot.erase("saved_at")
	snapshot["settings"] = scene.state.settings.duplicate(true)
	return JSON.stringify(snapshot)
func _initialize(): run.call_deferred()
func run():
	var store = Store.new()
	var versions = Pages.versions(store)
	check(versions.host == Store.BUILTIN_VERSION and versions.running == Store.BUILTIN_VERSION,"existing Script constant map resolves actual current host")
	store.running_version = "1.3.12-test.1"
	versions = Pages.versions(store)
	check(versions.host == Store.BUILTIN_VERSION and versions.running == "1.3.12-test.1","old active content does not overwrite newer installed host")
	var old_host_script = GDScript.new()
	old_host_script.source_code = 'extends RefCounted\nconst BUILTIN_VERSION = "1.3.1-test.1"\nvar running_version = "1.3.27-test.1"\n'
	check(old_host_script.reload() == OK,"old installed host fixture compiles")
	var old_host = old_host_script.new()
	old_host.running_version = Store.BUILTIN_VERSION
	var old_versions = Pages.versions(old_host)
	check(old_versions.host == "1.3.1-test.1" and old_versions.running == Store.BUILTIN_VERSION,"old loaded host with new content is not confused with current resource script")
	var service_script = GDScript.new()
	service_script.source_code = 'extends RefCounted\nvar current_version = "1.3.99"\nvar content_version = "1.3.98"\n'
	check(service_script.reload() == OK,"read-only service fixture compiles")
	var service = service_script.new()
	check(Pages.versions(null,service).host == "未知" and Pages.versions(null,service).running == "1.3.99","service fallback is content evidence only")
	check(Pages.versions(RefCounted.new()).host == "未知","missing script and constant stay unknown")
	check(Pages.versions(null).host == "未知" and Pages.versions(null).context.contains("开发"),"direct scene does not fabricate host from project version")
	var dead = Node.new(); dead.free()
	check(Pages.versions(dead).host == "未知","freed metadata object fails safely")
	check(Pages.versions({}).host == "未知","non-object metadata fails safely")
	check(Pages.clean("x".repeat(500)).length() == 48,"long adapter bounded")
	check(Pages.clean("a\nb\tc\rd") == "a b c d" and Pages.clean({}) == "未知","malformed strings safely normalized")
	check(Pages.flag({"supported":"true"},"supported") == "未知","wrong type never claims support")
	var rows = Pages.rows({"rendering_driver":"opengl3","adapter_name":"x".repeat(500)},versions,1)
	check(rows[1].contains("opengl3") and not str(rows).contains("ANGLE"),"actual OpenGL fallback not reported as configured ANGLE")
	rows = Pages.rows({"transparency_supported":false,"window_attached":false},versions,2)
	check(rows[1].ends_with("否") and rows[4].ends_with("未知") and rows[6].contains("不代表"),"unsupported and absent-window flags do not imply success")
	check(not str(Pages.rows({"token":"SECRET","path":"PRIVATE","command":"PASSWORD"},versions,1)).contains("SECRET"),"unlisted private fields are never rendered")
	var mixed = Pages.rows({"window_attached":true,"transparency_requested":true,"transparency_supported":false,"helper_transparency_applied":false,"window_transparent_flag":true,"viewport_transparent_background":false},versions,2)
	check(mixed[0].ends_with("是") and mixed[1].ends_with("否") and mixed[3].ends_with("否") and mixed[4].ends_with("是") and mixed[5].ends_with("否"),"mixed request support helper and window flags remain independent")
	var scene = load("res://main.tscn").instantiate()
	scene.state.save_path = "user://diagnostic_pages_test.json"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var before = saved_state(scene)
	var was_paused = scene.paused
	var was_elapsed = scene.elapsed
	var save_before = FileAccess.get_sha256(scene.state.save_path) if FileAccess.file_exists(scene.state.save_path) else "missing"
	for dimensions in [Vector2(960,320),Vector2(1200,540),Vector2(1600,900)]:
		scene.size = dimensions
		scene.strip = true
		scene._toggle_drawer("settings")
		scene.buttons.advanced.pressed.emit()
		check(scene.drawer_name == "desktop","settings to desktop route")
		scene.buttons.desktop_diagnostics.pressed.emit()
		check(scene.drawer_name == "diagnostics" and scene.diagnostic_page == 0,"desktop entry opens first page")
		check(Rect2(Vector2.ZERO,dimensions).encloses(scene._drawer_rect()),"diagnostics fit smallest logical strip")
		for i in range(6):
			for row in Pages.rows(scene.diagnostic_snapshot,scene.diagnostic_versions,scene.diagnostic_page):
				var fitted = Pages.fit(row,scene.SANS,13,412)
				check(scene.SANS.get_string_size(fitted,HORIZONTAL_ALIGNMENT_LEFT,-1,13).x <= 412,"fitted text stays within paper at existing font size")
			scene.buttons.diagnostic_refresh.pressed.emit()
			scene.buttons.diagnostic_next.pressed.emit()
		check(scene.diagnostic_page == 0,"repeated page navigation wraps")
		scene.buttons.diagnostic_back.pressed.emit()
		check(scene.drawer_name == "desktop","back preserves desktop navigation")
		scene.buttons.desktop_back.pressed.emit()
		check(scene.drawer_name == "settings","back to settings")
		scene._close_drawer()
	check(saved_state(scene) == before,"open refresh paging return do not mutate saved game or preferences")
	check(scene.paused == was_paused and scene.elapsed == was_elapsed,"diagnostic actions do not change pause or progress")
	check((FileAccess.get_sha256(scene.state.save_path) if FileAccess.file_exists(scene.state.save_path) else "missing") == save_before,"diagnostic actions never save")
	check(not root.has_node("UpdateService") and not root.has_meta("update_store"),"direct scene diagnostics do not instantiate updater")
	root.set_meta("update_store",store)
	var old_requested = scene.desktop.desired_transparent
	scene.desktop.desired_transparent = not old_requested
	scene._open_display_diagnostics()
	check(scene.diagnostic_snapshot.transparency_requested == not old_requested,"reopen reads fresh flags")
	check(scene.diagnostic_versions.host == Store.BUILTIN_VERSION and scene.diagnostic_versions.running == store.running_version,"UI reads existing root-owned store")
	scene.desktop.desired_transparent = old_requested
	scene._refresh_display_diagnostics()
	check(scene.diagnostic_snapshot.transparency_requested == old_requested,"explicit refresh replaces snapshot")
	for i in range(3):
		scene._close_drawer()
		scene._open_display_diagnostics()
	await create_timer(.9).timeout
	# Gameplay processing is frozen for read-only assertions; simulate its visual sync.
	scene._sync_drawer_visuals()
	check(scene.drawer_name == "diagnostics" and is_instance_valid(scene.drawer) and scene.buttons.diagnostic_back.get_parent() == scene.drawer,"interrupted close/reopen leaves current navigation alive")
	check(scene.buttons.diagnostic_back.focus_mode != Control.FOCUS_NONE,"navigation focus restored after animation")
	scene.buttons.drawer_close.pressed.emit()
	await create_timer(.8).timeout
	check(scene.drawer_name.is_empty() and not is_instance_valid(scene.drawer),"close removes the diagnostic drawer")
	check(root.get_meta("update_store") == store and store.running_version == "1.3.12-test.1","diagnostics leave existing store and metadata unchanged")
	root.remove_meta("update_store")
	scene.closing = true
	scene.queue_free()
	await process_frame
	print("DISPLAY DIAGNOSTIC PAGES: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
