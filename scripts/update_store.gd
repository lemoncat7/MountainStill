extends RefCounted
## Installed bootstrap-owned update journal. No code is mounted by this class.
const Guard = preload("res://scripts/update_pack_guard.gd")
const Policy = preload("res://scripts/update_policy.gd")
const BUILTIN_VERSION = "1.3.17-test.1"
const MAX_PACK = 536870912
var directory = "user://updates"
var save_path = "user://cultivation_save.json"
var platform = "windows" if OS.get_name() == "Windows" else ("macos" if OS.get_name() == "macOS" else "unsupported")
var status = ""
var error = ""
var running_version = BUILTIN_VERSION

func current_version() -> String:
	return running_version

func _read(name: String) -> Dictionary:
	var path = directory.path_join(name)
	if not FileAccess.file_exists(path): return {}
	var f = FileAccess.open(path, FileAccess.READ)
	if f == null or f.get_length() > 65536: return {}
	var parser = JSON.new()
	if parser.parse(f.get_as_text()) != OK: return {}
	return parser.data if parser.data is Dictionary else {}

func _write(name: String, value: Dictionary) -> bool:
	if DirAccess.make_dir_recursive_absolute(directory) != OK: return _fail("更新目录无法写入")
	var path = directory.path_join(name)
	var f = FileAccess.open(path + ".tmp", FileAccess.WRITE)
	if f == null: return _fail("更新记录无法写入")
	f.store_string(JSON.stringify(value)); f.flush()
	var result = f.get_error(); f.close()
	if result != OK: return _fail("更新记录写入失败")
	if DirAccess.rename_absolute(path + ".tmp", path) != OK: return _fail("更新记录提交失败")
	return true

func _remove(name: String) -> bool:
	if FileAccess.file_exists(directory.path_join(name)) and DirAccess.remove_absolute(directory.path_join(name)) != OK:
		return _fail("更新记录清理失败；请检查磁盘权限")
	return true

func _fail(message: String) -> bool:
	error = message; status = message
	return false

func _number_is(value, expected: int) -> bool:
	return (value is int or value is float) and float(value) == float(expected)

func validate(record: Dictionary) -> bool:
	if record.is_empty(): return false
	var hash = str(record.get("sha256", ""))
	if hash.length() != 64 or not hash.is_valid_hex_number(false): return false
	if hash != hash.to_lower(): return false
	if str(record.get("path", "")) != directory.path_join(hash + ".pck"): return false
	if str(record.get("engine", "")) != "4.6.3" or str(record.get("platform", "")) != platform: return false
	if not _number_is(record.get("schema"), 1) or not _number_is(record.get("bootstrap"), 1) or not _number_is(record.get("save_schema"), 4): return false
	if str(record.get("kind", "")) != "pck" or not record.get("restart_required") is bool or not record.restart_required: return false
	var version = str(record.get("version", ""))
	var regex = RegEx.new(); regex.compile("^[0-9]+\\.[0-9]+\\.[0-9]+(-[0-9A-Za-z.-]+)?(\\+[0-9A-Za-z.-]+)?$")
	if regex.search(version) == null: return false
	var size_value = record.get("size", 0)
	if not (size_value is int or size_value is float): return false
	if float(size_value) != float(int(size_value)) or int(size_value) < 12 or int(size_value) > MAX_PACK: return false
	var f = FileAccess.open(record.path, FileAccess.READ)
	if f == null: return false
	var length = f.get_length(); var magic = f.get_32(); f.close()
	if length != int(size_value) or magic != 0x43504447: return false
	return FileAccess.get_sha256(record.path) == hash and Guard.validate(record.path)

func pending() -> Dictionary:
	return _read("pending.json")

func _snapshot() -> Dictionary:
	var result = {}
	var prefix = "snapshot-" + str(Time.get_unix_time_from_system()).replace(".", "-") + "-" + str(Time.get_ticks_usec())
	for suffix in ["", ".bak"]:
		var source = save_path + suffix
		var target = directory.path_join(prefix + suffix)
		var exists = FileAccess.file_exists(source)
		if exists and DirAccess.copy_absolute(source, target) != OK:
			_fail("无法备份存档；更新未应用"); return {}
		result[suffix] = exists
	return {"files": result, "prefix": prefix}

