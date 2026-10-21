extends SceneTree
## Native anatomical-view fixture. Hand and actual weapon have separate transforms.
## -- --capture-root=/path writes holding-hands.png.
const Hand := preload("res://scripts/weapon_grip_hand.gd")
class Proof extends Node2D:
	var sword:=preload("res://assets/cultivation/avatars/sword.png")
	var fan:=preload("res://assets/cultivation/avatars/fan.png")
	func _draw()->void:
		draw_rect(Rect2(0,0,1200,1040),Color("e7e2d5"))
		draw_string(ThemeDB.fallback_font,Vector2(22,30),"ANATOMICAL HAND VIEWS | wrist -Y, knuckles +Y | actual hilt between the appropriate skin layers",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("344c46"))
		var views:=[['Near / dorsal','dorsal',1.0],['Far / palm','palm',-1.0],['Near / edge','edge',1.0]]
		for row in range(3):
			var style:="sword" if row==0 else "fan"
			var openness:=0.0 if row==2 else 1.0
			for column in range(3):
				var item:Array=views[column]
				var cell:=Vector2(column*400,50+row*320)
				draw_string(ThemeDB.fallback_font,cell+Vector2(20,24),("Sword" if row==0 else ("Open fan" if row==1 else "Closed fan"))+" | "+item[0],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("344c46"))
				_draw_hand_case(cell+Vector2(180,145),24.0,style,openness,item[1],item[2],0.0,PI,true)
				# At 5x the independent shaft rotates while hand anatomy is fixed.
				_draw_hand_case(cell+Vector2(310,172),5.0,style,openness,item[1],item[2],-PI/2.0,PI/2.0+0.22,true)
				_draw_hand_case(cell+Vector2(340,250),1.0,style,openness,item[1],item[2],-0.32,2.82,true)
				draw_string(ThemeDB.fallback_font,cell+Vector2(26,290),"24x view detail / 5x side pose / 1x low catch",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("52665a"))
	func _draw_hand_case(center:Vector2,scale_value:float,style:String,openness:float,view:String,handedness:float,hand_angle:float,weapon_angle:float,crop:bool)->void:
		draw_set_transform(center,hand_angle,Vector2.ONE*scale_value)
		# Anatomical wrist continuation, intentionally not attached to the blade.
		draw_colored_polygon(PackedVector2Array([Vector2(-1.43,-4.1),Vector2(1.43,-4.1),Vector2(1.43,-1.5),Vector2(-1.43,-1.5)]),Color("f6c49d"))
		Hand.draw_back(self,style,openness,Color.WHITE,view,handedness)
		var socket:=Hand.grip_socket(style,view,handedness)
		draw_set_transform(center+socket.rotated(hand_angle)*scale_value,weapon_angle,Vector2.ONE*scale_value)
		if crop:_weapon_crop(style,openness)
		draw_set_transform(center,hand_angle,Vector2.ONE*scale_value)
		Hand.draw_front(self,style,openness,Color.WHITE,view,handedness)
		draw_set_transform(Vector2.ZERO)
	func _weapon_crop(style:String,openness:float)->void:
		var texture:Texture2D=sword if style=="sword" else fan
		var rect:=Rect2(-7.8,-53.7,26,76)
		if style=="fan":
			var fold:=lerpf(0.17,1.0,openness)
			rect=Rect2(-23.3*fold,-25.6,48*fold,40)
		var crop:=Rect2(-3.2,-5.1,6.4,10.0)
		var source:=Rect2((crop.position-rect.position)/rect.size*Vector2(texture.get_size()),crop.size/rect.size*Vector2(texture.get_size()))
		draw_texture_rect_region(texture,crop,source)

func _initialize()->void:
	root.size=Vector2i(1200,1040)
	root.mode=Window.MODE_WINDOWED
	root.add_child(Proof.new())
	_finish.call_deferred()

func _finish()->void:
	await process_frame
	root.size=Vector2i(1200,1040)
	await process_frame
	await create_timer(0.20).timeout
	await RenderingServer.frame_post_draw
	var capture:=root.get_texture().get_image()
	var destination:="/tmp/holding-hands"
	for argument in OS.get_cmdline_user_args():
		if argument.begins_with("--capture-root="):destination=argument.trim_prefix("--capture-root=")
	DirAccess.make_dir_recursive_absolute(destination)
	print("HOLDING_HAND_CAPTURE ",capture.save_png(destination+"/holding-hands.png")," ",destination)
	quit()
