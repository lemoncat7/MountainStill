extends AcceptDialog
## A deliberately explicit two-step update: download, then save/apply/restart.
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
var confirmation: ConfirmationDialog
var rolling_back := false
var confirmed_sha := ""
var confirmed_channel := ""
var confirmed_previous := ""

func setup(owner_game: Control) -> void:
	game = owner_game
	title = "山居更新 · GitHub Releases"
	min_size = Vector2i(570, 300)
	get_ok_button().text = "关闭（继续修行）"
	add_theme_font_override("font", preload("res://assets/fonts/NotoSansCJK-Regular.ttc"))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	add_child(box)
	info = Label.new()
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info.custom_minimum_size = Vector2(540, 100)
	box.add_child(info)
	selector = OptionButton.new()
	selector.add_item("正式频道 · 只看稳定版本")
	selector.add_item("测试频道 · 含测试版和正式版")
	box.add_child(selector)
	automatic = CheckButton.new()
	automatic.text = "运行时自动检查（启动后 / 每 6 小时；关闭即手动离线模式）"
	box.add_child(automatic)
	var row := HBoxContainer.new()
	box.add_child(row)
	check_button = _button(row, "检查更新", func(): service.check_updates())
	download_button = _button(row, "下载更新", func(): service.download_update())
	cancel_button = _button(row, "取消下载", func(): service.cancel())
	apply_button = _button(row, "保存并重启应用", _confirm_apply)
	rollback_button = _button(box, "回退到上一版本（恢复更新前存档）…", _confirm_rollback)
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
		info.text = "当前版本：" + store.current_version() + "\n" + service.status + "\n存档保留在本机；下载不会自动应用。脚本更新需重启，不覆盖安装目录。"
		if not service.content_version.is_empty():
			info.text += "\n内容版本：" + service.content_version
		if not store.pending().is_empty():
			info.text += "\n已下载：" + str(store.pending().get("version", "")) + ("（文案 / 墨色，可热加载）" if store.pending().get("kind") == "content_json" else "（等待你确认重启）")
	apply_button.text = "热加载内容" if available and store.pending().get("kind") == "content_json" else "保存并重启应用"
	check_button.disabled = not available or (available and service.busy)
	download_button.disabled = not available or (available and (service.busy or service.candidate.is_empty()))
	cancel_button.disabled = not available or (available and not service.busy)
	apply_button.disabled = not available or (available and (service.busy or store.pending().is_empty()))
	rollback_button.disabled = not available or (available and service.busy)
	automatic.disabled = not available
	selector.disabled = not available or (available and service.busy)

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
