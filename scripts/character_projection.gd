extends Node2D
## Off-screen world actor for the portal's actual equipped-pixel dissolve.
## Uses the same modular render path as the scene, never a preset outfit.
var host:Control
const FEET=Vector2(96,158)
func _draw():
	if is_instance_valid(host):host._draw_avatar(FEET,false,self)
func _scene_set_transform(origin:Vector2,rotation:float=0.0,scale_value:Vector2=Vector2.ONE):
	draw_set_transform(origin,rotation,scale_value)
