extends SceneTree
## Local impact articulation is presentation-only, contact-gated and bounded.
const Impact=preload("res://scripts/combat_impact.gd")
const Rig=preload("res://scripts/monster_pose_renderer.gd")
const Geometry=preload("res://scripts/melee_contact_geometry.gd")
const Moves=preload("res://scripts/monster_move_library.gd")
var checks:=0
var failures:=0

func _initialize()->void:
	test_contact_envelopes()
	test_regions()
	test_joint_reactions()
	test_audio_weight()
	print("CONTACT_WEIGHT_REACTIONS: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)

func expect(ok:bool,label:String)->void:
	checks+=1
	if not ok:
		failures+=1
		if failures<30:push_error(label)

func event(kind:String)->Dictionary:
	return {"type":"contact","actor":"hero","target":"enemy","move":"basic_unarmed_jab" if kind=="light" else "thunder_strike",
		"resolution":"guard" if kind=="block" else "hit","poise_broken":kind=="guardbreak","damage":2 if kind=="block" else 12,
		"raw_damage":16,"contact_id":"weight-7:0","action_id":7,"hit_index":0,"enemy_visual_type":"moss_beast"}

func motion(kind:String,key:String,age:float)->Dictionary:
	var profile:Dictionary=Impact.describe(event(kind))
	return {"combat_phase":"idle","move_family":"crane_peck" if key.begins_with("cloud") else "moss_rush",
		"monster_pose":Moves.neutral_pose(),"defense_action":"guard" if kind=="block" else "hit",
		"reaction_amount":1.0,"reaction_age":age,"reaction_strength":profile.reaction_magnitude,
		"recoil_distance":profile.knockback,"impact_profile":profile,
		"visual_offset":Vector2(profile.knockback,0),"visual_rotation":0.035*float(profile.reaction_magnitude)}

func test_contact_envelopes()->void:
	for kind in ["light","heavy","block","guardbreak"]:
		var original:Dictionary=event(kind)
		var frozen:Dictionary=original.duplicate(true)
		var profile:Dictionary=Impact.describe(original)
		var duration:float=profile.reaction_duration
		expect(profile.kind==kind,"authored contact kind "+kind)
		var original_duration:float=0.18+float(profile.intensity)*0.055
		if kind=="heavy":original_duration=0.29+float(profile.intensity)*0.04
		elif kind=="block":original_duration=0.18+float(profile.intensity)*0.035
		elif kind=="guardbreak":original_duration=0.40
		expect(is_equal_approx(duration,original_duration),"authoritative reaction duration remains baseline")
		expect(original==frozen,"profile leaves authoritative contact unmodified")
		var first:Dictionary=Impact.reaction(profile,0.0)
		var transfer:Dictionary=Impact.reaction(profile,duration*.30)
		var settle:Dictionary=Impact.reaction(profile,duration*.55)
		expect(first.impulse>0.0 and first.recoil==0.0 and first.followthrough==0.0,"compression starts at real contact without advance recoil")
		expect(transfer.recoil>first.recoil and transfer.impulse<first.impulse,"load transfers after the catch")
		expect(settle.impulse==0.0 and settle.followthrough>0.0,"loose limbs settle after compression")
		for invalid_age in [-.1,duration,duration+1.0,NAN]:
			var empty:Dictionary=Impact.reaction(profile,invalid_age)
			for field in ["amount","compression","impulse","recoil","followthrough"]:
				expect(empty[field]==0.0,"inactive/expired envelope is exactly zero")
		for i in range(101):
			var sample:Dictionary=Impact.reaction(profile,duration*i/100.0)
			for field in ["amount","compression","impulse","recoil","followthrough"]:
				expect(is_finite(sample[field]) and sample[field]>=0.0,"one-shot envelope never oscillates/sign-flips")
	for resolution in ["miss","evade","whiff","dodge","support","heal"]:
		var missed:Dictionary=event("guardbreak")
		missed.resolution=resolution # Even contradictory damage/break metadata cannot invent contact.
		var profile:Dictionary=Impact.describe(missed)
		expect(not profile.active and profile.hitstop==0.0 and Impact.stream(profile)==null,"zero-contact resolution stays silent: "+resolution)
		expect(Impact.reaction(profile,.02).amount==0.0,"missed event has no reaction")

func test_regions()->void:
	for item in [[-70.0,"head"],[-58.0,"head"],[-40.0,"torso"],[-25.0,"torso"],[-12.0,"leg"]]:
		var hit:Dictionary=event("heavy");hit.actor="enemy";hit.target="hero"
		hit.enemy_contact={"contact":true,"point":Vector2(8,item[0]),"target":Vector2(19,item[0])}
		var profile:Dictionary=Impact.describe(hit)
		expect(profile.contact_region==item[1] and profile.contact_region_measured,"hero region comes from resolved hit point")
		expect(profile.contact_point==hit.enemy_contact.point and profile.contact_point_valid,"hero contact point copied without coordinate invention")
	var hit:Dictionary=event("heavy")
	hit.melee_contact={"contact":true,"point":Vector2(37,-36),"target":Vector2(40,-36)}
	hit.contact_region="leg";hit.contact_region_measured=true
	var profile:Dictionary=Impact.describe(hit)
	expect(profile.contact_region=="leg" and profile.contact_region_measured,"contact-time enemy classification is preserved")
	expect(profile.contact_point==hit.melee_contact.target and profile.contact_point_valid,"enemy receiver uses surface point, not weapon point")
	var head:Dictionary=motion("heavy","bamboo_pass",.05)
	head.impact_profile.contact_region="head"
	var leg:Dictionary=head.duplicate(true);leg.impact_profile.contact_region="leg"
	var head_reaction:Dictionary=Rig.contact_reaction("bamboo_pass",head)
	var leg_reaction:Dictionary=Rig.contact_reaction("bamboo_pass",leg)
	expect(Vector2(head_reaction.head_offset).length()>Vector2(leg_reaction.head_offset).length()*3.0,"head hit emphasizes skull, leg hit protects it")
	expect(Vector2(leg_reaction.limb_offset).length()>Vector2(head_reaction.limb_offset).length()*2.0,"low hit yields the foreground limb")
	var fallback:Dictionary=Impact.describe(event("light"))
	expect(not fallback.contact_point_valid and not fallback.contact_region_measured,"family fallback is never advertised as measured")

func test_joint_reactions()->void:
	for key in ["bamboo_pass","bamboo_pass_boss","cloud_slope","cloud_slope_boss"]:
		for kind in ["light","heavy","block","guardbreak"]:
			var m:Dictionary=motion(kind,key,.045)
			var frozen:Dictionary=m.duplicate(true)
			var source:String=Rig.source_pose(key,m)
			var data:Dictionary=Rig.landmarks(key+"_"+source)
			var body_before:Dictionary=Geometry._body_data(m,{"route_id":"cloud_slope" if key.begins_with("cloud") else "bamboo_pass","boss":"boss" in key})
			var reaction:Dictionary=Rig.contact_reaction(key,m)
			var texture:Texture2D=load("res://assets/cultivation/beasts/"+key+"_"+source+".png")
			var grid:Dictionary=Rig._reaction_grid(key+"_"+source,texture,data)
			var rendered:=PackedVector2Array()
			for p in grid.points:rendered.append(Rig.reaction_point(p,data,reaction,key.begins_with("cloud")))
			for i in range(0,grid.indices.size(),3):
				var a:Vector2=rendered[grid.indices[i]]
				var b:Vector2=rendered[grid.indices[i+1]]
				var c:Vector2=rendered[grid.indices[i+2]]
				expect((b-a).cross(c-a)>0.0,"local mesh never folds or inverts")
			var canvas:=Node2D.new()
			Rig._draw_contact_mesh(canvas,texture,key+"_"+source,data,Vector2.ZERO,1.0,reaction,Color.WHITE)
			canvas.free()
			expect(not reaction.is_empty(),"actual contact articulates "+key+" "+kind)
			var head:Array=data.head_landmark
			var corners:Array[Vector2]=[Vector2(head[0],head[1]),Vector2(head[2],head[1]),Vector2(head[2],head[3]),Vector2(head[0],head[3])]
			for a in corners:
				for b in corners:
					var qa:Vector2=Rig.reaction_point(a,data,reaction,key.begins_with("cloud"))
					var qb:Vector2=Rig.reaction_point(b,data,reaction,key.begins_with("cloud"))
					expect(absf(qa.distance_to(qb)-a.distance_to(b))<.00005,"entire measured skull stays rigid")
			for x in range(0,257,8):
				for y in [230.0,232.0,236.0,256.0]:
					var sole:=Vector2(x,y)
					expect(Rig.reaction_point(sole,data,reaction,key.begins_with("cloud"))==sole,"support row never slides or shrinks")
			var maximum:=0.0
			for x in range(0,257,16):
				for y in range(0,257,16):
					var p:=Vector2(x,y)
					var q:Vector2=Rig.reaction_point(p,data,reaction,key.begins_with("cloud"))
					expect(q.is_finite(),"finite reaction vertex")
					maximum=maxf(maximum,p.distance_to(q))
					var authority:Vector2=Rig.transform_point(p,key,m)
					expect(authority==p+Rig.registration_offset(key,m),"authority transform retains static registration only")
			expect(maximum<14.0 and maximum>0.1,"local articulation bounded to a few display pixels")
			expect(Rig.source_pose(key,m)==source and m==frozen,"render sampling cannot alter source or motion")
			var body_after:Dictionary=Geometry._body_data(m,{"route_id":"cloud_slope" if key.begins_with("cloud") else "bamboo_pass","boss":"boss" in key})
			for field in ["rect","skull","origin","rotation","key","front_rows","registration"]:
				expect(body_after[field]==body_before[field],"collision source remains byte-equivalent: "+field)
			if kind!="block":
				expect((Vector2(m.visual_offset)+Vector2(reaction.root_offset)).is_zero_approx(),"old whole-root hit slide becomes joint motion")
				expect(absf(float(m.visual_rotation)+float(reaction.root_rotation))<.000001,"old whole-root hit tilt is removed")
			var committed:Dictionary=m.duplicate(true);committed.combat_phase="strike"
			if kind!="guardbreak":
				expect(Vector2(Rig.contact_reaction(key,committed).head_offset).length()<Vector2(reaction.head_offset).length(),"committed striker preserves attack endpoint")
			for invalid in ["missing_profile","before_contact","dodge","expired","defeated","wrong_target"]:
				var absent:Dictionary=m.duplicate(true)
				match invalid:
					"missing_profile":absent.erase("impact_profile")
					"before_contact":absent.reaction_age=-.01
					"dodge":absent.defense_action="dodge"
					"expired":absent.reaction_age=absent.impact_profile.reaction_duration
					"defeated":absent.combat_phase="defeated"
					"wrong_target":absent.impact_profile.target="hero"
				expect(Rig.contact_reaction(key,absent).is_empty(),"no invented receiver impulse: "+invalid)
	var light:Dictionary=Rig.contact_reaction("bamboo_pass",motion("light","bamboo_pass",.04))
	var heavy:Dictionary=Rig.contact_reaction("bamboo_pass",motion("heavy","bamboo_pass",.04))
	var block:Dictionary=Rig.contact_reaction("bamboo_pass",motion("block","bamboo_pass",.04))
	expect(Vector2(block.head_offset).length()<Vector2(light.head_offset).length(),"guard protects skull")
	expect(Vector2(light.head_offset).length()<Vector2(heavy.head_offset).length(),"heavy displaces skull more than a tap")

func audio_energy(profile:Dictionary)->float:
	var audio:AudioStreamWAV=Impact.stream(profile)
	var gain:float=db_to_linear(float(profile.gain_db))
	var energy:=0.0
	for i in range(audio.data.size()/2):
		var value:float=float(audio.data.decode_s16(i*2))/32768.0*gain
		energy+=value*value
	return energy/Impact.SAMPLE_RATE

func test_audio_weight()->void:
	var light:Dictionary=Impact.describe(event("light"))
	var heavy:Dictionary=Impact.describe(event("heavy"))
	var guard:Dictionary=Impact.describe(event("block"))
	expect(audio_energy(heavy)>audio_energy(light)*1.6,"heavy audible energy exceeds light at actual host gains")
	expect(Impact.stream(guard).data!=Impact.stream(heavy).data,"guard has a compact ringing catch rather than the flesh body")
	seed(51923)
	var expected:float=randf()
	seed(51923)
	for kind in ["light","heavy","block","guardbreak"]:Impact.stream(Impact.describe(event(kind)))
	expect(randf()==expected,"contact synthesis never consumes shared gameplay RNG")
