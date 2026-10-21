extends SceneTree
## Painted anatomy contract: production selector, true fixed-volume art,
## support-foot registration, shared body masks and grounded reactions.
const Rig=preload("res://scripts/monster_pose_renderer.gd")
const Moves=preload("res://scripts/monster_move_library.gd")
const Original=preload("res://scripts/beast_presentation.gd")
var checks:=0
var failures:Array[String]=[]

func _initialize():
	var sample_count:=0
	for family in ["moss_pounce","moss_rush","moss_slam","crane_peck","crane_sweep","crane_dive"]:
		for boss in [false,true]:
			var key:String=("bamboo_pass" if family.begins_with("moss") else "cloud_slope")+("_boss" if boss else "")+"_idle"
			for phase in ["windup","strike","contact","recovery","stagger"]:
				for i in range(11):
					var t:float=i/10.0
					var motion:Dictionary=Moves.sample({"move_family":family,"start":0.0,"windup":.8},{"name":phase,"progress":t,"index":0},t)
					motion.combat_phase=phase;motion.phase_progress=t;motion.interrupted_phase="strike"
					var source:String=Rig.source_pose(key,motion)
					_expect(source.begins_with("authored_"),"Every supported state stays in its painted family: "+key+" "+phase)
					for v in [Vector2(32,144),Vector2(64,144),Vector2(100,220),Vector2(200,224),Vector2(145,64),Vector2(128,232)]:
						var q:Vector2=Rig.transform_point(v,key,motion)
						_expect(q.is_finite(),"Finite registered point")
						_expect(q.distance_to(v)<42.0,"Only small static support registration is permitted")
						var other:Vector2=Rig.transform_point(v+Vector2(13,-9),key,motion)
						_expect(other.distance_to(q+Vector2(13,-9))<.0001,"Painted anatomy is rigid, never elastic")
						sample_count+=1
	_expect(sample_count==3960,"Full 3,960-point pose sweep")
	_test_neutral_and_size()
	_test_planted_supports()
	_test_reactions_and_stride()
	_test_peck_darts()
	_test_sweep_release()
	_test_body_masks()
	if failures.is_empty():
		print("MONSTER_POSE_RENDERER_PASS ",checks," checks;3,960 point samples;stable authored neutral;fixed feet;rigid painted anatomy;profile reactions")
		quit(0)
	else:
		for failure in failures:push_error(failure)
		print("MONSTER_POSE_RENDERER_FAIL ",failures.size()," / ",checks)
		quit(1)

func _expect(ok:bool,label:String):
	checks+=1
	if not ok:failures.append(label)

func _motion(family:String,phase:String,t:float)->Dictionary:
	return {"move_family":family,"combat_phase":phase,"phase_progress":t,"strike_index":0,"monster_pose":Moves.neutral_pose()}

