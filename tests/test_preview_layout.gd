extends SceneTree
## Independent portrait bounds; the scene is never moved or scaled for a page.
var checks=0
var failures=0
var scene
func check(ok:bool,label:String):
	checks+=1
	if not ok: failures+=1;printerr("FAIL: "+label)
func _initialize():call_deferred("run")
func run():
	scene=load("res://main.tscn").instantiate()
	scene.demo=true
	scene.state.save_path="user://preview_layout_%d.json"%OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.set_process(false)
	scene.demo=true
	scene.state.new_game()
	scene.state.auto_advance=false
	for width in [1000,1200,1360]:
		scene.get_window().size=Vector2i(width,320)
		scene.size=Vector2(width,320)
		for page in ["wardrobe","alchemy","practice"]:
			if scene.drawer_name==page:scene._close_drawer()
			scene._toggle_drawer(page)
			var left:float=scene._drawer_rect().position.x
			var scale:float=scene._preview_stage_scale()
			var x:float=scene._preview_stage_x()*width/1040.0
			check(scene._preview_stage_active(),"Preview enabled "+page)
			check(x-62*scale>=0,"Base and full equipment layers inside left edge")
			check(x+62*scale<left-12,"All gear layers stay clear of paper")
			check(scene.character_preview.clip_contents,"Local spell effects are clipped to the dedicated portrait")
			check(scale>=1.6 and scale<=1.82,"Preview retains safe scale at %d"%width)
			scene.wardrobe_tab="technique"
			if page=="wardrobe":
				scene._start_practice()
				check(scene.drawer_name=="wardrobe" and scene.character_preview.cast_time>0 and scene.practice_time==0,"Try technique keeps page and left preview visible")
			scene._close_drawer()
			check(not scene._preview_stage_active() and scene._preview_stage_scale()==1.0,"Closing leaves normal scene scale")
	scene.strip=false
	scene.paused=true
	scene._capture_window_settings()
	check(scene.state.settings.window_mode=="window","Host serializes canonical ordinary-window mode")
	check(scene.state.save_game(),"Host window settings save atomically")
	var restored=scene.State.new()
	restored.save_path=scene.state.save_path
	restored.load_game()
	check(restored.settings.window_mode=="window","Ordinary-window mode survives host save and state reload")
	check(restored.settings.paused,"Paused setting survives host save and state reload")
	scene.queue_free()
	await process_frame
	for suffix in ["",".bak",".tmp"]:
		var path="user://preview_layout_%d.json"%OS.get_process_id()+suffix
		if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
	print("Preview layout: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
