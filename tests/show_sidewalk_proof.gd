extends SceneTree
## Graphical: godot --path . --script tests/show_sidewalk_proof.gd
## Set SIDEWALK_LIVE=1 to keep the walking preview open.
const Walk = preload("res://scripts/character_sidewalk.gd")
class ProofCanvas extends Node2D:
	var rig = Walk.new()
	func _ready()->void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	var clock := 0.0
	func _process(delta:float)->void:
		clock += delta
		queue_redraw()
	func _draw()->void:
		draw_rect(Rect2(0,0,1140,760),Color("f1ecdf"))
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(25,30),"GENUINE SIDE-PROFILE WALK | original cutout art | planted feet, fixed bones",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("294c49"))
		for row in range(3):
			var visual:Dictionary={}
			var title:="Shirtless / opaque white shorts / bare feet"
			if row==1:
				visual={"head":"head_crown","chest":"chest_blue","legs":"legs_jade","feet":"feet_boots"}
				title="Independent slots: crown + blue tunic + jade trousers + boots"
			if row==2:
				visual={"head":"head_pin","chest":"chest_jade","legs":"legs_blue","feet":"feet_cloth"}
				title="Independent slots: pin + jade chest + blue trousers + cloth shoes (left)"
			draw_string(font,Vector2(25,66+row*220),title,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("294c49"))
			for i in range(8):
				var p:=float(i)/8.0
				var feet:=Vector2(73+i*138,238+row*220)
				var motion:={"phase":p,"blend":1.0,"facing":-1.0 if row==2 else 1.0}
				draw_line(feet+Vector2(-68,0),feet+Vector2(68,0),Color("b5b3a3"))
				rig.draw_avatar_layers(self,feet,{},visual,motion,1.25)
				draw_string(font,feet+Vector2(-25,20),"%.3f"%p,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("526660"))
		draw_string(font,Vector2(25,736),"Eight distance-spaced poses. Independent equipment slots remain visible at every phase.",HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("294c49"))
func _initialize()->void:
	root.size=Vector2i(1140,760)
	root.add_child(ProofCanvas.new())
	_finish.call_deferred()
func _finish()->void:
	await process_frame
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var shot:=root.get_texture().get_image()
	if shot:
		DirAccess.make_dir_recursive_absolute("res://builds/full-v1")
		print("SIDEWALK_PROOF: ",shot.save_png("res://builds/full-v1/sidewalk-proof.png"))
	if OS.get_environment("SIDEWALK_LIVE")!="1":quit()
