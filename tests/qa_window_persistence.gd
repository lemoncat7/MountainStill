extends SceneTree
## Native-only geometry persistence regression. Isolated user data required.
var scene
var failures=0
var baseline:Vector2i
func _initialize():call_deferred("run")
func frames(n:int):
	for i in range(n):await process_frame
func record(label:String):
	scene._capture_window_settings()
	var stored=Vector2i(scene.state.settings.normal_width,scene.state.settings.normal_height)
	print("PERSIST_QA ",label," native=",root.size," normal=",scene.desktop._normal_size," strip=",scene.desktop._strip_size," stored=",stored," mode=",root.mode)
	if stored!=baseline:failures+=1;printerr("PERSIST_FAIL normal rectangle changed ",label)
func run():
	scene=load("res://main.tscn").instantiate();scene.state.save_path="user://geometry-native-proof.json";root.add_child(scene)
	await frames(10)
	scene._resize_preset(Vector2i(1234,650))
	await frames(20)
	baseline=root.size
	record("baseline")
	for i in range(4):
		scene._toggle_window()
		record("toggle%d immediate"%i)
		await frames(1);record("toggle%d frame1"%i)
		await frames(4);record("toggle%d frame5"%i)
		await frames(15);record("toggle%d frame20"%i)
	scene._save_current()
	scene.queue_free();await frames(3)
	scene=load("res://main.tscn").instantiate();scene.state.save_path="user://geometry-native-proof.json";root.add_child(scene)
	await frames(20);record("reloaded")
	print("PERSIST_QA complete failures=",failures)
