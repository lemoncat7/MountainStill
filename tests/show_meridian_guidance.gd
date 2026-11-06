extends SceneTree
## Explicit synthetic UI fixture, not an earned campaign/native-platform proof.
var scene
var output:String="/tmp/meridian-guidance-ui"
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
	scene.state.save_path="user://meridian_guidance_visual_fixture.json"
	root.add_child(scene);await process_frame
	scene.set_process(false);scene.state.new_game();scene.state.auto_advance=false
	scene.demo=true;scene.get_window().min_size=Vector2i(0,0)
	scene.get_window().size=Vector2i(width,height);scene.size=Vector2(width,height)
	scene.get_window().transparent_bg=false
	RenderingServer.set_default_clear_color(Color("e8e7df"))
	var label=Label.new();label.text="经脉导航 · 合成测试状态 / 仅供界面验收";label.position=Vector2(18,8);label.add_theme_font_size_override("font_size",10);label.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(label)
	scene.wardrobe_tab="meridian";scene._toggle_drawer("wardrobe")
	press("meridian_branch_edge");press("meridian_row_jianjing")
	if interactive:
		await capture("interactive-start")
		print("MERIDIAN_GUIDANCE_INTERACTIVE synthetic=true window=",scene.get_window().size," scene=",scene.size)
		return
	await capture("01-locked-diamond")
	press("meridian_prerequisite");await capture("02-first-parent")
	press("meridian_prerequisite");press("meridian_prerequisite");await capture("03-root-shortfall")
	press("meridian_return");press("meridian_return");press("meridian_return");await capture("04-original-node")
	press("meridian_branch_central");press("meridian_row_qihai")
	scene.state.qi=28.5;scene.state.herbs=1;scene.state.dew=0;scene._refresh_drawer();await capture("05-exact-shortfall")
	scene.queue_free();await process_frame;await process_frame
	print("MERIDIAN_GUIDANCE_VISUAL_FIXTURE ",output," width=",width," synthetic=true")
	quit()
