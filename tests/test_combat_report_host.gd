extends "res://tests/test_battle_resource_host.gd"
## Actual host integration, using the existing isolated encounter fixture.
func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	fixture("unarmed",[],0)
	scene.demo=false
	begin_depleted_duel(1)
	scene._set_paused(true)
	var frozen:Dictionary=scene.duel.combat_report()
	advance(20)
	check(scene.duel.combat_report()==frozen and scene.state.combat_reports.is_empty(),"pause creates neither time nor completion report")
	scene._set_paused(false)
	until(func():return scene.encounter_phase=="pickup",30,"actual victory enters pickup")
	check(scene.state.combat_reports.size()==1 and scene.state.combat_reports[0].outcome=="victory","one actual victory report")
	check(scene.state.combat_reports[0].damage_dealt==1,"overkill uses actual HP difference")
	var report:Dictionary=scene.state.combat_reports[0].duplicate(true)
	var before:Dictionary=scene.state._snapshot()
	scene._record_combat_report("victory");scene._record_combat_report("retreat")
	check(scene.state.combat_reports.size()==1 and scene.state.combat_reports[0]==report,"repeated completion observation does not duplicate")
	check(scene.state.qi==before.qi and scene.state.herbs==before.herbs,"report observation awards no resources")
	scene._retreat_encounter()
	check(scene.state.combat_reports.size()==1,"return during pickup is not a second report")
	check(scene._save_current(),"report durable save succeeds")
	var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
	check(loaded.combat_reports.size()==scene.state.combat_reports.size(),"reports survive actual save/load")
	for key in report:
		var actual:Variant=loaded.combat_reports[0][key]
		check(is_equal_approx(float(actual),float(report[key])) if report[key] is float else actual==report[key],"saved report field preserved: "+str(key))
	fixture("unarmed",[],0)
	scene.demo=false;scene.state.set_combat_tactic("frugal")
	begin_depleted_duel(100000)
	check(scene.duel.combat_report().tactic=="frugal","selected tactic enters combat snapshot")
	advance(1);scene._retreat_encounter()
	check(scene.state.combat_reports.size()==1 and scene.state.combat_reports[0].outcome=="retreat","manual retreat records exactly once")
	scene._retreat_encounter()
	check(scene.state.combat_reports.size()==1,"repeat retreat does not duplicate")
	until(func():return not scene.encounter_active,5,"return completes")
	scene._start_encounter();until(func():return scene.encounter_phase=="travel",5,"retry departs")
	begin_depleted_duel(100000)
	scene.duel.hero_hp=1;scene.duel._enemy.attack=100000
	until(func():return scene.encounter_phase!="fight",30,"actual defeat exits duel")
	check(scene.state.combat_reports.size()==2 and scene.state.combat_reports[0].outcome=="defeat","retry of same enemy records separate defeat")
	check(scene.state.combat_reports[0].hero_hp==0,"defeat records actual final HP")
	scene.queue_free();await process_frame;await process_frame
	for path in [save_path,save_path+".bak",save_path+".tmp"]:
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Combat report host recovery: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
