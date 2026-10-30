extends RefCounted
## Local, read-only presentation. Never loads an updater or changes its state.
const UNKNOWN = "未知"
const TITLES = ["版本与环境", "实际渲染后端", "透明状态"]

static func clean(value, limit: int = 48) -> String:
	if not value is String: return UNKNOWN
	var result: String = value.replace("\n", " ").replace("\r", " ").replace("\t", " ").strip_edges()
	if result.is_empty(): return UNKNOWN
	return result if result.length() <= limit else result.left(limit - 1) + "…"

static func property_value(object, key: String):
	if not is_instance_valid(object): return null
	for entry in object.get_property_list():
		if entry.name == key: return object.get(key)
	return null

static func versions(store, service = null) -> Dictionary:
	var host = null
	if is_instance_valid(store):
		# The bootstrap's EXISTING script was loaded before mounting an active PCK.
		# ProjectSettings, service constants or a fresh preload are not host evidence.
		var script = store.get_script()
		if script is Script:
			host = script.get_script_constant_map().get("BUILTIN_VERSION")
	var running = property_value(store, "running_version")
	if running == null: running = property_value(service, "current_version")
	return {"host": clean(host), "running": clean(running),
		"context": "已安装宿主" if host is String and not host.is_empty() else "开发场景 / 宿主未知",
		"hot_content": clean(property_value(service, "content_version"))}

static func flag(snapshot: Dictionary, key: String) -> String:
	var value = snapshot.get(key)
	return ("是" if value else "否") if value is bool else UNKNOWN

static func rows(snapshot: Dictionary, version: Dictionary, page: int) -> Array:
	match page:
		0: return ["安装宿主：" + clean(version.get("host")),
			"运行内容：" + clean(version.get("running")),
			"热内容：" + clean(version.get("hot_content")),
			"来源：" + clean(version.get("context")),
			"系统：" + clean(snapshot.get("os")),
			"窗口系统：" + clean(snapshot.get("display_server"))]
		1: return ["渲染方式：" + clean(snapshot.get("rendering_method")),
			"实际驱动：" + clean(snapshot.get("rendering_driver")),
			"图形 API：" + clean(snapshot.get("adapter_api")),
			"显卡：" + clean(snapshot.get("adapter_name")),
			"厂商：" + clean(snapshot.get("adapter_vendor")),
			"仅反映当前后端，不推断启动器选择。"]
		_: return ["透明请求：" + flag(snapshot, "transparency_requested"),
			"系统报告支持：" + flag(snapshot, "transparency_supported"),
			"原生窗口就绪：" + flag(snapshot, "native_window_ready"),
			"辅助器已应用：" + flag(snapshot, "helper_transparency_applied"),
			"窗口透明标记：" + (flag(snapshot, "window_transparent_flag") if snapshot.get("window_attached") == true else UNKNOWN),
			"视口透明背景：" + (flag(snapshot, "viewport_transparent_background") if snapshot.get("window_attached") == true else UNKNOWN),
			"标记 / 支持不代表透明显示成功。"]

static func fit(text: String, font: Font, font_size: int, width: float) -> String:
	var result = clean(text, 96)
	if font.get_string_size(result, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width: return result
	while result.length() > 1:
		result = result.left(result.length() - 1)
		if font.get_string_size(result + "…", HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x <= width: return result + "…"
	return "…"
