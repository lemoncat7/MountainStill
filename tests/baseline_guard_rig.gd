extends RefCounted
## Genuine side-profile cutout animation. Original generated art, fixed bone lengths.
## Neck-anchored side-profile proportions; independent equipment follows each part.
## Bone lengths, foot placement and weapon reach retain their authored scale.
const AttackRegistry = preload("res://scripts/attack_module_registry.gd")
const ResponseCues = preload("res://scripts/combat_response_cues.gd")
const BaseAttackModule = preload("res://scripts/combat_modules/attack_module.gd")
const PIXEL_SCALE := 132.0 / 488.0
const CONTACT := 0.60
const STRIDE := 29.0
const WALK_LIFT := 16.0
const CYCLE_DISTANCE := 2.0 * STRIDE / CONTACT * PIXEL_SCALE
const HIP := Vector2(0.0,-109.0)
const SHOULDER := Vector2(-6.0,-175.0)
const NECK := Vector2(0.0,-202.0)
const UPPER_LENGTH := 53.0
const LOWER_LENGTH := 43.0
const REST_ANKLE := Vector2(-5.0,-13.0)
# Shape only the individual art around anatomical anchors. Never widen the
# whole actor: face identity, feet, joint paths and weapon reach stay stable.
const HEAD_SCALE := 0.86
const HEAD_SETTLE := 15.0
const NECK_TAPER_START := -225.0
const NECK_TAPER_END := -189.0
const TORSO_WIDTH := 1.30
const ARM_WIDTH := 1.20
const LEG_WIDTH := 1.18
const HAND_WIDTH := 1.08
const FOOT_WIDTH := 1.08
const HEAD_RECT := Rect2(-150,-489,267,300)
const TORSO_RECT := Rect2(-28,-204,55,96)
const ASSET_ROOT := "res://assets/cultivation/sidewalk/"
var phase := 0.0
var blend := 0.0
var facing := 1.0
var idle_time := 0.0
var turn := 1.0
var assets: Dictionary = {}

func _init() -> void:
	for key in ["head","torso","arm","leg"]:
		assets[key] = _filtered_texture(ASSET_ROOT+key+".png")
	for key in ["head_pin","head_crown","chest_blue","chest_jade","sleeve_blue","sleeve_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
		if ResourceLoader.exists(ASSET_ROOT+key+".png"):assets[key] = _filtered_texture(ASSET_ROOT+key+".png")

static func _filtered_texture(path:String)->Texture2D:
	# The 132px actor reduces torso/limb source art almost tenfold. Trilinear
	# mip filtering preserves painted coverage instead of sparkling tiny edges.
	var canvas:=CanvasTexture.new()
	canvas.diffuse_texture=load(path)
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return canvas

static func filtered_weapon(texture:Texture2D)->Texture2D:
	## Call once when loading sword/fan art. Keeps the existing source file and
	## preview untouched; the returned actor texture has its own mip pyramid.
	var pixels:=texture.get_image()
	if not pixels.has_mipmaps():pixels.generate_mipmaps()
	var canvas:=CanvasTexture.new()
	canvas.diffuse_texture=ImageTexture.create_from_image(pixels)
	canvas.texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return canvas

func update_motion(delta: float, velocity: float, scale: float = 1.0) -> Dictionary:
	var dt := maxf(delta,0.0)
	var speed := absf(velocity)
	idle_time += dt
	if speed > 0.5:
		var requested := signf(velocity)
		if requested != facing: turn = 0.0
		facing = requested
		phase = fposmod(phase + speed * dt / (CYCLE_DISTANCE * maxf(scale,0.05)),1.0)
	turn = move_toward(turn,1.0,dt*9.0)
	blend = move_toward(blend,1.0 if speed>0.5 else 0.0,dt*8.0)
	if blend<0.0001:blend=0.0;phase=0.0
	return {"phase":phase,"blend":blend,"facing":facing,"turn":turn,
		"velocity":velocity,"moving":speed>0.5,"bob":0.0,"body_tilt":0.0}

static func _foot(cycle: float) -> Dictionary:
	if cycle<=CONTACT:
		return {"x":lerpf(STRIDE,-STRIDE,cycle/CONTACT),"lift":0.0,"planted":true}
	var t: float = (cycle-CONTACT)/(1.0-CONTACT)
	return {"x":lerpf(-STRIDE,STRIDE,t*t*(3.0-2.0*t)),"lift":sin(t*PI)*WALK_LIFT,"planted":false}

static func sample_pose(motion: Dictionary, cast_tilt: float=0.0) -> Dictionary:
	var amount := clampf(float(motion.get("blend",0.0)),0.0,1.0)
	var cycle := fposmod(float(motion.get("phase",0.0)),1.0)
	var near_foot := _foot(cycle)
	var far_foot := _foot(fposmod(cycle+0.5,1.0))
	# Attack weight transfer advances the pelvis and lead foot while the rear
	# contact stays rooted. The caller must not translate the whole actor too.
	var combat := _combat(motion)
	var lunge:=clampf(float(motion.get("actor_lunge",0.0))/PIXEL_SCALE,0.0,88.0)
	var phase_name:=str(motion.get("combat_phase",""))
	var phase_progress:=clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)
	var step_lift:=sin(phase_progress*PI)*12.0 if phase_name in ["strike","recovery"] else 0.0
	step_lift*=minf(lunge/20.0,1.0)
	var stance:=clampf(float(motion.get("combat_stance",0.0)),0.0,1.0)
	# The forward foot travels while the rear sole carries the center of mass.
	# Both legs articulate into the fighting stance; this is not a translated
	# upright paper doll. Foot plants coincide with the actual contact phase.
	var approach:Dictionary=approach_footwork(motion)
	var approach_progress:=float(motion.get("approach_progress",0.0))
	if absf(float(motion.get("approach_distance",0.0)))>0.1 and approach_progress<1.0:
		step_lift*=1.0-smoothstep(0.0,0.08,approach_progress)
	var search:=clampf(float(motion.get("search_amount",0.0)),0.0,1.0)
	var search_phase:=clampf(float(motion.get("search_phase",0.0)),0.0,1.0)
	var lead_step:=Vector2(lunge*0.88+float(combat.get("lead_stance",12.0))*stance,-step_lift)+Vector2(approach.lead)/PIXEL_SCALE
	var rear_step:=Vector2(-float(combat.get("rear_stance",12.0))*stance,0.0)+Vector2(approach.rear)/PIXEL_SCALE
	# A true evasion plants the lead sole and steps the rear foot out of line.
	# The same deterministic preparation/release amount owns hips and feet;
	# no cosmetic jump or second dodge roll lives in the renderer.
	if str(combat.defense)=="dodge":
		var evade:=float(combat.reaction)
		var evade_lift:=-sin(evade*PI)*9.0 if lead_step.y>=-.001 else 0.0
		rear_step+=Vector2(-32.0*evade,evade_lift)
	lead_step.x+=18.0*search;rear_step.x-=22.0*search
	var shift_x:=float(combat.shift_x)+lunge*0.48+float(approach.root)/PIXEL_SCALE
	var drop := 0.0
	for index in range(2):
		var foot:Dictionary=near_foot if index==0 else far_foot
		var step:Vector2=lead_step if index==0 else rear_step
		var dx:float=-5.0+float(foot.x)*amount+step.x-shift_x
		var reach:=UPPER_LENGTH+LOWER_LENGTH-0.1
		drop=maxf(drop,96.0-float(foot.lift)*amount+step.y-sqrt(maxf(0.0,reach*reach-dx*dx)))
	var shift:=Vector2(shift_x+15.0*search,drop+float(combat.shift_y)+52.0*search)
	var pick := maxf(clampf(float(motion.get("pickup_amount",0.0)),0.0,1.0),search*(.92+.08*sin(search_phase*TAU*2.0)))
	var angle := amount*0.035+cast_tilt+pick*0.26+float(combat.tilt)+search*.08
	var pose := {"phase":cycle,"blend":amount,"facing":float(motion.get("facing",1.0)),
		"shift":shift,"body_angle":angle,"turn":float(motion.get("turn",1.0)),"combat":combat}
	pose.near_leg = _leg(near_foot,amount,shift,0.0,lead_step)
	pose.far_leg = _leg(far_foot,amount,shift,-7.0,rear_step)
	pose.far_leg.foot_angle = -0.075*float(combat.reach)*stance
	pose.near_arm = _arm(cycle,amount,shift,angle,1.0,pick,combat)
	pose.far_arm = _arm(cycle,amount,shift,angle,-1.0,pick,combat)
	return pose

