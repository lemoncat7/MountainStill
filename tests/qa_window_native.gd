extends SceneTree
## Real GPU/window diagnostics. Run only on a supported native desktop with
## isolated XDG directories. Saves renderer output, not fabricated screenshots.
var scene
func _initialize():call_deferred("run")
func snap(label:String):
	await create_timer(2.0).timeout
	await RenderingServer.frame_post_draw
	print("WINDOW_QA ",label," native=",root.size," mode=",root.mode," visible=",root.visible," logical=",scene.size," factor=",root.content_scale_factor," transparent=",root.transparent," background=",root.transparent_bg," borderless=",root.borderless," strip=",scene.strip," scene_visible=",scene.visible)
	var image=root.get_texture().get_image()
	print("WINDOW_QA image=",image.get_size()," used=",image.get_used_rect())
	image.save_png("user://window-"+label+".png")
func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://native-window-qa.json"
	root.add_child(scene)
	await snap("normal")
	print("WINDOW_QA before toggle")
	scene._toggle_window()
	print("WINDOW_QA after toggle native=",root.size," logical=",scene.size," factor=",root.content_scale_factor)
	await snap("strip")
	print("WINDOW_QA before restore")
	scene._safe_restore()
	print("WINDOW_QA after restore")
	await snap("restore")
	print("WINDOW_QA before toggle")
	scene._toggle_window()
	print("WINDOW_QA after toggle native=",root.size," logical=",scene.size," factor=",root.content_scale_factor)
	await snap("strip-opaque")
	print("WINDOW_QA before restore")
	scene._safe_restore()
	print("WINDOW_QA after restore")
	print("WINDOW_QA done; remains open for inspection")
