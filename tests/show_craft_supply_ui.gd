extends SceneTree
## Explicit synthetic UI fixture, not an earned campaign/native-platform proof.
var scene
var output:String="/tmp/craft-supply-ui"
var width:int=960
var height:int=320
var interactive:bool=false
func _initialize():call_deferred("run")
func _process(_delta:float)->bool:
	if is_instance_valid(scene):
		scene._sync_drawer_visuals();scene.queue_redraw()
	return false
func capture(label:String):
	if scene.drawer_tween:scene.drawer_tween.kill()
	if scene.content_tween:scene.content_tween.kill()
	scene.content_offset=0.0;scene.paper_width=scene._drawer_rect().size.x
	scene.drawer_alpha=1.0;scene.content_alpha=1.0;scene.paper_reveal=1.0
	scene.queue_redraw()
	await create_timer(0.4).timeout
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png(output.path_join(label+".png"))
func press(id:String):
	var b=scene.buttons.get(id)
	if not is_instance_valid(b) or b.disabled:push_error("Unavailable fixture control "+id);quit(1);return
	b.pressed.emit()
func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--width="):width=int(arg.trim_prefix("--width="))
		if arg.begins_with("--height="):height=int(arg.trim_prefix("--height="))
		if arg=="--interactive":interactive=true
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://craft_supply_visual_fixture.json"
	root.add_child(scene);await process_frame
	scene.set_process(false);scene.state.new_game();scene.state.auto_advance=false
	scene.demo=true;scene.get_window().min_size=Vector2i(0,0)
	scene.get_window().size=Vector2i(width,height);scene.size=Vector2(width,height)
	scene.get_window().transparent_bg=false
	RenderingServer.set_default_clear_color(Color("e8e7df"))
	scene.wardrobe_tab="bag";scene.set_meta("bag_view","craft");scene._toggle_drawer("wardrobe")
	scene.InkPages.inspect_craft(scene,"weave_moon_robe")
	if interactive:
		press("craft_supply_open")
		await capture("interactive-start")
		print("CRAFT_SUPPLY_INTERACTIVE synthetic=true window=",scene.get_window().size," scene=",scene.size," recipe=",scene.get_meta("craft_recipe"))
		return
	await capture("01-recipe")
	press("craft_supply_open");await capture("02-shortfalls")
	press("craft_supply_moon_thread");await capture("03-locked-source")
	press("craft_supply_return");press("craft_supply_refinement_stone");await capture("04-synthesis")
	press("craft_supply_return");await capture("05-returned-recipe")
	press("craft_supply_close");scene.InkPages.inspect_craft(scene,"refine_route")
	scene.set_meta("craft_material_refine_route","spirit_jade");scene._refresh_drawer()
	press("craft_supply_open");await capture("06-rare-source")
	scene.queue_free();await process_frame;await process_frame
	print("CRAFT_SUPPLY_VISUAL_FIXTURE ",output," width=",width," synthetic=true")
	quit()