static func approach_footwork(motion:Dictionary)->Dictionary:
	if motion.has("frozen_approach"):
		var frozen:Dictionary=motion.frozen_approach
		var fade:=1.0-clampf(float(motion.get("approach_release",0.0)),0.0,1.0)
		var resting:=Vector2.ZERO if bool(motion.get("approach_disengage",false)) else Vector2(float(frozen.root),0)
		return {"root":lerpf(resting.x,float(frozen.root),fade),"lead":resting.lerp(Vector2(frozen.lead),fade),"rear":resting.lerp(Vector2(frozen.rear),fade)}
	var origin:=float(motion.get("approach_origin",0.0))
	var distance:=float(motion.get("approach_distance",0.0))
	var progress:=clampf(float(motion.get("approach_progress",0.0)),0.0,1.0)
	var returning:=bool(motion.get("approach_recovering",false))
	var count:=maxi(1,ceili(absf(distance)/14.0))
	var step:=distance/count
	var cursor:=progress*count
	var complete:=mini(count-1,int(floor(cursor)))
	var p:=1.0 if progress>=1.0 else fposmod(cursor,1.0)
	var first:=smoothstep(0.0,0.50,p)
	var second:=smoothstep(0.50,1.0,p)
	var lead:=step*(complete+first)
	var rear:=step*(complete+second)
	var lead_lift:=-sin(first*PI)*3.5 if first>0.0 and first<1.0 else 0.0
	var rear_lift:=-sin(second*PI)*3.5 if second>0.0 and second<1.0 else 0.0
	if returning:
		var previous:=lead
		lead=distance-rear;rear=distance-previous
		var lift:=lead_lift;lead_lift=rear_lift;rear_lift=lift
	return {"root":origin+(lead+rear)*0.5,"lead":Vector2(origin+lead,lead_lift),"rear":Vector2(origin+rear,rear_lift)}

static func _leg(foot:Dictionary, amount:float,shift:Vector2,offset:float,step:Vector2=Vector2.ZERO)->Dictionary:
	var hip := HIP+shift+Vector2(offset,0)
	var ankle := REST_ANKLE+Vector2(float(foot.x)*amount+offset,-float(foot.lift)*amount)+step
	var delta := ankle-hip
	var distance := clampf(delta.length(),UPPER_LENGTH-LOWER_LENGTH+0.001,UPPER_LENGTH+LOWER_LENGTH-0.001)
	var axis := delta.normalized()
	ankle=hip+axis*distance
	var along := (UPPER_LENGTH*UPPER_LENGTH-LOWER_LENGTH*LOWER_LENGTH+distance*distance)/(2.0*distance)
	var bend := sqrt(maxf(0.0,UPPER_LENGTH*UPPER_LENGTH-along*along))
	var knee := hip+axis*along+Vector2(axis.y,-axis.x)*bend
	return {"hip":hip,"knee":knee,"ankle":ankle,"upper_angle":(knee-hip).angle()-PI/2.0,
		"lower_angle":(ankle-knee).angle()-PI/2.0,"foot_angle":0.0 if foot.planted else -0.20*sin((float(foot.lift)/WALK_LIFT)*PI/2.0),
		"lift":float(foot.lift)*amount-step.y,"planted":bool(foot.planted) and step.y>=-0.001}

