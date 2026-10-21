extends SceneTree
## One transparent end-to-end economy proof; never loads or writes the player save.
const Journey = preload("res://tests/complete_player_journey_plan.gd")
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var journey = Journey.new()
var output := "/tmp/complete-player-journey.json"

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	if journey.prepare_intro():
		for chapter in range(6):
			if not journey.run_stage(str(Content.CHAPTER_ORDER[chapter])): break
			if not journey.prepare_after_chapter(chapter): break
	if journey.errors.is_empty():
		var s = journey.state
		journey.check(s.realm == 15 and s.total_victories == 18 and s.stage_clears.size() == 6, "six complete chapters and fifteen explicitly paid breakthroughs")
		journey.check(journey.rng_rewards == {"chests": 0, "equipment": 0, "treasure": 0, "opportunities": 0}, "entire first volume needs no random reward or repeated farming")
		journey.check(s.meridian_count == 1, "modest complete path never purchases every meridian")
		journey.check(s.chapter_status().epilogue_ready and not s.chapter_status().ending_complete, "ending remains an explicit home action")
		var before: Dictionary = journey.resources()
		journey.check(s.complete_home_epilogue().get("ok", false), "player writes the finite first-volume ending")
		journey.check(not s.complete_home_epilogue().get("ok", false), "ending cannot duplicate")
		journey.record("home_epilogue", before)
		_verify_real_save_and_offline()
	var report: Dictionary = journey.report()
	if journey.errors.is_empty():
		var guided = Journey.new()
		guided.follow_default_guidance()
		report.guided = guided.report()
		journey.checks += guided.checks
		journey.errors.append_array(guided.errors)
		report.checks = journey.checks
		report.errors = journey.errors.duplicate()
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	else: journey.check(false, "write reproducible economy ledger")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(journey.state.save_path + suffix): DirAccess.remove_absolute(journey.state.save_path + suffix)
	print("Complete fresh player journey: %d checks, %d failures; report %s" % [journey.checks, journey.errors.size(), output])
	quit(0 if journey.errors.is_empty() else 1)

func _verify_real_save_and_offline() -> void:
	var s = journey.state
	s.settings.paused = true
	journey.check(s.save_game(), "save complete earned state into isolated destination")
	var before: Dictionary = journey.resources()
	var restored := State.new(); restored.save_path = s.save_path
	journey.check(restored.load_game().get("loaded", false), "load genuine saved state")
	journey.state = restored
	journey.check(_same(journey.resources(), before), "paused load preserves all earned economic state")
	journey.check(restored.chapter_status().ending_complete and not restored.stage_status().active, "ending persists without new expedition")
	journey.verify_guide_readonly("saved_and_restored_ending")
	restored.step(60.0)
	journey.check(_same(journey.resources(), before), "paused time yields no economic change")
	restored.settings.paused = false
	journey.check(restored.save_game(), "save actual unpaused state for real offline interval")
	var old_time: float = restored.lifetime_seconds
	var old_merit: float = restored.merit
	OS.delay_msec(2100)
	var offline: Dictionary = restored.load_game()
	journey.check(offline.get("loaded", false) and float(offline.get("seconds", 0)) >= 1.0
		and float(offline.get("seconds", 0)) <= 4.0, "real wall-clock offline interval settles without editing timestamp")
	journey.check(restored.lifetime_seconds > old_time and restored.merit > old_merit
		and restored.total_victories == 18 and not restored.stage_status().active, "offline adds only peaceful income, never battle/search rewards")
	journey.check(restored.chapter_status().ending_complete and restored._valid_save(restored._snapshot()), "final saved state remains valid and complete")

func _same(a: Dictionary, b: Dictionary) -> bool:
	var left := a.duplicate(true); var right := b.duplicate(true)
	for key in ["seconds", "qi", "merit"]:
		if absf(float(left[key]) - float(right[key])) > .000001: return false
		left.erase(key); right.erase(key)
	return left == right
