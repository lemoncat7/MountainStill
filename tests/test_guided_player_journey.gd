extends SceneTree
## Follow only the default production guidance from genuine new game to ending.
## Migration/invalid-data fixtures below are separate from the natural-play proof.
const Journey = preload("res://tests/complete_player_journey_plan.gd")
const State = preload("res://scripts/cultivation_state.gd")
var journey = Journey.new()
var output := "/tmp/guided-player-journey.json"
var test_path := "user://test_guided_player_journey_%d.json" % OS.get_process_id()

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
	journey.follow_default_guidance()
	if journey.errors.is_empty():
		_test_alternate_order_and_skips()
		_test_old_save_and_malformed_guidance()
		_test_earned_checkpoint_offline()
	var report: Dictionary = journey.report()
	report.coverage = ["default suggested route, eighteen native-stat duels and complete searches", "no random rewards or repeated farming", "read-only repeated guidance", "optional skip/reset with no rewards", "depart before lessons and resume paused route", "earned prior chapter load keeps its current objective", "legacy saved auto=true preserved", "malformed guidance metadata cannot corrupt progress", "real offline interval at an affordable manual-breakthrough checkpoint"]
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify(report, "\t")); file.close()
	else: journey.check(false, "write guided economic verification")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(test_path + suffix): DirAccess.remove_absolute(test_path + suffix)
	print("Default guided player journey: %d checks, %d failures; report %s" % [journey.checks, journey.errors.size(), output])
	quit(0 if journey.errors.is_empty() else 1)

func fingerprint(s) -> Array:
	return [s.realm, s.qi, s.herbs, s.dew, s.merit, s.lifetime_seconds, s.inventory.duplicate(true),
		s.equipped.duplicate(), s.materials.to_dict(), s.total_victories, s.stage_clears.duplicate(),
		s.chapter_reward_claimed.duplicate(), s.quest_claimed.duplicate(), s.counters.duplicate(),
		s.technique_levels.duplicate(), s.meridian_opened.duplicate(), s.chest_count,
		s._adventure_rng.state, s.gear.rng.state]

func _test_alternate_order_and_skips() -> void:
	var s := State.new()
	var before := fingerprint(s)
	var skipped: Array = []
	for index in range(8):
		var goal: Dictionary = s.player_journey_status()
		for read in range(10):
			s.player_journey_status(); s.player_journey_rows(); s.breakthrough_preview()
		if not goal.get("skippable", false): break
		journey.check(s.skip_player_journey_suggestion(str(goal.id)), "skip current optional suggestion explicitly")
		skipped.append(str(goal.id))
		journey.check(fingerprint(s) == before, "skip/read/reopen awards no money, learning, gear, realm or chapter")
	journey.check(skipped.size() >= 4 and str(s.player_journey_status().kind) == "route", "optional opening lessons can all be skipped without blocking chapter one")
	journey.check(not s.skip_player_journey_suggestion("not_the_current_goal") and fingerprint(s) == before, "stale skip cannot affect unrelated suggestion or progress")
	s.save_path = test_path; s.settings.paused = true
	journey.check(s.save_game(), "save honest skipped suggestions")
	var restored := State.new(); restored.save_path = test_path
	journey.check(restored.load_game().get("loaded", false) and restored.journey_skipped == s.journey_skipped, "skips persist without becoming gameplay unlocks")
	journey.check(fingerprint(restored) == before, "skipped save roundtrip changes no economy")
	restored.reset_player_journey_suggestions()
	journey.check(restored.journey_skipped.is_empty() and str(restored.player_journey_status().id) == "first_equipment"
		and fingerprint(restored) == before, "reopening recommendations only restores optional directions")
	# Alternate order: chapter one is selectable before any lesson, gear or realm.
	s.settings.paused = false
	var started: Dictionary = s.start_stage()
	if not journey.check(started.get("ok", false) and str(s.player_journey_status().id) == "resume_route", "depart before lessons and guidance follows the real ongoing route"): return
	journey.check(s.pause_stage(int(started.run_id)).get("ok", false) and str(s.player_journey_status().id) == "resume_route", "voluntary home pause keeps the actual unfinished route as next action")
	journey.check(s.total_victories == 0 and s.stage_clears.is_empty() and s.realm == 0, "alternate-order read checks never fake battle wins")

func _write(data: Dictionary) -> bool:
	var file := FileAccess.open(test_path, FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data)); file.close()
	return true

