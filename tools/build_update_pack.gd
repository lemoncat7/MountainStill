extends SceneTree
## Usage: godot --headless --path . --script tools/build_update_pack.gd -- export.zip output.pck
func _init() -> void:
	var args := OS.get_cmdline_user_args()
	if args.size() != 2:
		push_error("Expected exported ZIP and destination PCK")
		quit(2)
		return
	var source := ZIPReader.new()
	if source.open(args[0]) != OK:
		quit(2)
		return
	var pack := PCKPacker.new()
	if pack.pck_start(args[1]) != OK:
		quit(2)
		return
	var temp_root := "user://update-pack-build"
	DirAccess.make_dir_recursive_absolute(temp_root)
	var temps: Array[String] = []
	var count := 0
	for path in source.get_files():
		if path.ends_with("/"):
			continue
		# Trusted bootstrap/updater stays installed. Update packs contain gameplay only.
		if path in ["project.binary", "project.godot", "bootstrap.tscn"] or path.begins_with("scripts/update_") or (path.begins_with(".godot/") and not path.begins_with(".godot/imported/")):
			continue
		if ".." in path or path.begins_with("/") or "\\" in path:
			push_error("Unsafe exported path: " + path)
			quit(2)
			return
		var temp := temp_root.path_join(str(count))
		temps.append(temp)
		var file := FileAccess.open(temp, FileAccess.WRITE)
		if file == null:
			quit(2)
			return
		file.store_buffer(source.read_file(path))
		file.close()
		if pack.add_file("res://" + path, temp) != OK:
			quit(2)
			return
		count += 1
	if pack.flush() != OK:
		quit(2)
		return
	for temp in temps:
		DirAccess.remove_absolute(temp)
	DirAccess.remove_absolute(temp_root)
	print("UPDATE_PACK_FILES=", count)
	quit(0)
