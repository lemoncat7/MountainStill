extends SceneTree
## Expanded v1 campaign regression suite. All saves use isolated test paths.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
var prefix := "user://test_campaign_%d" % OS.get_process_id()

func _initialize() -> void:
	_test_content_and_balance()
	_test_assisted_balance()
	_test_techniques()
	_test_alchemy()
	_test_journey_equivalence()
	_test_quests_collections()
	_test_migration_pause_clock()
	_test_sanitization_limits()
	_test_long_idle_performance()
	_test_offline_summary_claims()
	_cleanup()
	print("Campaign tests: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(value: bool, label: String) -> void:
	checks += 1
	if not value:
		failures += 1
		push_error("FAIL: " + label)

func state(suffix: String = "") -> State:
	var result := State.new()
	result.auto_advance = true # Historical quiet-path regression explicitly opts in.
	result.save_path = prefix + suffix + ".json"
	return result

func _test_content_and_balance() -> void:
	check(Content.REALM_NAMES.size() == 16 and State.MAX_REALM == 15, "five realms three phases plus final")
	check(Content.TECHNIQUES.size() == 10 and Content.RECIPES.size() == 3 and Content.JOURNEYS.size() == 3, "bounded authored content")
	check(Content.QUESTS.size() == 12 and Content.DISCOVERIES.size() == 6, "twelve quests and six travel discoveries")
	var s := state()
	var milestones: Array = []
	var previous := 0
	while s.realm < State.MAX_REALM and s.lifetime_seconds < 40000:
		s.step(1.0)
		if s.realm != previous:
			milestones.append("%s %.0fs" % [s.realm_name(), s.lifetime_seconds])
			previous = s.realm
	check(s.realm == 15 and s.completion_status().complete, "unassisted peaceful idle reaches ending")
	check(s.campaign_finished_at >= 6 * 3600 and s.campaign_finished_at <= 10 * 3600, "main arc balances to six to ten hours")
	check(s.quest_claimed.is_empty() and s.total_victories == 0 and s.journey_completed == 0, "no combat quests or journeys gate main ending")
	check(is_equal_approx(s.campaign_finished_at, 30772.0), "base completion exact 8h32m52s")
	print("BASE CAMPAIGN: %.0fs / %.2fh; %s" % [s.campaign_finished_at, s.campaign_finished_at / 3600.0, "; ".join(milestones)])
	var before := s.merit
	s.step(100.0)
	check(s.merit > before and s.qi == 0.0 and not s.breakthrough(), "postgame calmly continues merit")
	check(s.journal_rows().any(func(row): return String(row.text).contains("此心归处")), "ending recorded in journal")

func _test_assisted_balance() -> void:
	var s := state()
	s.gear.rng.seed = 2026
	s._journey_rng.seed = 2026
	s.start_journey("bamboo", true)
	var reward: Dictionary = s.open_chest()
	if reward.item is Dictionary:
		s.equip_item(int(reward.item.id))
	while s.realm < State.MAX_REALM and s.lifetime_seconds < 40000:
		for row in s.quest_rows():
			if bool(row.ready):
				s.claim_quest(String(row.id))
		if s.realm >= 3 and int(s.technique_levels.stillness) == 0:
			s.upgrade_technique("stillness")
		if int(s.technique_levels.stillness) > 0 and s.equipped_heart.is_empty():
			s.confirm_heart_switch(s.quote_heart_switch("stillness"))
		s.step(30.0)
	check(s.realm == State.MAX_REALM and s.campaign_finished_at >= 6.0 * 3600.0 and s.campaign_finished_at <= 10.0 * 3600.0, "lightly assisted route remains six-to-ten-hour main arc")
	print("ASSISTED CAMPAIGN: %.2fh; starter gear, stillness I, repeating bamboo journey; %d returns" % [s.campaign_finished_at / 3600.0, s.journey_completed])
	var a := state("_eight_hour_live")
	var b := state("_eight_hour_offline")
	a._journey_rng.seed = 20261019
	b._journey_rng.seed = 20261019
	a.start_journey("bamboo", true)
	b.start_journey("bamboo", true)
	for index in range(State.OFFLINE_CAP_SECONDS):
		a.step(1.0)
	b.step(State.OFFLINE_CAP_SECONDS)
	check(a.realm == b.realm and a.herbs == b.herbs and a.dew == b.dew and a.pills == b.pills and a.journey_completed == b.journey_completed, "eight-hour offline and online full campaign equivalence")
	check(is_equal_approx(a.qi, b.qi) and is_equal_approx(a.merit, b.merit) and a._journey_rng.state == b._journey_rng.state, "eight-hour energy and deterministic rng equivalence")

func _test_techniques() -> void:
	var s := state()
	check(s.technique_rows().size() == 10 and s.technique_levels.mist == 1, "bounded ten-manual catalog preserves starter technique")
	check(not s.select_technique("missing") and not s.select_technique("petal"), "cannot choose locked or unlearned technique")
	s.herbs = 20000
	s.dew = 10000
	s.auto_advance = false
	check(not s.upgrade_technique("ember").ok, "cannot learn locked technique")
	s.realm = 15
	for id in Content.TECHNIQUES:
		var cap := int(Content.TECHNIQUES[id].max_level)
		for target in range(int(s.technique_levels[id]) + 1, cap + 1):
			var row: Dictionary = s.technique_rows().filter(func(r): return r.id == id)[0]
			var old_herbs := s.herbs
			var old_dew := s.dew
			var result := s.upgrade_technique(id)
			check(result.ok, "start paid study " + id)
			if not result.ok: break
			check(s.herbs == old_herbs - int(row.cost_herbs) and s.dew == old_dew - int(row.cost_dew), "training deducts exact displayed costs once")
			check(int(s.technique_levels[id]) == target - 1, "rank waits for its actual timer")
			s.step(float(result.duration))
			check(int(s.technique_levels[id]) == target, "paid timed training completes " + id)
		check(int(s.technique_levels[id]) == cap and not s.upgrade_technique(id).ok, "book-specific finite rank cap")
		if s.equipped_technique_slots(id).is_empty(): s.unattune_technique(id)
	check(s.select_technique("mist") and s.stats().attack == 8 + s.realm * 2 + 18, "mist operating rank6 attack scales alongside earned realm attack")
	check(is_equal_approx(s.gather_multiplier(), 1.0) and is_equal_approx(s.brew_multiplier(), 1.0), "dormant learned gathering/alchemy books grant no effects")
	s.unequip_technique("mist", "active")
	check(s.attune_technique("petal").ok and s.select_technique("petal") and is_equal_approx(s.gather_multiplier(), 1.6), "petal operating slot retains old gathering bonus")
	check(s.stats().attack == 8 + s.realm * 2, "mist bonus absent when no operating mist slot")
	check(s.attune_technique("ember").ok and s.select_technique("ember") and is_equal_approx(s.brew_multiplier(), 1.75), "general active bar can combine alchemy and gathering utility")
	check(s.attune_technique("stillness").ok and s.confirm_heart_switch(s.quote_heart_switch("stillness")).ok and is_equal_approx(s.qi_rate(), State.QI_RATES[15] * 1.48), "separate confirmed heart retains old per-rank meditation bonus")
	check(int(s.technique_levels.mist) == 6, "operating slot switches preserve learned ranks")

func _test_alchemy() -> void:
	var s := state()
	s.realm = 4
	s.herbs = 500
	s.dew = 500
	s.auto_advance = false
	for id in Content.RECIPES:
		check(s.select_recipe(id), "recipe selected " + id)
		s.set_activity("brew")
		var recipe: Dictionary = Content.RECIPES[id]
		var old_herbs := s.herbs
		var old_dew := s.dew
		s.step(float(recipe.seconds) - 0.25)
		check(s.pill_stocks[id] == 0 and s.herbs == old_herbs, "brewing waits without early payment")
		s.step(0.25)
		check(s.pill_stocks[id] == 1 and s.herbs == old_herbs - int(recipe.herbs) and s.dew == old_dew - int(recipe.dew), "stored pill and exact recipe costs")
	check(s.use_pill("spring") and s.use_pill("clarity"), "temporary pills consume")
	check(s.buff_rows().size() == 2 and is_equal_approx(s.gather_multiplier(), 1.5), "gather buff actual effect")
	check(is_equal_approx(s.qi_rate(), State.QI_RATES[4] * 1.35), "qi buff actual effect")
	s.set_activity("meditate")
	var old_qi := s.qi
	s.step(400.0)
	check(is_equal_approx(s.qi - old_qi, State.QI_RATES[4] * (300.0 * 1.35 + 100.0)), "buff expires at exact simulation boundary")
	check(s.buff_rows().is_empty(), "buff expires offline simulation")
	check(not s.use_pill("spring") and not s.use_pill("unknown"), "empty or invalid pill rejected")
	s.select_recipe("qi")
	s.set_activity("brew")
	s.step(5.0)
	s.select_recipe("spring")
	s.step(7.0)
	s.select_recipe("qi")
	check(is_equal_approx(s._brew_clock, 5.0), "switching recipe preserves partially brewed work")
	s.step(15.0)
	check(s.pills == 2, "restored partial recipe finishes once")
	s.pill_stocks.spring = 30
	for index in range(12):
		check(s.use_pill("spring"), "buff duration stacks to cap")
	check(not s.use_pill("spring") and s.pill_stocks.spring == 18, "full buff duration never wastes pill")

func _configure_equivalence(s: State) -> void:
	s.realm = 9
	s.auto_advance = false
	s.activity = "gather"
	s.technique_levels.petal = 3
	s.attune_technique("petal")
	s.select_technique("petal")
	s.pill_stocks.spring = 1
	s.use_pill("spring")
	s._journey_rng.seed = 778899
	s.start_journey("creek", true)

func _test_journey_equivalence() -> void:
	var bulk := state("_bulk")
	var split := state("_split")
	_configure_equivalence(bulk)
	_configure_equivalence(split)
	check(not bulk.start_journey("bamboo").ok, "busy fox cannot be dispatched twice")
	bulk.step(7200.0)
	for index in range(72000):
		split.step(0.1)
	check(bulk.herbs == split.herbs and bulk.dew == split.dew and bulk.journey_bond == split.journey_bond, "offline and online resources equal with skill buffs and repeated journeys")
	check(is_equal_approx(bulk.qi, split.qi) and bulk.discoveries == split.discoveries, "deterministic offline journey rewards")
	check(bulk.journey_completed == 12 and split.journey_completed == 12 and bulk.chest_count == 5, "every three returns grants unopened chest")
	check(bulk._journey_rng.state == split._journey_rng.state, "saved deterministic journey RNG at same position")
	check(bulk.journey_status().active and is_equal_approx(float(bulk.journey.remaining), 600.0), "explicit repeat starts next journey at exact boundary")
	bulk.set_journey_repeat(false)
	bulk.step(600.0)
	check(not bulk.journey_status().active and bulk.journey_completed == 13, "repeat disabled completes current journey and stops")
	var s := state("_journey_save")
	_configure_equivalence(s)
	s.step(123.0)
	check(s.save_game(), "partial journey saves")
	var restored := state("_journey_save")
	var report := restored.load_game()
	if int(report.seconds) > 0:
		s.step(float(report.seconds))
	check(report.loaded and restored.journey.id == s.journey.id and is_equal_approx(float(restored.journey.remaining), float(s.journey.remaining)) and restored._journey_rng.state == s._journey_rng.state, "journey timer and rng roundtrip")
	check(restored.buffs == s.buffs, "remaining simulated buff persisted")
	s.step(477.0)
	restored.step(477.0)
	check(s.journey_last_result == restored.journey_last_result, "same return event after reload")
	var fresh := state()
	check(not fresh.start_journey("ridge").ok and not fresh.start_journey("unknown").ok, "unknown and locked routes rejected")
	check(fresh.start_journey("bamboo").ok, "first route available without combat")
	fresh.step(300.0)
	check(fresh.journey_completed == 1 and not fresh.journey_status().active, "single journey never repeats implicitly")

func _test_quests_collections() -> void:
	var s := state()
	check(not s.claim_quest("settle").ok and not s.claim_quest("unknown").ok, "quest claim checks objective and id")
	s.step(60.0)
	check(s.quest_rows()[0].ready and s.claim_quest("settle").ok, "first actionable quest claims")
	check(not s.claim_quest("settle").ok, "quest cannot duplicate rewards")
	check(not s.claim_quest("home").ok, "later quest requires preceding claims")
	s.realm = 15
	s.qi = 0.0
	s.lifetime_seconds = 50000.0
	s.journey_completed = 4
	for key in s.counters:
		s.counters[key] = 10
	for row in s.quest_rows():
		if not bool(row.claimed):
			check(s.claim_quest(String(row.id)).ok, "claim completed chain " + String(row.id))
	check(s.completion_status().quest_claimed == 12, "all twelve claimable quests recorded")
	var reward: Dictionary = s.open_chest()
	check(bool(reward.ok) and reward.item is Dictionary, "starter chest still guarantees gear")
	var id := int(reward.item.id)
	var template_id := String(reward.item.template_id)
	s.herbs = 1000
	s.dew = 1000
	check(s.enhance_item(id).ok and s.counters.enhanced == 11, "state wrapper pays and records enhancement")
	check(s.salvage_item(id).ok, "unequipped enhanced item can salvage")
	var row: Dictionary = s.collection_status().items.filter(func(item): return item.id == template_id)[0]
	check(row.unlocked, "acquired collection survives salvage")
	check(s.collection_status().total == 45, "collection shows all realms items discoveries skills recipes")
	for index in range(90):
		s._record("journal " + str(index))
	check(s.journal_rows().size() == 60 and s.journal_rows()[0].text == "journal 89", "journal bounded newest-first")

func _test_migration_pause_clock() -> void:
	for old_realm in range(8):
		var s := state("_migration%d" % old_realm)
		var data := s._snapshot()
		data.version = 2
		data.realm = old_realm
		data.qi = 0.0
		data.pills = 3
		data.erase("pill_stocks")
		data.erase("technique_levels")
		data.auto_advance = false
		_write(s.save_path, data)
		var report := s.load_game()
		check(report.loaded and report.migrated and s.realm == [0, 1, 2, 3, 6, 9, 12, 15][old_realm], "legacy realm semantic migration")
		check(s.pills == 3 and s.inventory.is_empty(), "legacy consumables preserved without inventing gear")
		check(s._valid_save(s._snapshot()), "migrated save validates")
	var paused := state("_paused")
	paused.settings.paused = true
	paused.start_journey("bamboo", true)
	var data := paused._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 3600
	_write(paused.save_path, data)
	var report := paused.load_game()
	check(report.seconds == 0 and paused.lifetime_seconds == 0 and paused.journey.remaining == 300, "paused offline rest grants no catchup")
	paused.step(900.0)
	check(paused.lifetime_seconds == 0 and paused.qi == 0, "paused online freezes entire simulation")
	paused.settings.paused = false
	report = paused.load_game()
	check(report.seconds == 0, "pause checkpoint consumes absence interval")
	var rollback := state("_rollback")
	data = rollback._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) + 3600
	_write(rollback.save_path, data)
	report = rollback.load_game()
	check(report.clock_invalid and report.seconds == 0, "clock rollback gives no award")
	var checkpoint: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(rollback.save_path))
	check(int(checkpoint.saved_at) == int(data.saved_at), "rollback retains timestamp high-water mark")
	report = rollback.load_game()
	check(report.clock_invalid and rollback.lifetime_seconds == 0, "repeated rollback load cannot farm progress")

