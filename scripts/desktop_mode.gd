class_name DesktopMode
extends RefCounted
## Conservative native-window helper. No global hooks, injected code, or
## whole-window input passthrough. Main owns all restore shortcut handling.

const NORMAL_SIZE := Vector2i(1200, 400)
const STRIP_SIZE := Vector2i(1200, 320)
const MARGIN := 12

var strip_enabled := false
var top_enabled := false
var transparent_enabled := false
var passthrough_enabled := false
var desired_top := false
var desired_transparent := false
var desired_passthrough := false
var _window: Window
var _normal_size := NORMAL_SIZE
var _normal_position := Vector2i.ZERO
var _safe_rect := Rect2()
var _interactive_rects: Array = []
var _note := ""
var _last_polygon := PackedVector2Array()


func attach(window: Window) -> void:
	dispose()
	_window = window
	if not is_instance_valid(_window):
		return
	_normal_size = _window.size
	_normal_position = _window.position
	_window.min_size = Vector2i(1000, 320)
	_window.mouse_passthrough = false
	_window.mouse_passthrough_polygon = PackedVector2Array()
	if not _window.size_changed.is_connected(_on_size_changed):
		_window.size_changed.connect(_on_size_changed)
	if not _window.tree_exiting.is_connected(dispose):
		_window.tree_exiting.connect(dispose)


func dispose() -> void:
	# A Window signal's bound Callable owns this RefCounted helper, while the
	# helper owns the Window reference. Explicitly detach before scene teardown.
	if is_instance_valid(_window):
		_clear_passthrough()
		if _window.size_changed.is_connected(_on_size_changed):
			_window.size_changed.disconnect(_on_size_changed)
		if _window.tree_exiting.is_connected(dispose):
			_window.tree_exiting.disconnect(dispose)
	_window = null
	_safe_rect = Rect2()
	_interactive_rects.clear()


func set_strip(enabled: bool) -> void:
	if not _ready_window():
		return
	if enabled == strip_enabled:
		return
	_clear_passthrough()
	if enabled:
		_normal_size = _window.size
		_normal_position = _window.position
	strip_enabled = enabled
	_window.mode = Window.MODE_WINDOWED
	_window.borderless = enabled
	_window.unresizable = enabled
	_window.min_size = Vector2i(1000, 320)
	_note = ""
	if enabled:
		_window.size = _fit_size(STRIP_SIZE)
		_snap_bottom()
		set_top(desired_top)
		set_transparent(desired_transparent)
		set_passthrough(desired_passthrough)
	else:
		_window.transparent = false
		_window.transparent_bg = false
		transparent_enabled = false
		_window.size = _fit_size(_normal_size)
		_window.position = _clamp_position(_normal_position, _window.size)


func set_top(enabled: bool) -> void:
	desired_top = enabled
	top_enabled = enabled
	if _ready_window():
		_window.always_on_top = enabled
		if DisplayServer.get_name().to_lower() == "wayland" and enabled:
			_note = "Wayland 的置顶效果由桌面合成器决定。"


func set_transparent(enabled: bool) -> bool:
	desired_transparent = enabled
	if not _ready_window():
		return false
	if not strip_enabled:
		transparent_enabled = false
		_window.transparent = false
		_window.transparent_bg = false
		return true
	if enabled and not DisplayServer.is_window_transparency_available():
		transparent_enabled = false
		_window.transparent = false
		_window.transparent_bg = false
		_note = "当前渲染器或桌面合成器不支持透明背景。"
		return false
	transparent_enabled = enabled
	_window.transparent_bg = enabled
	_window.transparent = enabled
	_note = ""
	return true


func set_passthrough(enabled: bool) -> void:
	desired_passthrough = enabled
	_clear_passthrough()
	if not enabled:
		_note = ""
		return
	if not _ready_window():
		return
	if not strip_enabled:
		_note = "已记住穿透偏好，仅在桌面小窗模式应用。"
		return
	var backend := DisplayServer.get_name().to_lower()
	if OS.get_name() == "Windows":
		_note = "Windows 暂不启用穿透，以免 Godot 隐藏景观画面。"
		return
	if backend != "x11" and OS.get_name() != "macOS":
		_note = "景观区穿透仅支持 macOS 或 Linux X11。"
		return
	if not _usable_input_rect(_safe_rect):
		_note = "右上小印与顶部安全区尚未就绪，鼠标穿透保持关闭。"
		return
	passthrough_enabled = true
	_note = "空白区可穿透，右上小印、顶部安全区与场景入口仍可操作。"
	_apply_passthrough()


