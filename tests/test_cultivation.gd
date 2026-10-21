extends SceneTree
## godot --headless --path . --script tests/test_cultivation.gd
## All writes use a unique test prefix, never the user's cultivation save.

const State = preload("res://scripts/cultivation_state.gd")
var checks := 0
var failures := 0
var prefix := "user://test_cultivation_%d" % OS.get_process_id()


func _initialize() -> void:
	_test_defaults()
	_test_appearance()
	_test_appearance_persistence()
	_test_activities()
	_test_activity_boundaries()
	_test_breakthroughs()
	_test_auto_and_frame_invariance()
	_test_persistence()
	_test_offline_and_clock()
	_test_malformed()
	_cleanup()
	print("Cultivation tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)


func _check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)


func _state(suffix: String = "") -> State:
	var state := State.new()
	state.save_path = prefix + suffix + ".json"
	return state


func _test_defaults() -> void:
	var state := _state()
	_check(state.realm == 0 and state.qi == 0 and state.herbs == 3 and state.dew == 1, "fresh cultivation state")
	_check(state.realm_name() == "炼气初期" and state.activity_name() == "静坐吐纳", "localized names")
	_check(state.next_realm_name() == "炼气中期" and state.activity_progress == 0, "UI helper defaults")
	_check(not state.auto_advance and not state.autoadvance, "new player explicitly chooses breakthroughs and auto is opt-in")
	_check(state.stats().need_qi == 120 and state.stats().need_herbs == 6, "first breakthrough costs")
	_check(not state.use_pill() and not state.breakthrough(), "empty resources are safe")
	_check(not state.set_activity("fight") and state.activity == "meditate", "unknown activity rejected")
	_check(state.step(-1).is_empty() and state.step(NAN).is_empty() and state.step(INF).is_empty(), "invalid delta rejected")
	_check(state.lifetime_seconds == 0, "invalid delta gives no lifetime credit")


func _test_appearance() -> void:
	var state := _state()
	_check(state.outfit == "moon" and state.weapon == "sword" and state.technique == "mist", "appearance starter defaults")
	var original_stats := state.stats()
	for category in State.APPEARANCE_OPTIONS:
		for id in State.APPEARANCE_OPTIONS[category]:
			_check(state.equip(category, id), "starter appearance choice unlocked: %s/%s" % [category, id])
			_check(state.get(category) == id, "appearance selection applied: %s/%s" % [category, id])
	_check(state.herbs == 3 and state.dew == 1 and state.qi == 0 and state.pills == 0, "appearance is free")
	_check(state.stats().qi_rate == original_stats.qi_rate and not state.auto_advance and state.activity == "meditate", "legacy cosmetics preserve resources and untrained qi rate")
	state.equip("technique", "mist")
	_check(state.stats().attack == original_stats.attack, "selecting learned mist restores its active attack bonus")
	var before := [state.outfit, state.weapon, state.technique]
	for pair in [["outfit", "sword"], ["weapon", "jade"], ["technique", "moon"], ["other", "mist"], ["", ""], ["outfit", "MOON"], ["weapon", ""], ["technique", "lightning"]]:
		_check(not state.equip(pair[0], pair[1]), "invalid appearance rejected: %s/%s" % pair)
	_check([state.outfit, state.weapon, state.technique] == before, "invalid choices preserve all appearance fields")
	state.new_game()
	_check(state.outfit == "moon" and state.weapon == "sword" and state.technique == "mist", "new game restores appearance defaults")