func _test_sanitization_limits() -> void:
	var s := state("_optional")
	var data := s._snapshot()
	data.realm = 4
	data.auto_advance = false
	data.technique_levels = {"mist": -100, "petal": 999, "ember": [], "stillness": "oops"}
	data.pill_stocks = {"qi": 4, "spring": -100, "clarity": []}
	data.buffs = {"spring": 1.0e20, "clarity": []}
	data.journey = {"id": "missing", "remaining": -50}
	data.discoveries = {"made_up": true, "bamboo_leaf": true}
	data.quest_claimed = {"made_up": true}
	data.counters = {"brewed": 1.0e30}
	data.journal_entries = [{"text": "hello", "time": 0}, {"text": [], "time": -100}]
	data.settings.window_mode = []
	data.settings.window_x = "bad"
	_write(s.save_path, data)
	var report := s.load_game()
	check(report.loaded and s.realm == 4, "malformed optional sections preserve core save")
	check(s.technique_levels.mist == 0 and s.technique_levels.petal == 5 and s.technique_levels.ember == 0, "technique levels safely bounded")
	check(s.pills == 4 and s.pill_stocks.spring == 0 and s.pill_stocks.clarity == 0, "pill stocks sanitized")
	check(s.buffs.is_empty() and s.journey.is_empty() and s.discoveries.size() == 1 and s.quest_claimed.is_empty(), "invalid bonus routes and collection ids ignored")
	check(s.settings.window_mode == "strip" and s.settings.window_x == -99999, "window placement sanitizes independently")
	s.herbs = State.MAX_RESOURCE
	s.dew = State.MAX_RESOURCE
	s.qi = State.MAX_ENERGY
	s.set_activity("gather")
	s.start_journey("bamboo", true)
	s.step(State.OFFLINE_CAP_SECONDS)
	check(s.herbs == State.MAX_RESOURCE and s.dew == State.MAX_RESOURCE and s.qi == State.MAX_ENERGY, "all reward resources bounded")
	check(s._valid_save(s._snapshot()), "saturated state stays saveable")
	var clean := state()._snapshot()
	s.quest_claimed.set("settle", true)
	s.discoveries.set("pine_cone", true)
	s.pill_stocks.spring = 3
	s.use_pill("spring")
	for key in ["quest_claimed", "discoveries", "buffs", "journey", "pill_stocks", "journal_entries"]:
		clean.erase(key)
	_write(s.save_path, clean)
	var reload_report := s.load_game()
	check(reload_report.loaded and s.quest_claimed.is_empty() and s.discoveries.is_empty() and s.buffs.is_empty() and s.journey.is_empty() and s.pill_stocks.spring == 0, "repeated load clears missing optional campaign fields")
	check(s.reset_save() and s.realm == 0 and s.journey.is_empty() and s.buffs.is_empty() and s.quest_claimed.is_empty(), "reset removes all campaign progress")

