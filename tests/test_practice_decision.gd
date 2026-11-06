extends SceneTree
## Read-only current-state explanations, not a forecast or balance adjustment.
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Pages = preload("res://scripts/practice_pages.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func skill(id: String, cost: float = -1.0) -> Dictionary:
	var row: Dictionary = Content.TECHNIQUES[id].duplicate(true)
	row.id = id; row.active = true
	if cost >= 0: row.qi_cost = cost
	return row
func setup(ids: Array = ["ember", "frost"], mode: String = "balanced", qi: float = 40.0, style: String = "unarmed"):
	var active: Array = []
	for id in ids: active.append(skill(id))
	var d := Duel.new()
	d.start({"hp":100,"max_hp":100,"attack":25,"defense":10,"active_skills":active,"combat_qi_max":40.0,"combat_qi_regen":0.0,"combat_tactic":mode,"battle_resources":{"qi":qi}}, {"hp":5000,"attack":2,"defense":10}, "ember", style, 17)
	d._must_basic = false
	return d
func preserved(d) -> Array:
	return [d.battle_resource_snapshot(), d.combat_report(), d._rng.state, d._enemy_rng.state,
		d._pending.duplicate(true), d._lanes.duplicate(true), d._skill_uses.duplicate(true),
		d._counter_ready, d._counter_kind, d._next_skill_index, d._basic_turns, d._must_basic, d.elapsed,
		d.hero_hp, d.enemy_hp, d._hero.duplicate(true), d._cooldowns.duplicate(true)]
func reason(d, want: String, index: int = 0):
	var before := preserved(d)
	var report: Dictionary = d.skill_decision_snapshot()
	check(str(report.rows[index].reason) == want, "reason " + want + " got " + str(report.rows[index]))
	check(not Pages.decision_reason(report.rows[index], report).is_empty(), "visible reason " + want)
	check(Pages.decision_hint(report.rows[index], report).contains("下一次起手会重新核验"), "qualified explanation " + want)
	check(preserved(d) == before, "read preserves combat " + want)
	var selected := str(report.selected_lane)
	report.rows[index].name = "external mutation"
	check(d.skill_decision_snapshot().rows[index].name != "external mutation", "detached rows " + want)
	check(d._hero_action().kind == selected, "probe matches actual selection " + want)
func boundaries():
	check(Duel.new().skill_decision_snapshot().is_empty(), "unstarted unavailable")
	var d = setup(); reason(d,"selected")
	d = setup(); reason(d,"rotation",1)
	d = setup(); d._must_basic = true; reason(d,"basic_interleave")
	d = setup(["ember"],"frugal",20.0); d._skills.active_0.qi_cost = 18.0; reason(d,"reserve")
	d = setup(["ember"],"frugal",40.0); d._skills.active_0.qi_cost = 35.0
	check(d.skill_decision_snapshot().rows[0].reason == "selected", "expensive skill reserve capped to fit maximum"); reason(d,"selected")
	d = setup(["mending"],"frugal",18.0); d._skills.active_0.qi_cost = 18.0; d.hero_hp = 65
	check(d.skill_decision_snapshot().rows[0].reason == "selected", "emergency heal waives reserve"); reason(d,"selected")
	d = setup(["ember","frost"],"balanced",20.0); d._skills.active_0.qi_cost = 30.0; d._skills.active_1.qi_cost = 10.0; reason(d,"priority_wait",1)
	d = setup(["ember"],"balanced",0.0); reason(d,"qi")
	d = setup(["ember"]); d._skills.active_0.qi_cost = 40.00001; reason(d,"capacity")
	d = setup(["ember"]); d._skills.active_0.qi_cost = 40.00000005; reason(d,"selected")
	d = setup(["ember"]); d._cooldowns.ember = 0.000001; reason(d,"cooldown")
	d = setup(["ember"]); d._cooldowns.ember = 0.00000005; reason(d,"selected")
	d = setup(["mist"]); reason(d,"weapon_mismatch")
	d = setup(["ember"]); d._skills.active_0.active = false; reason(d,"unavailable")
	d = setup(["mending"]); d.hero_hp = 89; reason(d,"health_gate")
	d = setup(["mending"]); d.hero_hp = 88; reason(d,"selected")
	d = setup(["mending"]); d._hero_slow_until = .1; reason(d,"selected")
	d = setup(["mending"]); d._hero_slow_until = d.elapsed; reason(d,"health_gate")
	d = setup(["barrier"]); d._shield = 8; d._shield_until = 2.0; reason(d,"shield")
	d = setup(["barrier"]); d._shield = 8; d._shield_until = .00000005; reason(d,"selected")
	d = setup(["ember"],"frugal",26.0); d._skills.active_0.qi_cost = 30.0; d._cost_reduction = .25
	check(d.skill_decision_snapshot().rows[0].qi_cost == 22.5, "effective reduced cast cost explained"); reason(d,"reserve")
	d = setup(["ember"],"frugal",32.5); d._skills.active_0.qi_cost = 30.0; d._cost_reduction = .25; reason(d,"selected")
	d = setup(["ember"]); d.advance(.2)
	check(d.skill_decision_snapshot().current_action_active and d.skill_decision_snapshot().current_action == d._lanes.hero.action.label, "already committed action named separately")
	d = setup(); d.cancel(); check(d.skill_decision_snapshot().is_empty(), "cancelled unavailable")
	# Same actual Tactics.choose is tested against the committed action for a
	# bounded ordering/qi/health matrix; this never weakens existing policy tests.
	for mode in ["balanced","assault","guarded","frugal"]:
		for ids in [["ember","barrier"],["barrier","mending"],["mending","frost"]]:
			for qi in [0.0, 10.0, 20.0, 40.0]:
				for hp in [50, 90, 100]:
					for must_basic in [false,true]:
						d = setup(ids,mode,qi); d.hero_hp = hp; d._must_basic = must_basic
						var before := preserved(d)
						var result: Dictionary = d.skill_decision_snapshot()
						check(before == preserved(d), "matrix probe pure")
						check(result.selected_lane == d._hero_action().kind, "matrix actual chosen lane")
func trajectories():
	for mode in ["balanced","assault","guarded","frugal"]:
		var a = setup(["frost","thunder"],mode)
		var b = setup(["frost","thunder"],mode)
		for tick in range(120):
			var before := preserved(a)
			for repeat in range(3): a.skill_decision_snapshot()
			check(before == preserved(a), "repeated read pure tick %d" % tick)
			var left: Array = a.advance(.1); var right: Array = b.advance(.1)
			check(JSON.stringify(left) == JSON.stringify(right), "complete event bytes same tick %d" % tick)
			check(a._rng.state == b._rng.state and a._enemy_rng.state == b._enemy_rng.state, "both RNG same")
			check(a.battle_resource_snapshot() == b.battle_resource_snapshot(), "resources same")
			check(a.combat_report() == b.combat_report(), "reports and health same")
			if a.finished: break
		a.cancel(); b.cancel()
func _initialize():
	boundaries(); trajectories()
	print("Practice decision state: %d checks, %d failures" % [checks,failures])
	quit(1 if failures else 0)
