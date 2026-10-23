extends SceneTree
const Tactics = preload("res://scripts/combat_tactics.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	var candidates := [{"lane":"expensive","id":"ember","cost":30.0,"action_kind":"spell"},{"lane":"cheap","id":"frost","cost":10.0,"action_kind":"spell"}]
	check(Tactics.choose("balanced",candidates,20,40,100,100)=="basic", "balanced preserves first-eligible wait")
	check(Tactics.choose("frugal",candidates,20,40,100,100)=="cheap", "frugal can use affordable cheaper skill with reserve")
	check(Tactics.choose("frugal",[candidates[0]],40,40,100,100)=="expensive", "reserve cannot starve a cast at capacity")
	var support := [{"lane":"ward","id":"barrier","cost":16.0,"action_kind":"defense"},{"lane":"heal","id":"mending","cost":18.0,"action_kind":"utility"},candidates[1]]
	check(Tactics.choose("assault",support,40,40,90,100)=="cheap", "assault prioritizes offense above nonurgent support")
	check(Tactics.choose("assault",support,40,40,50,100)=="heal", "assault retains emergency mending")
	check(Tactics.choose("guarded",support,40,40,90,100)=="heal", "guarded mending priority")
	check(Tactics.choose("frugal",[support[1]],18,40,50,100)=="heal", "emergency healing waives reserve, not cost")
	for invalid in [null,{},[],9,"invalid"]:check(Tactics.sanitize(invalid)=="balanced", "invalid policy safe default")
	for mode in Tactics.IDS:
		for cost in [10.0,60.0]:
			var skill: Dictionary=Content.TECHNIQUES.ember.duplicate(true);skill.id="ember";skill.active=true;skill.qi_cost=cost
			var hero: Dictionary={"hp":5000,"max_hp":5000,"attack":10,"defense":2,"active_skills":[skill],"combat_qi_max":40,"combat_qi_regen":0,"battle_resources":{"qi":0},"combat_tactic":mode}
			var d:=Duel.new();d.start(hero,{"hp":5000,"attack":2,"defense":1},"mist","unarmed",11)
			hero.combat_tactic="guarded"
			var events:=d.advance(18)
			var turns:=0
			for e in events:
				if e.type=="turn_started" and e.actor=="hero":turns+=1;check(e.action_kind=="basic" and e.qi_cost==0,"zero qi always basic, no impossible skills")
			check(turns>2 and d.enemy_hp<5000,"all policies continue real combat")
			check(d.combat_report().tactic==mode,"battle policy snapshot ignores later external mutation")
	print("Combat tactics recovery: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