func _test_long_idle_performance() -> void:
	var s := state("_long_idle")
	s.realm = State.MAX_REALM
	s.campaign_finished_at = 30772.0
	s.lifetime_seconds = s.campaign_finished_at
	s.gear.rng.seed = 20261019
	s._journey_rng.seed = 20261019
	# Exercise a full inventory without allowing offline travel to create items.
	for index in range(s.gear.CAPACITY):
		var template_id: String = s.gear.TEMPLATES.keys()[index % s.gear.TEMPLATES.size()]
		s.gear.inventory.append(s.gear._make_item(index + 1, template_id, "epic", 100, 5))
		s.gear.discovered_templates[template_id] = true
	check(s.start_journey("bamboo", true).ok, "long-idle fastest repeated journey starts")
	var begin := Time.get_ticks_usec()
	var max_events := 0
	var max_journal := 0
	for chunk in range(90):
		var events := s.step(State.OFFLINE_CAP_SECONDS)
		max_events = maxi(max_events, events.size())
		max_journal = maxi(max_journal, s.journal_rows().size())
		check(events.size() <= 100, "eight-hour summary event count bounded")
		check(s.inventory.size() <= s.gear.CAPACITY and s.journal_rows().size() <= 60, "inventory and journal remain bounded through long idle")
	var elapsed_ms := float(Time.get_ticks_usec() - begin) / 1000.0
	check(s.journey_completed == 8640 and s.chest_count == 2881, "thirty days awards exactly 8640 returns and 2880 new unopened chests")
	check(s.journey_bond == 8640 and s.journal_rows().size() == 60, "thirty-day bond exact and journal keeps latest sixty")
	check(s.inventory.size() == 100 and s.qi == 0.0 and s.merit > 0.0, "full inventory preserved and postgame energy uses merit")
	check(s.herbs <= State.MAX_RESOURCE and s.dew <= State.MAX_RESOURCE and s.merit <= State.MAX_ENERGY, "long idle respects all resource caps")
	check(s.save_game(), "long-idle full-inventory checkpoint writes")
	var file := FileAccess.open(s.save_path, FileAccess.READ)
	var bytes := file.get_length()
	file.close()
	check(bytes < 262144 and s._read_save(s.save_path).ok, "full thirty-day save stays below 256KiB and validates")
	var restored := state("_long_idle")
	check(restored.load_game().loaded and restored.inventory.size() == 100 and restored.journal_rows().size() == 60, "long-idle save roundtrip preserves bounded history and full gear")
	print("LONG IDLE: 30 simulated days in 90 eight-hour chunks; %.2fms wall; 8640 fox returns; max %d events/chunk; max journal %d; inventory %d; save %d bytes" % [elapsed_ms, max_events, max_journal, s.inventory.size(), bytes])

