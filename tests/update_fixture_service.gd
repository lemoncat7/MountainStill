extends "res://scripts/update_service.gd"
# Test subclass only, not exported. Production has no network override setting.
var fixture_mode = "valid"
func platform_name() -> String:
	return "windows"
func _start(url: String, limit: int, redirect: bool = false) -> void:
	var kind = "releases" if url.begins_with(Policy.API) else ("manifest" if url.ends_with(Policy.MANIFEST) else "pack")
	if url.begins_with("https://release-assets.githubusercontent.com/"):
		kind = _phase + "-cdn"
	super._start("http://127.0.0.1:18765/" + fixture_mode + "/" + kind, limit, redirect)

func _ready() -> void:
	super._ready()
	set_auto_check(false)

func _configure_environment_proxy(_request_node: HTTPRequest) -> void:
	# Test transport is local; production proxy behavior has a separate live probe.
	pass
