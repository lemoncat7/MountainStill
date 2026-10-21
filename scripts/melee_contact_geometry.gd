extends RefCounted
## Shared physical contact geometry. Source artwork and rig joints own reach.
const Rig=preload("res://scripts/character_sidewalk.gd")
const Beast=preload("res://scripts/beast_presentation.gd")
const MonsterRig=preload("res://scripts/monster_pose_renderer.gd")
static var _images:Dictionary={}
static var _front_rows:Dictionary={}
# Source artwork, calibrated scale and body rows are immutable for one painted
# key. Cache them once; world transforms and current combat state stay per sample.
static var _source_records:Dictionary={}
static var _deformed_fronts:Dictionary={}
static var _hero_head_outline:=PackedVector2Array()
static func prewarm(definition:Dictionary)->void:
 # Run at encounter setup, before travel/contact. Pixel rows are cached once.
 for key in ["idle","windup","attack"]:_body_data({"pose_key":key},definition)
 var route:=str(definition.get("route_id","bamboo_pass"))
 var authored_samples:Array=[]
 if route=="bamboo_pass":authored_samples=[["moss_pounce","windup",.5,0.0],["moss_pounce","strike",.5,0.0],["moss_pounce","contact",0.0,0.0],["moss_slam","windup",.8,0.0],["moss_rush","strike",.5,1.0],["moss_rush","strike",.5,-1.0]]
 elif route=="cloud_slope":authored_samples=[["crane_peck","windup",.5,0.0],["crane_peck","contact",0.0,0.0],["crane_sweep","windup",.5,0.0],["crane_sweep","contact",0.0,0.0],["crane_dive","windup",.8,0.0],["crane_dive","contact",0.0,0.0]]
 for sample in authored_samples:_body_data({"move_family":sample[0],"combat_phase":sample[1],"phase_progress":sample[2],"monster_pose":{"step_cycle":sample[3]}},definition)
static func is_melee(motion:Dictionary)->bool:
 return str(motion.get("action_kind","")) in ["basic","weapon_art","weapon"]
static func attack_points(motion:Dictionary)->PackedVector2Array:
 var style:=str(motion.get("attack_style",motion.get("basic_style","unarmed")))
 var provider:Variant=motion.get("strike_provider")
 if provider==null:
  # Old preview/geometry APIs are adapted once; live combat carries its bound
  # weapon provider directly and does not classify types in contact probes.
  var registry=Rig.AttackRegistry.default_registry()
  provider=registry.pose_provider("weapon."+style)
 var pose:=Rig.sample_contact_pose(motion)
 var grip:Dictionary={}
 if style!="unarmed":grip=Rig.contact_weapon_pose(motion,1.0,0.0,style,pose)
 return provider.geometry_points(motion,pose,grip)
static func strike_segment_points(hero:Dictionary)->PackedVector2Array:
 var authored:=attack_points(hero)
 var points:=PackedVector2Array()
 for i in range(authored.size()):
  points.append(authored[i])
  if i==0:continue
  var length:=authored[i-1].distance_to(authored[i])
  for step in range(1,ceili(length/2.0)):
   points.append(authored[i-1].lerp(authored[i],float(step)/ceili(length/2.0)))
 return points
