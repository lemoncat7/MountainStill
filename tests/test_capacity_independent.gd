extends SceneTree
# Independent synthetic transaction-guard parity, not natural progression.
const State = preload("res://scripts/cultivation_state.gd")
const Capacity = preload("res://scripts/reward_capacity.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func _initialize():
	var s = State.new()
	for i in range(100): s.gear.inventory.append(s.gear._make_item(s.gear._allocate_id(), "chest_blue", "common", 1))
	var reward := {"herbs":3,"dew":2,"qi":7.5,"chests":1,"materials":{"moss_fiber":2},"item_spec":{}}
	for realm in [0, 15]:
		s.realm = realm
		for mask in range(32):
			s.herbs = s.MAX_RESOURCE if mask & 1 else 0
			s.dew = s.MAX_RESOURCE if mask & 2 else 0
			s.qi = s.MAX_ENERGY if mask & 4 else 0
			s.merit = s.qi
			s.gear.chests = s.Equipment.MAX_CHESTS if mask & 8 else 0
			s.materials.inventory["moss_fiber"] = s.Materials.MAX_STACK if mask & 16 else 0
			for item in [false, true]:
				reward.item_spec = {"template_id":"chest_blue"} if item else {}
				var report:Dictionary = Capacity.corpse(s,reward)
				check(report.blocked == not s._corpse_capacity_reason(reward).is_empty(), "corpse parity realm %d mask %d item %s" % [realm,mask,item])
				check(report.blockers.size() == int(bool(mask & 1)) + int(bool(mask & 2)) + int(bool(mask & 4)) + int(bool(mask & 8)) + int(bool(mask & 16)) + int(item), "all and only actual blockers")
				for block in report.blockers:
					check(float(block.need)>0 and float(block.add)>0, "positive needed increments")
					if block.id == "merit": check(block.destination.is_empty(), "no nonexistent merit spending route")
	# At exact room, not just at zero/full, transaction guards must agree.
	for missing in [-1,0,1,2,3]:
		s.herbs = s.MAX_RESOURCE - 3 + missing
		s.dew = 0;s.qi=0;s.merit=0;s.gear.chests=0;s.materials.inventory.clear()
		reward.item_spec={}
		var report:Dictionary=Capacity.corpse(s,reward)
		check(report.blocked == (missing>0), "exact room boundary %d" % missing)
		if missing>0: check(report.blockers[0].need==missing, "exact missing amount")
	# Formula scope: no equipment claim is needed for quest/opportunity.
	s.herbs=0;s.dew=0;s.realm=0;s.qi=0
	for stage in s.Content.ROUTE_OPPORTUNITIES:
		s.pending_opportunity={"stage_id":stage,"run_id":1}
		for choice in s.opportunity_status().choices:
			check(not Capacity.opportunity(s,str(choice.id)).blocked,"full equipment alone cannot block opportunity")
	# Equipment scan is observation only, including empty/invalid target.
	var rng:int=s.gear.rng.state
	var inventory:Array=s.gear.inventory.duplicate(true)
	for i in range(20):
		Capacity.corpse(s,reward);Capacity.chest(s);Capacity.chapter(s,"missing");Capacity.salvage(s,-99)
	check(s.gear.rng.state==rng and s.gear.inventory==inventory,"diagnosis never rolls, mutates items or allocates IDs")
	print("Independent capacity guard parity: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
