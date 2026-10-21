extends SceneTree
## Read-only live API probe. No download/application, no arbitrary URL override.
class WindowsService extends "res://scripts/update_service.gd":
	func platform_name() -> String: return "windows"
var service: Node
func _initialize() -> void: _run.call_deferred()
func _run() -> void:
	service = WindowsService.new()
	root.add_child(service)
	service.set_auto_check(false)
	service.set_channel("testing")
	service.current_version = "1.3.7"
	var args = OS.get_cmdline_user_args()
	if args.size() == 1:
		# Optional replay of actual read-only API bytes captured by curl in a proxy-only executor.
		service._phase = "releases"
		service.busy = true
		service._completed(HTTPRequest.RESULT_SUCCESS, 200, PackedStringArray(), FileAccess.get_file_as_bytes(args[0]))
	else:
		service.check_updates()
	var deadline = Time.get_ticks_msec() + 45000
	while service.busy and Time.get_ticks_msec() < deadline: await process_frame
	print("LIVE_GITHUB_STATUS: ", service.status)
	var expected = "未提供兼容的游戏内更新清单" in service.status
	print("LIVE_GITHUB_NO_DOWNLOAD: ", service.candidate.is_empty() and not FileAccess.file_exists("user://updates/pending.json"))
	service.cancel()
	quit(0 if expected else 1)