func _test_neutral_and_size():
	for prefix in ["bamboo_pass","bamboo_pass_boss","cloud_slope","cloud_slope_boss"]:
		var moss:bool=prefix.begins_with("bamboo")
		var neutral:String="authored_land" if moss else "authored_coil"
		_expect(Rig.source_pose(prefix+"_idle",{})==neutral,"Approach and idle share authored neutral")
		var phase:Dictionary=_motion("moss_pounce" if moss else "crane_peck","recovery",1.0)
		_expect(Rig.source_pose(prefix+"_idle",phase)==neutral,"Recovery returns to same authored neutral")
		phase.combat_phase="stagger";phase.interrupted_phase="strike"
		_expect(Rig.source_pose(prefix+"_idle",phase)==neutral,"Stagger exit shares authored neutral")
		var display:float=174.0 if "boss" in prefix else 112.0
		var poses:Array=["crouch","pounce","charge_a","charge_b","rear","land"] if moss else ["coil","peck","wing_back","wing_sweep","lift","dive"]
		var diameter:float=-1.0
		for pose in poses:
			var key:String=prefix+"_authored_"+str(pose)
			var data:Dictionary=Rig.landmarks(key)
			_expect(not data.is_empty(),"Authored pose metadata exists:"+key)
			_expect(is_equal_approx(float(data.ground_anchor[0]),128.0) and is_equal_approx(float(data.ground_anchor[1]),232.0),"Original planted baseline remains 128,232")
			var current:float=float(data.head_diameter)*Rig.pose_scale(key)*display/256.0
			if diameter<0:diameter=current
			_expect(absf(current-diameter)<.00001,"Skull size stays constant across source keyposes")
			if prefix=="bamboo_pass_boss":_expect(is_equal_approx(float(data.get("family_import_factor",0)),.84),"Boss moss uses one fixed family import calibration")
	# Compare the resting boss's apparent width to the former production art.
	var old:Dictionary=Original.landmarks("bamboo_pass_boss_idle")
	var fresh:Dictionary=Rig.landmarks("bamboo_pass_boss_authored_land")
	var old_width:float=(float(old.alpha_bbox[2])-float(old.alpha_bbox[0]))*174.0/256.0
	var width:float=(float(fresh.alpha_bbox[2])-float(fresh.alpha_bbox[0]))*Rig.pose_scale("bamboo_pass_boss_authored_land")*174.0/256.0
	_expect(absf(width/old_width-1.0)<.10,"New boss rest volume stays within 10 percent of original apparent width")

func _atlas_point(raw:Vector2,key:String,motion:Dictionary,display:float)->Vector2:
	var prefix:String=key.trim_suffix("_idle")
	var source:String=prefix+"_"+Rig.source_pose(key,motion)
	var data:Dictionary=Rig.landmarks(source)
	var anchor:Array=data.source_ground_anchor
	var v:Vector2=Vector2(128,232)+(raw-Vector2(float(anchor[0]),float(anchor[1])))*float(data.import_scale)
	return (Rig.transform_point(v,key,motion)-Vector2(128,232))*Rig.pose_scale(source)*display/256.0

func _test_planted_supports():
	var down:Dictionary=_motion("moss_slam","windup",.2)
	var up:Dictionary=_motion("moss_slam","windup",.65)
	var normal_before:Vector2=_atlas_point(Vector2(306,337),"bamboo_pass_idle",down,112)
	var normal_after:Vector2=_atlas_point(Vector2(660,692),"bamboo_pass_idle",up,112)
	_expect(normal_before.distance_to(normal_after)<3.0,"Normal moss far hind paw remains planted across rear-up")
	var boss_before:Vector2=_atlas_point(Vector2(327,1053),"bamboo_pass_boss_idle",down,174)
	var boss_after:Vector2=_atlas_point(Vector2(660,1410),"bamboo_pass_boss_idle",up,174)
	_expect(boss_before.distance_to(boss_after)<3.0,"Boss moss farhindpaw remains planted across rear-up")
	var wing_back:Dictionary=_motion("crane_sweep","windup",.8)
	var wing_front:Dictionary=_motion("crane_sweep","strike",.7)
	var toe_before:Vector2=_atlas_point(Vector2(860,1065),"cloud_slope_boss_idle",wing_back,174)
	var toe_after:Vector2=_atlas_point(Vector2(194,1418),"cloud_slope_boss_idle",wing_front,174)
	_expect(toe_before.distance_to(toe_after)<3.0,"Boss crane support toe stays planted through horizontal fan cut")

