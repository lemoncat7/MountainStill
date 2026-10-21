extends SceneTree
## Production host pause and real-time hitstop at both native and faster speed.
var checks := 0
var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(ok: bool, label: String) -> void:
	checks+=1
	if not ok:
		failures+=1
		push_error(label)

func run() -> void:
	for speed in [100.0,140.0]:
		var scene = load("res://main.tscn").instantiate()
		scene.state.save_path="user://combat_speed_host_"+str(int(speed))+".json"
		root.add_child(scene)
		await process_frame
		scene.demo=true
		scene.state.new_game()
		scene.state.auto_advance=false
		scene.set_process(false)
		scene._start_encounter()
		for i in range(2000):
			if scene.encounter_phase=="fight":break
			scene._process(0.02)
		check(scene.encounter_phase=="fight","production route reaches the speed fixture encounter")
		var hero:Dictionary=scene.duel._hero.duplicate(true)
		var enemy:Dictionary=scene.duel._enemy.duplicate(true)
		hero.speed=speed
		enemy.speed=speed
		scene.duel.start(hero,enemy,scene.state.technique,scene._attack_style(),scene.encounter_run_id*1337+scene.encounter_index*79+17)
		scene.duel_pose=scene.duel.pose()
		for i in range(2000):
			if scene.combat_hitstop>0.0:break
			scene._process(0.005)
		check(scene.combat_hitstop>0.0,"real contact starts host hitstop at speed"+str(speed))
		var time:float=scene.duel.elapsed
		var hold:float=scene.combat_hitstop
		var resources:Dictionary=scene.duel.battle_resource_snapshot()
		var phase:Dictionary=scene.duel._sample_lane("hero")
		var event_id:String=str(scene.duel._last_contact.contact_id)
		scene.paused=true
		scene._process(0.5)
		check(scene.duel.elapsed==time and scene.combat_hitstop==hold and scene.duel.battle_resource_snapshot()==resources,"pause freezes hitstop, cooldown and timeline")
		check(scene.duel._sample_lane("hero")==phase,"paused speed pose remains stationary")
		scene.paused=false
		var first_slice:float=hold*0.4
		scene._process(first_slice)
		check(is_equal_approx(scene.combat_hitstop,hold-first_slice),"hitstop consumes real seconds at speed"+str(speed))
		check(scene.duel.elapsed==time and scene.duel.battle_resource_snapshot()==resources,"hitstop never accelerates cooldown or repeats costs")
		check(str(scene.duel._last_contact.contact_id)==event_id,"held contact is not replayed")
		var remainder:float=scene.combat_hitstop
		scene._process(remainder+0.01)
		check(is_equal_approx(scene.duel.elapsed-time,0.01),"resume advances only unheld real delta, never a global speed multiplier")
		scene.queue_free()
		await process_frame
		await process_frame
	print("Combat speed host: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