static func _combat(motion:Dictionary)->Dictionary:
	var t:=clampf(float(motion.get("attack_phase",0.0)),0.0,1.0)
	var strength:=clampf(float(motion.get("attack_amount",1.0)),0.0,1.0)
	var gather:=smoothstep(0.0,0.22,t)*(1.0-smoothstep(0.22,0.43,t))*strength
	var extend:=smoothstep(0.22,0.45,t)*(1.0-smoothstep(0.57,1.0,t))*strength
	# When a duel timeline supplies exact phases, visual contact and HP damage
	# share that clock. A whole-move fallback supports legacy practice callers.
	if motion.has("combat_phase"):
		var cp:=str(motion.get("combat_phase","idle"))
		var progress:=clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)
		var hit_index:=int(motion.get("strike_index",0))
		if cp=="stagger":
			strength*=1.0-smoothstep(0.0,1.0,progress)
			cp=str(motion.get("interrupted_phase","recovery"))
			progress=clampf(float(motion.get("interrupted_progress",0.0)),0.0,1.0)
		match cp:
			"windup":
				gather=smoothstep(0.0,1.0,progress)*strength;extend=0.0
			"strike":
				if hit_index>0:
					gather=sin(progress*PI)*0.24*strength
					extend=(1.0-sin(progress*PI)*0.46)*strength
				else:
					gather=(1.0-smoothstep(0.0,0.72,progress))*strength
					extend=smoothstep(0.0,1.0,progress)*strength
			"contact":
				gather=0.0;extend=strength
			"recovery":
				gather=0.0;extend=lerpf(1.0,clampf(float(motion.get("carry_exit",0.0)),0.0,0.25),smoothstep(0.0,1.0,progress))*strength
			_:
				gather=0.0;extend=0.0
	var move:=str(motion.get("combat_move",""))
	var action_kind:=str(motion.get("action_kind",""))
	var is_basic:=action_kind=="basic" or move.begins_with("basic_")
	var style:=str(motion.get("basic_style",motion.get("attack_style","sword"))) if is_basic else str(motion.get("attack_style","sword"))
	var stance:=clampf(float(motion.get("combat_stance",0.0)),0.0,1.0)
	var track: Dictionary
	var provider: Variant = motion.get("pose_provider")
	if provider != null:
		track = provider.pose_track(motion, gather, extend, stance)
	else:
		# Legacy practice sheets have no live binding. Resolve their registered
		# module once in the registry cache; production never takes this path.
		var registry := AttackRegistry.default_registry()
		if move.is_empty() and not is_basic:
			track = BaseAttackModule.standard_track(gather, extend, stance)
			if style == "fan": track.merge({"upper":0.18*gather-0.70*extend,"lower":0.35*gather-1.16*extend,"hand":-0.45*extend},true)
			elif style == "unarmed": track.merge({"upper":0.18*gather-1.03*extend,"lower":0.40*gather-1.34*extend,"hand":0.40*gather-1.34*extend},true)
		else:
			track = registry.sample_pose_track(registry.module_id_for_motion(motion), motion, gather, extend, stance)
	var upper:=float(track.upper)
	var lower:=float(track.lower)
	var hand:=float(track.hand)
	var tilt:=float(track.tilt)
	var shift_x:=float(track.shift_x)
	var shift_y:=float(track.shift_y)
	var far_upper:=float(track.far_upper)
	var far_lower:=float(track.far_lower)
	var far_hand:=float(track.far_hand)
	var attack_hand:=str(track.attack_hand)
	var hand_form:=str(track.hand_form)
	var fan_open:=float(track.fan_open)
	var lead_stance:=float(track.lead_stance)
	var rear_stance:=float(track.rear_stance)
	var form:=str(track.form)
	# Contact has a little body follow-through instead of freezing all joints
	# for the impact hold. Its endpoints meet strike and recovery exactly.
	if str(motion.get("combat_phase",""))=="contact":
		var settle:=sin(clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)*PI)*strength
		tilt+=0.018*settle;shift_y+=1.5*settle
		upper-=0.025*settle;far_lower+=0.04*settle
	# The guard stance stays alive between actions. Hands breathe subtly, but
	# never switch to the hanging-arm walk pose between linked exchanges.
	var ready:=stance*(1.0-maxf(gather,extend))
	var breath:=sin(float(motion.get("clock",0.0))*3.1)*0.025*ready
	var ready_upper:=-0.50 if style=="sword" else -0.46 if style=="fan" else -0.38
	var ready_lower:=-1.20 if style=="sword" else -1.28 if style=="fan" else -1.08
	upper+=(ready_upper+breath)*ready;lower+=(ready_lower-breath)*ready
	hand+=0.65*ready if style=="sword" else -0.12*ready
	# Unarmed rear-hand jabs keep the lead palm in guard. The source art's
	# knuckles rotate with the forearm while palm/finger casts use a real hand
	# silhouette; the attachment API follows whichever hand is striking.
	if attack_hand=="far":far_hand=far_lower
	elif hand_form=="fist":far_hand=far_lower
	# Whole-chain height aim preserves both bone lengths and grip alignment.
	# A bounded knee bend lowers cuts for small bodies; raised punches tuck
	# the chin rather than extending an arm through the face.
	var aim:=clampf(float(motion.get("strike_aim",0.0)),-1.2,1.2)*extend
	if action_kind in ["basic","weapon_art","weapon"]:
		if attack_hand=="near":upper+=aim;lower+=aim;hand+=aim
		else:far_upper+=aim;far_lower+=aim;far_hand+=aim
		tilt+=minf(aim,0.0)*0.10
		shift_y+=clampf(float(motion.get("aim_crouch",0.0)),0.0,10.0)/PIXEL_SCALE*extend
	# A generic earned-counter load works with every bound pose provider. The
	# elbow chambers while the free hand controls the line, then releases early
	# in strike. Contact endpoints and active strike-hand identity stay intact.
	var counter_load:=ResponseCues.counter_load(motion)
	if counter_load>0.0:
		if attack_hand=="near":
			upper+=.38*counter_load;lower+=.26*counter_load
			far_upper-=.16*counter_load;far_lower-=.16*counter_load
		else:
			far_upper+=.38*counter_load;far_lower+=.26*counter_load
			upper-=.16*counter_load;lower-=.16*counter_load
	var defense:=str(motion.get("defense_action","ready"))
	var reaction:=clampf(float(motion.get("reaction_amount",0.0)),0.0,1.0)
	var impact_profile:Dictionary=motion.get("impact_profile",{})
	var impact_kind:=str(impact_profile.get("kind",""))
	var impact_weight:=clampf(float(impact_profile.get("reaction_magnitude",1.0)),0.3,2.3)
	if impact_kind=="guardbreak":defense="hit"
	var committed:=str(motion.get("combat_phase","")) in ["strike","contact"]
	var free_hand_reaction:=reaction*(0.16 if committed and attack_hand=="near" else 1.0)
	var far_reaction:=reaction*(0.16 if committed and attack_hand=="far" else 1.0)
	if defense=="guard":
		# A simultaneous counter uses the free arm to deflect. Its attacking
		# hand must still reach the point that actually caused its own damage.
		if style=="sword":
			# Cross the real blade ahead of the chest. The rear hand braces by
			# the hilt, elbows bend, and the shoulder/knees absorb the impact.
			# The wrist follows the hilt axis instead of holding a painted dome.
			upper=lerpf(upper,-0.94,free_hand_reaction);lower=lerpf(lower,-1.78,free_hand_reaction);hand=lerpf(hand,0.98,free_hand_reaction)
			far_upper=lerpf(far_upper,-0.88,far_reaction);far_lower=lerpf(far_lower,-1.90,far_reaction)
		else:
			upper=lerpf(upper,-0.74,free_hand_reaction);lower=lerpf(lower,-2.10,free_hand_reaction);hand=lerpf(hand,-0.25,free_hand_reaction)
			far_upper=lerpf(far_upper,-0.72,far_reaction);far_lower=lerpf(far_lower,-2.05,far_reaction)
		var redirect:=ResponseCues.guard_release(motion)
		# After catching the real strike, turn the arm/weapon outward to clear
		# the line. Do not displace a simultaneously committed striking hand.
		upper-=.19*redirect*(0.0 if committed and attack_hand=="near" else 1.0)
		lower+=.36*redirect*(0.0 if committed and attack_hand=="near" else 1.0)
		far_upper-=.16*redirect*(0.0 if committed and attack_hand=="far" else 1.0)
		far_lower+=.28*redirect*(0.0 if committed and attack_hand=="far" else 1.0)
		tilt-=0.045*reaction;shift_y+=3.0*reaction
		shift_x-=clampf(float(impact_profile.get("knockback",0.0))/PIXEL_SCALE,0.0,10.0)*reaction
		shift_y+=2.0*reaction*impact_weight
	elif defense=="dodge":
		upper=lerpf(upper,0.60,free_hand_reaction);lower=lerpf(lower,-0.70,free_hand_reaction)
		if style=="sword":hand=lerpf(hand,1.05,free_hand_reaction)
		# Slip the chest back over a real rear-foot step. The lead sole stays
		# planted and the head tilt remains restrained; this is not a teleport.
		tilt-=0.12*reaction;shift_x-=36.0*reaction;shift_y+=10.0*reaction
	elif defense=="hit":
		if style=="sword":hand=lerpf(hand,0.85,free_hand_reaction)
		var recoil:=reaction*(0.45 if committed else 1.0)
		# Contact weight drives the hip/knee absorption and shoulder release.
		# The planted soles do not slide or translate with the entire actor.
		var travel:=clampf(float(impact_profile.get("knockback",3.0))/PIXEL_SCALE,8.0,36.0)
		tilt-=clampf(.10+.035*impact_weight,.10,.19)*recoil
		shift_x-=travel*recoil;shift_y+=(3.0+3.5*impact_weight)*recoil
		if impact_kind in ["heavy","guardbreak"]:
			upper=lerpf(upper,.38,free_hand_reaction*.5);lower=lerpf(lower,-.35,free_hand_reaction*.5)
			far_upper=lerpf(far_upper,-.20,far_reaction*.7);far_lower=lerpf(far_lower,-.62,far_reaction*.7)
			lead_stance+=8.0*recoil;rear_stance+=4.0*recoil
	far_hand=far_lower
	var result := {"upper":upper,"lower":lower,"hand":hand,"tilt":tilt,"shift_x":shift_x,"shift_y":shift_y,
		"far_upper":far_upper,"far_lower":far_lower,"far_hand":far_hand,"stance":stance,"amount":maxf(maxf(gather,extend),reaction),"defense":defense,"reaction":reaction,"reach":extend,"gather":gather,
		"attack_hand":attack_hand,"hand_form":hand_form,"fan_open":fan_open,"lead_stance":lead_stance,"rear_stance":rear_stance,"basic_form":form,
		"style":style,"casting":action_kind in ["spell","defense","utility"]}
	# Carry the actual outgoing guard/recovery into the next anticipation. This
	# interpolation ends before strike; contact geometry remains fully authored.
	var entry: Dictionary = motion.get("entry_pose",{})
	var join := clampf(float(motion.get("entry_blend",1.0)),0.0,1.0)
	if not entry.is_empty() and join<1.0:
		for key in ["upper","lower","hand","tilt","shift_x","shift_y","far_upper","far_lower","far_hand","stance","amount","reaction","reach","gather","fan_open","lead_stance","rear_stance"]:
			result[key]=lerpf(float(entry.get(key,result[key])),float(result[key]),join)
		if float(entry.get("reaction",0.0))>float(reaction) and join<0.75: result.defense=str(entry.get("defense",defense))
	return result

