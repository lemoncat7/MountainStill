extends SceneTree
const Pages = preload("res://scripts/display_diagnostic_pages.gd")
class CopyScene extends "res://scripts/cultivation.gd":
	var copies: Array[String] = []
	var clipboard_available = true
	func _diagnostic_clipboard_available() -> bool: return clipboard_available
	func _write_diagnostic_clipboard(report: String): copies.append(report)
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
	var version = {"host":"1.3.1-test.1", "running":"1.3.29-test.1", "hot_content":"1.2.3"}
	var snapshot = {"os":"Windows", "display_server":"Windows", "rendering_method":"gl_compatibility", "rendering_driver":"opengl3", "adapter_api":"4.6 (Core Profile) Mesa 25.0", "adapter_name":"Intel UHD 630", "adapter_vendor":"Intel", "transparency_requested":true, "transparency_supported":false, "native_window_ready":true, "helper_transparency_applied":false, "window_attached":true, "window_transparent_flag":true, "viewport_transparent_background":false, "pixel_transparency_verified":true}
	var report = Pages.report(snapshot, version)
	var expected = "\n".join(["MountainStill 显示诊断（本地快照）", "安装宿主：1.3.1-test.1", "运行内容：1.3.29-test.1", "热内容：1.2.3", "系统：Windows", "窗口系统：Windows", "渲染方式：gl_compatibility", "实际驱动：opengl3", "图形 API：4.6 (Core Profile) Mesa 25.0", "显卡：Intel UHD 630", "厂商：Intel", "透明请求：是", "系统报告支持：否", "原生窗口就绪：是", "辅助器已应用：否", "窗口已连接：是", "窗口透明标记：是", "视口透明背景：否", "真实桌面透明像素：未验证；标记 / 支持不代表透明显示成功。", "仅反映当前后端，不推断启动器选择。仅手动复制，不上传。"])
	check(report == expected, "deterministic full report keeps host/content/hot versions and actual fallback separate")
	var before = snapshot.duplicate(true)
	for key in ["path", "save_path", "token", "args", "command", "username", "context"]:
		snapshot[key] = "PRIVATE_SECRET"
		version[key] = "PRIVATE_SECRET"
	check(Pages.report(snapshot,version) == expected, "unknown fields never exported")
	check(not report.contains("ANGLE") and report.contains("未验证"), "does not infer ANGLE or real pixel success")
	for bad in [null, true, 12, 1.5, {}, [], "", "\nSECRET", "A\rB", "A\tB", "A" + String.chr(1) + "B", "A" + String.chr(27) + "B", "a\u202eb", "/home/private/file", "C:\\Users\\private", "https://private.test", "user@example.com", "--token SECRET", "token=SECRET", "a".repeat(513)]:
		check(Pages.report_value(bad) == Pages.UNKNOWN, "reject malformed or private hardware value")
		check(Pages.report_value(bad,true) == Pages.UNKNOWN, "reject malformed or private version value")
	for gpu in ["NVIDIA GeForce GTX 1080/PCIe/SSE2", "GeForce 8800 GT/PCI/SSE2", "GeForce GTX 750 Ti/SSE2", "AMD Radeon RX 6800 XT (radeonsi, navi21, LLVM 15.0.7)", "ANGLE (NVIDIA, NVIDIA GeForce RTX 3060 Direct3D11 vs_5_0 ps_5_0, D3D11)"]:
		check(Pages.report_adapter_name(gpu) == gpu and Pages.report({"adapter_name":gpu},{}).contains("显卡：" + gpu), "realistic native and ANGLE GPU evidence retained")
	check(Pages.report_value("NVIDIA GeForce GTX 1080/PCIe/SSE2") == Pages.UNKNOWN, "GPU slash exceptions do not broaden other report fields")
	for bad in ["/home/private/PCIe/SSE2", "C:\\Users\\private/PCIe/SSE2", "C:/Users/private/PCIe/SSE2", "https://private/PCIe/SSE2", "private/folder/file", "private/path/PCIe/SSE2", "--token PRIVATE/PCIe/SSE2", "a\nPRIVATE/PCIe/SSE2", "token=PRIVATE/PCIe/SSE2", "/PCIe/SSE2", "x".repeat(513) + "/PCIe/SSE2", {}, null]:
		check(Pages.report_adapter_name(bad) == Pages.UNKNOWN, "GPU suffix support still rejects paths URLs commands and malformed inputs")
	check(Pages.report_adapter_name("x".repeat(500) + "/PCIe/SSE2").length() <= 96, "GPU suffix does not escape field bound")
	for bad in [null, "true", 1, [], {}]:
		var flags = {"window_attached":bad, "window_transparent_flag":true, "viewport_transparent_background":true, "transparency_supported":bad}
		var text = Pages.report(flags,{})
		check(text.contains("系统报告支持：未知") and text.contains("窗口透明标记：未知") and text.contains("视口透明背景：未知"), "wrong typed flags never imply support or attachment")
	var maximal = {}
	for key in before: maximal[key] = "x".repeat(512)
	var long_versions = {"host":"x".repeat(512), "running":"x".repeat(512), "hot_content":"x".repeat(512)}
	check(Pages.report_value("x".repeat(512)).length() == 96, "per-field bounded")
	check(Pages.report(maximal,long_versions).to_utf8_buffer().size() <= Pages.REPORT_MAX_BYTES, "report byte bound")
	check(Pages.report({},{}).contains("安装宿主：未知"), "missing metadata remains unknown")
	var scene = CopyScene.new()
	scene.state.save_path = "user://copy_diagnostic_test.json"
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	var saved = saved_state(scene)
	var save_hash = FileAccess.get_sha256(scene.state.save_path) if FileAccess.file_exists(scene.state.save_path) else "missing"
	var paused_before = scene.paused
	var elapsed_before = scene.elapsed
	scene._open_display_diagnostics()
	check(scene.copies.is_empty(), "opening never copies")
	scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.copies.is_empty(), "opening animation blocks explicit action")
	await create_timer(.9).timeout
	scene._sync_drawer_visuals()
	for dimensions in [Vector2(960,320), Vector2(1200,540), Vector2(1600,900)]:
		scene.size = dimensions; scene.strip = true; scene._refresh_display_diagnostics()
		for page in range(3):
			check(scene.copies.size() == page + (3 * [Vector2(960,320), Vector2(1200,540), Vector2(1600,900)].find(dimensions)), "navigation and refresh never copy")
			var button = scene.buttons.diagnostic_copy
			check(scene._drawer_rect().encloses(Rect2(button.position,button.size)), "copy button fits drawer")
			for key in ["diagnostic_back", "diagnostic_refresh", "diagnostic_next"]:
				var other = scene.buttons[key]
				check(not Rect2(button.position,button.size).intersects(Rect2(other.position,other.size)), "copy does not overlap navigation")
			var expected_copy = Pages.report(scene.diagnostic_snapshot,scene.diagnostic_versions)
			button.pressed.emit()
			check(scene.copies.back() == expected_copy, "explicit copy uses entire report on each page")
			scene._turn_display_diagnostics()
	var old_request = scene.desktop.desired_transparent
	scene.desktop.desired_transparent = not old_request
	scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.diagnostic_snapshot.transparency_requested == not old_request and scene.copies.back() == Pages.report(scene.diagnostic_snapshot,scene.diagnostic_versions), "copy refreshes flags before writing instead of exporting stale snapshot")
	scene.desktop.desired_transparent = old_request
	var count = scene.copies.size()
	scene.clipboard_available = false
	scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.copies.size() == count and scene.toast.contains("不支持"), "unsupported clipboard never writes or claims success")
	scene.clipboard_available = true
	scene.buttons.diagnostic_copy.disabled = true
	scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.copies.size() == count, "disabled button blocked")
	scene.buttons.diagnostic_copy.disabled = false
	scene.closing = true; scene.buttons.diagnostic_copy.pressed.emit(); scene.closing = false
	check(scene.copies.size() == count, "shutdown guard")
	scene.practice_session = RefCounted.new(); scene.buttons.diagnostic_copy.pressed.emit(); scene.practice_session = null
	check(scene.copies.size() == count, "practice guard")
	scene._copy_display_diagnostics(null)
	check(scene.copies.size() == count, "invalid source drawer blocked")
	scene.content_alpha = .2; scene.buttons.diagnostic_copy.pressed.emit(); scene.content_alpha = 1
	check(scene.copies.size() == count, "transition guard")
	var stale_drawer = scene.drawer
	var stale_button = scene.buttons.diagnostic_copy
	scene._refresh_display_diagnostics()
	stale_button.pressed.emit(); scene._copy_display_diagnostics(stale_drawer)
	check(scene.copies.size() == count, "stale refreshed controls cannot copy")
	scene._close_drawer()
	scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.copies.size() == count, "closing drawer cannot copy")
	scene._open_display_diagnostics()
	scene._copy_display_diagnostics(stale_drawer)
	check(scene.copies.size() == count, "interrupted close reopen rejects old drawer")
	await create_timer(.9).timeout
	scene._sync_drawer_visuals()
	for i in range(3): scene.buttons.diagnostic_copy.pressed.emit()
	check(scene.copies.size() == count + 3, "repeated explicit clicks each copy once")
	check(saved_state(scene) == saved and scene.paused == paused_before and scene.elapsed == elapsed_before, "copy leaves game and preferences unchanged")
	check((FileAccess.get_sha256(scene.state.save_path) if FileAccess.file_exists(scene.state.save_path) else "missing") == save_hash, "copy never saves")
	check(not root.has_node("UpdateService") and not root.has_meta("update_store"), "copy does not instantiate updater")
	scene.closing = true; scene.queue_free()
	await process_frame
	print("DISPLAY DIAGNOSTIC COPY: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