func _test_offline_summary_claims() -> void:
	var s := state("_offline_summary")
	var data := s._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 180
	_write(s.save_path, data)
	var report := s.load_game()
	check(report.realm_up == 1 and s.realm == 1, "offline summary counts each breakthrough once")
	check(report.herbs == 3 and report.qi >= 168.0 and report.qi < 172.0, "offline summary reports gross gains rather than double-counting spent rewards")
	check(s.quest_rows()[0].ready and not s.quest_rows()[0].claimed, "offline objective progress unlocks an explicitly claimable quest")
	var summary_before := s.last_offline.duplicate(true)
	var herbs_before := s.herbs
	check(s.claim_quest("settle").ok and s.herbs == herbs_before + 3, "offline-ready quest awards its materials exactly once on claim")
	check(s.last_offline == summary_before and not s.claim_quest("settle").ok, "quest claim neither duplicates nor rewrites previous offline summary")
	check(s.save_game(), "claimed offline-ready reward checkpoints")
	report = s.load_game()
	check(report.realm_up == 0 and report.herbs == 0 and report.qi <= 3.0, "repeat load cannot duplicate offline breakthrough or gathered rewards")
	check(s.quest_rows()[0].claimed and s.herbs == herbs_before + 3, "claimed quest remains paid exactly once after reload")

func _write(path: String, data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(data))
	file.close()

func _cleanup() -> void:
	var directory := DirAccess.open("user://")
	for filename in directory.get_files():
		if filename.begins_with(prefix.trim_prefix("user://")):
			directory.remove(filename)
