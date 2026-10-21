extends SceneTree
const Desktop = preload("res://scripts/desktop_mode.gd")
const State = preload("res://scripts/cultivation_state.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr(label)
func _initialize() -> void:
	for rect in [Rect2i(0,0,1920,1040),Rect2i(0,0,1366,728),Rect2i(-1920,0,1920,1080),Rect2i(0,-900,1440,860),Rect2i(0,0,800,600),Rect2i(0,0,50,30),Rect2i(0,0,3840,2100)]:
		for requested in [Vector2i(1440,720),Vector2i(1000,320),Vector2i(9000,5000),Vector2i(-1,-1)]:
			var fit := Desktop.fit_size(requested, rect)
			check(fit.x > 0 and fit.y > 0 and fit.x <= rect.size.x and fit.y <= rect.size.y, "fit bounded "+str(rect)+str(requested))
			for pos in [Vector2i(-99999,-99999),Vector2i(99999,99999),rect.position]:
				var safe := Desktop.clamp_position(pos, fit, rect)
				check(rect.encloses(Rect2i(safe,fit)), "position visible "+str(rect)+str(safe))
	var helper = Desktop.new()
	helper.attach(root)
	helper.initialize({"window_mode":"strip"})
	check(helper.strip_enabled, "headless initialization preserves logical strip")
	helper.initialize({"window_mode":"strip"}, true)
	check(not helper.strip_enabled, "expanded launch overrides saved strip")
	check(helper.display_scale() == 1.0, "headless display factor deterministic")
	helper.dispose()
	var state = State.new()
	state.save_path = "user://geometry_test.json"
	check(state.settings.window_mode == "window" and state.settings.ui_scale == 1.5, "new save comfortable normal")
	state.settings.normal_width = 1600
	state.settings.normal_height = 900
	state.settings.normal_x = -1500
	state.settings.normal_y = 90
	state.settings.window_mode = "strip"
	state.settings.ui_scale = 1.75
	check(state.save_game(), "save dimensions")
	var restored = State.new()
	restored.save_path = state.save_path
	check(restored.load_game().loaded, "reload dimensions")
	for key in ["normal_width","normal_height","normal_x","normal_y","window_mode","ui_scale"]:
		check(restored.settings[key] == state.settings[key], "roundtrip "+key)
	var legacy: Dictionary = state._snapshot()
	legacy.settings = {"width":1000,"window_mode":"strip","window_x":-9000,"window_y":5000}
	var file = FileAccess.open(state.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	check(restored.load_game().loaded, "legacy loads")
	check(restored.settings.window_mode == "strip", "legacy explicit strip preserved")
	check(restored.settings.strip_width == 1000, "legacy strip width preserved")
	check(restored.settings.normal_width == 1440 and restored.settings.normal_height == 720, "legacy normal restore size repaired")
	legacy.settings.geometry_version = 2
	legacy.settings.normal_width = "bad"
	legacy.settings.normal_height = -50
	legacy.settings.normal_x = []
	legacy.settings.ui_scale = "bad"
	file = FileAccess.open(state.save_path,FileAccess.WRITE)
	file.store_string(JSON.stringify(legacy));file.close()
	check(restored.load_game().loaded, "invalid optional geometry does not destroy save")
	check(restored.settings.normal_width == 1440 and restored.settings.normal_height == 320 and restored.settings.ui_scale == 1.5, "invalid geometry sanitized")
	for suffix in ["", ".bak", ".tmp"]:
		DirAccess.remove_absolute(state.save_path + suffix)
	print("Window geometry: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
