extends SceneTree
const Store = preload("res://scripts/update_store.gd")
var checks = 0
var failures = 0
var store = Store.new()
func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1; push_error(label)
func put(path: String, content: String) -> void:
	var f = FileAccess.open(path, FileAccess.WRITE); f.store_string(content); f.close()
func _init() -> void:
	store.directory = "user://update-store-tests-" + str(Time.get_ticks_usec())
	store.save_path = store.directory.path_join("save.json")
	store.platform = "windows"
	DirAccess.make_dir_recursive_absolute(store.directory)
	put(store.save_path, "old save"); put(store.save_path + ".bak", "old backup")
	var pack = store.directory.path_join("fixture.pck")
	var source = store.directory.path_join("content.txt"); put(source, "fixture")
	var packer = PCKPacker.new()
	check(packer.pck_start(pack) == OK, "packer start")
	check(packer.add_file("res://assets/fixture.json", source) == OK, "packer file")
	check(packer.flush() == OK, "packer flush")
	var hash = FileAccess.get_sha256(pack)
	var target = store.directory.path_join(hash + ".pck")
	DirAccess.rename_absolute(pack, target)
	var record = {"schema":1,"version":"1.3.16-test.2","engine":"4.6.3","platform":"windows","kind":"pck","asset":"MountainStill-windows.pck","size":FileAccess.get_file_as_bytes(target).size(),"sha256":hash,"restart_required":true,"save_schema":4,"bootstrap":1,"path":target}
	check(store.validate(record), "valid pack")
	for field in ["engine", "platform", "kind", "sha256", "path", "version", "save_schema", "bootstrap", "schema", "restart_required", "size"]:
		var bad = record.duplicate(); bad[field] = "invalid"
		check(not store.validate(bad), "reject " + field)
	check(store._write("pending.json", record), "stage record")
	check(store.startup().is_empty(), "download alone cannot activate")
	check(store.activate_pending(), "explicit activate")
	check(store.pending().is_empty(), "pending consumed")
	check(not store.activate_pending(), "double activation refused")
	check(store.startup().get("sha256") == hash, "first restart selects update")
	check(store.current_version() == "1.3.16-test.2", "running version")
	put(store.save_path, "new save"); put(store.save_path + ".bak", "new backup")
	var snapshot_prefix = str(store._read("previous.json").snapshot.prefix)
	put(store.directory.path_join("recovered-newer-" + snapshot_prefix + ".tmp"), "interrupted partial copy")
	var fresh = Store.new(); fresh.directory = store.directory; fresh.save_path = store.save_path; fresh.platform = store.platform
	check(fresh.startup().is_empty(), "failed boot reverts built-in")
	check(fresh.error.is_empty(), "failed boot recovered cleanly")
	check(FileAccess.get_file_as_string(store.save_path) == "old save", "save snapshot restored")
	check(FileAccess.get_file_as_string(store.save_path + ".bak") == "old backup", "backup snapshot restored")
	check(FileAccess.get_file_as_string(store.directory.path_join("recovered-newer-" + snapshot_prefix)) == "new save", "newer save retained")
	check(not FileAccess.file_exists(store.directory.path_join("recovered-newer-" + snapshot_prefix + ".tmp")), "partial preservation copy replaced and committed")
	store = fresh
	store._write("pending.json", record); check(store.activate_pending(), "activate again")
	check(not store.startup().is_empty(), "second boot")
	store.mark_healthy()
	check(store._read("booting.json").is_empty(), "healthy clears boot marker")
	check(not store.startup().is_empty(), "healthy remains active")
	put(store.save_path, "later save")
	check(store.rollback(), "manual rollback")
	check(FileAccess.get_file_as_string(store.save_path) == "old save", "manual rollback restores snapshot")
	check(store.startup().is_empty(), "manual rollback built-in")
	store._write("pending.json", record); check(store.activate_pending(), "activate interrupted pointer")
	store._write("active.json", {})
	check(store.startup().is_empty() and store.error.is_empty(), "interrupted apply recovered")
	store._write("pending.json", record)
	var stale = record.duplicate(); stale.version = Store.BUILTIN_VERSION
	store._write("pending.json", stale)
	check(not store.activate_pending(), "stale pending refused")
	put(store.directory.path_join("active.json"), "not json")
	check(store.startup().is_empty() and not store.error.is_empty(), "malformed active fails closed")
	put(store.directory.path_join("active.json"), JSON.stringify({"oversized":"x".repeat(65536)}))
	check(store.startup().is_empty() and not store.error.is_empty(), "oversized active fails closed")
	store._write("active.json", {})
	store._write("pending.json", record)
	put(target, "corrupt")
	check(not store.activate_pending(), "corrupt payload rejected")
	print("UPDATE STORE: %s checks, %s failures" % [checks, failures])
	quit(1 if failures else 0)