func _test_appearance_persistence() -> void:
	var state := _state("_appearance")
	for category in State.APPEARANCE_OPTIONS:
		for id in State.APPEARANCE_OPTIONS[category]:
			state.equip(category, id)
			_check(state.save_game(), "appearance save: %s/%s" % [category, id])
			var restored := _state("_appearance")
			var result := restored.load_game()
			_check(result.loaded and restored.get(category) == id, "appearance roundtrip: %s/%s" % [category, id])
	state.equip("outfit", "jade")
	state.equip("weapon", "fan")
	state.equip("technique", "petal")
	_check(state.reset_save(), "appearance profile reset succeeds")
	var reset := _state("_appearance")
	reset.load_game()
	_check(reset.outfit == "moon" and reset.weapon == "sword" and reset.technique == "mist", "appearance reset persists defaults")
	# Cosmetics are forward-compatible optional fields. A typo or wrong type
	# must not destroy a player's otherwise healthy progression.
	var data := state._snapshot()
	data.realm = 2
	data.qi = 55.0
	data.herbs = 19
	data.auto_advance = false
	data.outfit = "unknown_robe"
	data.weapon = {"bad": "type"}
	data.technique = 123
	_write(state.save_path, JSON.stringify(data))
	var result := state.load_game()
	_check(result.loaded and not result.invalid_save, "malformed appearance keeps valid save")
	_check(state.outfit == "moon" and state.weapon == "sword" and state.technique == "mist", "malformed appearance individually sanitized")
	_check(state.realm == 2 and state.herbs == 19 and state.qi >= 55.0, "sanitization preserves cultivation progress")
	var repaired: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(state.save_path))
	_check(repaired.outfit == "moon" and repaired.weapon == "sword" and repaired.technique == "mist", "sanitized values checkpoint to disk")
	data = state._snapshot()
	data.outfit = "jade"
	data.weapon = []
	data.technique = "petal"
	_write(state.save_path, JSON.stringify(data))
	state.load_game()
	_check(state.outfit == "jade" and state.weapon == "sword" and state.technique == "petal", "invalid category does not reset valid choices")
	for category in State.APPEARANCE_OPTIONS:
		data.erase(category)
	_write(state.save_path, JSON.stringify(data))
	result = state.load_game()
	_check(result.loaded and state.realm == 2, "legacy save without cosmetics still loads")
	_check(state.outfit == "moon" and state.weapon == "sword" and state.technique == "mist", "legacy save receives starter appearance")


func _test_activities() -> void:
	var state := _state()
	state.herbs = 0
	state.dew = 0
	_check(state.set_activity("meditate") and not state.auto_advance, "manual selection disables auto")
	state.step(10.0)
	_check(is_equal_approx(state.qi, 10.0), "meditation produces qi")
	state.set_activity("gather")
	state.step(7.99)
	_check(state.herbs == 0 and state.dew == 0, "gather waits for interval")
	state.step(0.01)
	_check(state.herbs == 1 and state.dew == 0, "herb at exactly eight seconds")
	state.step(16.0)
	_check(state.herbs == 3 and state.dew == 1, "dew at exactly 24 seconds")
	_check(is_equal_approx(state.qi, 10.0), "gathering does not produce extra qi")
	state.set_activity("brew")
	state.step(19.0)
	_check(state.herbs == 3 and state.dew == 1 and state.pills == 0, "brewing only consumes resources at completion")
	state.step(1.0)
	_check(state.herbs == 0 and state.dew == 0 and state.pills == 1, "brew costs three herbs and one dew")
	state.step(10.0)
	_check(is_equal_approx(state.qi, 13.0), "empty pot gently meditates at 30 percent")
	var before := state.qi
	_check(state.use_pill(), "pill can be used")
	_check(state.pills == 0 and is_equal_approx(state.qi - before, 55.0), "pill consumed for exact qi")
	_check(not state.use_pill(), "pill cannot be consumed twice")
	state.herbs = 12
	state.dew = 4
	state.step(80.0)
	_check(state.herbs == 0 and state.dew == 0 and state.pills == 4, "large delta brews exact number of pills")
	state.set_activity("gather")
	state.step(4.0)
	state.set_activity("meditate")
	state.step(5.0)
	state.set_activity("gather")
	state.step(4.0)
	_check(state.herbs == 1, "activity switching preserves partial gathering progress")


