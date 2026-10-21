extends SceneTree
const Bootstrap = preload("res://scripts/update_bootstrap.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args = OS.get_cmdline_user_args()
	var platform = args[1]
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("MountainStill-update.json")))
	var record: Dictionary = manifest.packages[platform].duplicate()
	for key in ["schema", "version", "engine", "bootstrap", "save_schema"]: record[key] = manifest[key]
	record.platform = platform
	record.path = "user://updates/" + record.sha256 + ".pck"
	DirAccess.make_dir_recursive_absolute("user://updates")
	assert(DirAccess.copy_absolute(args[0].path_join(record.asset), record.path) == OK)
	var boot = Bootstrap.new()
	boot.store.platform = platform
	boot.store.running_version = "1.3.8-test.1"
	assert(boot.store._write("pending.json", record))
	assert(boot.store.activate_pending())
	root.add_child(boot)
	for i in range(90): await process_frame
	assert(root.get_meta("update_gameplay_ready", false))
	assert(boot.store.error.is_empty())
	assert(not FileAccess.file_exists("user://updates/booting.json"))
	print("EXPORTED_UPDATE_PACK: ", platform, " actual mount + gameplay ready + health commit PASS")
	quit()