func _restore(snapshot: Dictionary) -> bool:
	if not snapshot.get("files") is Dictionary or not str(snapshot.get("prefix", "")).begins_with("snapshot-") or "/" in str(snapshot.get("prefix", "")) or "\\" in str(snapshot.get("prefix", "")): return _fail("更新存档备份记录损坏；已停止启动")
	for suffix in ["", ".bak"]:
		var target = save_path + suffix
		var preserved = directory.path_join("recovered-newer-" + str(snapshot.prefix) + suffix)
		if FileAccess.file_exists(target) and not FileAccess.file_exists(preserved):
			if DirAccess.copy_absolute(target, preserved + ".tmp") != OK: return _fail("无法保留新版本存档；已停止回退")
			if FileAccess.get_sha256(target) != FileAccess.get_sha256(preserved + ".tmp"): return _fail("新版本存档保留校验失败；已停止回退")
			if DirAccess.rename_absolute(preserved + ".tmp", preserved) != OK: return _fail("无法提交新版本存档备份；已停止回退")
		if bool(snapshot.files.get(suffix, false)):
			if DirAccess.copy_absolute(directory.path_join(str(snapshot.prefix) + suffix), target + ".update-restore") != OK: return _fail("存档备份无法恢复")
			if DirAccess.rename_absolute(target + ".update-restore", target) != OK: return _fail("存档恢复失败")
		elif FileAccess.file_exists(target):
			if DirAccess.remove_absolute(target) != OK: return _fail("存档恢复失败")
	return true

func activate_pending() -> bool:
	error = ""
	var record = pending()
	if not validate(record): return _fail("更新包校验失败，请重新下载")
	if Policy.compare(str(record.version), running_version) <= 0: return _fail("更新版本不高于当前版本；请重新检查")
	if not _read("booting.json").is_empty(): return _fail("已有更新等待重启")
	var old = _read("active.json")
	if not old.is_empty() and not validate(old): return _fail("当前更新损坏，请先安全回退")
	var snapshot = _snapshot()
	if snapshot.is_empty(): return false
	if not _write("previous.json", {"record": old, "snapshot": snapshot}): return false
	if not _write("booting.json", {"phase": "armed", "sha256": record.sha256}): return false
	if not _write("active.json", record): return false
	_remove("pending.json")
	status = "更新已准备；重启后生效"
	return true

func rollback() -> bool:
	error = ""
	var previous = _read("previous.json")
	if previous.is_empty(): return _fail("没有可回退的更新")
	var old = previous.get("record", {})
	if not old is Dictionary or (not old.is_empty() and not validate(old)): return _fail("上一版本校验失败；已停止回退")
	# Keep journal until save AND pointer restoration complete: retry after interruption.
	if not _write("booting.json", {"phase": "rollback"}): return false
	if not _restore(previous.get("snapshot", {})): return false
	if not _write("active.json", old): return false
	if not _remove("booting.json"): return false
	if not _remove("previous.json"): return false
	status = "已回退上一版本及更新前存档"
	return true

func startup() -> Dictionary:
	error = ""
	running_version = BUILTIN_VERSION
	var journal = _read("booting.json")
	var record = _read("active.json")
	if FileAccess.file_exists(directory.path_join("active.json")):
		var active_file = FileAccess.open(directory.path_join("active.json"), FileAccess.READ)
		if active_file == null or active_file.get_length() > 65536:
			_fail("当前更新记录无法读取或过大；请使用安全模式回退"); return {}
		var parser = JSON.new()
		if parser.parse(active_file.get_as_text()) != OK or not parser.data is Dictionary:
			_fail("当前更新记录损坏；请使用安全模式回退"); return {}
	if FileAccess.file_exists(directory.path_join("booting.json")) and journal.is_empty():
		_fail("更新启动记录损坏；请使用安全模式"); return {}
	if not journal.is_empty():
		if str(journal.get("phase", "")) != "armed" or str(journal.get("sha256", "")) != str(record.get("sha256", "")):
			if not rollback(): return {}
			record = _read("active.json")
		else:
			if not _write("booting.json", {"phase": "launching", "sha256": record.get("sha256")}): return {}
	if not record.is_empty() and not validate(record):
		if not rollback(): return {}
		record = _read("active.json")
	if not record.is_empty(): running_version = str(record.version)
	return record

func mark_healthy() -> void:
	if str(_read("booting.json").get("phase", "")) == "launching":
		if not _remove("booting.json"): return
		status = "更新已生效；可在设置中回退"