func _test_activity_boundaries() -> void:
	var state := _state()
	state.set_activity("brew")
	state.step(10.0)
	_check(is_equal_approx(state.activity_progress, 0.5), "brew progress exposed to UI")
	state.step(10.0)
	_check(state.pills == 1 and state.herbs == 0 and state.dew == 0, "starter basket immediately supports one elixir")
	state.herbs = 2
	state.dew = 10
	state.step(20.0)
	_check(state.herbs == 2 and state.dew == 10 and state.pills == 1, "insufficient herbs never consume dew")
	state.herbs = 10
	state.dew = 0
	state.step(20.0)
	_check(state.herbs == 10 and state.pills == 1, "insufficient dew never consumes herbs")
	state.set_activity("gather")
	state.step(4.0)
	_check(is_equal_approx(state.activity_progress, 0.5), "gather progress exposed to UI")
	state.herbs = State.MAX_RESOURCE
	state.dew = State.MAX_RESOURCE
	state.step(48.0)
	_check(state.herbs == State.MAX_RESOURCE and state.dew == State.MAX_RESOURCE, "resource counters are bounded")
	state.set_activity("meditate")
	state.qi = State.MAX_ENERGY
	state.step(100.0)
	_check(state.qi == State.MAX_ENERGY and state.realm == 0, "manual cultivation never forces breakthrough")
	var split := _state()
	split.set_activity("brew")
	split.herbs = 30
	split.dew = 10
	for index in range(1000):
		split.step(0.1)
	var bulk := _state()
	bulk.set_activity("brew")
	bulk.herbs = 30
	bulk.dew = 10
	bulk.step(100.0)
	_check(split.pills == 5 and split.herbs == bulk.herbs and split.dew == bulk.dew, "brewing is frame-rate independent")
	_check(split._valid_save(split._snapshot()), "fractional timer remains saveable")


func _test_breakthroughs() -> void:
	var state := _state()
	state.auto_advance = false
	state.qi = 120.0
	state.herbs = 5
	_check(not state.breakthrough() and state.qi == 120 and state.herbs == 5, "insufficient herbs consume nothing")
	state.herbs = 6
	_check(state.breakthrough(), "first breakthrough succeeds")
	_check(state.realm == 1 and state.qi == 0 and state.herbs == 0, "breakthrough exact resource deduction")
	_check(state.stats().qi_rate > 1.0, "new realm improves qi rate")
	for expected in range(2, State.MAX_REALM + 1):
		state.qi = state.stats().need_qi + 5.0
		state.herbs = state.stats().need_herbs + 2
		_check(state.breakthrough() and state.realm == expected, "advance realm %d" % expected)
	_check(state.realm_name() == "归真" and state.qi == 0 and state.merit == 5, "final realm converts surplus qi to merit")
	_check(not state.breakthrough() and state.realm == State.MAX_REALM, "realm cap cannot overflow")
	state.set_activity("meditate")
	state.step(10.0)
	_check(is_equal_approx(state.merit, 5.0 + 10.0 * float(State.QI_RATES[State.MAX_REALM])), "final realm keeps earning merit")
	state.pills = 1
	var before := state.merit
	state.use_pill()
	_check(state.merit > before and state.qi == 0, "final-realm pill grants merit")
	_check(state._valid_save(state._snapshot()), "final-realm state remains saveable")


