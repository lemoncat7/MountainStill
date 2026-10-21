extends SceneTree
## Branch purchases, exact legacy migration, canonical restoration and real stats.
const State = preload("res://scripts/cultivation_state.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
var save_path := "user://meridian_branches_%d.json" % OS.get_process_id()

func _initialize() -> void:
	_test_content_graph()
	_test_branch_choices()
	_test_exact_migration()
	_test_explicit_roundtrip()
	_test_all_nodes_and_peaceful_progress()
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(save_path + suffix):DirAccess.remove_absolute(save_path + suffix)
	print("Meridian branches: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func funded(realm: int = 14):
	var s := State.new()
	s.realm = realm
	s.auto_advance = false
	s.qi = 100000.0
	s.herbs = 10000
	s.dew = 10000
	s.settings.paused = true
	s.save_path = save_path
	return s

func row(s, id: String) -> Dictionary:
	for point in s.meridian_rows():
		if str(point.id) == id:return point
	return {}

func resources(s) -> Array:
	return [s.qi, s.merit, s.herbs, s.dew, s.meridian_node_ids()]

func _test_content_graph() -> void:
	check(Content.ACUPOINTS.size() == 22, "22 bounded nodes")
	var seen := {}
	var branches := {}
	for point in Content.ACUPOINTS:
		check(not seen.has(point.id), "unique ID " + str(point.id))
		check(not point.bonuses.is_empty() and not str(point.effect).is_empty(), "node has a real effect " + str(point.id))
		check(int(point.unlock_realm) >= 0 and int(point.unlock_realm) <= 14, "node unlocks before peaceful completion")
		for parent in point.prerequisites:
			check(seen.has(parent), "acyclic topological prerequisite " + str(point.id))
		seen[point.id] = true
		branches[point.branch] = int(branches.get(point.branch, 0)) + 1
	check(branches == {"central": 6, "edge": 4, "ward": 4, "flow": 4, "quiet": 4}, "four distinct branches plus preserved central channel")

func _test_branch_choices() -> void:
	var s = funded(0)
	check(s.unlock_meridian("qihai").ok, "shared root opens")
	check(row(s, "guanyuan").can_unlock and row(s, "shangyang").can_unlock and row(s, "lieque").can_unlock and row(s, "laogong").can_unlock, "four independent next choices after 气海")
	check(not row(s, "taixi").can_unlock, "游风 keeps its own realm gate")
	check(s.unlock_meridian("lieque").ok and not row(s, "shangyang").active, "defensive branch need not buy offensive branch")
	check(s.stats().poise_bonus == 4 and s.stats().break_bonus == 0.0, "branch choice changes real build")
	var before := resources(s)
	check(not s.unlock_meridian("lieque").ok and resources(s) == before, "duplicate purchase does not charge or grant twice")
	check(not s.unlock_meridian("daling").ok and resources(s) == before, "terminal cannot skip parents")
	s.realm = 1
	check(s.unlock_meridian("neiguan").ok, "one side of diamond opens")
	check(not row(s, "daling").unlocked and row(s, "daling").missing_prerequisites == ["间使"], "both diamond parents are required")
	s.realm = 3
	check(s.unlock_meridian("jianshi").ok, "other side of diamond opens")
	check(not row(s, "daling").unlocked and str(row(s, "daling").locked_reason).contains("元婴"), "terminal still obeys realm gate after both parents")
	s.realm = 9
	before = resources(s)
	var selected := row(s, "daling")
	check(s.unlock_meridian("daling").ok, "both parents and realm permit terminal")
	check(s.qi == before[0] - selected.cost_qi and s.herbs == before[2] - selected.cost_herbs and s.dew == before[3] - selected.cost_dew, "displayed terminal costs paid exactly once")
	check(s.stats().poise_bonus == 10 and is_equal_approx(s.stats().guard_bonus, 0.08) and is_equal_approx(s.stats().recovery_bonus, 0.04), "defensive path aggregates poise, guard and recovery")
	check(s.meridian_node_ids() == ["qihai", "lieque", "neiguan", "jianshi", "daling"], "unlock is explicit branch IDs, never a positional prefix")
	s.qi = 0.0
	before = resources(s)
	check(s.unlock_meridian("shangyang").reason == "resources" and resources(s) == before, "insufficient resources change nothing")
	check(s.unlock_meridian("unknown").reason == "missing" and resources(s) == before, "unknown node changes nothing")

func _test_exact_migration() -> void:
	for count in range(7):
		var s = funded()
		s._restore_meridians({"meridian_count": count})
		check(s.meridian_node_ids() == Content.LEGACY_ACUPOINT_IDS.slice(0, count), "v4 prefix %d maps exactly to the legacy IDs" % count)
		check(s.stats().combat_haste == 0.0 and s.stats().poise_bonus == 0 and s.stats().dodge_bonus == 0.0, "legacy save gains no new combat perks")
	for realm in range(16):
		var s = funded(realm)
		s._restore_meridians({"meridian_count": 999999})
		var expected: Array[String] = []
		for point in Content.ACUPOINTS.slice(0, 6):
			if realm >= int(point.unlock_realm):expected.append(str(point.id))
		check(s.meridian_node_ids() == expected, "legacy count validates realm %d without opening new branches" % realm)
	for bad in [1.5, "6", true, [], {}, null]:
		var s = funded()
		s._restore_meridians({"meridian_count": bad})
		check(s.meridian_count == 0, "invalid legacy count is rejected")
	var s = funded()
	var snapshot: Dictionary = s._snapshot()
	snapshot.adventure.erase("meridian_nodes")
	snapshot.adventure.erase("meridian_revision")
	snapshot.adventure.meridian_count = 6
	_write(snapshot)
	check(s.load_game().loaded and s.meridian_node_ids() == Content.LEGACY_ACUPOINT_IDS, "real v4 file migration preserves all and only six old unlocks")
	check(s.save_game(), "migrated save writes new node list")
	var again = funded()
	check(again.load_game().loaded and again.meridian_node_ids() == Content.LEGACY_ACUPOINT_IDS, "migration is idempotent after writing new format")

func _test_explicit_roundtrip() -> void:
	var s = funded()
	for id in ["qihai", "taixi", "xuanzhong", "zhaohai", "fengchi", "laogong"]:
		check(s.unlock_meridian(id).ok, "non-prefix branch purchase " + id)
	var before := resources(s)
	var stats: Dictionary = s.stats()
	check(s.save_game(), "branched save written")
	var restored = funded()
	check(restored.load_game().loaded and resources(restored) == before, "branched IDs and exact paid balances roundtrip")
	check(restored.stats() == stats, "real effective modifiers roundtrip")
	check(not restored.unlock_meridian("fengchi").ok and resources(restored) == before, "reloaded terminal cannot charge twice")
	# Unordered lists are accepted canonically; malformed types and unsupported
	# IDs never become upgrades, and absent parent chains are never filled in.
	restored._restore_meridians({"meridian_revision": 1, "meridian_count": 22, "meridian_nodes": ["hegu", "qihai", "shangyang", "hegu", "unknown", 3, true, "daling"]})
	check(restored.meridian_node_ids() == ["qihai", "shangyang", "hegu"], "sanitize unordered/duplicate/unknown nodes and unearned terminal")
	restored.realm = 0
	restored._restore_meridians({"meridian_revision": 1, "meridian_nodes": ["qihai", "taixi", "zhaohai", "xuanzhong", "fengchi", "shangyang"]})
	check(restored.meridian_node_ids() == ["qihai", "shangyang"], "new list cannot bypass realm gates")
	for bad in ["qihai", {"qihai": true}, true, null]:
		restored._restore_meridians({"meridian_revision": 1, "meridian_count": 6, "meridian_nodes": bad})
		check(restored.meridian_count == 0, "malformed new list never falls back to count")
	restored._restore_meridians({"meridian_revision": 1, "meridian_count": 6})
	check(restored.meridian_count == 0, "missing list in new format does not invent legacy nodes")

func _test_all_nodes_and_peaceful_progress() -> void:
	var s = funded()
	for point in Content.ACUPOINTS:
		check(s.unlock_meridian(str(point.id)).ok, "all 22 nodes are attainable " + str(point.id))
	check(s.meridian_count == 22 and s.meridian_rows().all(func(r): return r.active and not r.can_unlock), "finite 22-node cap")
	var expected := {"combat_haste": 0.08, "poise_bonus": 10.0, "break_bonus": 0.18, "counter_bonus": 0.18, "guard_bonus": 0.08, "dodge_bonus": 0.07, "recovery_bonus": 0.08}
	for key in expected:
		check(is_equal_approx(float(s.stats()[key]), float(expected[key])), "real stats exposes bounded modifier " + key)
	check(is_equal_approx(s.qi_rate(), float(State.QI_RATES[14]) * 1.20), "all peaceful qi perks use live formula")
	check(is_equal_approx(s.gather_multiplier(), 1.17) and is_equal_approx(s.brew_multiplier(), 1.20), "quiet branch affects actual gather and brew work")
	var peaceful := State.new()
	peaceful.auto_advance = true # Optional peaceful progression remains available.
	peaceful.step(28800.0)
	peaceful.step(7200.0)
	check(peaceful.realm == 15 and peaceful.meridian_count == 0 and peaceful.total_victories == 0, "all 16 peaceful stages remain possible without any branch or duel")
	peaceful.merit = 10000.0
	peaceful.herbs = 100
	peaceful.dew = 100
	check(peaceful.unlock_meridian("qihai").ok and peaceful.unlock_meridian("laogong").ok and peaceful.merit == 9930.0 and peaceful.qi == 0.0, "postgame nodes pay merit exactly and keep qi invariant")
	check(peaceful._valid_save(peaceful._snapshot()), "postgame branched state is valid")

func _write(data: Dictionary) -> void:
	var file := FileAccess.open(save_path, FileAccess.WRITE)
	check(file != null, "isolated test file writable")
	if file:
		file.store_string(JSON.stringify(data))
		file.close()