func set_width(width: int) -> void:
	if not _ready_window():
		return
	_window.size = _fit_size(Vector2i(maxi(width, 1000), _window.size.y))
	if strip_enabled:
		_snap_bottom()
	else:
		_window.position = _clamp_position(_window.position, _window.size)
	_apply_passthrough()


func safe_restore() -> void:
	_clear_passthrough()
	strip_enabled = false
	top_enabled = false
	transparent_enabled = false
	desired_top = false
	desired_transparent = false
	desired_passthrough = false
	if not _ready_window():
		return
	_window.mode = Window.MODE_WINDOWED
	_window.unfocusable = false
	_window.unresizable = false
	_window.always_on_top = false
	_window.transparent = false
	_window.transparent_bg = false
	_window.borderless = false
	_window.min_size = Vector2i(1000, 320)
	_window.size = _fit_size(NORMAL_SIZE)
	_window.position = _center_position(_window.size)
	_window.grab_focus()
	_note = "已安全恢复普通窗口。"


func update_passthrough(safe_rect: Rect2, interactive_rects: Array = []) -> void:
	# Rectangles are in root-viewport coordinates. The full-width recovery band
	# and connected stems down to scene hotspots always retain native input.
	_safe_rect = safe_rect
	_interactive_rects = interactive_rects.duplicate()
	if not passthrough_enabled and desired_passthrough and strip_enabled:
		set_passthrough(true)
	_apply_passthrough()


func status() -> String:
	var mode_text := "桌面小窗" if strip_enabled else "普通窗口"
	if not _note.is_empty():
		return "%s · %s" % [mode_text, _note]
	return "%s · %s" % [mode_text, DisplayServer.get_name()]


func begin_drag() -> bool:
	if _ready_window() and DisplayServer.has_feature(DisplayServer.FEATURE_WINDOW_DRAG):
		_window.start_drag()
		return true
	return false


func _ready_window() -> bool:
	return is_instance_valid(_window) and DisplayServer.get_name() != "headless"


func _clear_passthrough() -> void:
	passthrough_enabled = false
	_last_polygon = PackedVector2Array()
	if is_instance_valid(_window):
		_window.mouse_passthrough = false
		_window.mouse_passthrough_polygon = PackedVector2Array()


func _apply_passthrough() -> void:
	if not passthrough_enabled or not _ready_window():
		return
	if not strip_enabled:
		_clear_passthrough()
		return
	var polygon := _build_passthrough_polygon(Vector2(_window.size), _window.get_final_transform(), _safe_rect, _interactive_rects)
	if polygon.is_empty():
		_clear_passthrough()
		_note = "顶部安全区或场景入口测量无效，鼠标穿透保持关闭。"
		return
	if polygon != _last_polygon:
		_window.mouse_passthrough = false
		_window.mouse_passthrough_polygon = polygon
		_last_polygon = polygon


static func _usable_input_rect(rect: Rect2) -> bool:
	return rect.position.is_finite() and rect.size.is_finite() and rect.size.x > 0.0 and rect.size.y > 0.0