static func _basic_form(style:String,move:String,g:float,e:float,stance:float,motion:Dictionary)->Dictionary:
	# Compatibility entry point for existing practice/test callers.
	var sample:=motion.duplicate()
	sample.combat_move=move;sample.basic_style=style;sample.action_kind="basic"
	return AttackRegistry.default_registry().sample_pose_track("weapon."+style,sample,g,e,stance)

static func _arm(cycle:float,amount:float,shift:Vector2,body_angle:float,side:float,pick:float,combat:Dictionary)->Dictionary:
	var active_side:bool=(side>0.0)==(str(combat.get("attack_hand","near"))=="near")
	# A chibi head projects beyond a relaxed shoulder. Empty-hand contact
	# needs real scapular protraction and a rearward chin, not longer bones.
	var protract:=20.0*float(combat.reach) if str(combat.get("style",""))=="unarmed" and active_side else 0.0
	var shoulder := _body(SHOULDER+Vector2((-6.0 if side<0.0 else 0.0)+protract,0),shift,body_angle)
	var swing := cos(cycle*TAU)*amount*0.44*side*(1.0-float(combat.amount))
	var upper := swing+body_angle-pick*0.30
	var lower := swing*0.72-0.08+body_angle-pick*0.58
	if side>0.0:
		upper+=float(combat.upper);lower+=float(combat.lower)
	else:
		upper+=float(combat.get("far_upper",0.0));lower+=float(combat.get("far_lower",0.0))
	var elbow := shoulder+Vector2(0,42).rotated(upper)
	var wrist := elbow+Vector2(10,36).rotated(lower)
	var active:bool=(side>0.0)==(str(combat.get("attack_hand","near"))=="near")
	var authored_grip:=float(combat.hand) if side>0.0 else lower
	var grip_angle:=lerpf(lower,authored_grip,float(combat.amount))
	var style:=str(combat.get("style","sword"))
	var hand_target:=grip_angle
	if active and style in ["sword","fan"] and not bool(combat.get("casting",false)):
		# The source hand points DOWN; sword/fan source blades point UP. They
		# have different local axes. Using blade angle directly for the fist
		# inverted the wrist almost 180 degrees during every thrust.
		hand_target=grip_angle-PI+(0.22 if style=="sword" else 0.0)
	var wrist_limit:=0.42 if style=="sword" else 0.56
	var wrist_turn:=clampf(angle_difference(lower,hand_target),-wrist_limit,wrist_limit)
	var hand_angle:=lower+wrist_turn*float(combat.amount)
	return {"shoulder":shoulder,"elbow":elbow,"wrist":wrist,"upper_angle":upper,"lower_angle":lower,
		"hand_angle":hand_angle,"grip_angle":grip_angle,
		"hand_form":str(combat.get("hand_form","fist")) if active and float(combat.reach)>0.12 else "fist"}

