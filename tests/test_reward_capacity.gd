extends SceneTree
## Synthetic capacity-boundary fixtures, not natural gameplay progression.
const State = preload("res://scripts/cultivation_state.gd")
const Capacity = preload("res://scripts/reward_capacity.gd")
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func frozen(value: Variant) -> Variant:
	if value is RandomNumberGenerator: return {"seed": value.seed, "state": value.state}
	if value is Object:
		var result := {}
		for property in value.get_property_list():
			if int(property.usage) & PROPERTY_USAGE_SCRIPT_VARIABLE: result[property.name] = frozen(value.get(property.name))
		return result
	if value is Dictionary:
		var result := {}
		for key in value: result[key] = frozen(value[key])
		return result
	if value is Array:
		var result: Array = []
		for element in value: result.append(frozen(element))
		return result
	return value

func _initialize() -> void:
	var s = State.new()
	s.stage_clears["bamboo_pass"] = 1
	for i in range(99): s.gear.inventory.append(s.gear._make_item(s.gear._allocate_id(), "chest_blue", "common", 1))
	check(not Capacity.chapter(s, "bamboo_pass").blocked, "99 items fit chapter")
	s.gear.inventory.append(s.gear._make_item(s.gear._allocate_id(), "chest_blue", "common", 1))
	var report: Dictionary = Capacity.chapter(s, "bamboo_pass")
	check(report.blockers.size() == 1, "100 items only equipment blocks")
	check(report.blockers[0].id == "equipment" and report.blockers[0].need == 1, "one slot needed")
	check(report.destinations == ["wardrobe"], "wardrobe destination")
	check(not report.boundary, "attainable equipment capacity not artificial resource boundary")
	check(s.claim_chapter_reward("bamboo_pass").reason == "inventory_full", "diagnosis matches production")
	check(not Capacity.diagnose(s, {"herbs": 1}).blocked, "no equipment in reward no gear blocker")
	var before = frozen(s)
	for repeat in range(5):
		Capacity.chapter(s, "bamboo_pass")
		Capacity.quest(s, "missing")
		Capacity.opportunity(s, "missing")
		Capacity.corpse(s)
		Capacity.chest(s)
		Capacity.salvage(s, int(s.inventory[0].id))
	check(frozen(s) == before, "repeated diagnosis preserves all fields and RNG")
	s.herbs = s.MAX_RESOURCE
	s.dew = s.MAX_RESOURCE
	s.qi = s.MAX_ENERGY
	s.gear.chests = s.Equipment.MAX_CHESTS
	s.materials.inventory["moss_fiber"] = s.Materials.MAX_STACK
	report = Capacity.diagnose(s, {"herbs": 3, "dew": 2, "qi": 4, "chests": 1, "materials": {"moss_fiber": 2}}, 1)
	check(report.blockers.size() == 6, "all actual blockers listed")
	check(report.boundary, "extreme resource boundary explicitly labelled")
	check(report.blockers[5].cap == 9999 and report.blockers[5].need == 2, "material real cap not chest cap")
	check(not Capacity.diagnose(s, {"herbs": 0, "dew": 0, "qi": 0, "chests": 0, "materials": {"moss_fiber": 0}}).blocked, "full unrelated resources ignored")
	check(Capacity.corpse(s, {"materials": {"moss_fiber": 1}}).blockers.size() == 1, "material-only corpse excludes gear")
	check(Capacity.corpse(s, {"chests": 1}).blockers[0].id == "chests", "chest-only corpse")
	check(Capacity.corpse(s, {"item_spec": {"template_id": "chest_blue"}}).blockers[0].id == "equipment", "item corpse needs slot")
	s.realm = s.MAX_REALM
	s.merit = s.MAX_ENERGY
	report = Capacity.diagnose(s, {"qi": 1})
	check(report.blockers[0].id == "merit" and report.destinations.is_empty(), "merit has no false spending path")
	check("暂无消耗途径" in report.description, "honest merit limitation")
	check(not Capacity.diagnose(s, {"qi": 1}, 0, false).blocked, "quest energy clips not rejects")
	for row in s.quest_rows():
		report = Capacity.quest(s, String(row.id))
		for blocker in report.blockers: check(blocker.id != "merit", "quest never false merit block")
	report = Capacity.chest(s)
	check(report.equipment_full and "5灵草" in report.conversion_warning, "chest equipment conversion disclosed")
	check(not report.resource_warning.is_empty(), "resource clipping disclosed")
	check(Capacity.salvage(s, int(s.inventory[0].id)).blockers[0].id == "herbs", "salvage secondary block diagnosed")
	s.herbs = 0
	s.dew = 0
	s.merit = 0
	check(s.salvage_item(int(s.inventory[0].id)).ok, "explicit salvage succeeds")
	check(not Capacity.chapter(s, "bamboo_pass").blocked, "整理 removes actual blocker")
	check(s.claim_chapter_reward("bamboo_pass").ok, "explicit claim after整理")
	check(s.claim_chapter_reward("bamboo_pass").reason == "already_claimed", "repeat no duplication")
	var q = State.new()
	q.lifetime_seconds = 61
	q.herbs = q.MAX_RESOURCE
	report = Capacity.quest(q, "settle")
	check(report.blocked and report.blockers[0].id == "herbs", "actual ready quest herb blocker")
	before = frozen(q)
	check(q.claim_quest("settle").reason == "resource_full", "actual quest failure")
	check(frozen(q) == before and q.quest_rows()[0].ready, "quest failure fully atomic still ready")
	q.herbs = 0
	check(not Capacity.quest(q, "settle").blocked and q.claim_quest("settle").ok, "quest retry after space")
	check(q.claim_quest("settle").reason == "claimed", "quest duplicate prevented")
	var o = State.new()
	o.pending_opportunity = {"stage_id": "bamboo_pass", "run_id": 1}
	o.herbs = o.MAX_RESOURCE
	o.dew = o.MAX_RESOURCE
	report = Capacity.opportunity(o, "gather_gift")
	check(report.blockers.size() == 2 and report.blockers[0].need == 6 and report.blockers[1].need == 2, "actual opportunity increments")
	check(not Capacity.opportunity(o, "read_inscription").blocked, "other choice not blocked by unrelated herbs/dew")
	before = frozen(o)
	check(o.choose_opportunity("gather_gift").reason == "resource_full", "actual opportunity failure")
	check(frozen(o) == before, "opportunity fully atomic including pending choice and RNG")
	var c = State.new()
	c.herbs = c.MAX_RESOURCE
	check(Capacity.chest(c).resource_warning.is_empty(), "nonfull starter no false resource warning")
	c.gear.starter_chest_unopened = false
	report = Capacity.chest(c)
	check(report.resource_warnings.size() == 1 and report.resource_warnings[0].id == "herbs", "normal chest only herbs at risk")
	check(report.resource_warnings[0].current == c.MAX_RESOURCE and report.resource_warnings[0].cap == c.MAX_RESOURCE, "warning exact current and cap")
	check(report.resource_warnings[0].max_add == 2 and report.resource_warnings[0].max_overflow == 2 and not report.resource_warnings[0].certain, "normal nonfull conditional max2")
	c.herbs = 0
	c.dew = c.MAX_RESOURCE
	report = Capacity.chest(c)
	check(report.resource_warnings.size() == 1 and report.resource_warnings[0].id == "dew" and report.resource_warnings[0].max_add == 1, "only dew warning")
	c.herbs = c.MAX_RESOURCE
	report = Capacity.chest(c)
	check(report.resource_warnings.size() == 2, "both named resource warnings")
	c.dew = 0
	c.gear.starter_chest_unopened = true
	for i in range(100): c.gear.inventory.append(c.gear._make_item(c.gear._allocate_id(), "chest_blue", "common", 1))
	before = frozen(c)
	report = Capacity.chest(c)
	check(frozen(c) == before and c.gear.chests == 1, "warning does not consume first chest")
	check(report.resource_warnings[0].certain and report.resource_warnings[0].max_add == 5, "full starter certain conversion5")
	c.gear.starter_chest_unopened = false
	check(not Capacity.chest(c).resource_warnings[0].certain and Capacity.chest(c).resource_warnings[0].max_add == 5, "full normal chest conditional conversion5")
	c.gear.starter_chest_unopened = true
	var opened: Dictionary = c.open_chest()
	check(opened.ok and opened.starter and opened.reason == "inventory_full", "existing starter conversion remains")
	check(opened.herbs == 0 and opened.dew == 1 and opened.resource_overflow.herbs == 5, "existing clipping preserved not changed")
	print("Reward capacity: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
