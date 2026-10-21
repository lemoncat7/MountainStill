extends RefCounted
# Diagnostic only: v1.3.5 hand painter using CURRENT shared joint samples
# so paired art comparisons cannot conflate wrist choreography and hand style.
const CurrentRig=preload("res://scripts/character_sidewalk.gd")
## Genuine side-profile cutout animation. Original generated art, fixed bone lengths.
## Neck-anchored side-profile proportions; independent equipment follows each part.
## Bone lengths, foot placement and weapon reach retain their authored scale.
const AttackRegistry = preload("res://scripts/attack_module_registry.gd")
const ResponseCues = preload("res://scripts/combat_response_cues.gd")
const Impact = preload("res://scripts/combat_impact.gd")
const BaseAttackModule = preload("res://scripts/combat_modules/attack_module.gd")
const GripHand = preload("res://scripts/weapon_grip_hand.gd")
const EquipmentTemplate = preload("res://assets/cultivation/sidewalk/template.gd")
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
const ASSET_ROOT := EquipmentTemplate.ASSET_ROOT
var phase := 0.0
var blend := 0.0
var facing := 1.0
var idle_time := 0.0
var turn := 1.0
var assets: Dictionary = {}

func _init() -> void:
	for key in EquipmentTemplate.ASSET_KEYS:
		assets[key] = _filtered_texture(ASSET_ROOT+key+".png")
	assets.held_sword=filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))

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

static func draw_held_weapon(host:CanvasItem,texture:Texture2D,rect:Rect2,style:String,rear:bool=false,stowed:bool=false)->void:
	# The rear hilt is behind the holding forearm. The blade/crossguard remain
	# in front. A single flat weapon layer made the pommel run through wrists.
	if style!="sword" or stowed:
		if not rear:host.draw_texture_rect(texture,rect,false)
		return
	var cut:=clampf(-rect.position.y/rect.size.y,0.0,1.0)
	var fraction:=Rect2(0,cut,1,1-cut) if rear else Rect2(0,0,1,cut)
	var target:=Rect2(rect.position+fraction.position*rect.size,fraction.size*rect.size)
	var source:=Rect2(fraction.position*Vector2(texture.get_size()),fraction.size*Vector2(texture.get_size()))
	host.draw_texture_rect_region(texture,target,source)

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
	var sample:=motion
	if not bool(motion.get("contact_authority",false)) and str(motion.get("combat_phase",""))=="strike" and int(motion.get("strike_index",0))==0:
		# Keep the authored contact endpoint, but save speed for the last part
		# of the swing. Only rendering uses this acceleration; contact authority
		# remains on the original clock and sampled weapon reach.
		sample=motion.duplicate()
		sample.phase_progress=pow(clampf(float(motion.get("phase_progress",0.0)),0.0,1.0),1.50)
	if not bool(motion.get("contact_authority",false)) and str(motion.get("defense_action",""))=="guard":
		sample=sample.duplicate()
		var cp:=str(motion.get("combat_phase",""))
		var progress:=float(motion.get("phase_progress",0.0))
		sample.render_defense_commit=1.0 if cp in ["strike","contact"] else (smoothstep(.8,1.0,progress) if cp=="windup" else (1.0-smoothstep(0.0,.35,progress) if cp=="recovery" else 0.0))
	var combat := _combat(sample)
	if not bool(motion.get("contact_authority",false)):
		combat = _presentation_response(motion,combat)
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
	if not bool(motion.get("contact_authority",false)):
		if combat.has("guard_catch"):
			var catch:Dictionary=combat.guard_catch
			var catch_angle:=float(catch.angle)
			var wrist:Vector2=(Vector2(catch.point)-Vector2(0,-float(catch.distance)).rotated(catch_angle))/PIXEL_SCALE
			# A body-front probe may be high above the shoulder. Keep the
			# hand inside the fixed-length chain, then let another point along
			# the blade meet that line; never drag the sewn sleeve off the body.
			var socket:=_body(EquipmentTemplate.NEAR_ARMHOLE,pose.shift,float(pose.body_angle))
			wrist=socket+(wrist-socket).limit_length(75.0)
			catch_angle=(Vector2(catch.point)-wrist*PIXEL_SCALE).angle()+PI/2.0
			var hold:=float(combat.get("guard_hold",0.0))*float(catch.get("weight",1.0))
			pose.near_arm.wrist=Vector2(pose.near_arm.wrist).lerp(wrist,hold)
			pose.near_arm.grip_angle=lerp_angle(float(pose.near_arm.grip_angle),catch_angle-.22,hold)
			var far_socket:=_body(EquipmentTemplate.FAR_ARMHOLE,pose.shift,float(pose.body_angle))
			var support:=far_socket+(wrist+Vector2(-8,10)-far_socket).limit_length(75.0)
			pose.far_arm.wrist=Vector2(pose.far_arm.wrist).lerp(support,hold)
		pose.near_arm = _fit_render_socket(pose.near_arm,pose,EquipmentTemplate.NEAR_ARMHOLE)
		pose.far_arm = _fit_render_socket(pose.far_arm,pose,EquipmentTemplate.FAR_ARMHOLE)
		if combat.has("guard_catch"):
			# The handle sits inside the fist, not in the anatomical wrist.
			# Aim the real blade from that internal socket at the incoming line.
			var hold:=float(combat.get("guard_hold",0.0))
			var grip:=Vector2(pose.near_arm.wrist)*PIXEL_SCALE+_grip_offset(pose.near_arm,"near","sword",float(combat.get("grip_axial_roll",0.0)))
			var aim:=(Vector2(combat.guard_catch.point)-grip).angle()+PI/2.0-.22
			pose.near_arm.grip_angle=lerp_angle(float(pose.near_arm.grip_angle),aim,hold)
	return pose