static func _body(p:Vector2,shift:Vector2,angle:float)->Vector2:
	return HIP+(p-HIP).rotated(angle)+shift

static func attachment_offset(_source_point:Vector2,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0)->Vector2:
	var p := sample_pose(motion,cast_tilt)
	var arm:Dictionary=p.far_arm if str(p.combat.get("attack_hand","near"))=="far" else p.near_arm
	return Vector2(arm.wrist)*Vector2(float(p.facing)*lerpf(0.40,1.0,float(p.turn)),1.0)*PIXEL_SCALE*scale

static func attachment_rotation(motion:Dictionary,cast_tilt:float=0.0)->float:
	var pose:=sample_pose(motion,cast_tilt)
	return float(pose.far_arm.grip_angle if str(pose.combat.get("attack_hand","near"))=="far" else pose.near_arm.grip_angle)

static func weapon_pose(motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0,weapon_key:String="sword",sampled_pose:Dictionary={})->Dictionary:
	var technique:=str(motion.get("technique",""))
	var move:=str(motion.get("combat_move",""))
	var kind:=str(motion.get("action_kind",""))
	# Passive hearts cannot sheath a weapon during free basics. Keep the old
	# practice API's empty-kind palm behavior, but live actions are explicit.
	var search_amount:=clampf(float(motion.get("search_amount",0.0)),0.0,1.0)
	var stowed:=search_amount>.01 or kind in ["spell","defense","utility"] or (kind.is_empty() and (technique in ["ember","stillness"] or move.begins_with("ember_") or move.begins_with("stillness_")))
	var pose:=sample_pose(motion,cast_tilt) if sampled_pose.is_empty() else sampled_pose
	var direction:=float(pose.facing)
	if stowed:
		var anchor:=Vector2(-27,-134) if "sword" in weapon_key else Vector2(-28,-120)
		var point:=_body(anchor,pose.shift,float(pose.body_angle))
		var rotation:=(-0.48 if "sword" in weapon_key else 0.28)+float(pose.body_angle)
		var stow_amount:=1.0
		if search_amount>.01 or kind in ["spell","defense","utility"]:
			var cp:=str(motion.get("combat_phase",""))
			var progress:=clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)
			if cp=="windup":stow_amount=smoothstep(0.0,0.42,progress)
			elif cp=="recovery":stow_amount=1.0-smoothstep(0.55,1.0,progress)
			if search_amount>.01:stow_amount=search_amount
			var ready:=motion.duplicate()
			ready.action_kind="basic";ready.combat_move="";ready.combat_phase="idle";ready.attack_amount=0.0
			var ready_pose:=sample_pose(ready,cast_tilt)
			point=Vector2(ready_pose.near_arm.wrist).lerp(point,stow_amount)
			var carry:=lerpf(0.86,1.24,float(ready_pose.combat.stance)) if "sword" in weapon_key else float(ready_pose.near_arm.grip_angle)
			rotation=lerp_angle(carry,rotation,stow_amount)
		return {"offset":point*Vector2(direction*lerpf(0.40,1.0,float(pose.turn)),1.0)*PIXEL_SCALE*scale,
			"rotation":rotation,"stowed":true,"draw_behind":true,"facing":direction,
			"fan_open":lerpf(1.0,0.12,stow_amount),"grip":"stowed","stow_amount":stow_amount}
	var active_arm:Dictionary=pose.far_arm if str(pose.combat.get("attack_hand","near"))=="far" else pose.near_arm
	var blade_angle:=float(active_arm.grip_angle)
	if "sword" in weapon_key:
		# Carry / ready is an authored forward guard, not the relaxed forearm
		# angle plus an arbitrary correction. The old sum stood the blade
		# straight through the face during every recovery-to-ready transition.
		var ready_blade:=lerpf(0.64,1.02,float(pose.combat.stance))
		blade_angle=lerp_angle(ready_blade,blade_angle,float(pose.combat.amount))
	return {"offset":Vector2(active_arm.wrist)*Vector2(direction*lerpf(0.40,1.0,float(pose.turn)),1.0)*PIXEL_SCALE*scale,
		"rotation":blade_angle,"stowed":false,"draw_behind":false,"facing":direction,
		"fan_open":float(pose.combat.get("fan_open",1.0)),"grip":"closed" if float(pose.combat.get("fan_open",1.0))<0.35 else "open"}