func _test_auto_and_frame_invariance() -> void:
	var state := _state()
	state.auto_advance = true # Explicit opt-in exercises the unchanged quiet path.
	state.step(0.1)
	_check(state.activity == "meditate" and state.herbs == 3 and is_equal_approx(state.qi, 0.1), "auto launch begins in peaceful meditation")
	state.step(119.9)
	_check(state.activity == "gather" and is_equal_approx(state.qi, 120.0) and state.herbs == 3, "auto switches to gathering only after qi goal")
	state.step(23.9)
	_check(state.realm == 0, "first automatic breakthrough not premature")
	var events := state.step(0.1)
	_check(state.realm == 1 and state.herbs == 0 and state.qi < 0.001, "first auto breakthrough at 144 seconds")
	_check(events.has("境界提升 · 炼气中期"), "breakthrough emits localized event")
	var chunked := _state()
	chunked.auto_advance = true # Explicit opt-in exercises the unchanged quiet path.
	for index in range(900 * 60):
		chunked.step(1.0 / 60.0)
	var bulk := _state()
	bulk.auto_advance = true # Explicit opt-in exercises the unchanged quiet path.
	bulk.step(900.0)
	_check(chunked.realm == bulk.realm and chunked.herbs == bulk.herbs and chunked.dew == bulk.dew, "frame-independent resources")
	_check(absf(chunked.qi - bulk.qi) < 0.001, "frame-independent qi")
	var boundary := _state()
	boundary.auto_advance = true # Explicit opt-in exercises the unchanged quiet path.
	boundary.step(130.0)
	_check(boundary.activity == "gather" and is_equal_approx(boundary.qi, 120.0) and boundary.herbs == 4, "bulk meditation stops exactly at qi goal before gathering")
	_check(absf(chunked.lifetime_seconds - bulk.lifetime_seconds) < 0.001, "frame-independent lifetime")
	_check(bulk.realm == 2, "15-minute auto progression reaches late qi in the longer campaign")
	print("15-minute calm auto mode: %s, %.2f qi, %d herbs, %d dew" % [bulk.realm_name(), bulk.qi, bulk.herbs, bulk.dew])
	bulk.step(State.OFFLINE_CAP_SECONDS)
	bulk.step(3600.0)
	_check(bulk.realm == State.MAX_REALM and bulk.merit > 0, "long idle reaches cap and continues merit")
	var lifetime := bulk.lifetime_seconds
	bulk.step(1.0e10)
	_check(is_equal_approx(bulk.lifetime_seconds - lifetime, State.OFFLINE_CAP_SECONDS), "single oversized tick is capped")
	var assisted := _state()
	assisted.auto_advance = true # Explicit opt-in exercises the unchanged quiet path.
	assisted.herbs = 6
	assisted.pills = 3
	assisted.step(0.01)
	_check(assisted.realm == 1 and assisted.pills == 0, "auto mode uses existing pills for breakthrough")


func _test_persistence() -> void:
	var state := _state("_roundtrip")
	state.set_activity("gather")
	state.step(29.0)
	state.settings.music = 0.6
	state.settings.click_through = true
	_check(state.save_game(), "atomic save succeeds")
	_check(not FileAccess.file_exists(state.save_path + ".tmp"), "temporary save renamed")
	var restored := _state("_roundtrip")
	var result := restored.load_game()
	_check(result.loaded and not result.save_error, "save reloads")
	_check(restored.last_offline == result, "last offline summary is public")
	_check(restored.herbs == state.herbs and restored.dew == state.dew, "resource roundtrip")
	_check(restored.activity == "gather" and not restored.auto_advance, "manual mode roundtrip")
	_check(absf(restored._gather_clock - state._gather_clock) <= 1.0, "partial activity clock persisted")
	_check(not restored.settings.click_through and is_equal_approx(restored.settings.music, 0.6), "safe settings roundtrip")
	_check(FileAccess.file_exists(state.save_path + ".bak"), "backup checkpoint retained")
	_check(restored.reset_save() and restored.realm == 0 and restored.herbs == 3 and restored.dew == 1, "reset is safe and complete")
	var again := _state("_roundtrip")
	again.load_game()
	_check(again.realm == 0 and not again.auto_advance, "reset persists")
	var invalid_path := _state("_write_error")
	invalid_path.save_path = "user://missing_cultivation_directory_%d/save.json" % OS.get_process_id()
	_check(not invalid_path.save_game(), "write failure reported")


