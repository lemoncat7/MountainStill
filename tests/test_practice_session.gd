extends SceneTree
const Session = preload("res://scripts/practice_session.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	var hero := {"attack": 15, "defense": 2, "max_hp": 100, "hp": 1, "active_skills": [], "combat_qi_max": 40.0, "battle_resources": {"qi": 1.0, "cooldowns": {"ember": 500.0}}}
	var enemy: Dictionary = Content.STAGES.bamboo_pass.monsters[0].duplicate(true)
	var original := JSON.stringify(hero)
	var enemy_original := JSON.stringify(enemy)
	var s := Session.new()
	check(s.status().started == false and s.report().is_empty(), "idle safe")
	check(s.start(hero, enemy).ok, "valid start")
	check(s.duel.hero_hp == 100 and s.duel.battle_resource_snapshot().qi == 40, "full copy health and qi")
	check(float(s.duel.battle_resource_snapshot().cooldowns.get("ember",0)) == 0, "copy cooldown reset")
	var baseline := hero.duplicate(true); baseline.hp = 100; baseline.erase("battle_resources")
	var d := Duel.new(); d.start(baseline, enemy, "mist", "unarmed", 17)
	for i in range(900):
		var a := s.advance(.05); var b := d.advance(.05)
		check(JSON.stringify(a) == JSON.stringify(b), "real engine events match %d" % i)
		if d.finished: break
	check(s.status().finished and s.report().outcome == "victory", "victory temporary report")
	check(not s.report().rewarded and s.report().practice and s.report().seed == 17, "practice explicitly labeled")
	check(JSON.stringify(hero) == original and JSON.stringify(enemy) == enemy_original, "caller state untouched")
	var r := s.report(); r.damage_dealt = 999
	check(s.report().damage_dealt != 999, "returned report independent")
	check(s.advance(999).is_empty(), "finished cannot advance")
	s.cancel(); check(s.report().outcome == "victory", "cancel after finish idempotent")
	s.start(hero, enemy); s.advance(.5)
	var before := JSON.stringify(s.report()); var pose_before := JSON.stringify(s.pose())
	s.pause(); check(s.advance(20).is_empty(), "paused ignores time")
	check(JSON.stringify(s.report()) == before and JSON.stringify(s.pose()) == pose_before, "pause preserves report and pose")
	s.resume(); s.advance(.1); check(s.status().elapsed > .5, "resume moves")
	s.cancel(); before = JSON.stringify(s.report()); s.cancel(); s.advance(20)
	check(JSON.stringify(s.report()) == before and s.report().outcome == "cancelled", "cancel idempotent")
	for i in range(20):
		s.start(hero, enemy); s.advance(.3); s.cancel()
		check(s.status().elapsed <= .3 and s.report().elapsed <= .3, "repeat resets elapsed")
	check(JSON.stringify(hero) == original, "repeated training no mutations")
	s.start(hero, enemy); hero.attack = 99999; enemy.hp = 1
	check(s.duel.enemy_max_hp == 90, "enemy deep copy")
	s.advance(.6); check(s.report().damage_dealt < 100, "hero snapshot ignores external mutation")
	check(s.advance(NAN).is_empty() and s.advance(INF).is_empty() and s.advance(-1).is_empty(), "invalid deltas ignored")
	check(not s.start({}, enemy).ok and not s.status().started, "reject empty and clear old")
	hero = {"attack":1,"max_hp":100000,"defense":99999,"active_skills":[],"combat_qi_regen":0}
	enemy = {"attack":1,"hp":100000,"defense":99999}
	s.start(hero, enemy); s.advance(1000)
	check(s.status().finished and s.report().outcome == "timeout" and s.status().elapsed <= 120.00001, "bounded timeout")
	hero = {"attack":1,"max_hp":1,"active_skills":[]}
	enemy = {"attack":999,"hp":9999,"defense":10}
	s.start(hero, enemy); s.advance(120)
	check(s.status().finished and s.report().outcome == "defeat", "defeat safe")
	print("Practice session: %d checks, %d failures" % [checks, failures]); quit(1 if failures else 0)
