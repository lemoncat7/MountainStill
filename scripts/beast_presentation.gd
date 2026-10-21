extends RefCounted
## Measured anatomy landmarks, rather than a 256px sheet or trailing effects,
## define scale. A crouch can lower the head without miniaturizing its skull.
const METADATA_PATH := "res://assets/cultivation/beasts/body-landmarks.json"
static var metadata:Dictionary={}

static func landmarks(key:String)->Dictionary:
	if metadata.is_empty():
		var file:=FileAccess.open(METADATA_PATH,FileAccess.READ)
		if file:
			var value=JSON.parse_string(file.get_as_text())
			if value is Dictionary:metadata=value.get("poses",{})
	return metadata.get(key,{})

static func pose_scale(key:String)->float:
	var data:=landmarks(key)
	return float(data.get("reference_head_diameter",1.0))/maxf(1.0,float(data.get("head_diameter",1.0)))

static func draw_rect(key:String,canvas_size:Vector2,display_size:float)->Rect2:
	var data:=landmarks(key)
	var anchor:Array=data.get("ground_anchor",[128,232])
	var scale_value:=display_size/256.0*pose_scale(key)
	return Rect2(-Vector2(float(anchor[0]),float(anchor[1]))*scale_value,canvas_size*scale_value)

static func visible_bounds(key:String,display_size:float)->Rect2:
	var data:=landmarks(key)
	var alpha:Array=data.get("alpha_bbox",[0,0,256,256])
	var rect:=draw_rect(key,Vector2(256,256),display_size)
	return Rect2(rect.position+Vector2(float(alpha[0]),float(alpha[1]))*rect.size.x/256.0,Vector2(float(alpha[2])-float(alpha[0]),float(alpha[3])-float(alpha[1]))*rect.size.x/256.0)
