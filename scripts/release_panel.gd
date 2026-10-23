extends AcceptDialog
## Gameplay UI only. Calls the already installed updater; never replaces transport,
## validation, store, policy or bootstrap. Compatible with legacy services.
var game: Control
var service: Node
var store: RefCounted
var info: Label
var selector: OptionButton
var automatic: CheckButton
var check_button: Button
var download_button: Button
var apply_button: Button
var cancel_button: Button
var rollback_button: Button
var help_dialog: AcceptDialog
var help_text: Label
var help_previous: Button
var help_next: Button
var help_page := 0
var confirmation: ConfirmationDialog
var rolling_back := false
var confirmed_sha := ""
var confirmed_channel := ""
var confirmed_previous := ""

func setup(owner_game: Control) -> void:
	game = owner_game
	title = "山居更新 · GitHub Releases"
	min_size = Vector2i(570, 260)
	get_ok_button().text = "关闭（继续修行）"
	theme = Theme.new()
	theme.default_font = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
	theme.default_font_size = 16
	theme.set_color("title_color", "Window", Color("f4eee2"))
	theme.set_color("font_disabled_color", "Button", Color("77766d"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(540, 70)
	box.add_child(info)
	selector = OptionButton.new()
	selector.add_item("正式频道 · 只看稳定版本")
	selector.add_item("测试频道 · 含测试版和正式版")
	box.add_child(selector)
	automatic = CheckButton.new()
	automatic.text = "运行时自动检查（启动后 / 每 6 小时）"
	box.add_child(automatic)
	var row := HBoxContainer.new()
	box.add_child(row)
	check_button = _button(row, "检查更新", func(): service.check_updates())
	download_button = _button(row, "下载更新", func(): service.download_update())
	cancel_button = _button(row, "取消下载", func(): service.cancel())
	apply_button = _button(row, "保存并重启应用", _confirm_apply)
	var footer := HBoxContainer.new()
	box.add_child(footer)
	rollback_button = _button(footer, "回退上一版（恢复更新前存档）…", _confirm_rollback)
	_button(footer, "更新说明…", _open_help)
	_build_help()
	visibility_changed.connect(func():
		if visible: _refresh()
		elif is_instance_valid(help_dialog): help_dialog.hide())
	confirmation = ConfirmationDialog.new()
	confirmation.title = "确认更新"
	confirmation.confirmed.connect(_apply)
	add_child(confirmation)
	service = get_tree().root.get_node_or_null("UpdateService")
	store = get_tree().root.get_meta("update_store", null)
	if service != null and store != null:
		service.changed.connect(_refresh)
		automatic.button_pressed = service.auto_check
		automatic.toggled.connect(func(enabled): service.set_auto_check(enabled))
		selector.selected = 1 if service.channel == "testing" else 0
		selector.item_selected.connect(func(index): service.set_channel("testing" if index == 1 else "stable"))
	_refresh()

func _button(parent: Node, caption: String, action: Callable) -> Button:
	var b := Button.new()
	b.text = caption
	b.pressed.connect(action)
	parent.add_child(b)
	return b

func _refresh() -> void:
	var available := service != null and store != null
	if not available:
		info.text = "当前以开发场景启动。请从完整程序入口启动以使用更新。\n离线仍可正常修行，无需账号或令牌。"
	else:
		var message: String = service.rate_limit_message() if _limited() else service.status
		info.text = "当前版本：" + store.current_version() + "\n" + message
		if not _supports_rate_limit():
			info.text += "\n限流保护需安装新版完整包；详见更新说明。"
	apply_button.text = "热加载内容" if available and store.pending().get("kind") == "content_json" else "保存并重启应用"
	check_button.disabled = not available or (available and (service.busy or _limited()))
	download_button.disabled = not available or (available and (service.busy or _limited() or service.candidate.is_empty()))
	cancel_button.disabled = not available or (available and not service.busy)
	apply_button.disabled = not available or (available and (service.busy or store.pending().is_empty()))
	rollback_button.disabled = not available or (available and service.busy)
	automatic.disabled = not available
	selector.disabled = not available or (available and service.busy)
	if is_instance_valid(help_dialog) and help_dialog.visible: _refresh_help()


func _supports_rate_limit() -> bool:
	return service != null and service.has_method("rate_limit_remaining") and service.has_method("rate_limit_message")

func _limited() -> bool:
	return _supports_rate_limit() and service.rate_limit_remaining() > 0

func _build_help() -> void:
	help_dialog = AcceptDialog.new()
	help_dialog.title = "更新说明"
	help_dialog.min_size = Vector2i(570, 250)
	help_dialog.get_ok_button().text = "返回更新"
	help_dialog.theme = Theme.new()
	help_dialog.theme.default_font = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
	help_dialog.theme.default_font_size = 18
	help_dialog.theme.set_color("title_color", "Window", Color("f4eee2"))
	help_dialog.theme.set_color("font_disabled_color", "Button", Color("77766d"))
	add_child(help_dialog)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	help_dialog.add_child(box)
	help_text = Label.new()
	help_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help_text.custom_minimum_size = Vector2(540, 150)
	box.add_child(help_text)
	var row := HBoxContainer.new()
	box.add_child(row)
	help_previous = _button(row, "上一页", func(): help_page = maxi(0, help_page - 1); _refresh_help())
	help_next = _button(row, "下一页", func(): help_page = mini(2, help_page + 1); _refresh_help())

func _open_help() -> void:
	help_page = 0
	_refresh_help()
	help_dialog.popup_centered()

func _refresh_help() -> void:
	help_dialog.title = "更新说明 · %d / 3" % (help_page + 1)
	if help_page == 0:
		help_text.text = "GitHub 可能限制共享网络的请求次数，不表示没有新版本。\n\n等待期间暂停检查与下载；结束后可手动重试。切换频道或重开不会提前解除等待。游戏与存档不受影响。"
		if not _supports_rate_limit():
			help_text.text = "当前安装的更新器不支持限流保护。\n\n遇到限流可稍后再试，或从 GitHub Releases 下载新版完整包。无需账号或令牌；游戏与存档不受影响。"
	elif help_page == 1:
		help_text.text = "新版限流保护需要安装完整包。游戏内更新包不会替换旧更新器。\n\n正式频道只看稳定版；测试频道包含测试版。关闭自动检查后，可随时手动检查。"
	else:
		help_text.text = "下载并校验后仍需确认应用。文案与墨色可热加载；脚本更新保存后重启。\n\n回退会恢复更新前存档，请先阅读确认说明。"
		if service != null and not service.content_version.is_empty():
			help_text.text += "\n内容版本：" + service.content_version
		if store != null and not store.pending().is_empty():
			help_text.text += "\n已下载：" + str(store.pending().get("version", ""))
	help_previous.disabled = help_page == 0
	help_next.disabled = help_page == 2

func _confirm_apply() -> void:
	rolling_back = false
	confirmed_sha = str(store.pending().get("sha256", ""))
	confirmed_channel = service.channel
	confirmation.dialog_text = "现在保存进度，应用已校验的更新并重启？\n失败启动会回退到上一版本和更新前存档。\n引擎或启动器不兼容的版本需安装完整包。"
	if store.pending().get("kind") == "content_json":
		confirmation.dialog_text = "立即热加载山居文案与墨色？\n此更新仅含经过校验的数据，不执行脚本、不重启、不改存档。"
	confirmation.popup_centered()

func _confirm_rollback() -> void:
	rolling_back = true
	confirmed_previous = FileAccess.get_sha256("user://updates/previous.json")
	confirmation.dialog_text = "回退会恢复更新前的存档；更新后的进度不会自动合并。\n确认回退并重启？（当前存档会另存留档）"
	confirmation.popup_centered()

func _apply() -> void:
	confirmation.hide()
	if service.busy:
		return
	if not rolling_back and (confirmed_sha.is_empty() or str(store.pending().get("sha256", "")) != confirmed_sha or service.channel != confirmed_channel):
		info.text = "更新选择已变化，请重新确认。"
		return
	if rolling_back and FileAccess.get_sha256("user://updates/previous.json") != confirmed_previous:
		info.text = "回退目标已变化，请重新确认。"
		return
	if not rolling_back and store.pending().get("kind") == "content_json":
		service.apply_hot_content()
		_refresh()
		return
	if OS.has_feature("editor"):
		info.text = "开发环境不应用更新，请使用导出的完整程序验证。"
		return
	if not game._save_current():
		info.text = "保存失败，更新未应用。请检查磁盘空间或权限。"
		return
	# A failed filesystem transaction may already have restored one save file.
	# Never allow the still-running newer game to autosave over recovery data.
	_freeze_for_update()
	var ok: bool = store.rollback() if rolling_back else store.activate_pending()
	if not ok:
		_recovery_failure(str(store.error))
		return
	# Godot restarts the same installed executable; no downloaded executable runs.
	# Editor/source sessions cannot be relaunched safely as a standalone app.
	OS.set_restart_on_exit(true)
	get_tree().quit()

func _recovery_failure(message: String) -> void:
	confirmation.hide()
	_freeze_for_update()
	for b in [check_button, download_button, cancel_button, apply_button, rollback_button, selector, automatic]:
		b.disabled = true
	info.text = "更新事务中断；修行已暂停以保护存档。" + message
	var recovery := AcceptDialog.new()
	recovery.process_mode = Node.PROCESS_MODE_ALWAYS
	recovery.title = "安全恢复"
	recovery.dialog_text = "更新未完成，已暂停游戏，避免覆盖恢复中的存档。\n" + message + "\n确认后退出并重启恢复；不会再次保存当前场景。"
	recovery.get_ok_button().text = "退出并恢复"
	recovery.confirmed.connect(func(): OS.set_restart_on_exit(true); get_tree().quit(1))
	recovery.close_requested.connect(func(): OS.set_restart_on_exit(true); get_tree().quit(1))
	add_child(recovery)
	recovery.popup_centered()

func _freeze_for_update() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	game.closing = true
	game.set_meta("update_transaction", true)
	if not game.get_window().close_requested.is_connected(_safe_restart):
		game.get_window().close_requested.connect(_safe_restart)
	get_tree().paused = true

func _safe_restart() -> void:
	OS.set_restart_on_exit(true)
	get_tree().quit(1)