static func _build_passthrough_polygon(native_size: Vector2, viewport_to_native: Transform2D, safe_rect: Rect2, interactive_rects: Array = []) -> PackedVector2Array:
	# Pure geometry, tested without a display server. Empty means fail CLOSED:
	# Godot then accepts input over the whole window, rather than passing it on.
	var empty := PackedVector2Array()
	if not native_size.is_finite() or native_size.x <= 0.0 or native_size.y <= 0.0 or not _usable_input_rect(safe_rect):
		return empty
	if not viewport_to_native.x.is_finite() or not viewport_to_native.y.is_finite() or not viewport_to_native.origin.is_finite() or absf(viewport_to_native.determinant()) < 0.000001:
		return empty
	var bounds := Rect2(Vector2.ZERO, native_size)
	var native_safe: Rect2 = viewport_to_native * safe_rect
	if not _usable_input_rect(native_safe) or not bounds.intersects(native_safe):
		return empty
	var band := clampf(ceilf(native_safe.end.y), minf(50.0, native_size.y), native_size.y)
	# Vector3 holds [left, right, bottom]. Round outward so fractional scaling
	# never excludes a visible edge of an interactive rectangle.
	var spans: Array[Vector3] = []
	for value in interactive_rects:
		if not (value is Rect2 or value is Rect2i):
			return empty
		var rect: Rect2 = value
		if not rect.position.is_finite() or not rect.size.is_finite():
			return empty
		rect = rect.abs()
		if not rect.has_area():
			continue
		var native_rect: Rect2 = viewport_to_native * rect
		if not _usable_input_rect(native_rect):
			return empty
		native_rect = native_rect.intersection(bounds)
		if not native_rect.has_area() or native_rect.end.y <= band:
			continue
		spans.append(Vector3(maxf(0.0, floorf(native_rect.position.x)), minf(native_size.x, ceilf(native_rect.end.x)), minf(native_size.y, ceilf(native_rect.end.y))))
	spans.sort_custom(func(a: Vector3, b: Vector3) -> bool: return a.x < b.x)
	var merged: Array[Vector3] = []
	for span in spans:
		if merged.is_empty() or span.x > merged[-1].y:
			merged.append(span)
		else:
			var previous := merged[-1]
			merged[-1] = Vector3(previous.x, maxf(previous.y, span.y), maxf(previous.z, span.z))
	# Trace one X-monotone lower boundary right-to-left. This gives a connected,
	# non-self-intersecting comb, never disconnected islands or blind holes.
	var polygon := PackedVector2Array([Vector2.ZERO, Vector2(native_size.x, 0), Vector2(native_size.x, band)])
	for i in range(merged.size() - 1, -1, -1):
		var span := merged[i]
		for point in [Vector2(span.y, band), Vector2(span.y, span.z), Vector2(span.x, span.z), Vector2(span.x, band)]:
			if point != polygon[-1]:
				polygon.append(point)
	if polygon[-1] != Vector2(0, band):
		polygon.append(Vector2(0, band))
	return polygon


func _usable_rect() -> Rect2i:
	var rect := DisplayServer.screen_get_usable_rect(_window.current_screen)
	if rect.size.x <= 0 or rect.size.y <= 0:
		rect = Rect2i(Vector2i.ZERO, Vector2i(1280, 800))
	return rect


func _fit_size(requested: Vector2i) -> Vector2i:
	var usable := _usable_rect()
	var available := usable.size - Vector2i(MARGIN * 2, MARGIN * 2 + 32)
	var minimum := Vector2i(mini(1000, available.x), mini(320, available.y))
	_window.min_size = minimum
	return Vector2i(clampi(requested.x, minimum.x, available.x), clampi(requested.y, minimum.y, available.y))


func _clamp_position(requested: Vector2i, dimensions: Vector2i) -> Vector2i:
	var usable := _usable_rect()
	return Vector2i(
		clampi(requested.x, usable.position.x + MARGIN, maxi(usable.position.x + MARGIN, usable.end.x - dimensions.x - MARGIN)),
		clampi(requested.y, usable.position.y + 32 + MARGIN, maxi(usable.position.y + 32 + MARGIN, usable.end.y - dimensions.y - MARGIN))
	)


func _center_position(dimensions: Vector2i) -> Vector2i:
	var usable := _usable_rect()
	return _clamp_position(usable.position + (usable.size - dimensions) / 2, dimensions)


func _snap_bottom() -> void:
	var usable := _usable_rect()
	_window.position = Vector2i(usable.position.x + (usable.size.x - _window.size.x) / 2, usable.end.y - _window.size.y - MARGIN)
	if DisplayServer.get_name().to_lower() == "wayland":
		_note = "Wayland 可能接管窗口位置，可拖动顶部安全区调整。"


func _on_size_changed() -> void:
	_apply_passthrough()




func restore_position(x:int, y:int) -> void:
	if not _ready_window() or x == -99999 or y == -99999:
		return
	_window.position = _clamp_position(Vector2i(x,y), _window.size)