# Place the visible upper-arm cap inside the actual painted armhole. Solve
# both fixed-length bones back to the unchanged wrist, so weapons retain their
# real endpoints. A full extension advances the shoulder socket/garment patch
# together instead of stretching a bone or detaching the sleeve.
static func _fit_render_socket(source:Dictionary,pose:Dictionary,socket:Vector2)->Dictionary:
	var arm:=source.duplicate()
	var shoulder:=_body(socket,pose.shift,float(pose.body_angle))
	var target:=Vector2(source.wrist)
	var upper_length:=42.0
	var lower_length:=Vector2(10,36).length()
	var delta:=target-shoulder
	var maximum:=upper_length+lower_length-.001
	if delta.length()>maximum:
		shoulder+=delta.normalized()*(delta.length()-maximum)
		delta=target-shoulder
	var distance:=clampf(delta.length(),absf(upper_length-lower_length)+.001,maximum)
	var axis:=delta.normalized()
	var along:=(upper_length*upper_length-lower_length*lower_length+distance*distance)/(2.0*distance)
	var bend:=sqrt(maxf(0.0,upper_length*upper_length-along*along))
	var normal:=Vector2(-axis.y,axis.x)
	var a:=shoulder+axis*along+normal*bend
	var b:=shoulder+axis*along-normal*bend
	var elbow:=a # Authored lower/front pole; never switch branches frame-to-frame.
	arm.shoulder=shoulder;arm.elbow=elbow;arm.wrist=target
	arm.upper_angle=(elbow-shoulder).angle()-PI/2.0
	arm.lower_angle=(target-elbow).angle()-Vector2(10,36).angle()
	var wrist_turn:=clampf(angle_difference(float(arm.lower_angle),float(source.hand_angle)),-.42,.42)
	arm.hand_angle=float(arm.lower_angle)+wrist_turn
	return arm

# Contact authority uses the established rig sample. Defensive staging below
# is render-only: changing a brace must not reroll or create a physical hit.
# The active striking chain is never overridden by presentation during contact.
static func sample_contact_pose(motion:Dictionary,cast_tilt:float=0.0)->Dictionary:
	var contact:=motion.duplicate()
	contact.contact_authority=true
	return sample_pose(contact,cast_tilt)

static func _presentation_response(motion:Dictionary,source:Dictionary)->Dictionary:
	return CurrentRig._presentation_response(motion,source)

