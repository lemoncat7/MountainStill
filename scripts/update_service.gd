extends Node
## Downloads only. UpdateStore/UI must explicitly activate staged content.
const Policy = preload("res://scripts/update_policy.gd")
const CURRENT_VERSION = "1.3.10-test.1"
const ROOT = "user://updates/"
const PART = ROOT + "download.part"
const PENDING = ROOT + "pending.json"
signal changed
signal content_applied(data: Dictionary)
var status = "更新由你决定；存档始终保留在本地。"
var channel = "stable"
var candidate: Dictionary = {}
var busy = false
var downloaded = false
var auto_check = true
var _auto_timer: Timer
var content_version = ""
var _content: Dictionary = {}
var current_version = CURRENT_VERSION
var _request: HTTPRequest
var _generation = 0
var _release: Dictionary = {}
var _manifest_asset: Dictionary = {}
var _releases: Array = []
var _page = 1
var _phase = ""
var _redirects = 0
var _url = ""
var _limit = 0
var _last_progress = -1

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(ROOT))
	# A .part or temporary manifest can never be activated.
	_cleanup_part()
	var preferences = ConfigFile.new()
	if preferences.load(ROOT + "preferences.cfg") == OK:
		auto_check = bool(preferences.get_value("updates", "auto_check", true))
		channel = "testing" if preferences.get_value("updates", "channel", "stable") == "testing" else "stable"
	downloaded = FileAccess.file_exists(PENDING)
	var active_content = _read_content_pointer(ROOT + "content-active.json")
	if not active_content.is_empty():
		_content = active_content.data
		content_version = active_content.pointer.version
	_auto_timer = Timer.new()
	_auto_timer.one_shot = true
	_auto_timer.timeout.connect(_automatic_check)
	add_child(_auto_timer)
	if auto_check: _auto_timer.start(15.0)

func platform_name() -> String:
	return {"Windows": "windows", "macOS": "macos"}.get(OS.get_name(), "")

func set_channel(value: String) -> void:
	if value not in ["stable", "testing"] or value == channel: return
	cancel()
	if FileAccess.file_exists(PENDING):
		if DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING)) != OK:
			_finish("无法清除已下载的旧通道更新；未切换通道。")
			return
	downloaded = false
	channel = value
	candidate = {}
	var preferences = ConfigFile.new()
	preferences.set_value("updates", "auto_check", auto_check)
	preferences.set_value("updates", "channel", channel)
	if preferences.save(ROOT + "preferences.cfg") != OK:
		_finish("无法保存更新通道；本次选择仍然有效。")
	else: _finish("已切换通道并撤下旧下载选择；请重新检查更新。")

func check_updates() -> void:
	if busy: return
	if platform_name() == "":
		_finish("此平台不提供游戏内更新；目前支持 Windows 和 macOS。")
		return
	var store = get_tree().root.get_meta("update_store") if get_tree().root.has_meta("update_store") else null
	if store != null and store.has_method("current_version"):
		current_version = store.current_version()
	candidate = {}
	_releases = []
	_page = 1
	busy = true
	_phase = "releases"
	status = "正在检查 GitHub 发布版本…"
	changed.emit()
	_start(Policy.API + "?per_page=100&page=1", 4 * 1024 * 1024)

func download_update() -> void:
	if busy or candidate.is_empty(): return
	busy = true
	_phase = "pack"
	status = "正在下载更新；下载完成后仍需你确认应用。"
	_last_progress = -1
	changed.emit()
	_start(candidate.url, int(candidate.size))

func cancel() -> void:
	_generation += 1
	if is_instance_valid(_request):
		_request.cancel_request()
		_request.queue_free()
		_request = null
	_cleanup_part()
	if busy: _finish("已取消；当前游戏与存档未改变。")

func _exit_tree() -> void:
	cancel()

