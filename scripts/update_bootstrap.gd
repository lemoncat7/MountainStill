extends Node
## These scripts are loaded from the installed pack BEFORE any downloaded pack.
const Store = preload("res://scripts/update_store.gd")
const Service = preload("res://scripts/update_service.gd")
var _instance_lock = TCPServer.new()
var store = Store.new()
var service: Node

func _ready() -> void:
	# Fail closed before updater or gameplay can touch shared user data.
	if _instance_lock.listen(47893, "127.0.0.1") != OK:
		_show_lock_failure(); return
	name = "UpdateBootstrap"
	get_tree().root.set_meta("update_store", store)
	service = Service.new()
	service.name = "UpdateService"
	get_tree().root.add_child.call_deferred(service)
	get_tree().root.set_meta("update_service", service)
	_start.call_deferred()

func _start() -> void:
	if "--safe-mode" in OS.get_cmdline_user_args():
		if FileAccess.file_exists("user://updates/previous.json") and not store.rollback():
			_show_failure(store.error); return
	var record = store.startup()
	if not store.error.is_empty():
		_show_failure(store.error); return
	if not record.is_empty():
		if not ProjectSettings.load_resource_pack(record.path, true):
			_show_failure("更新包无法加载。请退出重启，系统将恢复上一版。")
			return
	service.current_version = store.current_version()
	get_tree().root.set_meta("update_version", store.current_version())
	print("UPDATE BOOT: " + store.current_version() + (" / " + store.status if not store.status.is_empty() else ""))
	get_tree().root.set_meta("update_gameplay_ready", false)
	var scene = ResourceLoader.load("res://main.tscn", "PackedScene", ResourceLoader.CACHE_MODE_IGNORE)
	if not scene is PackedScene or not scene.can_instantiate():
		_show_failure("新版本场景无法加载。请退出重启以恢复上一版。")
		return
	var game = scene.instantiate()
	if game == null:
		_show_failure("新版本无法启动。请退出重启以恢复上一版。")
		return
	get_tree().root.add_child(game)
	get_tree().current_scene = game
	for _frame in range(3): await get_tree().process_frame
	if is_instance_valid(game) and bool(get_tree().root.get_meta("update_gameplay_ready", false)):
		store.mark_healthy()
		if not store.error.is_empty():
			game.process_mode = Node.PROCESS_MODE_DISABLED
			game.free()
			_show_failure(store.error + "。启动确认未完成，请重启恢复。")
	else:
		if is_instance_valid(game):
			game.process_mode = Node.PROCESS_MODE_DISABLED
			game.free()
		_show_failure("新版本未完成启动。请退出重启以恢复上一版。")

func _show_failure(message: String) -> void:
	get_tree().paused = true
	push_error(message)
	var panel = AcceptDialog.new()
	panel.process_mode = Node.PROCESS_MODE_ALWAYS
	panel.title = "山隐 · 更新恢复"
	panel.dialog_text = message + "\n未覆盖安装包；更新前存档仍保留。"
	panel.confirmed.connect(func():
		if OS.has_feature("standalone"): OS.set_restart_on_exit(true)
		get_tree().quit(1))
	add_child(panel)
	if DisplayServer.get_name() != "headless": panel.popup_centered(Vector2i(520, 180))
	else: get_tree().quit(1)

func _show_lock_failure() -> void:
	var message = "已有山隐正在运行 / 本地更新锁不可用。\n请关闭另一个山隐窗口后重试；存档未被修改。"
	print("UPDATE LOCK: " + message)
	if DisplayServer.get_name() == "headless":
		get_tree().quit(2); return
	var panel = AcceptDialog.new()
	panel.title = "山隐 · 启动保护"
	panel.dialog_text = message
	panel.confirmed.connect(func(): get_tree().quit(2))
	panel.canceled.connect(func(): get_tree().quit(2))
	add_child(panel)
	panel.popup_centered(Vector2i(520, 180))
