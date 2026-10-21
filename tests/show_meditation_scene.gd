extends SceneTree
var scene
func _initialize():call_deferred("run")
func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://motion_scene_%d.json"%OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.demo=true;scene.state.new_game();scene._prepare_campaign_demo();scene.state.activity="meditate";scene.state.auto_advance=false
	scene.toast_time=0;scene.get_window().size=Vector2i(1200,320)
	scene.character_x=520;scene.character_y=230
	await create_timer(2.1).timeout
	await RenderingServer.frame_post_draw
	save_frame("res://builds/motion-v2/MountainStill-Motion-v2-Meditation.png")
	scene._toggle_drawer("practice")
	await create_timer(.8).timeout
	await RenderingServer.frame_post_draw
	save_frame("res://builds/motion-v2/MountainStill-Motion-v2-Journal.png")
	scene.get_window().size=Vector2i(1000,320);scene.size=Vector2(1000,320)
	await create_timer(.9).timeout;await RenderingServer.frame_post_draw
	save_frame("res://builds/motion-v2/MountainStill-Motion-v2-Narrow.png")
	scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
	scene._toggle_drawer("wardrobe")
	await create_timer(.9).timeout;await RenderingServer.frame_post_draw
	save_frame("res://builds/motion-v2/MountainStill-Motion-v2-Wardrobe.png")
	print("MOTION_FULL_SCENE_RENDERED")
	scene.queue_free();scene=null;await process_frame;await process_frame
	quit()

func save_frame(path:String):
	var frame:Image=root.get_texture().get_image()
	frame.save_png(path)
	frame=null
