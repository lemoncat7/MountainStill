extends SceneTree
const UpdatePanel = preload("res://scripts/release_panel.gd")
class LegacyService extends Node:
	signal changed
	var busy = false
	var auto_check = false
	var channel = "testing"
	var status = "GitHub 请求受限，请稍后重试；游戏不受影响。"
	var content_version = ""
	var candidate = {}
	func set_auto_check(value): auto_check = value
	func set_channel(value): channel = value; changed.emit()
	func check_updates(): pass
	func download_update(): pass
	func cancel(): busy = false; changed.emit()
class NewService extends LegacyService:
	var remaining = 30
	func rate_limit_remaining(): return remaining
	func rate_limit_message(): return "GitHub 请求次数已用尽；请等待至本机时间 2026-10-23 14:38:08 后重试。游戏与存档不受影响。"
class Store extends RefCounted:
	var staged = {}
	func current_version(): return "1.3.16-test.1"
	func pending(): return staged
var checks = 0
var failures = 0
func check(value: bool, label: String):
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func _initialize(): run.call_deferred()
func run():
	root.size = Vector2i(1200, 400)
	root.content_scale_factor = 1.25
	var host = Control.new()
	root.add_child(host)
	var store = Store.new()
	root.set_meta("update_store", store)
	for legacy in [false, true]:
		var service = LegacyService.new() if legacy else NewService.new()
		service.name = "UpdateService"
		root.add_child(service)
		var panel = UpdatePanel.new()
		host.add_child(panel)
		panel.setup(host)
		panel.popup_centered()
		for i in range(3): await process_frame
		check(panel.size.y <= 290 and panel.size.x <= 960, "main panel fits short window")
		check(panel.info.get_theme_font_size("font_size") >= 16, "readable main status")
		check(panel.theme.get_color("title_color", "Window").get_luminance() > 0.7, "light title on dark native title bar")
		check(panel.theme.get_color("font_disabled_color", "Button").get_luminance() < 0.5, "disabled controls readable on rice paper")
		print("PANEL_SIZE legacy=", legacy, " main=", panel.size)
		check(panel._supports_rate_limit() == not legacy, "capability detection supports old installed bootstrap")
		check(panel.check_button.disabled == not legacy, "limited checks blocked but old service remains usable")
		check(panel.download_button.disabled, "no candidate cannot download")
		if legacy:
			check(panel.info.text.contains("限流保护需安装新版完整包"), "old installed bootstrap upgrade notice")
		else:
			check(panel.info.text.contains("14:38:08"), "wait until time is visible")
			service.candidate = {"version":"fixture"}
			store.staged = {"version":"fixture", "kind":"content_json"}
			service.changed.emit()
			check(panel.download_button.disabled, "limit blocks existing candidate download")
			check(not panel.apply_button.disabled, "limit does not block already verified apply")
			service.remaining = 0
			service.changed.emit()
			check(not panel.check_button.disabled and not panel.download_button.disabled, "expiry event re-enables check and download")
		service.content_version = "1.3.15-test.1"
		store.staged = {"version":"1.3.16-test.1", "kind":"pck"}
		service.changed.emit()
		for i in range(3): await process_frame
		check(panel.size.y <= 290, "content and pending detail do not expand main panel")
		check(panel.apply_button.text == "保存并重启应用", "staged script update retains explicit restart action")
		check(not panel.info.text.contains("内容版本："), "version detail moved out of compact main status")
		service.busy = true
		service.changed.emit()
		check(not panel.cancel_button.disabled, "busy request can always cancel")
		check(panel.check_button.disabled and panel.apply_button.disabled, "busy mutations disabled")
		service.cancel()
		check(panel.cancel_button.disabled, "cancel updates button")
		panel._open_help()
		for i in range(3): await process_frame
		check(panel.help_dialog.size.y <= 290 and panel.help_dialog.size.x <= 960, "help page one fits short window")
		print("HELP_SIZE legacy=", legacy, " page=1 size=", panel.help_dialog.size)
		check(panel.help_previous.disabled and not panel.help_next.disabled, "first page controls")
		check(panel.help_text.get_theme_font_size("font_size") >= 18, "large readable help text")
		check(panel.help_text.text.contains("完整包") == legacy, "legacy-specific help")
		panel.help_next.pressed.emit()
		for i in range(3): await process_frame
		check(panel.help_dialog.size.y <= 290, "help page two fits short window")
		print("HELP_SIZE legacy=", legacy, " page=2 size=", panel.help_dialog.size)
		check(panel.help_page == 1 and not panel.help_next.disabled and not panel.help_previous.disabled, "middle page controls")
		check(panel.help_text.text.contains("完整包"), "full installer boundary explicit")
		panel.help_next.pressed.emit()
		for i in range(3): await process_frame
		check(panel.help_dialog.size.y <= 290, "third page fits scaled short window")
		check(panel.help_page == 2 and panel.help_next.disabled, "last page controls")
		print("HELP_SIZE legacy=", legacy, " page=3 size=", panel.help_dialog.size)
		check(panel.help_text.text.contains("恢复更新前存档"), "rollback consequence explicit")
		check(panel.help_text.text.contains("内容版本：1.3.15-test.1") and panel.help_text.text.contains("已下载：1.3.16-test.1"), "content and pending version preserved in third page")
		panel.help_previous.pressed.emit()
		check(panel.help_page == 1, "previous returns one page")
		panel.help_dialog.hide()
		check(panel.visible and not panel.confirmation.visible, "closing help does not open apply confirmation")
		panel._open_help()
		check(panel.help_page == 0, "reopening help starts at first page")
		panel.hide()
		check(not panel.help_dialog.visible, "closing updater dismisses help")
		panel.popup_centered()
		check(panel.visible, "updater can reopen")
		panel.queue_free()
		service.queue_free()
		store.staged = {}
		await process_frame
	print("UPDATE_PANEL_RATE: %d checks, %d failures" % [checks, failures])
	quit(failures)