static func separate(enemy:Dictionary,hero:Dictionary,definition:Dictionary)->Dictionary:
 var result:=enemy.duplicate()
 var articulated:=enemy.has("monster_pose") and MonsterRig.supports(str(definition.get("route_id","bamboo_pass")))
 var probes:=hero_body_fronts(hero) if articulated else PackedVector2Array([hero_front(hero)])
 if articulated and float(hero.get("reaction_amount",0.0))>0.0:
  # A hit bends the defender's head/chest but does not instantly free its
  # physical stance for the attacker to teleport into. Retain the ready
  # body envelope through that local recoil, alongside the visible body.
  var planted:=hero.duplicate();planted.reaction_amount=0.0;planted.defense_action="ready";planted.guard_broken=false
  probes.append_array(hero_body_fronts(planted))
 var correction:=0.0
 var weights:Dictionary=enemy.get("clearance_weights",{str(enemy.get("pose_key","idle")):1.0})
 # Articulated creatures have one actual source and deformed silhouette; the
 # old texture crossfade union is only needed for untouched legacy species.
 if articulated:
  weights={str(enemy.get("pose_key","idle")):1.0}
 for key in weights:
  if float(weights[key])<=0.0:continue
  var sample:=result.duplicate();sample.pose_key=key
  var source:=_body_data(sample,definition)
  for nose in probes:
   var front:=_front_at_y(nose.y,source)
   if bool(front.valid):correction=maxf(correction,maxf(0.0,nose.x+3.0-Vector2(front.point).x)*float(weights[key]))
 # Reserve/release the solid head/torso landing envelope smoothly. These
 # pure time samples anticipate a painted keypose or descending skull before
 # it reaches the body plane, rather than teleporting the root at that frame.
 var immediate_correction:=correction
 for preview in enemy.get("clearance_previews",[]):
  var sample:Dictionary=preview.motion.duplicate()
  sample.visual_offset=Vector2(Vector2(enemy.get("visual_offset",Vector2.ZERO)).x,Vector2(sample.visual_offset).y)
  var weight:=float(preview.weight)
  var source:=_body_data(sample,definition)
  for nose in probes:
   var front:=_front_at_y(nose.y,source)
   if bool(front.valid):correction=maxf(correction,maxf(0.0,nose.x+3.0-Vector2(front.point).x)*weight)
 result.visual_offset=Vector2(result.get("visual_offset",Vector2.ZERO))+Vector2(correction,0)
 result.body_separation=correction
 result.body_reservation=correction-immediate_correction
 var clearance:=INF
 var solid:=_body_data(result,definition)
 for nose in probes:
  var current:=_front_at_y(nose.y,solid)
  if bool(current.valid):clearance=minf(clearance,Vector2(current.point).x-nose.x)
 if is_finite(clearance):result.body_clearance=clearance
 return result
static func fit_approach(hero:Dictionary,enemy:Dictionary,definition:Dictionary,origin:float)->Dictionary:
 var best:={"cost":INF,"target":origin,"aim":0.0,"crouch":0.0}
 for crouch in [0.0,5.0,10.0]:
  for ai in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6]:
   var candidate:=hero.duplicate();candidate.strike_aim=float(ai)*0.2;candidate.aim_crouch=crouch
   var measured:=measure(candidate,enemy,definition)
   if not bool(measured.vertical_valid):continue
   var target:=clampf(float(measured.gap)+0.5,-70.0,110.0)
   candidate.approach_origin=target
   var final_enemy:=separate(enemy,candidate,definition)
   var final:=measure(candidate,final_enemy,definition)
   var residual:=absf(float(final.gap)) if bool(final.vertical_valid) else 100.0
   var cost:float=maxf(0.0,residual-2.0)*20.0+absf(float(ai))*0.45+crouch*0.16+absf(target-origin)*0.015
   if bool(final.contact):
    cost-=5.0
    if ai==0 and crouch==0.0:return {"cost":cost,"target":target,"aim":0.0,"crouch":0.0}
   if cost<float(best.cost):best={"cost":cost,"target":target,"aim":candidate.strike_aim,"crouch":crouch}
 return best