static func _presentation_hit(motion:Dictionary,source:Dictionary)->Dictionary:
	var result:=source.duplicate()
	var profile:Dictionary=motion.get("impact_profile",{})
	var age:=float(motion.get("reaction_age",-1.0))
	if age<0.0 or str(motion.get("contact_id","")).is_empty() or not bool(profile.get("active",false)):return result
	var response:=Impact.reaction(profile,age)
	var impulse:=float(response.get("impulse",0.0))
	var recoil:=float(response.get("recoil",0.0))
	var follow:=float(response.get("followthrough",0.0))
	var committed:=str(motion.get("combat_phase","")) in ["strike","contact"]
	var region:=str(profile.get("contact_region","torso"))
	# The face remains a rigid piece; a neck pivot lets the head lag behind
	# shoulder compression rather than wobbling the complete sprite.
	result.head_recoil=(-.095*impulse-.065*follow)*(1.0 if region=="head" else .58)
	if committed:return result
	var neutral:=motion.duplicate()
	neutral.defense_action="ready";neutral.reaction_amount=0.0;neutral.erase("impact_profile")
	var base:=_combat(neutral)
	var heavy:=str(profile.get("kind","")) in ["heavy","guardbreak"]
	var force:=1.0 if heavy else .75
	result.tilt=float(base.tilt)-(.10*impulse+.10*recoil)*force
	result.shift_x=float(base.shift_x)-9.0*recoil*force
	result.shift_y=float(base.shift_y)+(14.0*impulse+7.0*recoil)*force
	result.upper=float(base.upper)+.34*impulse+.15*follow
	result.lower=float(base.lower)+.48*impulse-.15*follow
	result.far_upper=float(base.far_upper)+.22*impulse
	result.far_lower=float(base.far_lower)+.35*impulse+.12*follow
	result.far_hand=result.far_lower
	result.lead_stance=float(base.lead_stance)+(7.0 if heavy else 3.0)*recoil
	result.rear_stance=float(base.rear_stance)+(5.0 if heavy else 2.0)*recoil
	return result

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
	return CurrentRig._combat(motion)

static func _basic_form(style:String,move:String,g:float,e:float,stance:float,motion:Dictionary)->Dictionary:
	# Compatibility entry point for existing practice/test callers.
	var sample:=motion.duplicate()
	sample.combat_move=move;sample.basic_style=style;sample.action_kind="basic"
	return AttackRegistry.default_registry().sample_pose_track("weapon."+style,sample,g,e,stance)

static func _arm(cycle:float,amount:float,shift:Vector2,body_angle:float,side:float,pick:float,combat:Dictionary)->Dictionary:
	return CurrentRig._arm(cycle,amount,shift,body_angle,side,pick,combat)

static func _body(p:Vector2,shift:Vector2,angle:float)->Vector2:
	return HIP+(p-HIP).rotated(angle)+shift

static func attachment_offset(_source_point:Vector2,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0)->Vector2:
	var p := sample_pose(motion,cast_tilt)
	var arm:Dictionary=p.far_arm if str(p.combat.get("attack_hand","near"))=="far" else p.near_arm
	return Vector2(arm.wrist)*Vector2(float(p.facing)*lerpf(0.40,1.0,float(p.turn)),1.0)*PIXEL_SCALE*scale

static func attachment_rotation(motion:Dictionary,cast_tilt:float=0.0)->float:
	var pose:=sample_pose(motion,cast_tilt)
	return float(pose.far_arm.grip_angle if str(pose.combat.get("attack_hand","near"))=="far" else pose.near_arm.grip_angle)

static func contact_weapon_pose(motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0,weapon_key:String="sword",sampled_pose:Dictionary={})->Dictionary:
	var contact:=motion.duplicate()
	contact.contact_authority=true
	return weapon_pose(contact,scale,cast_tilt,weapon_key,sample_contact_pose(contact,cast_tilt) if sampled_pose.is_empty() else sampled_pose)

