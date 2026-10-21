extends SceneTree
## Graphical proof: godot --path . --script tests/show_character_walk.gd
## Captures six step phases in base, blue, and jade outfits at 1.6x character scale.
const Walk = preload("res://scripts/character_walk.gd")
class WalkCanvas extends Node2D:
	var rig = Walk.new()
	var textures: Dictionary = {}
	func _ready() -> void:
		for key in ["base","head_crown","head_pin","chest_blue","chest_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
			textures[key] = load("res://assets/cultivation/equipment/" + key + ".png")
		queue_redraw()
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1000, 760), Color("f5f2e9"))
		var font = ThemeDB.fallback_font
		var labels = ["Base with opaque white shorts / walking right", "Blue outfit + boots + crown / walking right", "Jade outfit + cloth shoes + pin / walking left"]
		for row in range(3):
			draw_string(font,Vector2(20,26+row*250),labels[row],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("32443e"))
			for col in range(6):
				var phase := float(col) / 6.0
				var feet := Vector2(84+col*166,230+row*250)
				var motion := {"phase":phase,"blend":1.0,"facing":-1.0 if row==2 else 1.0,"bob":(20.0+2.5*sin(phase*TAU*2.0))*Walk.PIXEL_SCALE,"body_tilt":0.018}
				var visual := {}
				if row == 1:visual = {"chest":"chest_blue","legs":"legs_blue","feet":"feet_boots","head":"head_crown"}
				if row == 2:visual = {"chest":"chest_jade","legs":"legs_jade","feet":"feet_cloth","head":"head_pin"}
				rig.draw_avatar_layers(self,feet,textures,visual,motion,1.6,0.0)
				draw_line(feet+Vector2(-64,0),feet+Vector2(64,0),Color(0.5,0.5,0.5,0.45))
				draw_string(font,feet+Vector2(-48,19),"phase %.2f" % phase,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("4b5954"))

func _initialize() -> void:
	root.size = Vector2i(1000, 760)
	root.add_child(WalkCanvas.new())
	_finish.call_deferred()

func _finish() -> void:
	await process_frame
	root.size = Vector2i(1000,760)
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var screenshot := root.get_texture().get_image()
	if screenshot:
		DirAccess.make_dir_recursive_absolute("res://builds/full-v1")
		var result := screenshot.save_png("res://builds/full-v1/walk-contact.png")
		print("WALK_CONTACT_RENDER: ", result, " res://builds/full-v1/walk-contact.png")
	quit()