static func _body_data(enemy:Dictionary,definition:Dictionary)->Dictionary:
 var route:=str(definition.get("route_id","bamboo_pass"))
 var boss:=bool(definition.get("boss",false))
 var prefix:=route+("_boss" if boss else "")
 var articulated:=MonsterRig.supports(prefix) and enemy.has("monster_pose")
 var pose_key:=MonsterRig.source_pose(prefix,enemy) if articulated else str(enemy.get("pose_key","idle"))
 var requested_key:=prefix+"_"+pose_key
 # Keep legacy texture-only requests separate from anatomical requests. A
 # missing painted source keeps its original fallback and registration rules.
 var cache_key:=requested_key+("|body" if articulated else "|sprite")
 if not _source_records.has(cache_key):
  _source_records[cache_key]=_compile_source_record(requested_key,prefix,boss,articulated,enemy)
 var source:Dictionary=_source_records[cache_key]
 return {"image":source.image,"rect":source.rect,"skull":source.skull,
  "origin":Vector2(float(definition.get("engagement_distance",128.0)),float(definition.get("feet_y_delta",0.0)))+Vector2(enemy.get("visual_offset",Vector2.ZERO)),
  "rotation":float(enemy.get("visual_rotation",0.0)),"key":source.key,
  "front_rows":source.front_rows,"articulated":articulated,"motion":enemy,"registration":source.registration}

static func _compile_source_record(requested_key:String,prefix:String,boss:bool,articulated:bool,enemy:Dictionary)->Dictionary:
 var key:=requested_key
 var path:="res://assets/cultivation/beasts/"+key+".png"
 if not ResourceLoader.exists(path):
  key=prefix+"_idle"
  path="res://assets/cultivation/beasts/"+key+".png"
 if not _images.has(key):_images[key]=load(path).get_image()
 var image:Image=_images[key]
 var supported:=MonsterRig.supports(key)
 var metadata:=MonsterRig.landmarks(key) if supported else Beast.landmarks(key)
 var display_size:=174.0 if boss else 112.0
 var scale_value:=display_size/256.0*(MonsterRig.pose_scale(key) if supported else Beast.pose_scale(key))
 var anchor:Array=metadata.get("ground_anchor",[128,232])
 var rect:=Rect2(-Vector2(float(anchor[0]),float(anchor[1]))*scale_value,Vector2(image.get_size())*scale_value)
 var skull:Array=metadata.get("head_landmark",[30,90,125,195])
 if not _front_rows.has(key):
  var rows:=PackedInt32Array();rows.resize(image.get_height());rows.fill(-1)
  for y in range(maxi(0,int(skull[1])-2),image.get_height()):
   for x in range(0 if articulated else maxi(0,int(skull[0])-3),image.get_width()-2):
    if image.get_pixel(x,y).a>=0.65 and image.get_pixel(x+1,y).a>=0.65 and image.get_pixel(x+2,y).a>=0.65 and (not articulated or MonsterRig.is_body_point(Vector2(x,y),key,enemy)):
     rows[y]=x;break
  _front_rows[key]=rows
 var source:={"image":image,"rect":rect,"skull":skull,"key":key,"front_rows":_front_rows[key],
  "registration":MonsterRig.registration_offset(key,enemy) if articulated else Vector2.ZERO}
 source.make_read_only()
 return source
static func _opaque(world:Vector2,data:Dictionary)->bool:
 var local:Vector2=(world-Vector2(data.origin)).rotated(-float(data.rotation))
 var source:Vector2=(local-Rect2(data.rect).position)/Rect2(data.rect).size*256.0
 if "_authored_" in str(data.key):
  source-=Vector2(data.registration)
 elif bool(data.get("articulated",false)):
  var desired:=source
  # Invert the same local skin transform that paints the actual source pixels.
  # Core head/body mappings are rigid; joint blends converge within eight steps.
  for iteration in range(8):
   var error:=desired-MonsterRig.transform_point(source,str(data.key),data.motion)
   source+=error*.85
   if error.length_squared()<.04:break
 var uv:=source/256.0
 var image:Image=data.image
 var x:=int(floor(uv.x*image.get_width()));var y:=int(floor(uv.y*image.get_height()))
 # Decorative antlers, wings and detached missiles are not body contacts.
 if (not bool(data.get("articulated",false)) and x<int(data.skull[0])-3) or y<int(data.skull[1])-2:return false
 if bool(data.get("articulated",false)) and not MonsterRig.is_body_point(Vector2(x,y),str(data.key),data.motion):return false
 return x>=0 and x<image.get_width() and y>=0 and y<image.get_height() and image.get_pixel(x,y).a>=0.65