func _process(_delta: float) -> void:
	if busy and _phase == "pack" and is_instance_valid(_request) and not candidate.is_empty():
		var progress = int(100.0 * _request.get_downloaded_bytes() / maxi(1, int(candidate.size)))
		if progress != _last_progress:
			_last_progress = progress
			status = "正在下载更新 %d%%；可随时取消。" % mini(progress, 100)
			changed.emit()

func _start(url: String, limit: int, redirect: bool = false) -> void:
	if not redirect: _redirects = 0
	_url = url
	_limit = limit
	_generation += 1
	var token = _generation
	if is_instance_valid(_request): _request.queue_free()
	_request = HTTPRequest.new()
	_request.timeout = 180.0 if _phase == "pack" else 30.0
	_request.max_redirects = 0
	_request.body_size_limit = limit
	_request.accept_gzip = false
	_request.use_threads = true
	_configure_environment_proxy(_request)
	if _phase == "pack": _request.download_file = PART
	add_child(_request)
	_request.request_completed.connect(func(result, code, headers, body):
		if token == _generation: _completed(result, code, headers, body))
	var error = _request.request(url, PackedStringArray(["Accept: application/vnd.github+json" if _phase == "releases" else "Accept: application/octet-stream", "User-Agent: MountainStill-Updater/1", "X-GitHub-Api-Version: 2022-11-28"]))
	if error != OK: _fail("无法开始连接，请稍后重试。")

func _completed(result: int, code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	# Godot reports redirect-limit when max_redirects=0; inspect the status first.
	if code in [301, 302, 303, 307, 308]:
		var location = ""
		for header in headers:
			if header.to_lower().begins_with("location:"): location = header.substr(9).strip_edges()
		if _phase == "releases" or _redirects >= 3 or not Policy.allowed_redirect(location):
			_fail("更新服务器返回了不允许的跳转。")
			return
		_redirects += 1
		_cleanup_part()
		_start(location, _limit, true)
		return
	if code in [403, 429]:
		_fail("GitHub 请求受限，请稍后重试；游戏不受影响。")
		return
	if result != HTTPRequest.RESULT_SUCCESS or code != 200:
		_fail("更新连接失败（HTTP %d）；请检查网络后重试。" % code)
		return
	if _phase == "pack":
		_stage_pack()
		return
	var parser = JSON.new()
	if parser.parse(body.get_string_from_utf8()) != OK:
		_fail("更新服务器返回了无效的 JSON；未修改游戏。")
		return
	var data = parser.data
	if _phase == "releases":
		if not data is Array:
			_fail("发布列表格式无效。")
			return
		_releases.append_array(data)
		if data.size() == 100:
			_page += 1
			if _page > 10:
				_fail("发布列表过长，未能完整检查；请稍后重试。")
				return
			_start(Policy.API + "?per_page=100&page=" + str(_page), 4 * 1024 * 1024)
			return
		_release = Policy.select_release(_releases, current_version, channel)
		if _release.is_empty():
			_finish("当前已是所选通道的最新版本。")
			return
		var manifest = Policy.asset(_release, Policy.MANIFEST)
		if manifest.is_empty() or not (manifest.get("size") is int or manifest.get("size") is float) or manifest.get("size", 0) < 2 or manifest.get("size", 0) > 65536:
			_fail("发现 %s，但该版本未提供兼容的游戏内更新清单。" % _release.tag_name)
			return
		_manifest_asset = manifest
		_phase = "manifest"
		_start(manifest.browser_download_url, 65536)
	else:
		if body.size() != int(_manifest_asset.size):
			_fail("更新清单大小不符；请重新检查。")
			return
		var manifest_digest = _manifest_asset.get("digest")
		if manifest_digest != null:
			var digest = HashingContext.new()
			digest.start(HashingContext.HASH_SHA256)
			digest.update(body)
			if not manifest_digest is String or manifest_digest != "sha256:" + digest.finish().hex_encode():
				_fail("更新清单哈希不符；请重新检查。")
				return
		candidate = Policy.validate_manifest(data, _release, platform_name())
		if candidate.is_empty():
			_fail("更新清单不兼容或校验信息无效；未修改游戏。")
			return
		if candidate.kind == "content_json" and content_version != "" and Policy.compare(candidate.version, content_version) <= 0:
			candidate = {}
			_finish("此内容更新已经应用；当前游戏版本保持不变。")
			return
		_finish(("发现 %s；可下载并确认热加载配色与公告。" if candidate.kind == "content_json" else "发现 %s；可下载并在确认后重启应用。") % candidate.version)

func _stage_pack() -> void:
	var file = FileAccess.open(PART, FileAccess.READ)
	if file == null:
		_fail("无法读取下载文件。")
		return
	var length = file.get_length()
	var magic = file.get_buffer(4)
	file.close()
	if length != int(candidate.size) or (candidate.kind == "pck" and magic != PackedByteArray([71, 68, 80, 67])) or FileAccess.get_sha256(PART) != candidate.sha256:
		_fail("下载校验失败，已丢弃；当前版本未改变。")
		return
	if candidate.kind == "content_json":
		var content_parser = JSON.new()
		if content_parser.parse(FileAccess.get_file_as_string(PART)) != OK or not Policy.validate_content(content_parser.data):
			_fail("内容更新格式无效；只允许配色与公告文本。")
			return
	var destination = ROOT + candidate.sha256 + (".json" if candidate.kind == "content_json" else ".pck")
	# Existing verified content is safe to reuse. Never remove active pack files.
	if FileAccess.file_exists(destination):
		if FileAccess.get_sha256(destination) != candidate.sha256:
			_fail("本地更新文件校验失败；请关闭游戏后检查更新目录。")
			return
		_cleanup_part()
	elif DirAccess.rename_absolute(ProjectSettings.globalize_path(PART), ProjectSettings.globalize_path(destination)) != OK:
		_fail("无法保存更新，请检查磁盘空间与权限。")
		return
	var staged = candidate.duplicate(true)
	staged["path"] = destination
	var output = FileAccess.open(PENDING + ".tmp", FileAccess.WRITE)
	if output == null:
		_fail("无法保存更新状态；当前版本未改变。")
		return
	output.store_string(JSON.stringify(staged))
	output.flush()
	var write_error = output.get_error()
	output.close()
	if write_error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(PENDING + ".tmp"), ProjectSettings.globalize_path(PENDING)) != OK:
		_fail("无法提交更新状态；当前版本未改变。")
		return
	downloaded = true
	_finish("下载校验完成。确认后热加载配色与公告，无需重启。" if candidate.kind == "content_json" else "下载校验完成。确认应用后需重启；存档不会被覆盖。")