static func sword_edge_trace(motion:Dictionary,max_length:float=14.0)->PackedVector2Array:
	# A very short history of the ACTUAL tip, never a fabricated circular arc.
	# Use the source tip at y=-49.76, shared with melee contact geometry.
	var phase_name:=str(motion.get("combat_phase","idle"))
	if phase_name not in ["strike","contact"]:return PackedVector2Array()
	var progress:=clampf(float(motion.get("phase_progress",0.0)),0.0,1.0)
	var end:=progress if phase_name=="strike" else 1.0
	var span:=0.20*(1.0-progress) if phase_name=="contact" else 0.20
	var reverse:=PackedVector2Array()
	var travelled:=0.0
	for i in range(9):
		var sample:=motion.duplicate()
		sample.combat_phase="strike";sample.phase_progress=maxf(0.0,end-float(i)/8.0*span)
		if i==0 and phase_name=="contact":sample=motion.duplicate()
		# Contact lunge is already the physical endpoint. Keep the trace local
		# so body approach cannot leave a separate floating weapon silhouette.
		var grip:=weapon_pose(sample,1.0,0.0,"sword")
		var point:=Vector2(grip.offset)+Vector2(0,-49.76).rotated(float(grip.rotation)+0.22)*Vector2(float(grip.facing),1)
		if not reverse.is_empty():
			var segment:=reverse[-1].distance_to(point)
			if segment<0.05:continue
			if travelled+segment>max_length:
				reverse.append(reverse[-1].lerp(point,(max_length-travelled)/segment));break
			travelled+=segment
		reverse.append(point)
	reverse.reverse()
	return reverse

static func draw_grip_front(host:CanvasItem,feet:Vector2,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0,weapon_key:String="sword")->void:
	# Draw only the front fingers after the weapon. The underlying painted
	# fist remains behind its hilt, so the hand encloses rather than floats
	# underneath a weapon pasted over the completed actor.
	var weapon:=weapon_pose(motion,scale,cast_tilt,weapon_key)
	if bool(weapon.stowed) or weapon_key not in ["sword","fan"]:return
	var face:=float(weapon.facing)
	var angle:=float(weapon.rotation)+(0.22 if weapon_key=="sword" else 0.0)
	_set_transform(host,feet+Vector2(weapon.offset),angle*face,Vector2(face,1.0)*scale)
	var skin:=Color("e6ab80")
	var shadow:=Color("8b614a")
	var width:=1.65 if weapon_key=="sword" else 1.45
	for y in [-0.95,0.0,0.95]:
		host.draw_line(Vector2(-width,y),Vector2(0.75,y+0.18),shadow,1.2,true)
		host.draw_line(Vector2(-width,y-0.1),Vector2(0.65,y+0.08),skin,0.82,true)
	host.draw_line(Vector2(-1.65,-1.8),Vector2(0.25,-0.60),shadow,1.35,true)
	host.draw_line(Vector2(-1.65,-1.9),Vector2(0.25,-0.70),Color("f3c49a"),0.9,true)
	_set_transform(host,Vector2.ZERO)

func draw_avatar_layers(host:CanvasItem,feet:Vector2,_textures:Dictionary,visual:Dictionary,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0)->void:
	var pose := sample_pose(motion,cast_tilt)
	var facing_scale := Vector2(float(pose.facing)*lerpf(0.40,1.0,float(pose.turn)),1.0)*PIXEL_SCALE*scale
	_set_transform(host,feet,0.0,facing_scale)
	_draw_arm(host,pose.far_arm,visual,Color(0.80,0.82,0.86))
	_draw_leg(host,pose.far_leg,visual,Color(0.80,0.82,0.86))
	_draw_leg(host,pose.near_leg,visual,Color.WHITE)
	_draw_body_part(host,assets.torso,torso_rect(TORSO_RECT),pose)
	var chest:=str(visual.get("chest",""))
	if assets.has(chest):
		var chest_rect:=torso_rect(Rect2(-34,-204,72,112 if chest=="chest_blue" else 99))
		# Both cutout chest canvases contain an unrelated detached fragment in
		# the upper-right corner (blue: x217..267,y0..17; jade: x196..215,y0..4).
		# Draw only the actual collar/vest regions, keeping original UVs. This
		# removes the floating dark "neck dot" without covering the body seam.
		_draw_body_region(host,assets[chest],chest_rect,pose,Rect2(0,0,0.74,1))
		_draw_body_region(host,assets[chest],chest_rect,pose,Rect2(0.74,0.06,0.26,0.94))
	_draw_arm(host,pose.near_arm,visual,Color.WHITE)
	_draw_head_part(host,assets.head,HEAD_RECT,pose)
	var head:=str(visual.get("head",""))
	if assets.has(head):_draw_head_part(host,assets[head],Rect2(-72,-429,78,37) if head=="head_pin" else Rect2(-40,-445,43,47),pose)
	_set_transform(host,Vector2.ZERO)

