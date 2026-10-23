extends SceneTree
## Run against an ACTUAL v1.3.9 full installed payload, never current source.
## Linux editor harness overrides only platform label, not bootstrap/version/code.
const Bootstrap = preload("res://scripts/update_bootstrap.gd")
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	var args := OS.get_cmdline_user_args()
	assert(args.size() == 2)
	assert(ProjectSettings.get_setting("application/config/version") == "1.3.9-test.1")
	assert(not ResourceLoader.exists("res://scripts/scene_art_layout.gd"))
	var boot = Bootstrap.new()
	assert(boot.store.BUILTIN_VERSION == "1.3.9-test.1")
	assert(boot.store.current_version() == "1.3.9-test.1")
	var old_boot_hash := FileAccess.get_sha256("res://scripts/update_bootstrap.gd")
	var old_store_hash := FileAccess.get_sha256("res://scripts/update_store.gd")
	boot.store.platform = args[1]
	var manifest = JSON.parse_string(FileAccess.get_file_as_string(args[0].path_join("MountainStill-update.json")))
	assert(manifest.version == "1.3.12-test.1")
	var record: Dictionary = manifest.packages[args[1]].duplicate()
	for key in ["schema", "version", "engine", "bootstrap", "save_schema"]: record[key] = manifest[key]
	record.platform = args[1]
	record.path = "user://updates/" + record.sha256 + ".pck"
	DirAccess.make_dir_recursive_absolute("user://updates")
	assert(DirAccess.copy_absolute(args[0].path_join(record.asset), record.path) == OK)
	assert(boot.store._write("pending.json", record))
	assert(boot.store.activate_pending())
	root.add_child(boot)
	for i in range(90): await process_frame
	assert(root.get_meta("update_gameplay_ready", false))
	assert(root.get_meta("update_version") == "1.3.12-test.1")
	assert(boot.store.current_version() == "1.3.12-test.1")
	assert(boot.store.BUILTIN_VERSION == "1.3.9-test.1")
	assert(FileAccess.get_sha256("res://scripts/update_bootstrap.gd") == old_boot_hash)
	assert(FileAccess.get_sha256("res://scripts/update_store.gd") == old_store_hash)
	assert(boot.store.error.is_empty())
	assert(not FileAccess.file_exists("user://updates/booting.json"))
	var game = current_scene
	assert(game != null and game.state.settings.ui_scale == 1.5)
	assert(game.Desktop.NORMAL_SIZE == Vector2i(1440, 720))
	assert(game.Desktop.NORMAL_MIN == Vector2i(960, 540))
	assert(game.desktop._normal_size == Vector2i(1440, 720))
	assert(root.content_scale_mode == Window.CONTENT_SCALE_MODE_DISABLED)
	assert(root.content_scale_size == Vector2i.ZERO)
	assert(is_equal_approx(root.content_scale_factor, game.Readability.effective_scale(root.size, 1.5, game.desktop.display_scale())))
	assert(game.SceneArt.TEXTURES.size() == 7)
	for key in game.SceneArt.TEXTURES:
		var texture: Texture2D = game.SceneArt.texture(key)
		assert(texture != null and texture.get_width() > 2000)
		var source: Rect2 = game.SceneArt.source_rect(key)
		var destination: Rect2 = game.SceneArt.destination_rect(key, Rect2(0, 0, 1040, 280))
		assert(is_equal_approx(source.size.x / source.size.y, destination.size.x / destination.size.y))
	assert(ProjectSettings.get_setting("display/window/per_pixel_transparency/allowed"))
	print("OLD_INSTALLED_UPDATE: ", args[1], " immutable 1.3.9 bootstrap/store -> actual 1.3.12 gameplay, 1440x720, 150% UI, seven original panorama dependencies, uniform source aspect, health commit PASS")
	quit()