func _cleanup_part() -> void:
	for path in [PART, PENDING + ".tmp"]:
		if FileAccess.file_exists(path): DirAccess.remove_absolute(ProjectSettings.globalize_path(path))

func _fail(message: String) -> void:
	_cleanup_part()
	_finish(message)

func _finish(message: String) -> void:
	busy = false
	status = message
	changed.emit()

func content_data() -> Dictionary:
	return _content.duplicate(true)

func _read_content_pointer(path: String) -> Dictionary:
	if not FileAccess.file_exists(path): return {}
	var pointer_file = FileAccess.open(path, FileAccess.READ)
	if pointer_file == null or pointer_file.get_length() > 65536: return {}
	var parser = JSON.new()
	if parser.parse(pointer_file.get_as_text()) != OK: return {}
	var pointer = parser.data
	if not pointer is Dictionary: return {}
	if not pointer.get("kind") is String or pointer.get("kind") != "content_json" or Policy.version(pointer.get("version")).is_empty(): return {}
	if not Policy.exact_number(pointer.get("schema"), 1) or not Policy.exact_number(pointer.get("bootstrap"), 1) or not Policy.exact_number(pointer.get("save_schema"), 4): return {}
	if not pointer.get("engine") is String or pointer.engine != Policy.ENGINE: return {}
	if not pointer.get("sha256") is String or pointer.sha256.length() != 64 or not pointer.sha256.is_valid_hex_number(): return {}
	if not pointer.get("size") is int and not pointer.get("size") is float: return {}
	if pointer["size"] != int(pointer["size"]) or pointer["size"] < 4 or pointer["size"] > 16384: return {}
	var expected_path = ROOT + pointer.sha256 + ".json"
	if not pointer.get("path") is String or pointer.path != expected_path: return {}
	var file = FileAccess.open(expected_path, FileAccess.READ)
	if file == null or file.get_length() != int(pointer["size"]): return {}
	if FileAccess.get_sha256(expected_path) != pointer.sha256: return {}
	if parser.parse(file.get_as_text()) != OK or not Policy.validate_content(parser.data): return {}
	return {"pointer": pointer, "data": parser.data}

