extends SceneTree
## Pixel-space continuity and measured anatomy, independent of battle outcomes.
const Motion=preload("res://scripts/route_motion.gd")
const Beast=preload("res://scripts/beast_presentation.gd")
const ROUTES=["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]
var checks:=0
var failures:=0
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	for fps in [30,60,120]:
		var distance:=0.0
		var velocity:=0.0
		var scale_value:=1200.0/1040.0
		var prior_delta:=0.0
		var seen_cruise:=false
		var braking_frames:=0
		for step in range(fps*15):
			var frame:Dictionary=Motion.advance(distance,velocity,220.0,1.0/fps,scale_value)
			var displacement:float=(float(frame.distance)-distance)*scale_value
			check(displacement>=-.000001 and displacement<=48.0/fps+.00001,"monotonic bounded world displacement")
			check(absf(float(frame.velocity)-velocity)<=108.0/fps+.6,"bounded acceleration, including final frame")
			check(absf(displacement-prior_delta)<=108.0/(fps*fps)+.02,"no final-frame camera jump")
			if velocity>47.0:seen_cruise=true
			if seen_cruise and float(frame.velocity)<velocity:braking_frames+=1
			distance=float(frame.distance);velocity=float(frame.velocity);prior_delta=displacement
			if bool(frame.arrived):break
		check(distance==220.0 and velocity==0.0,"exact fight landmark and rest")
		check(seen_cruise and braking_frames>=fps*.3,"visible acceleration and braking ramp")
		var still:Dictionary=Motion.advance(distance,velocity,220.0,30.0,scale_value)
		check(still.distance==distance and still.velocity==0.0,"stopped world cannot drift")
	# Real alpha bounds must match each source file; anatomy landmarks must lie
	# in painted pixels, and normalized head size must match the idle reference.
	for route in ROUTES:
		for suffix in ["idle","windup","attack","boss_idle","boss_windup","boss_attack"]:
			var key:String=route+"_"+suffix
			var data:Dictionary=Beast.landmarks(key)
			check(not data.is_empty(),"anatomy metadata exists "+key)
			var image:Image=(load("res://assets/cultivation/beasts/"+key+".png") as Texture2D).get_image()
			var used:=image.get_used_rect()
			var bb:Array=data.alpha_bbox
			check(used==Rect2i(int(bb[0]),int(bb[1]),int(bb[2])-int(bb[0]),int(bb[3])-int(bb[1])),"alpha audit matches actual asset "+key)
			var head:Array=data.head_landmark
			var opaque:=0;var pixels:=0
			for y in range(int(head[1]),int(head[3])):
				for x in range(int(head[0]),int(head[2])):
					pixels+=1
					if image.get_pixel(x,y).a>.1:opaque+=1
			check(float(opaque)/pixels>.55,"head landmark covers actual painted anatomy "+key)
			var size_value:=174.0 if "boss" in suffix else 112.0
			var rect:Rect2=Beast.draw_rect(key,Vector2(256,256),size_value)
			var diameter:float=float(data.head_diameter)*rect.size.x/256.0
			var expected:float=float(data.reference_head_diameter)*size_value/256.0
			check(absf(diameter-expected)<.001,"same anatomical scale across pose "+key)
			check(absf(rect.position.y+232.0*rect.size.y/256.0)<.0001,"planted baseline remains fixed "+key)
			check(rect.size.x>=size_value*.85 and rect.size.x<=size_value*1.6,"normalization does not stretch or explode "+key)
	# Live host shares exactly the same route displacement with every actor,
	# and preparing a pending choice never teleports an already visible world.
	var scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://route_continuity_%d.json"%OS.get_process_id()
	root.add_child(scene);await process_frame;scene.set_process(false)
	scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene.size=Vector2(1200,320);scene.world_route="bamboo_pass";scene.encounter_active=true;scene.encounter_phase="travel";scene.encounter_index=0
	scene.character_x=scene.ROUTE_HERO_X;scene.meditation_amount=0;scene.route_distance=70.0;scene.route_scroll_velocity=0.0
	scene.route_target_distance=220.0;scene._update_enemy_route_position()
	var before:float=scene.route_distance
	var next_before:Vector2=scene._route_landmark_feet(scene._route_enemy_world_x(1))
	scene._process(1.0/60.0)
	var after:float=scene.route_distance
	var next_after:Vector2=scene._route_landmark_feet(scene._route_enemy_world_x(1))
	check(absf((next_before.x-next_after.x)-(after-before)*1200.0/1040.0)<.001,"next monster and panorama share worlddistance")
	check(absf(float(scene.side_motion.velocity)-(after-before)*1200.0/1040.0*60.0)<.001,"gait consumes actual landscape displacement")
	scene.state.start_stage();scene.state.defeat_stage_monster(int(scene.state.stage_run.run_id),0)
	scene.route_distance=273.0
	var queued:Vector2=scene._route_landmark_feet(scene._route_enemy_world_x(1))
	scene._prepare_stage_monster()
	check(scene.route_distance==273.0 and absf(scene._enemy_feet().x-queued.x)<.0001,"activating next monster keeps its onscreen address")
	check(scene.combat_impacts.is_empty(),"preparing encounter creates no fake impact")
	# Forced dodges keep the slash/travel choreography but never create a hit
	# flash. The comparison hit must create one from the actual contact event.
	var seen_dodge:=false;var seen_hit:=false
	for fixture_seed in range(1,17):
		var dodge_chance:=.72 if fixture_seed<15 else 0.0
		scene.encounter_phase="fight";scene.encounter_active=true;scene.combat_impacts.clear();scene.route_boss=false
		scene.duel.start({"hp":9999,"max_hp":9999,"attack":8,"defense":2},{"hp":9999,"max_hp":9999,"attack":3,"defense":0,"dodge_chance":dodge_chance,"guard_chance":0.0,"route_id":"bamboo_pass"},"mist","sword",fixture_seed)
		scene.duel_pose=scene.duel.pose()
		var saw_contact:=false
		for frame in range(240):
			scene._update_encounter(1.0/120.0)
			if scene.combat_number_time>0.0:
				saw_contact=true
				var target_impacts:Array=scene.combat_impacts.filter(func(v:Dictionary)->bool:return str(v.target)=="enemy")
				var missed:bool=scene.duel_resolution=="dodge"
				seen_dodge=seen_dodge or missed;seen_hit=seen_hit or not missed
				check(target_impacts.is_empty() if missed else not target_impacts.is_empty(),"dodge has no fabricated contact / landed hit has impact")
				break
		check(saw_contact,"impact regression reaches an actual hero contact")
		scene.combat_number_time=0.0
	check(seen_dodge and seen_hit,"impact fixtures cover both actual dodges and actual landed contacts")
	var choice_cases:Dictionary={}
	for seed_value in range(64):
		scene._reset_presentation();scene.state.new_game();scene.state.auto_advance=false
		scene.state._adventure_rng.seed=seed_value
		var started:Dictionary=scene.state.start_stage()
		scene.encounter_run_id=int(started.run_id)
		scene.state.defeat_stage_monster(scene.encounter_run_id,0);scene.state.defeat_stage_monster(scene.encounter_run_id,1)
		scene.world_route="bamboo_pass";scene.encounter_active=true;scene.character_x=scene.ROUTE_HERO_X;scene.meditation_amount=0.0
		scene.route_distance=553.0;scene.route_scroll_velocity=0.0;scene._prepare_stage_monster()
		var pending:bool=scene.state.stage_status().opportunity_pending
		if choice_cases.has(pending):continue
		choice_cases[pending]=true
		check(scene.encounter_phase=="travel" and scene.route_distance==553.0,"pre-resolving choice never teleports or prematurely stops")
		check(scene.state.stage_status().opportunity_checked,"chance resolves once before approach")
		var rng_state=scene.state._adventure_rng.state
		scene._prepare_stage_monster()
		check(scene.state._adventure_rng.state==rng_state,"preparation cannot reroll the shrine")
		var crossed_without_braking:=false
		for frame in range(60*8):
			scene._process(1.0/60.0)
			if not pending and scene.route_distance>665.0 and scene.route_distance<700.0:
				check(scene.route_scroll_velocity>47.99,"empty shrine is passed at cruising speed")
				crossed_without_braking=true
			if pending and scene.encounter_phase=="opportunity":break
			if not pending and scene.route_distance>700.0:break
		if pending:
			check(scene.route_distance==680.0 and scene.route_scroll_velocity==0 and scene.encounter_phase=="opportunity","pending choice stops at actual shrine")
			scene._prepare_stage_monster()
			check(scene.encounter_phase=="opportunity" and scene.route_distance==680.0 and scene.state._adventure_rng.state==rng_state,"pending resume stays at shrine without reroll")
		else:check(crossed_without_braking,"no-choice fixture actually crosses shrine")
		if choice_cases.size()==2:break
	check(choice_cases.size()==2,"both pending and empty shrine cases covered")
	scene.queue_free();await process_frame;await process_frame
	print("Route/body continuity: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
