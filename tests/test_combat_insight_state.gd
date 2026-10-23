extends SceneTree
const State = preload("res://scripts/cultivation_state.gd")
var checks := 0
var failures := 0
var path := "user://combat_insight_state_%d.json" % OS.get_process_id()
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void:
	var state := State.new()
	state.save_path = path
	check(state.combat_tactic == "balanced" and state.combat_reports.is_empty(), "legacy defaults")
	for id in ["balanced", "assault", "guarded", "frugal"]:
		check(state.set_combat_tactic(id) and state.stats().combat_tactic == id, "legal tactic " + id)
	check(not state.set_combat_tactic("all_powerful") and state.combat_tactic == "frugal", "invalid selection does not mutate")
	var before := state._snapshot()
	var sample := {"outcome": "victory", "enemy_name": "试炼", "stage_name": "青竹关", "elapsed": 3.2, "tactic": "assault", "hero_hp": 87, "hero_max_hp": 100, "damage_dealt": 44, "qi_spent": 12.5, "skill_casts": {"云岚": 1}}
	check(state.record_combat_report(sample), "record valid result")
	sample.damage_dealt = 999
	check(state.combat_reports[0].damage_dealt == 44, "detached report")
	var after := state._snapshot()
	for key in before:
		if key in ["combat_reports", "saved_at"]: continue
		check(before[key] == after[key], "report not reward: " + key)
	for index in range(10):
		sample.enemy_name = str(index)
		state.record_combat_report(sample)
	check(state.combat_reports.size() == 5 and state.combat_reports[0].enemy_name == "9" and state.combat_reports[4].enemy_name == "5", "latest five bounded")
	state.settings.paused = true
	check(state.save_game(), "durable save")
	var loaded := State.new()
	loaded.save_path = path
	check(loaded.load_game().loaded, "load optional fields")
	check(loaded.combat_tactic == "frugal" and loaded.combat_reports == state.combat_reports, "saved fields round trip")
	var old := state._snapshot()
	old.erase("combat_tactic"); old.erase("combat_reports")
	loaded._restore_and_award(old, loaded._offline_result(), false)
	check(loaded.combat_tactic == "balanced" and loaded.combat_reports.is_empty(), "old schema4 missing fields migration")
	check(not state.record_combat_report({"outcome": "reward"}), "invalid outcome refused")
	var malformed := sample.duplicate(true)
	malformed.merge({"enemy_name": "x".repeat(100), "stage_name": [1], "elapsed": INF, "qi_spent": NAN, "damage_taken": -4, "damage_dealt": "999", "hero_hp": 999, "hero_max_hp": 50, "tactic": [1]}, true)
	var skills := {}
	for index in range(40): skills["name" + str(index)] = INF if index % 2 else 2
	malformed.skill_casts = skills
	state.record_combat_report(malformed)
	var safe: Dictionary = state.combat_reports[0]
	check(safe.enemy_name.length() == 32 and safe.stage_name == "", "bounded typed strings")
	check(safe.elapsed == 0 and safe.qi_spent == 0 and safe.damage_taken == 0 and safe.damage_dealt == 0, "finite typed numeric fields")
	check(safe.hero_hp == 50 and safe.tactic == "balanced", "hp and tactic sanitized")
	check(safe.skill_casts.size() == 12, "skill entries bounded")
	for count in safe.skill_casts.values(): check(count in [0,2], "malformed skill count sanitized")
	check(state._sanitize_combat_reports(43).is_empty(), "nonarray history")
	check(state._sanitize_combat_reports([null,{},4,"a",false,sample]).is_empty(), "bounded scan ignores invalid head")
	for rank in range(16):
		state.realm = rank
		var rows: Array = state.combat_stat_breakdown().rows
		var stats := state.stats()
		check(rows.size() == 7, "seven major stats")
		check(rows[0].value == str(stats.attack) and rows[1].value == str(stats.defense) and rows[2].value == str(stats.max_hp), "stats same authority")
		for row in rows:
			check(row.label is String and row.value is String and row.source is String and not "%%" in row.source, "plain strings without doubled percent")
	state.new_game()
	check(state.combat_tactic == "balanced" and state.combat_reports.is_empty(), "reset fields")
	for suffix in ["", ".bak", ".tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	print("Combat insight state: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