func _read_fixture(data: Dictionary) -> State:
	journey.check(_write(data), "write isolated schema compatibility fixture")
	var restored := State.new(); restored.save_path = test_path
	journey.check(restored.load_game().get("loaded", false), "load isolated schema compatibility fixture")
	return restored

func _test_old_save_and_malformed_guidance() -> void:
	if not journey.check(journey.earned_checkpoints.size() == 6, "migration uses actually earned chapter states"): return
	var data: Dictionary = journey.earned_checkpoints[1].duplicate(true)
	data.settings.paused = true
	# This simulates the explicit auto preference stored by pre-revision saves.
	data.auto_advance = true
	for key in ["arrival_seen", "guidance_dismissed", "journey_skipped"]: data.erase(key)
	var restored := _read_fixture(data)
	journey.check(restored.auto_advance and restored.arrival_seen and not restored.guidance_dismissed
		and restored.journey_skipped.is_empty(), "legacy auto preference survives; old arrival is not reopened")
	journey.check(restored.stage_clears.size() == 2 and restored.total_victories == 6
		and restored.chapter_reward_claimed.size() == 2, "legacy load preserves actual prior clears and paid rewards")
	var goal: Dictionary = restored.player_journey_status()
	journey.check(str(goal.id) not in ["first_equipment", "first_heart", "first_meridian", "first_breakthrough"]
		and str(goal.phase) == "growth", "two prior clears resume next chapter preparation rather than resetting tutorial")
	var before := fingerprint(restored)
	for index in range(25): restored.player_journey_status(); restored.player_journey_rows()
	journey.check(fingerprint(restored) == before, "legacy guidance retrofit grants no compensation or repeated gifts")
	# Malformed guidance is cosmetic metadata, never authority to grant progress.
	for malformed in [[], "invalid", {"first_equipment": "true", "first_heart": false, "valid_skip": true}]:
		var damaged := data.duplicate(true)
		damaged.arrival_seen = "not a bool"; damaged.guidance_dismissed = 91; damaged.journey_skipped = malformed
		var repaired := _read_fixture(damaged)
		journey.check(repaired.arrival_seen and not repaired.guidance_dismissed, "invalid boolean guidance flags fall back safely")
		journey.check(not repaired.journey_skipped.has("first_equipment") and not repaired.journey_skipped.has("first_heart"), "non-true-boolean skip values are ignored")
		journey.check(fingerprint(repaired) == before and repaired.auto_advance, "malformed metadata cannot change realm, economy, chapters or old auto choice")
	var many := data.duplicate(true); many.journey_skipped = {}
	for index in range(90): many.journey_skipped["choice_" + str(index)] = true
	many.journey_skipped["x".repeat(81)] = true
	var bounded := _read_fixture(many)
	journey.check(bounded.journey_skipped.size() == 64 and not bounded.journey_skipped.has("x".repeat(81)), "skip state is bounded to sixty-four short identifiers")
	journey.check(fingerprint(bounded) == before, "bounded metadata recovery preserves earned state")

func _test_earned_checkpoint_offline() -> void:
	var data: Dictionary = journey.earned_checkpoints[0].duplicate(true)
	data.settings.paused = true
	var s := _read_fixture(data)
	journey.check(not s.auto_advance and s.qi >= s.QI_COSTS[s.realm] and s.herbs >= s.HERB_COSTS[s.realm], "offline test uses genuinely earned ready-but-unconfirmed breakthrough")
	var realm_before := s.realm
	var clears_before := s.stage_clears.duplicate()
	var victories_before := s.total_victories
	var qi_before := s.qi
	s.settings.paused = false
	journey.check(s.save_game(), "save unpaused earned manual checkpoint")
	OS.delay_msec(2100)
	var result: Dictionary = s.load_game()
	journey.check(result.get("loaded", false) and float(result.get("seconds", 0)) >= 1.0 and float(result.get("seconds", 0)) <= 4.0, "offline interval comes from actual elapsed wall-clock time")
	journey.check(s.realm == realm_before and s.qi > qi_before and s.stage_clears == clears_before
		and s.total_victories == victories_before and not s.stage_status().active,
		"offline meditation accrues qi but never confirms a ready breakthrough or starts combat")
	journey.check(s.breakthrough() and s.realm == realm_before + 1, "returned player can still confirm precisely one saved affordable breakthrough")
