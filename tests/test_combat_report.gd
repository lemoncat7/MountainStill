extends SceneTree
const Report = preload("res://scripts/combat_report.gd")
const Duel = preload("res://scripts/duel_timeline.gd")
const Content = preload("res://scripts/cultivation_content.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func _initialize() -> void:
	var r := Report.new(); r.begin("balanced")
	var start := {"type":"turn_started","actor":"hero","action_id":1,"skill_id":"ember","telegraph":"炎息","qi_cost":18.0}
	r.observe(start); r.observe(start)
	for i in range(3):
		var hit := {"type":"contact","actor":"hero","target":"enemy","contact_id":"1:%d" % i,"resolution":"hit","damage":2,"qi_cost":18.0}
		r.observe(hit); r.observe(hit)
	var snap := r.snapshot(4.0,80,100)
	check(snap.damage_dealt == 6, "actual contacts deduplicate")
	check(snap.qi_spent == 18 and snap.skill_casts == {"炎息":1}, "multi-hit cost counted once per commit")
	r.observe({"type":"turn_started","actor":"hero","action_id":2,"skill_id":"ember","telegraph":"炎息","qi_cost":18.0})
	check(r.snapshot(4,80,100).qi_spent == 36, "paid interrupted action counted without a contact")
	r.observe({"type":"contact","actor":"hero","target":"hero","contact_id":"3:0","resolution":"heal","heal":4,"shield_added":0})
	r.observe({"type":"contact","actor":"hero","target":"hero","contact_id":"4:0","resolution":"shield","heal":0,"shield_added":20})
	r.observe({"type":"contact","actor":"enemy","target":"hero","contact_id":"5:0","resolution":"guard","damage":3,"shield_absorbed":8})
	r.observe({"type":"contact","actor":"enemy","target":"hero","contact_id":"6:0","resolution":"whiff","damage":0})
	r.observe({"type":"contact","actor":"enemy","target":"hero","contact_id":"7:0","resolution":"dodge","damage":0})
	snap = r.snapshot(5,77,100)
	check(snap.healing == 4 and snap.shield_added == 20 and snap.shield_absorbed == 8, "actual healing, generated shield and absorbed damage distinct")
	check(snap.guards == 1 and snap.dodges == 1 and snap.incoming_misses == 1, "whiff not credited as dodge")
	snap.skill_casts.clear(); snap.damage_dealt = 999
	check(r.snapshot(5,77,100).skill_casts.size() == 1 and r.snapshot(5,77,100).damage_dealt == 6, "snapshot deeply detached")
	r.begin("frugal"); check(r.snapshot(0,100,100).damage_dealt == 0, "retry starts independent observer")
	for mode in ["balanced","assault","guarded","frugal"]:
		var skills: Array = []
		for id in ["ember","mending","barrier"]:
			var skill: Dictionary = Content.TECHNIQUES[id].duplicate(true); skill.id=id;skill.active=true;skills.append(skill)
		var d := Duel.new()
		d.start({"hp":80,"max_hp":100,"attack":20,"defense":2,"combat_tactic":mode,"active_skills":skills,"combat_qi_max":45,"combat_qi_regen":3}, {"hp":200,"attack":10,"defense":2}, "mist","unarmed",29)
		var events := d.advance(120)
		var expected := Report.new();expected.begin(mode)
		for e in events:expected.observe(e)
		check(d.combat_report() == expected.snapshot(d.elapsed,d.hero_hp,d.hero_max_hp), "observer exactly equals real returned commits/contacts: "+mode)
		var before := d.combat_report();d.cancel();d.advance(10)
		check(before.damage_dealt == d.combat_report().damage_dealt, "cancel cannot invent contacts")
	print("Combat report recovery: %d checks, %d failures" % [checks,failures]);quit(1 if failures else 0)