static func _front_at_y(y:float,data:Dictionary)->Dictionary:
 if "_authored_" in str(data.key) and absf(float(data.rotation))<.0001:
  # Painted keyposes have a constant support-foot registration, without
  # elastic deformation. Their filtered source row remains exact and cheap.
  var rect:Rect2=data.rect;var origin:Vector2=data.origin
  var scale:=rect.size.y/256.0;var rows:PackedInt32Array=data.front_rows
  origin+=Vector2(data.registration)*scale
  var row:=int(round((y-origin.y-rect.position.y)/scale))
  if row>=0 and row<rows.size() and int(rows[row])>=0:
   return {"point":Vector2(origin.x+rect.position.x+float(rows[row])*scale,y),"valid":true}
  return {"point":Vector2(origin.x+rect.position.x,y),"valid":false}
 if bool(data.get("articulated",false)):return _deformed_front_at_y(y,data)
 var rect:Rect2=data.rect
 var origin:Vector2=data.origin
 var rows:PackedInt32Array=data.front_rows
 var scale:float=rect.size.y/rows.size()
 var rotation:=float(data.rotation)
 var point:=origin+rect.position+Vector2(float(data.skull[0]),0)*scale
 point.y=y
 for _iteration in range(3):
  var local:Vector2=(point-origin).rotated(-rotation)
  var row:=clampi(int(round((local.y-rect.position.y)/scale)),0,rows.size()-1)
  var source_x:=int(rows[row])
  if source_x<0:
   return {"point":Vector2(origin.x+rect.position.x+float(data.skull[0])*scale,y),"valid":false}
  point=origin+(rect.position+Vector2(source_x,row)*scale).rotated(rotation)
  if absf(point.y-y)<=2.5:return {"point":point,"valid":true}
  point.y=y
 return {"point":point,"valid":false}
static func _deformed_front_at_y(y:float,data:Dictionary)->Dictionary:
 var shape_key:=str(data.key)+(str(data.motion.get("monster_pose",{})) if "_authored_" not in str(data.key) else "")+str(data.rotation)
 var shape:PackedVector2Array
 if _deformed_fronts.has(shape_key):shape=_deformed_fronts[shape_key]
 else:
  shape=PackedVector2Array()
  var rows:PackedInt32Array=data.front_rows
  var rect:Rect2=data.rect
  var scale:=rect.size.y/256.0
  for row in range(rows.size()):
   if int(rows[row])<0:
    shape.append(Vector2(INF,INF));continue
   var source:=Vector2(rows[row],row)
   var local:=source+Vector2(data.registration) if "_authored_" in str(data.key) else MonsterRig.transform_point(source,str(data.key),data.motion)
   shape.append((rect.position+local*scale).rotated(float(data.rotation)))
  if _deformed_fronts.size()>=96:_deformed_fronts.clear()
  _deformed_fronts[shape_key]=shape
 var origin:Vector2=data.origin
 var local_y:=y-origin.y
 var best:=Vector2(INF,y)
 for row in range(1,shape.size()):
  var a:=shape[row-1];var b:=shape[row]
  if not a.is_finite() or not b.is_finite():continue
  if local_y<minf(a.y,b.y)-.3 or local_y>maxf(a.y,b.y)+.3:continue
  var fraction:=clampf((local_y-a.y)/(b.y-a.y),0.0,1.0) if absf(b.y-a.y)>.001 else 0.0
  var x:=lerpf(a.x,b.x,fraction)+origin.x
  if x<best.x:best=Vector2(x,y)
 return {"point":best if best.is_finite() else Vector2(origin.x+Rect2(data.rect).position.x,y),"valid":best.is_finite()}