static func _grip_offset(arm:Dictionary,side:String,style:String,roll:float=0.0)->Vector2:
	var view:=GripHand.presentation(side,roll)
	return GripHand.grip_socket(style,str(view.view),float(view.handedness)).rotated(float(arm.hand_angle))

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
			var ready_point:=Vector2(ready_pose.near_arm.wrist)
			if not bool(motion.get("contact_authority",false)):
				ready_point+=_grip_offset(ready_pose.near_arm,"near",weapon_key,float(ready_pose.combat.get("grip_axial_roll",motion.get("grip_axial_roll",0.0))))/PIXEL_SCALE
			point=ready_point.lerp(point,stow_amount)
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
	var point:=Vector2(active_arm.wrist)*PIXEL_SCALE
	if not bool(motion.get("contact_authority",false)):
		point+=_grip_offset(active_arm,str(pose.combat.get("attack_hand","near")),weapon_key,float(pose.combat.get("grip_axial_roll",motion.get("grip_axial_roll",0.0))))
	return {"offset":point*Vector2(direction*lerpf(0.40,1.0,float(pose.turn)),1.0)*scale,
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
	var pose:=sample_pose(motion,cast_tilt)
	var weapon:=weapon_pose(motion,scale,cast_tilt,weapon_key,pose)
	if bool(weapon.stowed) or weapon_key not in ["sword","fan"]:return
	var face:=float(weapon.facing)
	var side:=str(pose.combat.get("attack_hand","near"))
	var arm:Dictionary=pose.far_arm if side=="far" else pose.near_arm
	var view:=GripHand.presentation(side,float(pose.combat.get("grip_axial_roll",motion.get("grip_axial_roll",0.0))))
	var angle:=float(arm.hand_angle)
	var wrist:=Vector2(arm.wrist)*Vector2(face*lerpf(.40,1.0,float(pose.turn)),1)*PIXEL_SCALE*scale
	_set_transform(host,feet+wrist,angle*face,Vector2(face,1.0)*scale)
	GripHand.draw_front(host,weapon_key,float(weapon.fan_open),Color(.80,.82,.86) if side=="far" else Color.WHITE,str(view.view),float(view.handedness))
	_set_transform(host,Vector2.ZERO)

static func draw_grip_back(host:CanvasItem,feet:Vector2,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0,weapon_key:String="sword")->void:
	var pose:=sample_pose(motion,cast_tilt)
	var weapon:=weapon_pose(motion,scale,cast_tilt,weapon_key,pose)
	if bool(weapon.stowed) or not GripHand.supports(weapon_key):return
	var face:=float(weapon.facing)
	var side:=str(pose.combat.get("attack_hand","near"))
	var arm:Dictionary=pose.far_arm if side=="far" else pose.near_arm
	var view:=GripHand.presentation(side,float(pose.combat.get("grip_axial_roll",motion.get("grip_axial_roll",0.0))))
	var angle:=float(arm.hand_angle)
	var wrist:=Vector2(arm.wrist)*Vector2(face*lerpf(.40,1.0,float(pose.turn)),1)*PIXEL_SCALE*scale
	_set_transform(host,feet+wrist,angle*face,Vector2(face,1.0)*scale)
	GripHand.draw_back(host,weapon_key,float(weapon.fan_open),Color(.80,.82,.86) if side=="far" else Color.WHITE,str(view.view),float(view.handedness))
	_set_transform(host,Vector2.ZERO)

func draw_avatar_layers(host:CanvasItem,feet:Vector2,_textures:Dictionary,visual:Dictionary,motion:Dictionary,scale:float=1.0,cast_tilt:float=0.0)->void:
	var pose := sample_pose(motion,cast_tilt)
	var weapon_key:=str(visual.get("weapon","")).trim_prefix("weapon_")
	if GripHand.supports(weapon_key) and not bool(weapon_pose(motion,scale,cast_tilt,weapon_key,pose).stowed):
		var active_arm:Dictionary=pose.far_arm if str(pose.combat.get("attack_hand","near"))=="far" else pose.near_arm
		active_arm.hand_form="holding"
	var facing_scale := Vector2(float(pose.facing)*lerpf(0.40,1.0,float(pose.turn)),1.0)*PIXEL_SCALE*scale
	_set_transform(host,feet,0.0,facing_scale)
	_draw_arm(host,pose.far_arm,visual,Color(0.80,0.82,0.86))
	_draw_leg(host,pose.far_leg,visual,Color(0.80,0.82,0.86))
	_draw_leg(host,pose.near_leg,visual,Color.WHITE)
	_draw_body_part(host,assets.torso,torso_rect(TORSO_RECT),pose)
	var chest:=str(visual.get("chest",""))
	if assets.has(chest):
		_draw_body_region(host,assets[chest],torso_rect(EquipmentTemplate.CHEST_RECT),pose,Rect2(0,0,1,1))
	if weapon_key=="sword":
		var held:=weapon_pose(motion,scale,cast_tilt,weapon_key,pose)
		if not bool(held.stowed):
			_set_transform(host,feet+Vector2(held.offset),(float(held.rotation)+.22)*float(held.facing),Vector2(float(held.facing),1)*scale)
			draw_held_weapon(host,assets.held_sword,Rect2(-7.8,-53.7,26,76),"sword",true)
			_set_transform(host,feet,0.0,facing_scale)
	_draw_arm(host,pose.near_arm,visual,Color.WHITE)
	_draw_head_part(host,assets.head,HEAD_RECT,pose)
	var head:=str(visual.get("head",""))
	if assets.has(head):_draw_head_part(host,assets[head],EquipmentTemplate.HEAD_RECT,pose)
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
		if arm and str(limb.get("hand_form","fist")) in ["palm","holding"]:
			var wrist_cut:=EquipmentTemplate.ARM_HAND_CUT_Y
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
	var q:Vector2=(p-EquipmentTemplate.LEG_ORIGIN)*EquipmentTemplate.LEG_SOURCE_SCALE
	var center:=lerpf(0.0,-5.0,clampf((q.y-53.0)/43.0,0.0,1.0))
	var width:=lerpf(LEG_WIDTH,FOOT_WIDTH,smoothstep(87.0,98.0,q.y))
	var flesh:=Vector2((q.x-center)*(width-1.0),0.0)
	var upper:Vector2=leg.hip+(q+flesh).rotated(float(leg.upper_angle))
	var lower:Vector2=leg.knee+(q-Vector2(0,53)+flesh).rotated(float(leg.lower_angle))
	var foot:Vector2=leg.ankle+(q-Vector2(-5,96)+flesh).rotated(float(leg.foot_angle))
	if q.y<61:return upper.lerp(lower,smoothstep(46,60,q.y))
	return lower.lerp(foot,smoothstep(87,98,q.y))

static func _skin_arm(p:Vector2,arm:Dictionary)->Vector2:
	var q:Vector2=(p-EquipmentTemplate.ARM_ORIGIN)*EquipmentTemplate.ARM_SOURCE_SCALE
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
	var rows:=32
	for row in range(rows):
		var top:=float(row)/rows;var bottom:=float(row+1)/rows
		var p:=rect.position+Vector2(0.0,rect.size.y*top)
		var e:=rect.position+Vector2(rect.size.x,rect.size.y*bottom)
		var points:=PackedVector2Array([p,Vector2(e.x,p.y),e,Vector2(p.x,e.y)])
		for i in range(4):
			points[i]=_body(head_point(points[i]),pose.shift,float(pose.body_angle))
			var pivot:=_body(head_point(NECK),pose.shift,float(pose.body_angle))
			points[i]=pivot+(points[i]-pivot).rotated(float(pose.combat.get("head_recoil",0.0)))
		_draw_quad(host,texture,points,PackedVector2Array([Vector2(0,top),Vector2(1,top),Vector2(1,bottom),Vector2(0,bottom)]),Color.WHITE)

# The generated torso canvases place the painted armhole behind the rig's
# shoulder. Align that local opening, not the entire torso or the skeleton.
# The same mapping carries the sleeve root during scapular reach; hips, chest
# width, neckline and all authoritative bones/grip coordinates are unchanged.
static func shoulder_surface_point(point:Vector2,pose:Dictionary,garment:bool=true)->Vector2:
	var source_socket:=EquipmentTemplate.NEAR_ARMHOLE if garment else EquipmentTemplate.BARE_SHOULDER_SURFACE
	var desired:Vector2=pose.near_arm.shoulder
	var resting:=_body(source_socket,pose.shift,float(pose.body_angle))
	var delta:=(desired-resting).rotated(-float(pose.body_angle))
	# Separate left/right widths keep the mesh monotone even during a jab.
	var dx:=point.x-source_socket.x
	var horizontal:=1.0-smoothstep(0.0,82.0 if dx>0.0 else 34.0,absf(dx))
	var dy:=point.y-source_socket.y
	var vertical:=1.0-smoothstep(7.0,38.0,absf(dy)) if garment else 1.0-smoothstep(0.0,27.0 if dy<0.0 else 70.0,absf(dy))
	var mapped:=point+delta*horizontal*vertical
	return _body(mapped,pose.shift,float(pose.body_angle))

func _draw_body_part(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary)->void:
	_draw_body_region(host,texture,rect,pose,Rect2(0,0,1,1),false)

func _draw_body_region(host:CanvasItem,texture:Texture2D,rect:Rect2,pose:Dictionary,region:Rect2,garment:bool=true)->void:
	var cols:=12
	var rows:=18
	var vertices:=PackedVector2Array()
	var texture_uv:=PackedVector2Array()
	for row in range(rows):
		for col in range(cols):
			var uv0:=region.position+region.size*Vector2(float(col)/cols,float(row)/rows)
			var uv1:=region.position+region.size*Vector2(float(col+1)/cols,float(row+1)/rows)
			var uv:=PackedVector2Array([uv0,Vector2(uv1.x,uv0.y),uv1,Vector2(uv0.x,uv1.y)])
			var points:=PackedVector2Array()
			for point in uv:points.append(shoulder_surface_point(rect.position+rect.size*point,pose,garment))
			for triangle in _quad_triangles(points,uv):
				vertices.append_array(triangle.vertices);texture_uv.append_array(triangle.uv)
	var indices:=PackedInt32Array()
	for i in range(vertices.size()):indices.append(i)
	RenderingServer.canvas_item_add_triangle_array(host.get_canvas_item(),indices,vertices,PackedColorArray([Color.WHITE]),texture_uv,PackedInt32Array(),PackedFloat32Array(),texture.get_rid())

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
