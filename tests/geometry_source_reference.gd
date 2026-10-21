extends RefCounted
## Frozen pre-cache source-data calculation for exact differential QA.
const Beast=preload("res://scripts/beast_presentation.gd")
const MonsterRig=preload("res://scripts/monster_pose_renderer.gd")
static var _images:Dictionary={}
static var _front_rows:Dictionary={}
static func _body_data(enemy:Dictionary,definition:Dictionary)->Dictionary:
 var route:=str(definition.get("route_id","bamboo_pass"))
 var prefix:=route+("_boss" if bool(definition.get("boss",false)) else "")
 var articulated:=MonsterRig.supports(prefix) and enemy.has("monster_pose")
 var pose_key:=MonsterRig.source_pose(prefix,enemy) if articulated else str(enemy.get("pose_key","idle"))
 var key:=prefix+"_"+pose_key
 var path:="res://assets/cultivation/beasts/"+key+".png"
 if not ResourceLoader.exists(path):
  key=route+("_boss" if bool(definition.get("boss",false)) else "")+"_idle"
  path="res://assets/cultivation/beasts/"+key+".png"
 if not _images.has(key):_images[key]=load(path).get_image()
 var image:Image=_images[key]
 var metadata:=MonsterRig.landmarks(key) if MonsterRig.supports(key) else Beast.landmarks(key)
 var display_size:=174.0 if bool(definition.get("boss",false)) else 112.0
 var scale_value:=display_size/256.0*(MonsterRig.pose_scale(key) if MonsterRig.supports(key) else Beast.pose_scale(key))
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
 return {"image":image,"rect":rect,"skull":skull,"origin":Vector2(float(definition.get("engagement_distance",128.0)),float(definition.get("feet_y_delta",0.0)))+Vector2(enemy.get("visual_offset",Vector2.ZERO)),"rotation":float(enemy.get("visual_rotation",0.0)),"key":key,"front_rows":_front_rows[key],"articulated":articulated,"motion":enemy,"registration":MonsterRig.registration_offset(key,enemy) if articulated else Vector2.ZERO}
