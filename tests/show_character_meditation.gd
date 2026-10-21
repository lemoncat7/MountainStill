extends SceneTree
const Meditation = preload("res://scripts/character_meditation.gd")
class MeditationCanvas extends Node2D:
	var rig = Meditation.new()
	var outfits_mode := false
	var textures: Dictionary = {}
	func _ready() -> void:
		for key in ["base","head_crown","head_pin","chest_blue","chest_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
			textures[key] = load("res://assets/cultivation/equipment/"+key+".png")
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0,0,1320,1020),Color("e9e4d6"))
		var font = ThemeDB.fallback_font
		if outfits_mode:
			_draw_outfit_matrix(font)
			return
		var outfits = [{},{"chest":"chest_blue","legs":"legs_blue","feet":"feet_boots","head":"head_crown"},{"chest":"chest_jade","legs":"legs_jade","feet":"feet_cloth","head":"head_pin"}]
		for row in range(3):
			draw_string(font,Vector2(24,30+row*330),["Bare base / opaque shorts","Blue tunic + blue trousers + boots + crown","Jade cape + jade trousers + cloth shoes + pin"][row],HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("415047"))
			for col in range(5):
				var amount := float(col)/4.0
				var feet := Vector2(132+col*264,296+row*330)
				draw_line(feet+Vector2(-100,0),feet+Vector2(100,0),Color("b9bba7"),1)
				rig.draw_avatar_layers(self,feet,textures,outfits[row],amount,0.0,2.0)
				draw_string(font,feet+Vector2(-65,24),"seated %.2f" % amount,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("415047"))

	func _draw_outfit_matrix(font: Font) -> void:
		var chests := ["", "chest_blue", "chest_jade"]
		var trousers := ["", "legs_blue", "legs_jade"]
		var shoes := ["", "feet_cloth", "feet_boots"]
		for row in range(3):
			draw_string(font, Vector2(18,28+row*330), ["Barefoot", "Cloth shoes", "Tall boots"][row] + " / all 9 chest and trouser combinations", HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("415047"))
			for col in range(9):
				var visual := {"chest":chests[col/3],"legs":trousers[col%3],"feet":shoes[row],"head":"head_pin" if col%2==0 else "head_crown"}
				var feet := Vector2(73+col*146,296+row*330)
				draw_line(feet+Vector2(-60,0),feet+Vector2(60,0),Color("b9bba7"),1)
				rig.draw_avatar_layers(self,feet,textures,visual,1.0,float(col)*0.7,1.7)
				draw_string(font,feet+Vector2(-54,24),"chest %d / legs %d" % [col/3,col%3],HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("415047"))

func _initialize() -> void:
	root.size = Vector2i(1320,1020)
	var canvas := MeditationCanvas.new()
	canvas.outfits_mode = "--outfits" in OS.get_cmdline_user_args()
	root.add_child(canvas)
	_finish.call_deferred()
func _finish() -> void:
	await process_frame
	root.size = Vector2i(1320,1020)
	await process_frame
	await create_timer(0.3).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot:
		DirAccess.make_dir_recursive_absolute("res://builds/meditation-qa")
		var filename := "meditation-outfits.png" if "--outfits" in OS.get_cmdline_user_args() else "meditation-contact.png"
		var result := screenshot.save_png("res://builds/meditation-qa/"+filename)
		print("MEDITATION_CONTACT_RENDER: ",result," res://builds/meditation-qa/"+filename)
	quit()