func _test_reactions_and_stride():
	var motion:Dictionary=_motion("moss_slam","strike",.5)
	motion.merge({"reaction_amount":1.0,"reaction_strength":1.0,"impact_profile":{"kind":"heavy"}},true)
	_expect(Rig.source_pose("bamboo_pass_boss_idle",motion)=="authored_rear","Ordinary heavy cannot interrupt committed strike")
	motion.guard_broken=true;motion.reaction_strength=1.2
	_expect(Rig.source_pose("bamboo_pass_boss_idle",motion)=="authored_crouch","Poise break produces planted moss recoil")
	motion.move_family="crane_dive";motion.reaction_age=.04
	_expect(Rig.source_pose("cloud_slope_boss_idle",motion)=="authored_wing_back","Crane break begins with planted wing brace")
	motion.reaction_age=.18
	_expect(Rig.source_pose("cloud_slope_boss_idle",motion)=="authored_coil","Crane brace resolves into coiled neck")
	motion.guard_broken=false;motion.impact_profile={"kind":"light"}
	_expect(Rig.source_pose("cloud_slope_boss_idle",motion)=="authored_dive","Light tap retains diving anatomy")
	motion=_motion("moss_rush","strike",.65);motion.monster_pose.step_cycle=-.8
	_expect(Rig.source_pose("bamboo_pass_boss_idle",motion)=="authored_charge_a","Final driving paw plants before impact")
	motion.phase_progress=.2
	_expect(Rig.source_pose("bamboo_pass_boss_idle",motion)=="authored_charge_b","Early rush retains alternate paw stride")
	motion.combat_phase="defeated";motion.defeat_amount=.5
	_expect(Rig.source_pose("bamboo_pass_boss_idle",motion)=="authored_land","Defeated moss settles into grounded painted landing")

func _test_body_masks():
	var motion:Dictionary=_motion("crane_sweep","windup",.8)
	var key:="cloud_slope_boss_authored_wing_back"
	var data:Dictionary=Rig.landmarks(key)
	var anchor:Array=data.source_ground_anchor
	var head:Vector2=Vector2(128,232)+(Vector2(830,820)-Vector2(float(anchor[0]),float(anchor[1])))*float(data.import_scale)
	var wing:Vector2=Vector2(128,232)+(Vector2(980,750)-Vector2(float(anchor[0]),float(anchor[1])))*float(data.import_scale)
	_expect(Rig.is_body_point(head,key,motion),"Head belongs to solid body")
	_expect(not Rig.is_body_point(wing,key,motion),"Decorative wing fan does not push melee body clearance")

func _test_peck_darts():
	for key in ["cloud_slope_idle","cloud_slope_boss_idle"]:
		var motion:Dictionary=_motion("crane_peck","strike",.60)
		_expect(Rig.source_pose(key,motion)=="authored_coil","First peck remains coiled until committed dart")
		motion.phase_progress=.67
		_expect(Rig.source_pose(key,motion)=="authored_peck","First peck commits before contact")
		motion.strike_index=1;motion.phase_progress=.69
		_expect(Rig.source_pose(key,motion)=="authored_coil","Repeat peck has a distinct coiled reset")
		motion.phase_progress=.71
		_expect(Rig.source_pose(key,motion)=="authored_peck","Repeat peck commits before contact")
		motion.combat_phase="contact";motion.phase_progress=.5
		_expect(Rig.source_pose(key,motion)=="authored_peck","Real contact retains the striking beak")
		motion.combat_phase="recovery";motion.phase_progress=.06
		_expect(Rig.source_pose(key,motion)=="authored_coil","Extended neck releases promptly after the contact hold")

func _test_sweep_release():
	for key in ["cloud_slope_idle","cloud_slope_boss_idle"]:
		var motion:Dictionary=_motion("crane_sweep","strike",.65)
		_expect(Rig.source_pose(key,motion)=="authored_wing_back","Sweep holds back until its committed fan")
		motion.phase_progress=.70
		_expect(Rig.source_pose(key,motion)=="authored_wing_sweep","Fan commits before actual hit")
		motion.combat_phase="contact";motion.phase_progress=0.0
		_expect(Rig.source_pose(key,motion)=="authored_wing_sweep","Sweep hit begins with full horizontal fan")
		motion.phase_progress=.51
		_expect(Rig.source_pose(key,motion)=="authored_wing_back","Forward fan clears during latter half of contact")
		motion.combat_phase="recovery";motion.phase_progress=.05
		_expect(Rig.source_pose(key,motion)=="authored_wing_back","Recovery cannot re-cover the hero with the fan")