func _draw_leg(host:CanvasItem,leg:Dictionary,visual:Dictionary,tint:Color)->void:
	_draw_limb(host,assets.leg,leg,false,tint)
	var pants:=str(visual.get("legs",""))
	var shoe:=str(visual.get("feet",""))
	if assets.has(pants):_draw_limb(host,assets[pants],leg,false,tint)
	if assets.has(shoe):_draw_limb(host,assets[shoe],leg,false,tint)

func _draw_arm(host:CanvasItem,arm:Dictionary,visual:Dictionary,tint:Color)->void:
	_draw_limb(host,assets.arm,arm,true,tint)
	var sleeve:=str(visual.get("chest","")).replace("chest_","sleeve_")
	if assets.has(sleeve):_draw_limb(host,assets[sleeve],arm,true,tint)
	_draw_hand_form(host,arm,tint)

func _draw_limb(host:CanvasItem,texture:Texture2D,limb:Dictionary,arm:bool,tint:Color)->void:
	# Every equipment file shares its associated bare limb's source canvas.
	var sz:=Vector2(texture.get_size())
	var rows:=32
	for row in range(rows):
		var top:=float(row)/rows*sz.y
		var bottom:=float(row+1)/rows*sz.y
		# The painted source is a fist. Open-palm casts replace only its final
		# hand pixels; the wrist and both fixed-length arm bones stay unchanged.
		if arm and str(limb.get("hand_form","fist"))=="palm":
			var wrist_cut:=38.0+72.0/0.245
			if top>=wrist_cut:break
			bottom=minf(bottom,wrist_cut)
		var source:=PackedVector2Array([Vector2(0,top),Vector2(sz.x,top),Vector2(sz.x,bottom),Vector2(0,bottom)])
		var target:=PackedVector2Array()
		var uv:=PackedVector2Array()
		for point in source:
			target.append(_skin_arm(point,limb) if arm else _skin_leg(point,limb))
			uv.append(point/sz)
		_draw_quad(host,texture,target,uv,tint)

static func _draw_hand_form(host:CanvasItem,arm:Dictionary,tint:Color)->void:
	var form:=str(arm.get("hand_form","fist"))
	if form=="fist":return
	var wrist:Vector2=arm.wrist
	var angle:=float(arm.hand_angle)
	var skin:=Color("e8ac7c")*tint
	var outline:=Color("805b42")*tint
	if form=="palm":
		# Small upright palm with four joined fingers and a distinct thumb.
		# At actor scale this is a 4px hand, so restrained flat shading matches
		# the painted limb much better than a luminous oversized hand effect.
		var local:=PackedVector2Array([Vector2(-7,-8),Vector2(6,-8),Vector2(7,-2),Vector2(10,4),Vector2(7,6),Vector2(5,3),Vector2(5,13),Vector2(2,16),Vector2(-4,16),Vector2(-7,13)])
		var points:=PackedVector2Array()
		for point in local:points.append(wrist+point.rotated(angle))
		host.draw_colored_polygon(points,skin)
		points.append(points[0]);host.draw_polyline(points,outline,0.7,true)
		for x in [-3.0,0.0,3.0]:
			host.draw_line(wrist+Vector2(x,8).rotated(angle),wrist+Vector2(x,13).rotated(angle),outline,0.55,true)
		host.draw_line(wrist+Vector2(-4,-4).rotated(angle),wrist+Vector2(-4,7).rotated(angle),Color("f9cf9d")*tint,1.6,true)
	elif form=="finger":
		var start:=wrist+Vector2(3,4).rotated(angle)
		var end:=wrist+Vector2(3,23).rotated(angle)
		host.draw_line(start,end,outline,4.4,true)
		host.draw_line(start,end,skin,3.0,true)
		host.draw_circle(end,1.45,skin,true,-1,true)

static func _skin_leg(p:Vector2,leg:Dictionary)->Vector2:
	var q:Vector2=(p-Vector2(102,20))*Vector2(0.225,0.225)
	var center:=lerpf(0.0,-5.0,clampf((q.y-53.0)/43.0,0.0,1.0))
	var width:=lerpf(LEG_WIDTH,FOOT_WIDTH,smoothstep(87.0,98.0,q.y))
	var flesh:=Vector2((q.x-center)*(width-1.0),0.0)
	var upper:Vector2=leg.hip+(q+flesh).rotated(float(leg.upper_angle))
	var lower:Vector2=leg.knee+(q-Vector2(0,53)+flesh).rotated(float(leg.lower_angle))
	var foot:Vector2=leg.ankle+(q-Vector2(-5,96)+flesh).rotated(float(leg.foot_angle))
	if q.y<61:return upper.lerp(lower,smoothstep(46,60,q.y))
	return lower.lerp(foot,smoothstep(87,98,q.y))

static func _skin_arm(p:Vector2,arm:Dictionary)->Vector2:
	var q:Vector2=(p-Vector2(54,38))*Vector2(0.245,0.245)
	var center:=lerpf(0.0,4.0,clampf(q.y/42.0,0.0,1.0)) if q.y<=42.0 else lerpf(4.0,14.0,clampf((q.y-42.0)/36.0,0.0,1.0))
	var width:=lerpf(ARM_WIDTH,HAND_WIDTH,smoothstep(66.0,78.0,q.y))
	var flesh:=Vector2((q.x-center)*(width-1.0),0.0)
	var upper:Vector2=arm.shoulder+(q+flesh).rotated(float(arm.upper_angle))
	var lower:Vector2=arm.elbow+(q-Vector2(4,42)+flesh).rotated(float(arm.lower_angle))
	# The fist is a rigid final joint around the same grip used by the weapon.
	# Previously the weapon rotated independently through a stationary fist.
	# At rest this is exactly the forearm transform; in combat it closes the
	# painted hand around the authored sword/fan angle without changing bones.
	var hand:Vector2=arm.wrist+(q-Vector2(14,78)+flesh).rotated(float(arm.hand_angle))
	var forearm:Vector2=upper.lerp(lower,smoothstep(34,49,q.y))
	return forearm.lerp(hand,smoothstep(66,78,q.y))

