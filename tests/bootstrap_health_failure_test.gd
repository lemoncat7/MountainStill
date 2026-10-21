extends SceneTree
class TestBootstrap extends "res://scripts/update_bootstrap.gd":
	func _show_failure(message: String) -> void:
		super._show_failure(message)
		assert(get_tree().paused, "failure must pause game")
		assert(get_tree().root.get_node_or_null("Emberline") == null, "failed game must be freed")
		print("BOOTSTRAP HEALTH FAILURE: marker removal failure pauses and frees game PASS")
class FailedRemoveStore extends "res://scripts/update_store.gd":
	func startup() -> Dictionary:
		_write("booting.json", {"phase": "launching"})
		return {}
	func _remove(_name: String) -> bool:
		return _fail("TEST injected marker removal failure")
func _initialize() -> void:
	var bootstrap = TestBootstrap.new()
	var test_store = FailedRemoveStore.new()
	test_store.directory = "user://update-health-failure-test"
	bootstrap.store = test_store
	root.add_child.call_deferred(bootstrap)
