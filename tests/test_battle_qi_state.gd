extends SceneTree
## Resource isolation, composable manuals, paid study and exact-once heart changes.
## Every file uses an isolated user:// test path, never the player's save.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Equipment = preload("res://scripts/equipment_ledger.gd")
var checks := 0
var failures := 0
var path := "user://battle_qi_state_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_test_authored_content()
	_test_actual_equipment()
	_test_attunement_and_slots()
	_test_timed_training()
	_test_training_persistence()
	_test_heart_confirmation()
	_test_heart_persistence()
	_test_heart_price_components()
	_test_route_resources()
	_test_resource_sanitization()
	_test_migration()
	_test_timer_partition_equivalence()
	_test_corrupt_loadout_and_cost_integrity()
	_test_peaceful_progression()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("Battle qi/manual state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func fresh(rank: int = 0):
	var s := State.new()
	s.realm = rank
	s.auto_advance = false
	s.save_path = path
	return s

func funded(rank: int = 15):
	var s = fresh(rank)
	s.qi = 100000.0 if rank < 15 else 0.0
	s.merit = 100000.0 if rank == 15 else 0.0
	s.herbs = 10000
	s.dew = 10000
	return s

func balance(s) -> Array:
	return [s.qi, s.merit, s.herbs, s.dew]

func learn_fixture(s, id: String, level: int = 1) -> void:
	s.technique_levels[id] = level
	if not s.attuned_techniques.has(id):
		check(s.attune_technique(id).ok, "fixture attunes " + id)

func equip_weapon(s, template: String) -> int:
	var item: Dictionary = s.gear._make_item(s.gear._allocate_id(), template, "common", 1)
	s.gear.inventory.append(item)
	check(s.equip_item(int(item.id)), "real owned weapon equips " + template)
	return int(item.id)

func write_save(data: Dictionary) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	check(file != null, "isolated save opens")
	if file:
		file.store_string(JSON.stringify(data))
		file.close()

func _test_authored_content() -> void:
	check(Content.VERSION == 4 and Content.TECHNIQUES.size() == 10, "v4 save compatibility and bounded ten-book catalog")
	var caps := {"mist": 6, "petal": 5, "ember": 5, "stillness": 6, "breath": 4, "frost": 4, "thunder": 3, "barrier": 5, "body": 7, "mending": 4}
	for id in caps:
		var book: Dictionary = Content.TECHNIQUES[id]
		check(int(book.max_level) == int(caps[id]) and book.rank_realms.size() == int(caps[id]), "distinct authored rank cap " + id)
		check(not book.tags.is_empty() and not book.slots.is_empty(), "taxonomy and operating slots separate " + id)
		check(float(book.training_seconds) >= 8.0 and float(book.training_seconds) <= 24.0, "bounded authored study duration " + id)
		check(int(book.rank_realms[0]) == int(book.unlock_realm), "first rank obeys book realm gate " + id)
	check(Content.TECHNIQUES.petal.legacy_name == "落英身法", "legacy petal identity and utility documented")
	var s = fresh()
	check(s.stats().combat_qi_max == 40.0 and s.stats().combat_qi_regen == 2.0, "empty starter heart has base40qi/2regen")
	check(s.equipped_heart.is_empty() and not s.heart_equipped_once, "first heart choice remains explicit")
	check(s.equipped_weapon_art == "mist" and s.equipped_actives == ["mist"], "starter original art retained in independent form and active slots")
	check(s.technique_levels.mist == 1 and s.technique_levels.breath == 1, "only original mist and basic breath start learned")
	for id in Content.TECHNIQUES:
		if id not in ["mist", "breath"]: check(s.technique_levels[id] == 0, "no invented trained power " + id)

func _test_actual_equipment() -> void:
	var s = fresh()
	s.weapon = "sword"
	check(s.stats().weapon_skill.is_empty(), "cosmetic sword preset grants no weapon skill")
	var sword := equip_weapon(s, "weapon_sword")
	var skill: Dictionary = s.stats().weapon_skill
	check(skill.id == "weapon_sword_pierce" and skill.move == "weapon_sword_pierce" and skill.qi_cost == 10.0 and skill.cooldown == 9.0, "actual sword canonical unique innate")
	s.gear.get_item(sword).weapon_skill = {"id": "forged", "qi_cost": 0.0}
	check(s.stats().weapon_skill.id == "weapon_sword_pierce", "instance-injected skill ignored")
	var returned: Dictionary = s.stats().weapon_skill
	returned.qi_cost = 0.0
	check(s.stats().weapon_skill.qi_cost == 10.0, "weapon skill descriptor deep copy protects content")
	equip_weapon(s, "weapon_fan")
	check(s.stats().weapon_skill.id == "weapon_fan_return" and s.stats().weapon_skill.qi_cost == 12.0, "fan grants its own canonical innate")
	check(s.unequip_slot("weapon") and s.stats().weapon_skill.is_empty(), "unarmed has no innate")
	var loaded := Equipment.new()
	loaded.load_data(s.gear.to_dict())
	check(loaded.equipped_weapon_skill().is_empty(), "save does not invent equipped weapon")

func _test_attunement_and_slots() -> void:
	var s = funded(0)
	check(s.attunement_capacity() == 3 and s.active_capacity() == 1 and s.passive_capacity() == 0 and s.training_capacity() == 1, "initial four distinct capacity rules")
	check(not s.attune_technique("barrier").ok, "attunement respects realm gate")
	for realm in [1, 3, 6, 9, 12]:
		s.realm = realm
		check(s.attunement_capacity() == {1:4,3:5,6:6,9:7,12:8}[realm], "attunement grows at realm%d" % realm)
	s = funded(9)
	for id in ["stillness", "body", "ember", "petal", "frost"]: learn_fixture(s, id)
	check(s.attuned_techniques.size() == 7 and not s.attune_technique("barrier").ok, "finite attunement cap enforced")
	check(not s.unattune_technique("mist").ok, "equipped art cannot silently become dormant")
	check(s.unequip_technique("mist", "active").ok and s.unequip_technique("mist", "weapon_art").ok, "active and form remove independently")
	check(s.unattune_technique("mist").ok and s.technique_levels.mist == 1, "dormancy preserves learned rank")
	check(not s.equip_technique("mist", "active").ok, "dormant power cannot operate")
	check(s.equip_technique("petal", "weapon_art").ok and s.equipped_actives.is_empty(), "basic form never auto fills active bar")
	check(s.equip_technique("ember", "active").ok and s.equip_technique("frost", "active").ok, "mixed active books share bounded general bar")
	check(not s.equip_technique("petal", "active").ok, "active capacity enforced independent of category")
	check(s.equip_technique("body", "passive").ok and s.stats().max_hp == 156 and s.stats().poise_bonus == 4.0, "body boosts effective hp/poise exactly once")
	check(not s.equip_technique("stillness", "passive").ok, "passive capacity enforced")
	check(is_equal_approx(s.gather_multiplier(), 1.12) and is_equal_approx(s.brew_multiplier(), 1.15), "old petal/ember utility follows operating slots")
	check(not s.stats().weapon_art.active and s.equipped_weapon_art == "petal", "incompatible form retained visibly inactive")
	equip_weapon(s, "weapon_fan")
	check(s.stats().weapon_art.active and s.stats().weapon_art.id == "petal", "real compatible weapon activates selected form")
	check(s.unequip_technique("ember", "active").ok and s.brew_multiplier() == 1.0, "collected/attuned inactive book grants no utility")

func _test_timed_training() -> void:
	var s = funded(0)
	var before := balance(s)
	var trained: Dictionary = s.upgrade_technique("mist")
	check(trained.ok and trained.reason == "training_started" and s.technique_levels.mist == 1, "study starts without instant rank")
	check(s.herbs == before[2] - Content.FIRST_MIST_STUDY_HERBS and s.dew == before[3] - 2 and s.qi == before[0], "study exact upfront cost leaves cultivationqi untouched")
	var paid := balance(s)
	check(not s.upgrade_technique("mist").ok and balance(s) == paid, "duplicate study callback cannot charge twice")
	check(not s.upgrade_technique("breath").ok and balance(s) == paid, "second training slot unavailable initially")
	s.settings.paused = true
	s.step(100.0)
	check(s.technique_training[0].remaining == trained.duration, "global pause freezes study")
	s.settings.paused = false
	s.step(float(trained.duration) - 0.1)
	check(s.technique_levels.mist == 1 and s.technique_training.size() == 1, "rank not granted before timer boundary")
	s.step(0.1)
	check(s.technique_levels.mist == 2 and s.technique_training.is_empty() and s.counters.techniques_trained == 1, "timer grants exactly one rank and counter")
	paid = balance(s)
	check(not s.upgrade_technique("mist").ok and balance(s) == paid, "next-rank realm gate cannot charge")
	s = funded(6)
	check(s.upgrade_technique("mist").ok and s.upgrade_technique("breath").ok, "realm6 supports two parallel paid study jobs")
	check(not s.unattune_technique("breath").ok, "training book cannot be unattuned")
	check(not s.upgrade_technique("ember").ok, "third parallel study rejected")
	s.step(30.0)
	check(s.technique_levels.mist == 2 and s.technique_levels.breath == 2 and s.technique_training.is_empty(), "both parallel timers finish")
	check(s.upgrade_technique("frost").ok, "new frost prerequisite breath2 is real")
	check(s.equipped_actives == ["mist"], "new study never equips a book")
	check(s.cancel_technique_training("frost").ok and s.technique_levels.frost == 0, "explicit study cancellation grants no free rank")
	var no_prereq = funded(9)
	check(not no_prereq.upgrade_technique("thunder").ok, "thunder requires learned frost")
	var raw: Dictionary = no_prereq._snapshot()
	raw.technique_levels.mist = 999
	no_prereq._restore_campaign(raw)
	check(no_prereq.technique_levels.mist == 6, "malformed rank clamps to this book's own cap")

func _test_training_persistence() -> void:
	var s = funded(6)
	s.upgrade_technique("mist")
	s.step(3.0)
	var remaining := float(s.technique_training[0].remaining)
	var data: Dictionary = s._snapshot()
	data.settings.paused = true
	write_save(data)
	var restored = fresh()
	check(restored.load_game().loaded and is_equal_approx(restored.technique_training[0].remaining, remaining), "paid timer resumes from saved remaining")
	check(restored.herbs == s.herbs and restored.dew == s.dew, "load does not deduct study twice")
	restored.settings.paused = false
	restored.step(remaining)
	check(restored.technique_levels.mist == 2 and restored.technique_training.is_empty(), "resumed study completes once")
	data.settings.paused = false
	data.saved_at = int(Time.get_unix_time_from_system()) - 30
	write_save(data)
	restored = fresh()
	restored.load_game()
	check(restored.technique_levels.mist == 2 and restored.counters.techniques_trained == 1, "normal offline study completes within cap")
	check(restored.herbs == s.herbs and restored.dew == s.dew, "offline study no repeated payment")
	data.saved_at = int(Time.get_unix_time_from_system()) + 1000
	write_save(data)
	restored = fresh()
	var report: Dictionary = restored.load_game()
	check(report.clock_invalid and restored.technique_levels.mist == 1 and is_equal_approx(restored.technique_training[0].remaining, remaining), "clock rollback grants no study progress")
	data.technique_training[0].remaining = -100.0
	restored._restore_campaign(data)
	check(restored.technique_training[0].remaining == 0.0, "negative remaining is safely bounded")
	data.technique_training[0].remaining = NAN
	restored._restore_campaign(data)
	check(restored.technique_training[0].remaining == restored.technique_training[0].duration, "NaN study duration restarts bounded pending duration")

func _test_heart_confirmation() -> void:
	var s = funded(6)
	learn_fixture(s, "stillness")
	check(s.equip_technique("breath", "heart").reason == "confirmation_required", "ordinary equip cannot bypass heart confirmation")
	var quote: Dictionary = s.quote_heart_switch("breath")
	var before := balance(s)
	check(quote.ok and quote.first_choice and quote.duration == 0.0 and quote.cost.qi == 0.0, "first confirmed choice is free")
	check(s.equipped_heart.is_empty() and balance(s) == before, "quote has no mutating cost or slot effect")
	check(s.confirm_heart_switch("forged").reason == "stale_quote" and balance(s) == before, "forged token cannot equip or spend")
	check(s.confirm_heart_switch(quote).ok and s.equipped_heart == "breath" and s.heart_equipped_once, "first confirmed heart activates once")
	check(not s.confirm_heart_switch(quote).ok and balance(s) == before, "replayed quote cannot spend or repeat activation")
	check(s.stats().combat_qi_max == 58.0 and is_equal_approx(s.stats().combat_qi_regen, 2.35), "heart qi effects folded exactly once")
	quote = s.quote_heart_switch("stillness")
	before = balance(s)
	check(quote.duration == 18.0 and quote.cost.qi == 125.0 and quote.cost.herbs == 7 and quote.cost.dew == 2, "paid heart quote shows exact bounded price/time")
	check(s.confirm_heart_switch(quote).ok and s.equipped_heart == "breath", "paid adjustment keeps old heart operating")
	check(s.qi == before[0] - 125.0 and s.herbs == before[2] - 7 and s.dew == before[3] - 2, "heart payment deducted exactly once")
	var paid := balance(s)
	check(s.start_stage().reason == "heart_adjusting" and not s.confirm_heart_switch(quote).ok and balance(s) == paid, "pending adjustment blocks departure and duplicate payment")
	check(not s.quote_heart_switch("stillness").ok and not s.unequip_technique("breath", "heart").ok, "cannot switch or clear heart mid-adjustment")
	check(not s.unattune_technique("stillness").ok and not s.upgrade_technique("stillness").ok, "pending target remains learned/attuned and stable")
	s.step(17.9)
	check(s.equipped_heart == "breath", "old heart persists before exact completion")
	s.step(0.1)
	check(s.equipped_heart == "stillness" and s.pending_heart_switch.is_empty(), "heart changes atomically at timer completion")
	check(s.stats().combat_qi_max == 52.0 and s.stats().poise_bonus == 6.0 and is_equal_approx(s.qi_rate(), Content.QI_RATES[6] * 1.08), "new heart stats and old cultivation utility effective after commit")
	check(s.unequip_technique("stillness", "heart").ok, "heart can be cleared deliberately at courtyard")
	quote = s.quote_heart_switch("breath")
	check(not quote.first_choice and quote.duration > 0.0 and quote.cost.qi > 0.0, "unequip cannot reset first-free marker")
	s.unequip_technique("mist", "weapon_art")
	check(s.confirm_heart_switch(quote).reason == "stale_quote", "loadout mutation invalidates quote")
	quote = s.quote_heart_switch("breath")
	s.realm = 9
	check(s.confirm_heart_switch(quote).reason == "stale_quote", "realm mutation invalidates quote price")
	var started: Dictionary = s.start_stage()
	check(started.ok and s.quote_heart_switch("breath").reason == "courtyard_only", "active route cannot switch heart")
	s.pause_stage(int(started.run_id))
	check(s.quote_heart_switch("breath").reason == "courtyard_only", "paused checkpoint is still not courtyard")

func _test_heart_persistence() -> void:
	var s = funded(6)
	learn_fixture(s, "stillness")
	s.confirm_heart_switch(s.quote_heart_switch("breath"))
	s.confirm_heart_switch(s.quote_heart_switch("stillness"))
	s.step(5.0)
	var data: Dictionary = s._snapshot()
	data.settings.paused = true
	write_save(data)
	var restored = fresh()
	check(restored.load_game().loaded and restored.equipped_heart == "breath" and restored.pending_heart_switch.remaining == 13.0, "pending paid heart adjustment persists without early commit")
	check(restored.herbs == s.herbs and restored.dew == s.dew and restored.qi == s.qi, "paid adjustment reload has no duplicate deduction")
	restored.settings.paused = false
	restored.step(13.0)
	check(restored.equipped_heart == "stillness" and restored.heart_equipped_once, "resumed pending heart completes once")
	data.settings.paused = false
	data.saved_at = int(Time.get_unix_time_from_system()) - 30
	write_save(data)
	restored = fresh()
	restored.load_game()
	check(restored.equipped_heart == "stillness" and restored.pending_heart_switch.is_empty(), "offline quiet adjustment progresses normally")
	check(restored.herbs == s.herbs and restored.dew == s.dew, "offline heart completion has no repeated material charge")
	data.saved_at = int(Time.get_unix_time_from_system()) + 1000
	write_save(data)
	restored = fresh()
	check(restored.load_game().clock_invalid and restored.equipped_heart == "breath" and restored.pending_heart_switch.remaining == 13.0, "clock rollback does not progress heart timer")

func _test_heart_price_components() -> void:
	var s = funded(6)
	learn_fixture(s, "stillness")
	s.confirm_heart_switch(s.quote_heart_switch("breath"))
	var base: Dictionary = s.quote_heart_switch("stillness")
	check(base.pricing.target_tier == 2 and base.pricing.tier_steps == 1 and base.pricing.style_gap == 1 and base.pricing.rank_gap == 0, "authored higher-tier and different-style factors enter quote")
	check(base.cost.qi == 125.0 and base.cost.herbs == 7 and base.cost.dew == 2 and base.duration == 18.0, "tier and style surcharges affect actual materials and duration")
	check(not String(base.cost_reason).is_empty(), "quote explains visible pricing components")
	s.technique_levels.stillness = 3
	var distant: Dictionary = s.quote_heart_switch("stillness")
	check(distant.pricing.rank_gap == 2 and distant.cost.qi == 161.0 and distant.duration == 28.0, "larger cultivation rank gap adds real cost/time beyond target rank alone")
	s.technique_levels.breath = 3
	var matched: Dictionary = s.quote_heart_switch("stillness")
	check(matched.pricing.rank_gap == 0 and matched.cost.qi == 155.0 and matched.duration == 26.0, "same target and realm with closer origin rank has lower price")
	s.technique_levels.breath = 1
	s.technique_levels.stillness = 1
	check(s.unequip_technique("breath", "heart").ok and s.last_equipped_heart == "breath", "unequip retains previous heart origin")
	var cleared: Dictionary = s.quote_heart_switch("stillness")
	check(cleared.cost == base.cost and cleared.duration == base.duration, "clearing old heart cannot evade style/rank surcharge")
	var data: Dictionary = s._snapshot()
	data.settings.paused = true
	write_save(data)
	var restored = fresh()
	restored.load_game()
	var reloaded: Dictionary = restored.quote_heart_switch("stillness")
	check(restored.last_equipped_heart == "breath" and reloaded.cost == base.cost and reloaded.duration == base.duration, "empty-slot origin and surcharge survive save/load")
	# Same-tier target uses no target-tier premium, but changing style still costs.
	s.equipped_heart = "stillness"
	s.last_equipped_heart = "stillness"
	var reverse: Dictionary = s.quote_heart_switch("breath")
	check(reverse.pricing.tier_steps == 0 and reverse.pricing.style_gap == 1 and reverse.cost.qi == 113.0 and reverse.cost.herbs == 6, "lower-tier target has deterministically smaller premium")
	# An accepted quote stays fixed if a previously equipped manual trains later.
	s = funded(6)
	learn_fixture(s, "stillness")
	s.confirm_heart_switch(s.quote_heart_switch("breath"))
	s.confirm_heart_switch(s.quote_heart_switch("stillness"))
	s.upgrade_technique("breath")
	s.step(9.0)
	data = s._snapshot()
	data.settings.paused = true
	write_save(data)
	restored = fresh()
	restored.load_game()
	check(restored.technique_levels.breath == 2 and restored.pending_heart_switch.duration == 18.0 and restored.pending_heart_switch.remaining == 9.0, "accepted paid duration is not repriced on reload after origin training")

func _test_route_resources() -> void:
	var s = funded(6)
	var sword := equip_weapon(s, "weapon_sword")
	var started: Dictionary = s.start_stage()
	var id := int(started.run_id)
	check(started.battle_resources.qi == s.stats().combat_qi_max, "new route initializes full battleqi only once")
	var cultivation_qi: float = s.qi
	var update: Dictionary = s.update_stage_battle_resources(id, {"qi": 3.5, "cooldowns": {"mist": 5.5, "ember": 6.0, "weapon_sword_pierce": 8.0}})
	check(update.ok and s.qi == cultivation_qi, "runtime battleqi is separate from cultivationqi")
	var snapshot: Dictionary = s.stage_battle_resources()
	snapshot.cooldowns.mist = 0.0
	check(s.stage_battle_resources().cooldowns.mist == 5.5, "public snapshot is deep independent copy")
	check(s.update_stage_battle_resources(id + 1, {"qi": 999.0}).reason == "stale_encounter" and s.stage_battle_resources().qi == 3.5, "stale run cannot overwrite resources")
	s.settings.paused = true
	check(s.update_stage_battle_resources(id, {"qi": 2.0}).ok, "global pause permits final observed resource flush")
	s.settings.paused = false
	check(s.stage_battle_resources().cooldowns.ember == 6.0, "partial snapshot never clears unselected cooldowns")
	equip_weapon(s, "weapon_fan")
	check(s.stage_battle_resources().cooldowns.weapon_sword_pierce == 8.0 and s.stage_battle_resources().weapon_skill_id == "weapon_fan_return", "gear change retains old innate cooldown")
	s.equip_item(sword)
	check(s.stage_battle_resources().weapon_cd == 8.0, "switching back does not reset weapon skill")
	s.pause_stage(id)
	check(s.update_stage_battle_resources(id, {"qi": 99.0}).reason == "inactive", "paused route refuses runtime mutation")
	var data: Dictionary = s._snapshot()
	data.saved_at = int(Time.get_unix_time_from_system()) - 3600
	write_save(data)
	var restored = fresh()
	check(restored.load_game().loaded and restored.stage_status().paused, "saved route reloads paused")
	check(restored.stage_battle_resources().qi == 2.0 and restored.stage_battle_resources().cooldowns.mist == 5.5 and restored.stage_battle_resources().weapon_cd == 8.0, "offline does not regenerate battleqi or advance cooldowns")
	var resumed: Dictionary = restored.start_stage()
	check(resumed.reason == "resumed" and resumed.battle_resources.qi == 2.0 and resumed.battle_resources.weapon_cd == 8.0, "retry/resume keeps resource debt")
	var before: Dictionary = restored.stage_battle_resources()
	restored.step(1000.0)
	check(restored.stage_battle_resources() == before, "cultivation step never advances live-route battle resources")
	restored.fail_stage(int(resumed.run_id))
	check(restored.start_stage().battle_resources.qi == 2.0, "defeat retry has no free qi refill")

func _test_resource_sanitization() -> void:
	var s = fresh(6)
	var started: Dictionary = s.start_stage()
	var id := int(started.run_id)
	for malformed in [NAN, INF, -INF, "99", true, null, [], {}]:
		var result: Dictionary = s.update_stage_battle_resources(id, {"qi": malformed, "cooldowns": {"mist": malformed}})
		check(result.ok and result.battle_resources.qi == 0.0 and result.battle_resources.cooldowns.mist == 6.0, "malformed nonfinite/type values cannot refill or ready a skill")
	var result: Dictionary = s.update_stage_battle_resources(id, {"qi": -10.0, "cooldowns": {"mist": -4.0, "ember": 99999.0, "unknown": 9.0}})
	check(result.battle_resources.qi == 0.0 and result.battle_resources.cooldowns.mist == 0.0 and result.battle_resources.cooldowns.ember == 7.0, "finite values bounded to per-ability authored caps")
	check(not result.battle_resources.cooldowns.has("unknown") and result.battle_resources.cooldowns.size() == 9, "only canonical ability IDs persist")
	result = s.update_stage_battle_resources(id, {"qi": 1.0e99, "cooldowns": "bad"})
	check(result.battle_resources.qi == s.stats().combat_qi_max and result.battle_resources.cooldowns.mending == 14.0, "hugeqi bounded and invalid cooldown object conservative")
	var data: Dictionary = s._snapshot()
	data.adventure.stage_run.battle_resources = {"qi": NAN, "cooldowns": {"mist": INF, "mending": "0"}}
	var restored = fresh(6)
	restored._restore_adventure(data.adventure)
	check(restored.stage_battle_resources().qi == 0.0 and restored.stage_battle_resources().cooldowns.mist == 6.0 and restored.stage_battle_resources().cooldowns.mending == 14.0, "malformed saved resources canonicalize independently of route progress")

func _test_migration() -> void:
	for legacy in ["mist", "petal", "ember", "stillness"]:
		var s = funded(12)
		var data: Dictionary = s._snapshot()
		for field in ["manual_revision", "equipped_heart", "equipped_weapon_art", "equipped_actives", "equipped_passives", "attuned_techniques", "technique_training", "pending_heart_switch", "heart_equipped_once", "heart_switch_serial"]:
			data.erase(field)
		data.technique = legacy
		data.technique_levels = {"mist": 5, "petal": 5, "ember": 5, "stillness": 5}
		data.settings.paused = true
		write_save(data)
		var restored = fresh()
		check(restored.load_game().loaded and restored.technique_levels[legacy] == 5, "legacy selected rank preserved " + legacy)
		if legacy == "stillness":
			check(restored.equipped_heart == legacy and restored.heart_equipped_once and restored.equipped_actives.is_empty(), "legacy stillness becomes heart and used-first marker")
		elif legacy in ["mist", "petal"]:
			check(restored.equipped_weapon_art == legacy and restored.equipped_actives == [legacy] and not restored.stats().weapon_art.active, "legacy art retains incompatible selection inactive " + legacy)
		else:
			check(restored.equipped_actives == [legacy] and restored.equipped_heart.is_empty(), "legacy ember maps to general active bar")
		for id in ["frost", "thunder", "barrier", "body", "mending"]:
			check(restored.technique_levels[id] == 0, "migration grants no new trained manual " + id)
	var s = fresh()
	var started: Dictionary = s.start_stage()
	var data: Dictionary = s._snapshot()
	data.adventure.stage_run.erase("battle_resources")
	s._restore_adventure(data.adventure)
	check(s.stage_battle_resources().qi == s.stats().combat_qi_max and s.stage_battle_resources().cooldowns.mist == 0.0, "v4 absent resource fields initialize full ready without altering checkpoints")
	data.adventure.stage_run.battle_resources = {"qi": 2.0, "technique_id": "technique_mist", "technique_cd": 5.0, "weapon_skill_id": "sword_pierce", "weapon_cd": 8.0}
	s._restore_adventure(data.adventure)
	check(s.stage_battle_resources().qi == 2.0 and s.stage_battle_resources().cooldowns.mist == 5.0 and s.stage_battle_resources().cooldowns.weapon_sword_pierce == 8.0, "intermediate old lanes migrate to stable ability IDs")
	check(int(s.stage_run.run_id) == int(started.run_id) and int(s.stage_run.kills) == 0, "resource migration preserves exact route checkpoint")
	data = s._snapshot()
	data.attuned_techniques = ["mist", "breath", "barrier", "petal", "stillness", "body", "ember", "frost", "thunder", "mending", "unknown", true]
	data.technique_levels = {"mist": 5,"petal":5,"ember":5,"stillness":5,"breath":4,"body":7,"frost":4,"thunder":3,"barrier":5,"mending":4}
	s.realm = 12
	s._restore_campaign(data)
	check(s.attuned_techniques.size() == 8 and s.technique_levels.thunder == 3 and s.technique_levels.mending == 4 and not s.attuned_techniques.has("thunder"), "oversized migrated set becomes dormant without erasing ranks")

func _test_timer_partition_equivalence() -> void:
	var bulk = funded(6)
	var split = funded(6)
	for state in [bulk, split]:
		learn_fixture(state, "stillness")
		state.confirm_heart_switch(state.quote_heart_switch("breath"))
		state.confirm_heart_switch(state.quote_heart_switch("stillness"))
		state.upgrade_technique("mist")
		state.upgrade_technique("breath")
	bulk.step(60.0)
	for tick in range(600): split.step(0.1)
	check(is_equal_approx(bulk.qi, split.qi) and bulk.herbs == split.herbs and bulk.dew == split.dew, "paid heart/study exact boundaries preserve bulk/split resources")
	check(bulk.technique_levels == split.technique_levels and bulk.equipped_heart == split.equipped_heart and bulk.technique_training == split.technique_training, "parallel study and atomic heart transitions partition invariant")
	check(bulk.counters.techniques_trained == 2 and split.counters.techniques_trained == 2, "partitioning never duplicates completed study counters")
	check(is_equal_approx(bulk.qi, 100000.0 - 125.0 + 18.0 * Content.QI_RATES[6] + 42.0 * Content.QI_RATES[6] * 1.08), "old/new heart utility applies on exact adjustment boundary")

func _test_corrupt_loadout_and_cost_integrity() -> void:
	var s = funded(6)
	learn_fixture(s, "stillness")
	var quote: Dictionary = s.quote_heart_switch("breath")
	quote.cost.qi = -99999.0
	quote.to_id = "stillness"
	check(s.confirm_heart_switch(quote).ok and s.equipped_heart == "breath" and s.qi == 100000.0, "client-mutated quote cannot change confirmed target or cost")
	quote = s.quote_heart_switch("stillness")
	quote.cost.qi = 0.0
	quote.cost.herbs = 0
	quote.duration = 0.0
	check(s.confirm_heart_switch(quote).ok and s.qi == 99875.0 and s.pending_heart_switch.remaining == 18.0, "confirmed payment uses stored quote rather than client edited fields")
	check(s.equip_technique("stillness", "passive").reason == "wrong_slot", "heart manuals cannot bypass paid switching through passive slot")
	s.step(18.0)
	s.technique_levels.breath = 2
	var exact: Dictionary = s.quote_heart_switch("breath")
	check(String(exact.new_effect).contains("+8") and String(exact.new_effect).contains("+0.40"), "quote displays actual target rank qi effects")
	check(String(exact.old_effect).contains("+6") and String(exact.old_effect).contains("+8%"), "quote displays actual old heart poise/cultivation effects")
	var data: Dictionary = s._snapshot()
	data.pending_heart_switch = {}
	data.equipped_heart = "mist"
	data.equipped_weapon_art = "stillness"
	data.equipped_actives = ["mist", "mist", "breath", "unknown", true, "stillness"]
	data.equipped_passives = ["breath", "stillness", "mist"]
	data.technique_training = [{"id":"mist", "target_level":99, "remaining":0}, {"id":"unknown", "target_level":1}, {"id":"breath", "target_level":3, "remaining":INF}, {"id":"breath", "target_level":3, "remaining":0}]
	s._restore_campaign(data)
	check(s.equipped_heart.is_empty() and s.equipped_weapon_art.is_empty() and s.equipped_actives == ["mist"] and s.equipped_passives.is_empty(), "wrong-slot/duplicate/unknown saved methods cannot create operating powers")
	check(s.technique_training.size() == 1 and s.technique_training[0].id == "breath" and is_finite(s.technique_training[0].remaining), "corrupt study targets/duplicates rejected and nonfinite timer bounded")
	s.start_stage()
	data = s._snapshot()
	data.adventure.stage_run.battle_resources = "malformed"
	s._restore_adventure(data.adventure)
	check(s.stage_battle_resources().qi == 0.0 and s.stage_battle_resources().cooldowns.mist == 6.0, "malformed entire resource object cannot ready paid skills")

func _test_peaceful_progression() -> void:
	var s := State.new()
	s.auto_advance = true # Deliberately opt into the unchanged quiet path.
	s.step(28800.0)
	s.step(7200.0)
	check(s.realm == 15 and s.campaign_finished_at == 30772.0, "unchanged peaceful completion remains exactly30772seconds")
	check(s.total_victories == 0 and s.stage_run.is_empty() and s.technique_training.is_empty(), "peaceful progress starts no battle or unsolicited training")
	var ranked = funded(14)
	for point in Content.ACUPOINTS:
		check(ranked.unlock_meridian(String(point.id)).ok, "all old/new meridian nodes remain obtainable " + String(point.id))
	check(ranked.stats().combat_qi_max == 76.0 and ranked.stats().combat_qi_regen == 2.25, "meaningful bounded meridian qi mods effective")
	check(is_equal_approx(ranked.stats().skill_cost_reduction, 0.06) and is_equal_approx(ranked.stats().skill_cooldown_reduction, 0.08), "separate cost and cooldown branches effective")
	check(ranked._valid_save(ranked._snapshot()), "new fields retain valid v4 save")
