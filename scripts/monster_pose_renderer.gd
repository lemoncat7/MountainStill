extends RefCounted
## Authored creature animation. Each attack has genuine painted anatomical
## keyposes. Skull registration, fixed source canvas and planted foot anchor
## replace broad UV warps. Contact-only joint offsets preserve the intact skull
## and planted supports; they never enter the source/collision geometry.
const ResponseCues=preload("res://scripts/combat_response_cues.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Presentation=preload("res://scripts/beast_presentation.gd")
const METADATA_PATH="res://assets/cultivation/beasts/authored-body-landmarks.json"
static var _metadata:Dictionary={}
static var _textures:Dictionary={}
static var _last_pose:Dictionary={}
# Source-space silhouettes never change during a fight. Compile once per
# painted key; live offset/rotation still belongs to each sampled motion.
static var _body_polygons:Dictionary={}
static var _reaction_grids:Dictionary={}

static func supports(key:String)->bool:
	return key.begins_with("bamboo_pass") or key.begins_with("cloud_slope")

static func landmarks(key:String)->Dictionary:
	if "_authored_" not in key:return Presentation.landmarks(key)
	if _metadata.is_empty():
		var file=FileAccess.open(METADATA_PATH,FileAccess.READ)
		if file:
			var data=JSON.parse_string(file.get_as_text())
			if data is Dictionary:_metadata=data.get("poses",{})
	return _metadata.get(key,{})

static func pose_scale(key:String)->float:
	var data:Dictionary=landmarks(key)
	return float(data.get("reference_head_diameter",1.0))/maxf(1.0,float(data.get("head_diameter",1.0)))

static func _prefix(key:String)->String:
	return ("bamboo_pass" if key.begins_with("bamboo_pass") else "cloud_slope")+("_boss" if "_boss" in key else "")

static func _family(move:String)->String:
	if "moss" in move:
		if move.ends_with("charge"):return "moss_rush"
		if move.ends_with("sweep"):return "moss_pounce"
		if move.ends_with("burst"):return "moss_slam"
	if "crane" in move:
		if move.ends_with("charge"):return "crane_dive"
		if move.ends_with("sweep"):return "crane_sweep"
		if move.ends_with("burst"):return "crane_peck"
	return ""

## Shared by the renderer and pixel-exact melee geometry.
static func source_pose(key:String,motion:Dictionary)->String:
	var neutral:String="authored_land" if key.begins_with("bamboo_pass") else "authored_coil"
	var family:String=str(motion.get("move_family",_family(str(motion.get("combat_move","")))))
	var phase:String=str(motion.get("combat_phase","idle"))
	var t:float=float(motion.get("phase_progress",0.0))
	var anatomy:Dictionary=motion.get("monster_pose",{})
	var stride:float=float(anatomy.get("step_cycle",0.0))
	var index:int=int(motion.get("strike_index",0))
	if phase=="defeated":
		if float(motion.get("defeat_amount",0.0))<.13:return str(_last_pose.get(_prefix(key),neutral))
		return "authored_land" if key.begins_with("bamboo_pass") else "authored_peck"
	# Heavy impacts have a separate grounded painted recoil. Light taps retain
	# the committed attack silhouette. Only a true poise break interrupts it.
	var impact:Dictionary=motion.get("impact_profile",{})
	var kind:String=str(impact.get("kind",""))
	var broken:bool=bool(motion.get("guard_broken",false)) or kind=="guardbreak"
	var reaction:float=float(motion.get("reaction_amount",0.0))
	var strength:float=float(motion.get("reaction_strength",.75))
	var eligible:bool=broken or (kind=="heavy" and phase in ["idle","recovery","stagger"])
	if eligible and reaction>.32 and strength>.80:
		if key.begins_with("bamboo_pass"):return "authored_crouch"
		return "authored_wing_back" if float(motion.get("reaction_age",0.0))<(.14 if broken else .09) else "authored_coil"
	if phase=="stagger":
		if t>.72:return neutral
		phase=str(motion.get("interrupted_phase","windup"));t=float(motion.get("interrupted_progress",0.0))
	if phase not in ["windup","strike","contact","recovery"]:return neutral
	match family:
		"moss_pounce":
			if phase=="windup":return neutral if t<.14 else "authored_crouch"
			if phase=="strike":return "authored_crouch" if t<.06 else ("authored_pounce" if t<.92 else "authored_land")
			if phase=="contact":return "authored_land"
			return "authored_land" if t<.24 else ("authored_pounce" if t<.65 else ("authored_crouch" if t<.84 else neutral))
		"moss_rush":
			if phase=="windup" and t<.28:return neutral if t<.12 else "authored_crouch"
			if phase=="recovery" and t>.91:return neutral
			# The final driving paw plants before impact. Alternation remains in
			# preparation / early travel, and returns for the recovery backstep.
			if phase=="contact" or (phase=="strike" and index==0 and t>=.5):return "authored_charge_a"
			return "authored_charge_a" if stride>=0.0 else "authored_charge_b"
		"moss_slam":
			if phase=="windup":return neutral if t<.14 else ("authored_crouch" if t<.40 else "authored_rear")
			if phase=="strike" and index==0:return "authored_rear" if t<.79 else "authored_land"
			if phase=="recovery" and t>.55:return "authored_crouch" if t<.84 else neutral
			return "authored_land"
		"crane_peck":
			if phase=="windup":return neutral if t<.12 else "authored_coil"
			# Keep the neck coiled until the short committed dart. The combat
			# clock and contact hold are shared with logic and remain unchanged.
			if phase=="strike":return "authored_coil" if t<(.70 if index>0 else .65) else "authored_peck"
			if phase=="contact":return "authored_peck"
			return "authored_peck" if t<.04 else ("authored_coil" if t<.82 else neutral)
		"crane_sweep":
			if phase=="windup":return "authored_coil" if t<.27 else "authored_wing_back"
			if phase=="strike":return "authored_wing_back" if t<.68 else "authored_wing_sweep"
			# Clear the foreground fan promptly so the hero's recoil remains
			# readable after the actual hit at contact start.
			if phase=="contact":return "authored_wing_sweep" if t<.5 else "authored_wing_back"
			return "authored_wing_back" if t<.58 else ("authored_coil" if t<.84 else neutral)
		"crane_dive":
			if phase=="windup":return "authored_coil" if t<.22 else "authored_lift"
			if phase=="strike":return "authored_lift" if t<.16 else "authored_dive"
			if phase=="contact":return "authored_dive"
			# Let the committed diving body finish its landing before the rebound.
			# The same rigid silhouette now spans contact -> recovery; timing,
			# root travel, damage budget and authored contact remain unchanged.
			return "authored_dive" if t<.16 else ("authored_lift" if t<.42 else ("authored_coil" if t<.80 else neutral))
	return neutral

static func registration_offset(key:String,motion:Dictionary)->Vector2:
	var data:Dictionary=landmarks(_prefix(key)+"_"+source_pose(key,motion))
	var value:Array=data.get("registration_offset",[0,0])
	return Vector2(float(value[0]),float(value[1]))

static func transform_point(source:Vector2,key:String,motion:Dictionary)->Vector2:
	# A constant pose-registration offset aligns planted support feet. The
	# original painted anatomy and its proportions remain completely rigid.
	return source+registration_offset(key,motion)

static func is_body_point(source:Vector2,key:String,motion:Dictionary)->bool:
	var full_key:String=_prefix(key)+"_"+source_pose(key,motion)
	var data:Dictionary=landmarks(full_key)
	if data.has("body_polygons"):
		if not _body_polygons.has(full_key):
			var compiled:Array=[]
			for poly in data.body_polygons:
				var points:=PackedVector2Array()
				for point in poly:points.append(Vector2(float(point[0]),float(point[1])))
				compiled.append(points)
			_body_polygons[full_key]=compiled
		for points in _body_polygons[full_key]:
			if Geometry2D.is_point_in_polygon(source,points):return true
		return false
	var head:Array=data.get("head_landmark",[35,100,120,190])
	if source.x<float(head[2])+8.0 and source.y>float(head[1])-2.0 and source.y<float(head[3])+8.0:return true
	if key.begins_with("cloud_slope"):return source.y>float(head[3])+5.0 and source.x>float(head[0])+25.0 and source.x<172.0
	return source.y>float(head[1])+12.0

## Rendering-only receiver articulation. A genuine resolved contact is required:
## upcoming defense previews, attack windup, misses and dodge have no impulse.
## The old root slide is redistributed over joints, leaving supporting paws/toes
## fixed. No value is written to motion, source_pose or the collision transform.
static func contact_reaction(key:String,motion:Dictionary)->Dictionary:
	var profile:Dictionary=motion.get("impact_profile",{})
	var phase:String=str(motion.get("combat_phase","idle"))
	var age:float=float(motion.get("reaction_age",-1.0))
	var resolution:String=str(motion.get("defense_action",profile.get("resolution","")))
	if not supports(key) or phase=="defeated" or not bool(profile.get("active",false)):
		return {}
	if str(profile.get("target","enemy"))!="enemy" or resolution not in ["hit","guard","block"]:
		return {}
	var amount:float=clampf(float(motion.get("reaction_amount",0.0)),0.0,1.0)
	if amount<=0.0:return {}
	var sampled:Dictionary=Impact.reaction(profile,age)
	if float(sampled.amount)<=0.0:return {}
	var kind:String=str(profile.get("kind","light"))
	var committed:bool=phase in ["strike","contact"] and kind!="guardbreak"
	var strength:float=0.32 if committed else 1.0
	var impulse:float=float(sampled.impulse)*strength
	var recoil:float=float(sampled.recoil)*strength
	var follow:float=float(sampled.followthrough)*strength
	var region:String=str(profile.get("contact_region","torso"))
	var protected_head:float=(0.32 if kind=="block" else 1.0)*(1.20 if region=="head" else 0.65 if region=="torso" else 0.22)
	var chest_weight:float=0.82 if region=="head" else 1.15 if region=="torso" else 0.68
	var limb_weight:float=1.65 if region=="leg" else 0.82 if region=="torso" else 0.55
	var crane:bool=key.begins_with("cloud_slope")
	var root_offset:=Vector2.ZERO
	var root_rotation:=0.0
	if resolution=="hit":
		root_offset.x=-float(motion.get("recoil_distance",profile.get("knockback",0.0)))*amount
		root_rotation=-0.035*amount*float(motion.get("reaction_strength",profile.get("reaction_magnitude",0.75)))
	return {
		"head_offset":Vector2(2.6*impulse+5.4*recoil,2.4*impulse-1.0*recoil)*protected_head,
		"head_rotation":(0.025*impulse+0.038*recoil)*(1.12 if crane else 1.0)*protected_head,
		"chest_offset":Vector2(1.6*impulse+3.0*recoil,3.8*impulse+0.9*follow)*chest_weight,
		"limb_offset":Vector2(-1.5*follow,2.7*impulse+1.8*follow)*limb_weight,
		"wing_offset":Vector2(-2.0*follow,4.2*follow),
		"root_offset":root_offset,"root_rotation":root_rotation,"contact_region":region,
		"impulse":impulse,"recoil":recoil,"followthrough":follow,
	}


## Pure point function for QA and the draw mesh. The skull is one rigid region;
## only the neck/shoulder blend into the yielding chest. Grounded extremities
## are unchanged, and there is no whole-image scaling or periodic displacement.
static func reaction_point(source:Vector2,data:Dictionary,reaction:Dictionary,crane:bool)->Vector2:
	if reaction.is_empty():return source
	var head:Array=data.get("head_landmark",[32,110,105,195])
	var lo:=Vector2(float(head[0]),float(head[1]))-Vector2(5,5)
	var hi:=Vector2(float(head[2]),float(head[3]))+Vector2(5,5)
	var center:Vector2=(lo+hi)*0.5
	var outside:=Vector2(maxf(maxf(lo.x-source.x,source.x-hi.x),0.0),maxf(maxf(lo.y-source.y,source.y-hi.y),0.0))
	var head_weight:float=1.0-smoothstep(0.0,21.0,outside.length())
	head_weight*=1.0-smoothstep(maxf(hi.y,216.0),230.0,source.y)
	var planted:float=1.0-smoothstep(208.0,230.0,source.y)
	var body:Vector2=Vector2(reaction.chest_offset)*planted
	var lower:float=smoothstep(hi.y-8.0,224.0,source.y)*planted
	var fore_x:float=hi.x+24.0 if not crane else 144.0
	var fore:float=1.0-smoothstep(8.0,51.0,absf(source.x-fore_x))
	body+=Vector2(reaction.limb_offset)*lower*fore
	if crane:
		var wing:float=smoothstep(hi.x-1.0,hi.x+33.0,source.x)*(1.0-smoothstep(center.y+18.0,219.0,source.y))
		body+=Vector2(reaction.wing_offset)*wing
	var skull:Vector2=(source-center).rotated(float(reaction.head_rotation))+center+Vector2(reaction.head_offset)
	# Every measured skull corner is fully rigid. The interpolation occurs
	# outside that rectangle, in the short neck/shoulder connection only.
	return (source+body).lerp(skull,head_weight)


static func _reaction_grid(source_key:String,texture:Texture2D,data:Dictionary)->Dictionary:
	if _reaction_grids.has(source_key):return _reaction_grids[source_key]
	var size:Vector2=texture.get_size()
	var xs:Array[float]=[]
	var ys:Array[float]=[]
	for x in range(0,int(size.x)+1,16):xs.append(minf(float(x),size.x))
	for y in range(0,int(size.y)+1,16):ys.append(minf(float(y),size.y))
	if xs[-1]!=size.x:xs.append(size.x)
	if ys[-1]!=size.y:ys.append(size.y)
	var head:Array=data.get("head_landmark",[32,110,105,195])
	# Explicit joint boundaries keep every triangle inside the skull rigid.
	for x in [float(head[0])-5.0,float(head[2])+5.0]:
		if x>0.0 and x<size.x and not x in xs:xs.append(x)
	for y in [float(head[1])-5.0,float(head[3])+5.0,230.0]:
		if y>0.0 and y<size.y and not y in ys:ys.append(y)
	xs.sort();ys.sort()
	var points:=PackedVector2Array()
	var uvs:=PackedVector2Array()
	var indices:=PackedInt32Array()
	for y in ys:
		for x in xs:
			points.append(Vector2(x,y));uvs.append(Vector2(x/size.x,y/size.y))
	for row in range(ys.size()-1):
		for col in range(xs.size()-1):
			var i:int=row*xs.size()+col
			indices.append_array(PackedInt32Array([i,i+1,i+xs.size(),i+1,i+xs.size()+1,i+xs.size()]))
	var grid:Dictionary={"points":points,"uvs":uvs,"indices":indices}
	_reaction_grids[source_key]=grid
	return grid


static func _draw_contact_mesh(canvas:CanvasItem,texture:Texture2D,source_key:String,data:Dictionary,
		origin:Vector2,scale_value:float,reaction:Dictionary,color:Color)->void:
	var grid:Dictionary=_reaction_grid(source_key,texture,data)
	var vertices:=PackedVector2Array()
	vertices.resize(grid.points.size())
	for i in range(vertices.size()):
		vertices[i]=origin+reaction_point(grid.points[i],data,reaction,source_key.begins_with("cloud_slope"))*scale_value
	# Submit copied vertex arrays, not a temporary ArrayMesh whose resource
	# lifetime could end before the canvas command is rendered. One command
	# also avoids hundreds of per-triangle draw calls during a contact.
	RenderingServer.canvas_item_add_triangle_array(canvas.get_canvas_item(),grid.indices,vertices,
		PackedColorArray([color]),grid.uvs,PackedInt32Array(),PackedFloat32Array(),texture.get_rid())


static func draw(canvas:CanvasItem,textures:Dictionary,key:String,feet:Vector2,display_size:float,motion:Dictionary,color:Color=Color.WHITE)->bool:
	if not supports(key):return false
	var prefix:String=_prefix(key)
	var pose:String=source_pose(key,motion)
	var source_key:String=prefix+"_"+pose
	var texture:Texture2D=textures.get(source_key,_textures.get(source_key))
	if texture==null:
		var path:String="res://assets/cultivation/beasts/"+source_key+".png"
		if ResourceLoader.exists(path):texture=load(path)
		if texture==null:
			var im:=Image.load_from_file(path)
			if im and not im.is_empty():texture=ImageTexture.create_from_image(im)
		if texture:_textures[source_key]=texture
	if texture==null:return false
	var phase:String=str(motion.get("combat_phase","idle"))
	if phase!="defeated" and (motion.has("action_id") or phase in ["windup","strike","contact","recovery","stagger"]):_last_pose[prefix]=pose
	var data:Dictionary=landmarks(source_key)
	var anchor:Array=data.get("ground_anchor",[128,232])
	var scale_value:float=display_size/256.0*pose_scale(source_key)
	var origin:Vector2=(-Vector2(float(anchor[0]),float(anchor[1]))+registration_offset(key,motion))*scale_value
	var offset:Vector2=motion.get("visual_offset",Vector2.ZERO)
	var rotation:float=float(motion.get("visual_rotation",0.0))
	if phase=="defeated":
		var settle:float=smoothstep(.1,.7,float(motion.get("defeat_amount",0.0)))
		offset=offset.lerp(Vector2(0,3),settle)
		rotation=lerpf(rotation,0.0,settle)
	var receiver:Dictionary=contact_reaction(key,motion)
	if not receiver.is_empty():
		offset+=Vector2(receiver.root_offset);rotation+=float(receiver.root_rotation)
	var deflected:=ResponseCues.deflection_transform(motion)
	offset+=Vector2(deflected.offset);rotation+=float(deflected.rotation)
	canvas.draw_set_transform(feet+offset,rotation,Vector2.ONE)
	if receiver.is_empty():
		canvas.draw_texture_rect(texture,Rect2(origin,texture.get_size()*scale_value),false,color)
	else:
		_draw_contact_mesh(canvas,texture,source_key,data,origin,scale_value,receiver,color)
	canvas.draw_set_transform(Vector2.ZERO,0.0,Vector2.ONE)
	return true
