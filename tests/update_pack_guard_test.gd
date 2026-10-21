extends SceneTree
const Guard = preload("res://scripts/update_pack_guard.gd")
var checks := 0
var failures := 0
var root_path := "user://pack-guard-test"
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error(label)
func make_pack(name: String, paths: Array, removal := false) -> String:
	var file := FileAccess.open(root_path + "/source", FileAccess.WRITE)
	file.store_string("fixture content"); file.close()
	var path := root_path + "/" + name + ".pck"
	var pack := PCKPacker.new()
	pack.pck_start(path)
	for target in paths:
		if removal: pack.add_file_removal(target)
		else: pack.add_file(target, root_path + "/source")
	pack.flush()
	return path
func mutate(source: String, position: int, value: int, bits := 32) -> String:
	var path := root_path + "/mutated.pck"
	DirAccess.copy_absolute(source, path)
	var f := FileAccess.open(path, FileAccess.READ_WRITE)
	f.seek(position)
	if bits == 64: f.store_64(value)
	else: f.store_32(value)
	f.close()
	return path
func _init() -> void:
	DirAccess.make_dir_recursive_absolute(root_path)
	var good := make_pack("good", ["res://main.tscn", "res://scripts/game.gd", "res://assets/test.png.import", "res://.godot/imported/test.ctex"])
	check(Guard.validate(good), "real 4.6.3 PCKPacker output accepted")
	for path in ["scripts/update_store.gd", "scripts/UPDATE_store.gd", "scripts/update_bootstrap.gd.remap", "project.binary", "bootstrap.tscn", ".godot/uid_cache.bin", ".godot/exported/main.scn", "assets/test.dll", "assets/test.gdextension", "assets/test.cs", "../main.tscn", "assets/../main.tscn", "res://main.tscn", "assets//test.png", "assets/a\\b.png", "/main.tscn", "assets/a./test.png"]:
		check(not Guard.allowed_path(path), "reject path " + path)
	for path in ["project.binary", "scripts/update_store.gd", ".godot/exported/main.scn", "assets/test.dll"]:
		check(not Guard.validate(make_pack("bad", [path])), "reject packaged " + path)
	check(not Guard.validate(make_pack("duplicate", ["scripts/game.gd", "scripts/game.gd"])), "duplicate denied")
	check(not Guard.validate(make_pack("removal", ["scripts/game.gd"], true)), "removal denied")
	check(not Guard.validate(mutate(good, 4, 2)), "v2 denied")
	check(not Guard.validate(mutate(good, 16, 4)), "different engine denied")
	check(not Guard.validate(mutate(good, 20, 3)), "encrypted directory denied")
	check(not Guard.validate(mutate(good, 24, -1, 64)), "overflow file base denied")
	check(not Guard.validate(mutate(good, 32, -1, 64)), "overflow directory denied")
	check(not Guard.validate(mutate(good, 40, 1)), "reserved header denied")
	var f := FileAccess.open(good, FileAccess.READ)
	f.seek(32); var directory := f.get_64(); f.seek(directory + 4); var path_length := f.get_32(); f.close()
	check(not Guard.validate(mutate(good, directory, 10001)), "excess entry count denied")
	check(not Guard.validate(mutate(good, directory + 4, 0xffffffff)), "excess name length denied")
	check(not Guard.validate(mutate(good, directory + 8 + path_length, -1, 64)), "overflow data offset denied")
	check(not Guard.validate(mutate(good, directory + 16 + path_length, -1, 64)), "overflow data size denied")
	check(not Guard.validate(mutate(good, directory + 40 + path_length, 1)), "encrypted entry denied")
	var truncated := root_path + "/truncated.pck"
	var contents := FileAccess.get_file_as_bytes(good)
	var trunc := FileAccess.open(truncated, FileAccess.WRITE)
	trunc.store_buffer(contents.slice(0, contents.size() - 1)); trunc.close()
	check(not Guard.validate(truncated), "truncated directory denied")
	var appended := root_path + "/appended.pck"
	var extra := FileAccess.open(appended, FileAccess.WRITE)
	extra.store_buffer(contents); extra.store_8(0); extra.close()
	check(not Guard.validate(appended), "trailing payload denied")
	# Second file may not alias first payload even with an allowed distinct path.
	var second := directory + 8 + path_length + 36
	f = FileAccess.open(good, FileAccess.READ); f.seek(second)
	var second_length := f.get_32(); f.close()
	check(not Guard.validate(mutate(good, second + 4 + second_length, 0, 64)), "overlapping payload denied")
	for platform in ["windows", "macos"]:
		var built: String = "res://builds/updater-release/MountainStill-" + platform + ".pck"
		if FileAccess.file_exists(built): check(Guard.validate(built), "actual " + platform + " release accepted")
	print("UPDATE_PACK_GUARD: ", checks, " checks, ", failures, " failures")
	quit(failures)