static func head_point(point:Vector2)->Vector2:
	# The skull settles toward the shoulders, while the lower neck attachment
	# remains fixed. Compress only the short painted neck band, rather than
	# translating the cutout and sliding its bottom over the collar/chest.
	# The exact same mesh mapping owns ornaments and collision clearance.
	var settled:=HEAD_SETTLE*(1.0-smoothstep(NECK_TAPER_START,NECK_TAPER_END,point.y))
	return NECK+(point-NECK)*HEAD_SCALE+Vector2(0.0,settled)

static func torso_point(point:Vector2)->Vector2:
	return point*Vector2(TORSO_WIDTH,1.0)

static func head_rect(rect:Rect2)->Rect2:
	return Rect2(head_point(rect.position),head_point(rect.end)-head_point(rect.position))

static func torso_rect(rect:Rect2)->Rect2:
	return Rect2(torso_point(rect.position),rect.size*Vector2(TORSO_WIDTH,1.0))

func _draw_head_part(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary)->void:
	# Separate neck rows resolve the authored taper smoothly; the head above
	# the jaw remains one rigid, uniformly scaled face/hairstyle.
	var rows:=32 if texture==assets.head else 1
	for row in range(rows):
		var top:=float(row)/rows;var bottom:=float(row+1)/rows
		var p:=rect.position+Vector2(0.0,rect.size.y*top)
		var e:=rect.position+Vector2(rect.size.x,rect.size.y*bottom)
		var points:=PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
		for i in range(4):points[i]=_body(head_point(points[i]),pose.shift,float(pose.body_angle))
		_draw_quad(host,texture,points,PackedVector2Array([Vector2(0,top),Vector2(1,top),Vector2(1,bottom),Vector2(0,bottom)]),Color.WHITE)

func _draw_body_part(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary)->void:
	var p:=rect.position
	var e:=rect.end
	var points:=PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
	for i in range(4):points[i]=_body(points[i],pose.shift,float(pose.body_angle))
	_draw_quad(host,texture,points,PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN]),Color.WHITE)

func _draw_body_region(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary,region:Rect2)->void:
	var p:=rect.position+rect.size*region.position
	var e:=rect.position+rect.size*region.end
	var points:=PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
	for i in range(4):points[i]=_body(points[i],pose.shift,float(pose.body_angle))
	var uv:=PackedVector2Array([region.position,Vector2(region.end.x,region.position.y),region.end,Vector2(region.position.x,region.end.y)])
	_draw_quad(host,texture,points,uv,Color.WHITE)

static func _quad_triangles(points:PackedVector2Array,uv:PackedVector2Array)->Array[Dictionary]:
	# Skinning can fold a strip into a concave/bow-tie quad, or put one corner
	# almost on its opposite edge. Godot's polygon ear-clipper rejects even
	# valid very thin triangles at some IK phases. Explicit indexed triangles
	# retain every nonzero piece of the original textured strip instead.
	var diagonals:=[[[0,1,2],[0,2,3]],[[0,1,3],[1,2,3]]]
	var best:Array=diagonals[0]
	var best_quality:=-1.0
	for candidate in diagonals:
		var quality:=INF
		for indices in candidate:
			var a:Vector2=points[indices[0]];var b:Vector2=points[indices[1]];var c:Vector2=points[indices[2]]
			quality=minf(quality,absf((b-a).cross(c-a)))
		if quality>best_quality:
			best_quality=quality;best=candidate
	var result:Array[Dictionary]=[]
	for indices in best:
		var area:float=(points[indices[1]]-points[indices[0]]).cross(points[indices[2]]-points[indices[0]])
		# An exactly collapsed triangle has no visible coverage. Do not use an
		# arbitrary area tolerance that drops a still-visible long thin strip.
		if area==0.0:continue
		var order:Array=indices if area>0.0 else [indices[0],indices[2],indices[1]]
		result.append({"vertices":PackedVector2Array([points[order[0]],points[order[1]],points[order[2]]]),
			"uv":PackedVector2Array([uv[order[0]],uv[order[1]],uv[order[2]]])})
	return result

static func _draw_quad(host:CanvasItem,texture:Texture2D,points:PackedVector2Array,uv:PackedVector2Array,tint:Color)->void:
	var vertices:=PackedVector2Array()
	var texture_uv:=PackedVector2Array()
	for triangle in _quad_triangles(points,uv):
		vertices.append_array(triangle.vertices);texture_uv.append_array(triangle.uv)
	if vertices.is_empty():return
	var indices:=PackedInt32Array()
	for i in range(vertices.size()):indices.append(i)
	# Bypass polygon triangulation entirely, while respecting the host's
	# current CanvasItem draw transform and the original texture coordinates.
	RenderingServer.canvas_item_add_triangle_array(host.get_canvas_item(),indices,vertices,PackedColorArray([tint]),texture_uv,PackedInt32Array(),PackedFloat32Array(),texture.get_rid())

static func _set_transform(host:CanvasItem,origin:Vector2,rotation:float=0.0,scale_value:Vector2=Vector2.ONE)->void:
	if host.has_method("_scene_set_transform"):host._scene_set_transform(origin,rotation,scale_value)
	else:host.draw_set_transform(origin,rotation,scale_value)