func _test_offline_and_clock() -> void:
	var state := _state("_offline")
	state.auto_advance = true # Legacy and opted-in offline preference is preserved.
	var data := state._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 180
	_write(state.save_path, JSON.stringify(data))
	var result := state.load_game()
	_check(result.seconds >= 180 and result.seconds <= 182 and result.realm_up == 1, "offline uses same breakthrough simulation")
	_check(result.herbs >= 3 and result.qi >= 120, "offline reports gross gathered and cultivated gains")
	result = state.load_game()
	_check(result.seconds <= 1 and result.realm_up == 0 and result.qi <= 2, "offline reward interval cannot repeat")
	data = state._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 24 * 3600
	_write(state.save_path, JSON.stringify(data))
	result = state.load_game()
	_check(result.capped and result.seconds == State.OFFLINE_CAP_SECONDS, "offline cap is eight hours")
	_check(state.realm == 14 and result.realm_up > 0, "eight-hour cap advances far into expanded campaign")
	for stamp in [1, int(Time.get_unix_time_from_system()) + 3600, 99999999999]:
		data = state._snapshot()
		data.saved_at = stamp
		var before := state.merit
		_write(state.save_path, JSON.stringify(data))
		result = state.load_game()
		_check(result.clock_invalid and result.seconds == 0 and is_equal_approx(state.merit, before), "invalid timestamp awards nothing: %d" % stamp)


func _test_malformed() -> void:
	var state := _state("_bad")
	_write(state.save_path, "{bad JSON")
	var result := state.load_game()
	_check(result.invalid_save and result.invalid_preserved and state.realm == 0, "malformed save preserved and safe")
	var recovered := _state("_recover")
	recovered.herbs = 4
	recovered.save_game()
	recovered.herbs = 9
	recovered.save_game()
	_write(recovered.save_path, "[]")
	result = recovered.load_game()
	_check(result.recovered and result.invalid_preserved and recovered.herbs == 4, "backup restores malformed save")
	var interrupted := _state("_interrupted")
	interrupted.herbs = 7
	interrupted.save_game()
	DirAccess.rename_absolute(interrupted.save_path, interrupted.save_path + ".bak")
	result = interrupted.load_game()
	_check(result.recovered and interrupted.herbs == 7, "interrupted atomic rename recovers backup")
	var oversized := _state("_oversized")
	_write(oversized.save_path, " ".repeat(65537))
	result = oversized.load_game()
	_check(result.invalid_save and result.invalid_preserved, "oversized file safely rejected and preserved")
	var good := state._snapshot()
	_check(state._valid_save(good), "default snapshot validates")
	for key in ["realm", "qi", "herbs", "dew", "pills", "merit", "lifetime_seconds", "activity", "auto_advance", "settings", "gather_clock", "dew_clock", "brew_clock"]:
		var invalid := good.duplicate(true)
		invalid[key] = []
		_check(not state._valid_save(invalid), "invalid field rejected: " + key)
	var invalid := good.duplicate(true)
	invalid.realm = State.MAX_REALM + 1
	_check(not state._valid_save(invalid), "out-of-range realm rejected")
	invalid = good.duplicate(true)
	invalid.herbs = -1
	_check(not state._valid_save(invalid), "negative resources rejected")
	invalid = good.duplicate(true)
	invalid.brew_clock = 20.0
	_check(not state._valid_save(invalid), "out-of-range activity clock rejected")
	invalid = good.duplicate(true)
	invalid.qi = NAN
	_check(not state._valid_save(invalid), "nonfinite energy rejected")


func _write(path: String, content: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		_check(false, "test fixture can be written")
		return
	file.store_string(content)
	file.close()


func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	if directory == null:
		return
	for filename in directory.get_files():
		if filename.begins_with(prefix.trim_prefix("user://")):
			directory.remove(filename)
