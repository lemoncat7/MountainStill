extends SceneTree
## Deterministic authored families, stateful choices, contact budgets and poses.
const Duel = preload("res://scripts/duel_timeline.gd")
const Moves = preload("res://scripts/monster_move_library.gd")
const Geometry = preload("res://scripts/melee_contact_geometry.gd")
const Rig = preload("res://scripts/character_sidewalk.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures += 1; push_error(label)
func make_duel(species: String, boss: bool = false, seed_value: int = 77) -> Duel:
	var d := Duel.new()
	d.start({"hp":10000,"max_hp":10000,"attack":1,"defense":1,"poise_bonus":500,"active_skills":[],"weapon_art":{},"heart_method":{},"weapon_skill":{}},
		{"hp":10000,"max_hp":10000,"attack":2,"defense":1,"visual_type":species,"route_id":"cloud_slope" if species=="cloud_crane" else "bamboo_pass","boss":boss,"dodge_chance":0.0,"guard_chance":0.0},"mist","sword",seed_value)
	return d
func _initialize() -> void:
	_test_families()
	_test_choices()
	_test_legacy_selection()
	_test_sampling()
	_test_guard_release()
	_test_painted_charge_range()
	_test_upper_head_envelope()
	_test_simulation()
	print("Monster choreography: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
func _test_families() -> void:
	for species in ["moss_beast", "cloud_crane"]:
		for boss in [false, true]:
			var families := {}; var timings := {}; var ranges := {}
			for kind in ["charge", "sweep", "burst"]:
				var action := Moves.authored(species, kind, boss, 66.0)
				families[action.move_family] = true
				timings[str([action.windup,action.strike,action.hits.size(),action.gap,action.recovery])] = true
				ranges[action.monster_range] = true
				var total := 0.0
				for hit in action.hits: total += float(hit)
				check(total <= (1.81 if boss else 1.25), "fair committed damage budget " + action.move_family)
				check(action.windup >= 0.45 and action.recovery >= 0.50, "readable tell and punishable recovery " + action.move_family)
			check(families.size()==3 and timings.size()==3 and ranges.size()==3, "three actual timing/range families " + species)
func _test_choices() -> void:
	for species in ["moss_beast", "cloud_crane"]:
		var near := Moves.choice_weights(species,{"distance":12.0,"stamina":100.0})
		var far := Moves.choice_weights(species,{"distance":110.0,"stamina":100.0})
		var tired := Moves.choice_weights(species,{"distance":110.0,"stamina":16.0})
		check(far.charge > near.charge,"distance favors the real gap closer")
		check(tired.charge < far.charge*0.1,"tired monsters suppress costly rush/dive")
		for last in ["charge","sweep","burst"]:
			var weights := Moves.choice_weights(species,{"distance":40.0,"stamina":100.0,"history":[last]})
			check(weights[last]==0.0,"immediate repeat is suppressed")
			for roll in [0.0,0.2,0.5,0.999]: check(Moves.choose(weights,roll)!=last,"selection honors suppression")
		var possibilities := {}
		for roll in [0.0,0.4,0.99]: possibilities[Moves.choose(near,roll)] = true
		check(possibilities.size()>=2,"same state has seeded alternatives instead of a rigid rotation")
func _test_guard_release() -> void:
	var d:=make_duel("moss_beast")
	d._lanes.enemy.action={}
	var event:={"type":"contact","actor":"enemy","target":"hero","resolution":"whiff","prepared_defense":"guard","contact_id":"release-test","move":"moss_beast_charge","time":0.0,"damage":0,"poise_broken":false}
	d._finalize_contact(event)
	check(event.resolution=="whiff" and not event.impact_profile.active,"guard release cannot manufacture an impact")
	for age in [0.0,0.05,0.15,0.22]:
		var motion:=d._neutral_motion()
		d._sample_defense("hero",motion,age)
		if age<.22:
			check(motion.defense_action=="guard" and motion.defense_release,"missed anticipated guard lowers smoothly")
			check(is_equal_approx(motion.reaction_amount,1.0-smoothstep(0.0,.22,age)),"guard release is pure time sampled")
		else:check(motion.reaction_amount==0.0,"guard release ends at neutral")
	check(not d._counter_ready and d.hero_hp==d.hero_max_hp,"visual release grants no counter or damage")
func _test_painted_charge_range() -> void:
	for species in ["moss_beast","cloud_crane"]:
		for boss in [false,true]:
			var d:=make_duel(species,boss)
			d._enemy.boss_move="charge"
			d._enemy_turns=0
			# Force the same legal charge preview for normal crane too.
			if species=="cloud_crane" and not boss:
				d._enemy_history=["burst","sweep"]
				d._enemy_turns=1
			d._enemy.enemy_front_extent=24.0
			var a:=d._enemy_action()
			d._enemy.enemy_front_extent=100.0
			var b:=d._enemy_action()
			check(a.kind=="charge" and b.kind=="charge","range regression samples committed gap closers")
			check(is_equal_approx(a.lunge,b.lunge),"new contact art cannot inherit stale old-art front extent")
			var sampled:=Moves.sample(a,{"name":"contact","index":0,"progress":0.0},0.0)
			var motion:={"monster_pose":sampled.monster_pose,"move_family":a.move_family,"combat_phase":"contact","phase_progress":0.0,"visual_offset":sampled.root_offset+Vector2(-float(a.lunge),0)}
			var gap:=INF
			for nose in Geometry.hero_body_fronts(d._neutral_motion()):
				var front:=Geometry.body_front(motion,d._enemy,nose.y)
				if bool(front.valid):gap=minf(gap,Vector2(front.point).x-nose.x)
			check(absf(gap-5.0)<0.01,"actual painted charge stops five pixels from the ready body")
func _test_upper_head_envelope() -> void:
	var d:=make_duel("cloud_crane")
	var motion:=d._neutral_motion()
	var pose:=Rig.sample_pose(motion)
	var points:=Geometry.hero_body_fronts(motion)
	var image:Image=load("res://assets/cultivation/sidewalk/head.png").get_image()
	# The authored solid core is a source-art contract, not a fixed world
	# height. Reconstruct its opaque front, then apply the actual approved
	# head/neck transform so skull inclusion and bun exclusion remain strict.
	var core:=PackedVector2Array([Vector2(290,190),Vector2(430,235),Vector2(494,335),Vector2(510,451),Vector2(530,509),Vector2(506,534),Vector2(500,565),Vector2(470,605),Vector2(360,630),Vector2(228,538),Vector2(188,408),Vector2(206,286)])
	var expected:=PackedVector2Array()
	var upper_face_samples:=0
	for y in range(190,631,8):
		for x in range(mini(image.get_width()-1,530),187,-1):
			if Geometry2D.is_point_in_polygon(Vector2(x,y),core) and image.get_pixel(x,y).a>=.65:
				var local:=Vector2(-150,-489)+Vector2(x,y)/Vector2(image.get_size())*Vector2(267,300)
				expected.append(Rig._body(Rig.head_point(local),pose.shift,float(pose.body_angle))*Rig.PIXEL_SCALE)
				if y<451:upper_face_samples+=1
				break
	check(expected.size()>=50 and upper_face_samples>=30,"authored opaque skull/forehead retains dense physical clearance probes")
	var expected_top:=INF
	for sample in expected:
		expected_top=minf(expected_top,sample.y)
		var closest:=INF
		for point in points:closest=minf(closest,point.distance_to(sample))
		check(closest<.001,"solid head envelope contains every transformed authored core sample")
	var top:=INF
	for point in points:
		top=minf(top,point.y)
	check(absf(top-expected_top)<.001,"envelope starts at transformed solid skull, not a stale absolute height")
	var bun_top:=INF
	for y in range(190):
		for x in range(image.get_width()):
			if image.get_pixel(x,y).a>=.65:
				var local:=Vector2(-150,-489)+Vector2(x,y)/Vector2(image.get_size())*Vector2(267,300)
				bun_top=minf(bun_top,(Rig._body(Rig.head_point(local),pose.shift,float(pose.body_angle))*Rig.PIXEL_SCALE).y)
	check(is_finite(bun_top) and bun_top<expected_top and top>bun_top+.001,"painted tall bun exists above and is excluded from the solid head envelope")
func _test_sampling() -> void:
	for species in ["moss_beast", "cloud_crane"]:
		var shapes := {}
		for kind in ["charge", "sweep", "burst"]:
			var action := Moves.authored(species,kind,false,66.0); action.start=0.0
			var end_wind := Moves.sample(action,{"name":"windup","index":0,"progress":1.0},action.windup)
			var start_strike := Moves.sample(action,{"name":"strike","index":0,"progress":0.0},action.windup)
			check(Vector2(end_wind.root_offset).distance_to(start_strike.root_offset)<0.001,"telegraph root joins strike continuously")
			for key in ["head_thrust","foreleg_lift","beak_thrust","wing_open","wing_sweep","step_cycle"]:
				check(absf(float(end_wind.monster_pose[key])-float(start_strike.monster_pose[key]))<0.001,"articulation joins continuously "+key)
			shapes[str(end_wind.monster_pose)] = true
			var middle := Moves.sample(action,{"name":"strike","index":0,"progress":0.5},action.windup+action.strike*.5)
			if action.move_family=="moss_pounce":check(middle.root_offset.y < -15.0,"pounce actually leaves the ground")
			if action.move_family=="moss_rush":check(middle.root_offset.y==0.0,"rush stays grounded")
			if action.move_family=="moss_slam":check(end_wind.monster_pose.foreleg_lift==1.0,"slam visibly raises front paws")
			if action.move_family=="crane_dive":check(end_wind.root_offset.y < -30.0,"dive climbs before descending")
			if action.move_family=="crane_sweep":check(end_wind.monster_pose.wing_open > .8,"wing sweep advertises its wide wing")
			if action.move_family=="crane_peck":
				var reset := Moves.sample(action,{"name":"strike","index":1,"progress":0.5},1.0)
				check(reset.monster_pose.neck_fold > .7 and reset.monster_pose.beak_thrust < .2,"each chained peck retracts its neck")
			var recovering := Moves.sample(action,{"name":"recovery","index":0,"progress":0.3},1.6)
			check(absf(float(recovering.monster_pose.step_cycle))>0.01 or float(recovering.root_offset.y)<-2.0,"recovery contains a visible backstep or rebound")
			var recovered := Moves.sample(action,{"name":"recovery","index":0,"progress":1.0},2.0)
			check(Vector2(recovered.root_offset).length()<0.001,"recovery returns root without scaling")
		check(shapes.size()==3,"each species has three different visible anticipations")
func _test_simulation() -> void:
	for species in ["moss_beast", "cloud_crane"]:
		for boss in [false,true]:
			var a:=make_duel(species,boss);var b:=make_duel(species,boss)
			var state:=a._enemy_rng.state;var stamina:=a._enemy_stamina_base;var history:=a._enemy_history.duplicate()
			for n in range(25): a._predicted_enemy_motion(1.0);a.pose()
			check(a._enemy_rng.state==state and a._enemy_stamina_base==stamina and a._enemy_history==history,"planning and pose never consume enemy choices")
			var events:Array[Dictionary]=[]
			for n in range(400):
				events.append_array(a.advance(0.1))
				var frame := a.pose()
				check(frame.enemy.visual_scale==Vector2.ONE,"creature body is never squash-scaled")
				if frame.enemy.has("body_clearance"):check(float(frame.enemy.body_clearance)>=2.99,"rendered source/deformation preserves body clearance")
			check(events==b.advance(40.0),"partition-independent choices/contacts "+species)
			var families:={};var last:="";var transitions:={}
			for event in events:
				if event.type=="turn_started" and event.actor=="enemy":
					check(last!=event.move_family,"no repeated move in live lane")
					if not last.is_empty():transitions[last+">"+str(event.move_family)]=true
					last=event.move_family;families[last]=true
					check(event.enemy_stamina>=0.0 and event.enemy_stamina<=100.0,"stamina remains bounded")
				if event.type=="contact" and event.actor=="enemy":
					check(event.has("enemy_contact") and (event.damage==0 or event.enemy_contact.contact),"monster damage requires its actual range")
			check(families.size()==3,"normal and boss both use all three core families "+species)
			check(transitions.size()>3,"live selection is not a three-step rotation "+species)

func _test_legacy_selection() -> void:
	var sequences := {"river_stone":["sweep","burst"], "ember_guardian":["sweep","burst","charge"], "moon_wisp":["burst","sweep","charge"], "summit_keeper":["charge","burst","sweep"]}
	for species in sequences:
		var d := Duel.new()
		d.start({"hp":10000,"max_hp":10000,"attack":1,"defense":1},{"hp":10000,"attack":1,"visual_type":species,"route_id":"creek_bridge"},"mist","sword",77)
		for count in range(9):
			d._enemy_turns=count
			check(d._enemy_action().kind==sequences[species][count%sequences[species].size()],"untouched chapter keeps exact established sequence "+species)
		for opening in ["charge","sweep","burst"]:
			d._enemy.boss=true;d._enemy.boss_move=opening
			var boss_order: Array=["charge","sweep","burst"]
			while boss_order[0]!=opening:boss_order.append(boss_order.pop_front())
			for count in range(6):
				d._enemy_turns=count
				check(d._enemy_action().kind==boss_order[count%3],"untouched boss preserves opening rotation "+species)
