extends SceneTree
## Synthetic observer boundaries plus real, unmodified Duel event comparisons.
## The combat fixture is explicitly synthetic, not a lawful-growth claim.
const Session = preload("res://scripts/practice_session.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Pages = preload("res://scripts/practice_pages.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		push_error("CONTROL CONTRIBUTION: " + label)

func hero_fixture() -> Dictionary:
	var skills: Array = []
	for id in ["frost", "thunder"]:
		var skill: Dictionary = Content.TECHNIQUES[id].duplicate(true)
		skill.id = id; skill.active = true
		skills.append(skill)
	return {"attack": 35, "defense": 20, "max_hp": 500, "hp": 2,
		"active_skills": skills, "combat_qi_max": 90.0, "combat_qi_regen": 5.0,
		"battle_resources": {"qi": 1.0, "cooldowns": {"frost": 500.0}}}

func enemy_fixture() -> Dictionary:
	var enemy: Dictionary = Content.STAGES.summit_gate.monsters[2].duplicate(true)
	enemy.route_id = "summit_gate"
	return enemy

func expected(events: Array) -> Dictionary:
	# Independent offline reduction: no production observer or report helper.
	var slowed: Array = []
	var interrupted: Array = []
	for e in events:
		if not e is Dictionary: continue
		if e.get("type") == "turn_started" and e.get("actor") == "enemy" and e.get("slowed", false) == true:
			if e.has("action_id") and str(e.action_id) != "" and not str(e.action_id) in slowed:
				slowed.append(str(e.action_id))
		if e.get("type") == "poise_break" and e.get("actor") == "hero" and e.get("target") == "enemy" and e.get("interrupted", false) == true:
			if e.has("contact_id") and str(e.contact_id) != "" and not str(e.contact_id) in interrupted:
				interrupted.append(str(e.contact_id))
	return {"slowed_enemy_starts": slowed.size(), "enemy_action_interrupts": interrupted.size()}

func check_metrics(report: Dictionary, want: Dictionary, label: String) -> void:
	check(report.get("control_metrics_version") == 1, label + " version")
	for key in ["slowed_enemy_starts", "enemy_action_interrupts"]:
		check(report.get(key, -1) == want[key], label + " " + key)

func synthetic_boundaries() -> void:
	var s := Session.new()
	var events: Array = [
		{"type":"turn_started","actor":"enemy","slowed":true,"action_id":1},
		{"type":"turn_started","actor":"enemy","slowed":true,"action_id":1},
		{"type":"turn_started","actor":"hero","slowed":true,"action_id":2},
		{"type":"turn_started","actor":"enemy","slowed":false,"action_id":3},
		{"type":"turn_started","actor":"enemy","slowed":true},
		{"type":"poise_break","actor":"hero","target":"enemy","interrupted":true,"contact_id":"4:0"},
		{"type":"poise_break","actor":"hero","target":"enemy","interrupted":true,"contact_id":"4:0"},
		{"type":"poise_break","actor":"hero","target":"enemy","interrupted":false,"contact_id":"5:0"},
		{"type":"poise_break","actor":"enemy","target":"hero","interrupted":true,"contact_id":"6:0"},
		{"type":"poise_break","actor":"hero","target":"hero","interrupted":true,"contact_id":"7:0"},
		{"type":"poise_break","actor":"hero","target":"enemy","interrupted":true},
		{"type":"contact","actor":"hero","target":"enemy","poise_broken":true,"contact_id":"8:0"},
		{}, null, 42, "not an event"]
	s._observe_control_events(events)
	check(s.report().is_empty(), "idle observation cannot create report")
	check(s.start(hero_fixture(), enemy_fixture()).ok, "synthetic observer start")
	var before := JSON.stringify(events)
	var engine_before := JSON.stringify(s.duel.combat_report())
	var rng_before: int = s.duel._rng.state
	var enemy_rng_before: int = s.duel._enemy_rng.state
	s._observe_control_events(events)
	check_metrics(s.report(), {"slowed_enemy_starts":1,"enemy_action_interrupts":1}, "synthetic filters")
	s._observe_control_events(events)
	check_metrics(s.report(), expected(events), "repeated batch deduplicated")
	check(JSON.stringify(events) == before, "observer never edits input events")
	check(JSON.stringify(s.duel.combat_report()) == engine_before and s.duel._rng.state == rng_before and s.duel._enemy_rng.state == enemy_rng_before, "observer cannot alter engine report or either RNG")
	var detached := s.report(); detached.slowed_enemy_starts = 999; detached.skill_casts["fake"] = 1
	check(s.report().slowed_enemy_starts == 1 and not s.report().skill_casts.has("fake"), "live report deeply detached")
	s.cancel()
	var frozen := JSON.stringify(s.report())
	s._observe_control_events([{"type":"turn_started","actor":"enemy","slowed":true,"action_id":999}])
	s.cancel(); s.advance(120)
	check(JSON.stringify(s.report()) == frozen, "cancelled report immutable to later observe/cancel/advance")
	detached = s.report(); detached.enemy_action_interrupts = 999; detached.skill_casts["fake"] = 1
	check(JSON.stringify(s.report()) == frozen, "finished report deeply detached")
	check(s.start(hero_fixture(), enemy_fixture()).ok, "retry valid")
	check_metrics(s.report(), {"slowed_enemy_starts":0,"enemy_action_interrupts":0}, "retry resets observer")
	s._observe_control_events(events)
	check(not s.start({}, enemy_fixture()).ok and s.report().is_empty(), "invalid start removes prior report")
	s._observe_control_events(events)
	check(s.report().is_empty(), "invalid session cannot observe")
	check(s.start(hero_fixture(), enemy_fixture()).ok, "start after invalid")
	check_metrics(s.report(), {"slowed_enemy_starts":0,"enemy_action_interrupts":0}, "invalid-start retry clears counts")
	s.cancel()

func real_event_equivalence(delta: float) -> void:
	var hero := hero_fixture(); var enemy := enemy_fixture()
	var originals := JSON.stringify([hero, enemy])
	var s := Session.new(); check(s.start(hero, enemy, "mist", "unarmed", 17).ok, "real fixture starts")
	var plain := hero.duplicate(true); plain.hp = plain.max_hp; plain.erase("battle_resources")
	var d := Duel.new(); d.start(plain, enemy, "mist", "unarmed", 17)
	var all_events: Array = []
	for tick in range(2401):
		var a: Array = s.advance(delta)
		var b: Array = d.advance(delta)
		check(JSON.stringify(a) == JSON.stringify(b), "untouched complete event batch delta=%s tick=%d" % [delta,tick])
		check(s.duel._rng.state == d._rng.state and s.duel._enemy_rng.state == d._enemy_rng.state, "same combat and enemy-choice RNG trajectory")
		check(s.duel.hero_hp == d.hero_hp and s.duel.enemy_hp == d.enemy_hp, "same HP trajectory")
		check(s.duel.battle_resource_snapshot() == d.battle_resource_snapshot(), "same resource trajectory")
		all_events.append_array(a)
		check_metrics(s.report(), expected(all_events), "live/final independent reduction")
		if s.status().finished: break
	check(s.status().finished and d.finished, "both real duels terminate before timeout")
	var wanted := expected(all_events)
	check(wanted.slowed_enemy_starts > 0 and wanted.enemy_action_interrupts > 0, "real fixture exercises both nonzero contributions")
	check_metrics(s.report(), wanted, "final batch counted before finish")
	check(not d.combat_report().has("control_metrics_version"), "formal engine report not expanded")
	var unchanged := s.report().duplicate(true)
	check(s.advance(120).is_empty() and s.report() == unchanged, "finished real report stable")
	check(JSON.stringify([hero, enemy]) == originals, "input snapshots remain untouched")
	print("REAL CONTROL delta=", delta, " counts=", wanted, " outcome=", s.report().outcome)

func timeout_and_pause() -> void:
	var hero := {"attack":1,"max_hp":100000,"defense":99999,"active_skills":[],"combat_qi_regen":0}
	var enemy := {"attack":1,"hp":100000,"defense":99999}
	var s := Session.new(); check(s.start(hero, enemy).ok, "timeout fixture starts")
	s.pause(); var before := s.report()
	check(s.advance(120).is_empty() and s.report() == before, "pause produces no observed actions")
	s.resume()
	var events := s.advance(1000)
	check(s.status().outcome == "timeout", "actual 120s cap reached")
	check_metrics(s.report(), expected(events), "timeout terminal batch")
	check(s.status().elapsed <= 120.00001, "timeout bounded")
	check(events[-1].type == "practice_timeout", "timeout notice retained")
	var result := s.report(); s.cancel(); s.advance(120)
	check(s.report() == result, "timeout report immutable")
	check(not s.start({"max_hp":NAN}, enemy).ok and s.report().is_empty(), "invalid numeric start removes timeout report")

func defeat_report() -> void:
	var s := Session.new()
	check(s.start({"attack":1,"max_hp":1,"active_skills":[]}, {"attack":999,"hp":9999,"defense":10}).ok, "defeat fixture starts")
	var events := s.advance(120)
	check(s.status().outcome == "defeat", "defeat freezes contribution report")
	check_metrics(s.report(), expected(events), "defeat terminal batch")

func ui_semantics() -> void:
	var valid := {"control_metrics_version":1,"slowed_enemy_starts":0,"enemy_action_interrupts":0}
	check(Pages.control_summary(valid).contains("霜滞起手0") and Pages.control_summary(valid).contains("中断动作0"), "measured zero displayed as zero")
	for missing in [{}, {"control_metrics_version":1}, {"control_metrics_version":1,"slowed_enemy_starts":0}, {"slowed_enemy_starts":2,"enemy_action_interrupts":2}]:
		check(Pages.control_summary(missing) == "控场统计：未记录", "missing or partial is unrecorded")
	for version in [0,2,1.5,"1",null,{},[]]:
		var r := valid.duplicate(true); r.control_metrics_version = version
		check(Pages.control_summary(r) == "控场统计：未记录", "invalid/unknown version is unrecorded: " + str(version))
	for key in ["slowed_enemy_starts","enemy_action_interrupts"]:
		for value in [-1,0.5,NAN,INF,"2",true,null,{},[]]:
			var r := valid.duplicate(true); r[key] = value
			check(Pages.control_summary(r) == "控场统计：未记录", "invalid count is unrecorded: " + key + "/" + str(value))
	var float_version := valid.duplicate(true); float_version.control_metrics_version = 1.0
	check(Pages.control_summary(float_version) == Pages.control_summary(valid), "numeric exact version 1.0 accepted")
	var nonzero := valid.duplicate(true); nonzero.slowed_enemy_starts = 3; nonzero.enemy_action_interrupts = 2
	check(Pages.control_summary(nonzero).contains("霜滞起手3") and Pages.control_summary(nonzero).contains("中断动作2"), "nonzero values not mixed with breaks/casts")
	var notes: String = Pages.control_notes()
	for phrase in ["后续新起手", "含收势", "不等于破势次数", "避免命中", "节省秒数", "固定种子"]:
		check(notes.contains(phrase), "limits explained: " + phrase)

func _initialize() -> void:
	synthetic_boundaries()
	real_event_equivalence(0.1)
	real_event_equivalence(120.0)
	timeout_and_pause()
	defeat_report()
	ui_semantics()
	print("Practice control contribution: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
