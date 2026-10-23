extends "res://tests/test_battle_resource_host.gd"
var cycles:=0
var duration:=3600.0
var started:=0
var observations:Array=[]
var timing:Array=[]
var next_progress_s:=30.0
var outfile:="/workspace/scratch/778a2592935f/quality-qa/soak-integrated.json"
func rss_kib()->int:
	var output:Array=[]
	OS.execute("/bin/cat",["/proc/"+str(OS.get_process_id())+"/status"],output)
	if not output.is_empty():
		for line in str(output[0]).split("\n"):
			if line.begins_with("VmRSS:"):return int(line.trim_prefix("VmRSS:").strip_edges().split(" ",false)[0])
	return -1
func observe()->void:
	var row={"wall_s":(Time.get_ticks_msec()-started)/1000.0,"cycle":cycles,"rss_kib":rss_kib(),"static_bytes":OS.get_static_memory_usage(),"nodes":Performance.get_monitor(Performance.OBJECT_NODE_COUNT),"orphans":Performance.get_monitor(Performance.OBJECT_ORPHAN_NODE_COUNT),"objects":Performance.get_monitor(Performance.OBJECT_COUNT),"resources":Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT),"reports":scene.state.combat_reports.size(),"checks":checks,"failures":failures}
	observations.append(row);print("SOAK ",JSON.stringify(row))
	var f=FileAccess.open(outfile,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"observations":observations,"timing":timing,"completed":false},"\t"))
func snapshot()->String:
	var data:Dictionary=scene.state._snapshot()
	data.erase("saved_at")
	return JSON.stringify(data)

func practice_cycle():
	scene._reset_presentation();scene.state.new_game();scene.state.save_path=save_path
	scene.state.stage_run={};scene.world_route="";scene.encounter_active=false
	scene.paused=cycles%2==0
	var was_paused:bool=scene.paused
	var before:=snapshot()
	var formal_duel=scene.duel
	check(scene.start_practice("bamboo_guardian" if cycles%2==0 else "bamboo_sprite"),"soak practice entry")
	if scene.practice_session==null:return
	check(not scene._save_current(),"practice cannot save")
	advance(.4)
	scene.toggle_practice_pause()
	var elapsed:float=scene.practice_session.status().elapsed
	advance(.4)
	check(is_equal_approx(scene.practice_session.status().elapsed,elapsed),"practice pause freezes clock")
	scene.toggle_practice_pause()
	if cycles%3==0:
		until(func():return scene.practice_session.status().finished,130.0,"soak practice completion")
	else:advance(1.0)
	check(snapshot()==before,"formal snapshot unchanged during practice")
	scene.end_practice()
	check(scene.duel==formal_duel and scene.practice_session==null,"formal engine restored")
	check(scene.paused==was_paused,"formal pause restored")
	check(snapshot()==before,"formal snapshot unchanged after practice")
	scene.paused=false

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--duration="):duration=maxf(1.0,float(arg.trim_prefix("--duration=")))
		if arg.begins_with("--out="):outfile=arg.trim_prefix("--out=")
	save_path="user://quality_soak_%d.json"%OS.get_process_id()
	started=Time.get_ticks_msec()
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame;scene.set_process(false);scene.demo=true
	while (Time.get_ticks_msec()-started)/1000.0<duration:
		var t=Time.get_ticks_usec()
		for name in ["wardrobe","practice","alchemy","wardrobe"]:
			scene._toggle_drawer(name)
			if name=="wardrobe":
				scene.set_meta("combat_insight_open",true);scene.set_meta("combat_insight_view","attributes");scene._refresh_drawer()
			await process_frame
		scene._close_drawer()
		fixture(["unarmed","sword","fan"][cycles%3],[],0);scene.demo=false
		begin_depleted_duel(1 if cycles%2==0 else 100000)
		if cycles%2==0:until(func():return scene.encounter_phase=="pickup",30,"soak victory")
		else:advance(.5)
		scene._retreat_encounter();until(func():return not scene.encounter_active,5,"soak retreat completes")
		check(scene._save_current(),"soak save")
		var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
		check(loaded.combat_reports.size()==scene.state.combat_reports.size(),"soak report reload")
		check(resource_equal(loaded.stage_battle_resources(),scene.state.stage_battle_resources()),"battle resources reload")
		loaded=null
		practice_cycle()
		timing.append({"cycle":cycles,"work_ms":(Time.get_ticks_usec()-t)/1000.0})
		cycles+=1
		# Let production tweens and deferred deletes settle in actual wall time.
		await create_timer(1.0).timeout
		if cycles%10==0:
			scene.queue_free();await process_frame;await process_frame
			scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
			await process_frame;scene.set_process(false);scene.demo=true
			await create_timer(.7).timeout
		if (Time.get_ticks_msec()-started)/1000.0>=next_progress_s or cycles==1:
			observe()
			next_progress_s=(Time.get_ticks_msec()-started)/1000.0+30.0
	observe()
	var f=FileAccess.open(outfile,FileAccess.WRITE)
	if f:f.store_string(JSON.stringify({"observations":observations,"timing":timing,"completed":true,"duration_s":(Time.get_ticks_msec()-started)/1000.0,"cycles":cycles,"checks":checks,"failures":failures,"requested_duration_s":duration,"method":"Real monotonic wall time; Linux headless CPU; production host panels, fixtures with alternating victory/retreat, 3 weapons, real save/load, no-reward practice (ordinary/boss, finish/cancel, pause isolation), host reconstruction every 10 cycles; no native rendering/GPU/platform performance claim"},"\t"))
	scene.queue_free();await process_frame;await process_frame
	quit(1 if failures else 0)
