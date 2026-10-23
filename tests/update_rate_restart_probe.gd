extends SceneTree
const Service = preload("res://tests/update_fixture_service.gd")
func _initialize(): run.call_deferred()
func run():
	var args = OS.get_cmdline_user_args()
	assert(args.size() == 1)
	var service = Service.new()
	root.add_child(service)
	if args[0] == "seed":
		service.fixture_mode = "primary"
		service.check_updates()
		var deadline = Time.get_ticks_msec() + 5000
		while service.busy and Time.get_ticks_msec() < deadline: await process_frame
		assert(not service.busy and service.rate_limit_remaining() > 0)
		print("RATE_RESTART seed persisted")
	else:
		assert(service.rate_limit_remaining() > 0 and service.rate_limit_remaining() <= 120)
		var before = service._generation
		service.set_channel("testing" if service.channel == "stable" else "stable")
		for i in range(20): service.check_updates()
		assert(service._generation == before + 1) # set_channel cancels once; clicks request nothing.
		assert(not service.busy and service.rate_limit_message().contains("限流"))
		print("RATE_RESTART actual second process preserved wait and suppressed clicks")
	quit()
