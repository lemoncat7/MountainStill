extends SceneTree
const Service = preload("res://scripts/update_service.gd")
func _init() -> void:
	assert(Service.parse_proxy("http://127.0.0.1:8080") == {"host":"127.0.0.1","port":8080})
	assert(Service.parse_proxy("http://proxy.local") == {"host":"proxy.local","port":80})
	for value in ["", "https://proxy.local:443", "http://user:secret@proxy.local:80", "http://proxy.local:0", "http://proxy.local:65536", "http://proxy.local/path", "http://proxy.local:80\n"]:
		assert(Service.parse_proxy(value).is_empty())
	print("UPDATE PROXY: 9 checks passed; no TLS verification changes")
	quit()