func apply_hot_content() -> bool:
	if busy: return false
	var staged = _read_content_pointer(PENDING)
	if staged.is_empty():
		_finish("无法应用内容更新：校验失败或没有待应用内容。")
		return false
	if content_version != "" and Policy.compare(staged.pointer.version, content_version) <= 0:
		_finish("该内容版本已应用或较旧；无需再次应用。")
		return false
	var temp = ROOT + "content-active.json.tmp"
	var file = FileAccess.open(temp, FileAccess.WRITE)
	if file == null: return false
	file.store_string(JSON.stringify(staged.pointer))
	file.flush()
	var error = file.get_error()
	file.close()
	if error != OK or DirAccess.rename_absolute(ProjectSettings.globalize_path(temp), ProjectSettings.globalize_path(ROOT + "content-active.json")) != OK:
		_finish("内容更新无法保存；原配色保持不变。")
		return false
	_content = staged.data
	content_version = staged.pointer.version
	DirAccess.remove_absolute(ProjectSettings.globalize_path(PENDING))
	downloaded = false
	content_applied.emit(content_data())
	_finish("配色与公告已热加载；游戏进度和游戏版本未改变。")
	return true

func set_auto_check(enabled: bool) -> void:
	auto_check = enabled
	if not enabled and busy and _phase != "pack": cancel()
	var preferences = ConfigFile.new()
	preferences.set_value("updates", "auto_check", auto_check)
	preferences.set_value("updates", "channel", channel)
	if preferences.save(ROOT + "preferences.cfg") != OK:
		status = "自动检查偏好未能保存；本次设置已生效。"
	if is_instance_valid(_auto_timer):
		if enabled: _auto_timer.start(15.0)
		else: _auto_timer.stop()
	changed.emit()

func _automatic_check() -> void:
	if not auto_check: return
	# Poll only while the game is running. Never download/apply without a click.
	if not busy: check_updates()
	if is_instance_valid(_auto_timer): _auto_timer.start(6 * 60 * 60)

static func parse_proxy(value: String) -> Dictionary:
	# Godot supports HTTP CONNECT proxies without embedded credentials. Never log values.
	if value.is_empty() or value.length() > 512: return {}
	var pattern = RegEx.new()
	pattern.compile("^http://([A-Za-z0-9.-]+)(?::([0-9]{1,5}))?/?$")
	var matched = pattern.search(value)
	if matched == null or matched.get_string() != value: return {}
	var port = 80 if matched.get_string(2).is_empty() else int(matched.get_string(2))
	if port < 1 or port > 65535: return {}
	return {"host": matched.get_string(1), "port": port}

func _configure_environment_proxy(request_node: HTTPRequest) -> void:
	# Existing app environment only: no system settings, credentials, or TLS bypass.
	var value = OS.get_environment("HTTPS_PROXY")
	if value.is_empty(): value = OS.get_environment("https_proxy")
	var proxy = parse_proxy(value)
	if not proxy.is_empty(): request_node.set_https_proxy(proxy.host, proxy.port)
	value = OS.get_environment("HTTP_PROXY")
	if value.is_empty(): value = OS.get_environment("http_proxy")
	proxy = parse_proxy(value)
	if not proxy.is_empty(): request_node.set_http_proxy(proxy.host, proxy.port)