static func measure(hero:Dictionary,enemy:Dictionary,definition:Dictionary)->Dictionary:
 var data:=_body_data(enemy,definition)
 var best:={"gap":INF,"contact":false,"vertical_valid":false,"point":Vector2.ZERO,"target":Vector2.ZERO,"enemy_pose":data.key}
 for point in strike_segment_points(hero):
  var front:=_front_at_y(point.y,data)
  if not bool(front.valid):continue
  var target:Vector2=front.point
  var gap:float=target.x-point.x
  var contact:=_opaque(point,data) or absf(gap)<=3.0
  if contact or not bool(best.vertical_valid) or absf(gap)<absf(float(best.gap)):
   best={"gap":gap,"contact":contact,"vertical_valid":true,"point":point,"target":target,"enemy_pose":data.key}
  if contact:break
 if not bool(best.vertical_valid):
  var points:=attack_points(hero)
  if not points.is_empty():
   var point:Vector2=points[0]
   var front:=_front_at_y(point.y,data)
   best.point=point;best.target=front.point;best.gap=Vector2(front.point).x-point.x
 return best

static func body_front(enemy:Dictionary,definition:Dictionary,height:float)->Dictionary:
 return _front_at_y(height,_body_data(enemy,definition))
static func clearance_front(enemy:Dictionary,definition:Dictionary,height:float)->Dictionary:
 # Conservative union of the three painted body poses. The collision plane
 # cannot jump when the renderer swaps a windup/attack texture.
 var result:={"point":Vector2(INF,height),"valid":false}
 for key in ["idle","windup","attack"]:
  var sample:=enemy.duplicate();sample.pose_key=key
  var front:=body_front(sample,definition,height)
  if bool(front.valid) and Vector2(front.point).x<Vector2(result.point).x:result=front
 return result
static func hero_front(hero:Dictionary)->Vector2:
 var pose:=Rig.sample_contact_pose(hero)
 return Rig._body(Rig.head_point(Vector2(89,-253)),pose.shift,float(pose.body_angle))*Rig.PIXEL_SCALE

static func hero_body_fronts(hero:Dictionary)->PackedVector2Array:
 var pose:=Rig.sample_contact_pose(hero)
 var points:=PackedVector2Array()
 # The nose is not the top of this chibi head. Actual painted alpha rows
 # above it cover eyes, forehead and solid skull, while the calibrated core
 # mask excludes the long loose hair tips and bun from physical clearance.
 if _hero_head_outline.is_empty():
  var image:Image=load("res://assets/cultivation/sidewalk/head.png").get_image()
  var core:=PackedVector2Array([Vector2(290,190),Vector2(430,235),Vector2(494,335),Vector2(510,451),Vector2(530,509),Vector2(506,534),Vector2(500,565),Vector2(470,605),Vector2(360,630),Vector2(228,538),Vector2(188,408),Vector2(206,286)])
  for y in range(190,631,8):
   for x in range(mini(image.get_width()-1,530),187,-1):
    if Geometry2D.is_point_in_polygon(Vector2(x,y),core) and image.get_pixel(x,y).a>=.65:
     _hero_head_outline.append(Vector2(-150,-489)+Vector2(x,y)/Vector2(image.get_size())*Vector2(267,300))
     break
 for local in _hero_head_outline:points.append(Rig._body(Rig.head_point(local),pose.shift,float(pose.body_angle))*Rig.PIXEL_SCALE)
 # Continue down the reshaped chest and hips; all samples follow the same
 # rigid torso transform used to draw the head and body.
 var anchors:=PackedVector2Array()
 for local in [Rig.head_point(Vector2(89,-253)),Rig.torso_point(Vector2(31,-175)),Rig.torso_point(Vector2(28,-125))]:
  anchors.append(Rig._body(local,pose.shift,float(pose.body_angle))*Rig.PIXEL_SCALE)
 # A continuous solid outline prevents a thin beak/neck from appearing and
 # disappearing between three sparse height probes during a landing.
 for index in range(anchors.size()-1):
  var count:=maxi(1,ceili(absf(anchors[index+1].y-anchors[index].y)/1.5))
  for step in range(count):points.append(anchors[index].lerp(anchors[index+1],float(step)/count))
 points.append(anchors[-1])
 return points
