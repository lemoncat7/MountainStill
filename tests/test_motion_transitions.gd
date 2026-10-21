extends SceneTree
var scene
var checks=0
var failures=0
var save_path="user://motion_transitions_%d.json"%OS.get_process_id()
func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)
func press(key:String):
	var button=scene.buttons.get(key)
	check(is_instance_valid(button) and button is BaseButton,"Button exists: "+key)
	if is_instance_valid(button) and not button.disabled:button.pressed.emit()
func advance(seconds:float):
	for i in range(ceili(seconds*60.0)):scene._process(1.0/60.0)
func _initialize():call_deferred("run")
func run():
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame;scene.set_process(false);scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene.character_x=520;scene.character_y=230
	advance(.2);check(scene.meditation_amount==0,"Arrival has a quiet settling interval")
	advance(.45);check(scene.meditation_amount>0 and scene.meditation_amount<1,"Entering is a genuine intermediate pose")
	advance(1);check(scene.meditation_phase=="seated" and scene.meditation_amount==1,"Enter reaches full folded pose")
	var qi:float=scene.state.qi
	advance(3);check(scene.state.qi>qi,"Meditation remains tied to actual qi progression")
	var clock_before:float=scene.meditation_clock
	scene.paused=true;advance(2)
	check(scene.meditation_clock==clock_before and scene.meditation_amount==1,"Pause freezes breath and seated pose")
	scene.paused=false;scene.state.set_activity("gather")
	var x_before:float=scene.character_x
	advance(.2);check(scene.meditation_phase=="leaving" and scene.meditation_amount>0,"Changing activity begins standing transition")
	check(scene.character_x==x_before,"No seated skating toward the herb garden")
	advance(.6);check(scene.meditation_amount==0 and scene.character_x<x_before,"Walking begins after standing")
	scene.state.set_activity("meditate");scene.character_x=520;advance(1.5)
	for page in ["wardrobe","practice","alchemy"]:
		scene._toggle_drawer(page);advance(.8)
		check(scene.preview_blend==1,"Portrait reveal completes: "+page)
		check(scene.character_x==520,"Portrait reveal does not pretend to be walking")
		check(scene.meditation_amount==1,"Meditation remains seated while reading")
		scene._close_drawer();advance(.8);await create_timer(.26).timeout
		check(scene.preview_blend==0 and scene.drawer_name.is_empty(),"Portrait fades while scene stays unchanged")
	# Opening any page leaves all world layers in the original coordinate system.
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);scene._toggle_drawer("practice");advance(.8)
		check(scene._scene_camera_transform()==Transform2D.IDENTITY,"Scene has no UI camera at %d"%width)
		check(scene.rendered_stage_scale==1.0,"World actor stays original size")
		check(scene.character_preview.visible and scene.character_preview.size.x<scene._drawer_rect().position.x,"Independent portrait stays left of book")
		scene._close_drawer();advance(.8);await create_timer(.7).timeout
	scene.size=Vector2(1200,320)
	# A refresh must neither restart opening nor reveal invisible live hit regions.
	scene._toggle_drawer("wardrobe")
	check(scene.drawer_alpha==0 and scene.paper_reveal==0,"New paper starts transparent")
	scene._sync_drawer_visuals();check(scene.buttons.drawer_close.mouse_filter==Control.MOUSE_FILTER_IGNORE,"Unfurled controls wait for visible paper")
	await create_timer(.10).timeout
	var reveal_before:float=scene.paper_reveal
	scene._refresh_drawer();check(scene.paper_reveal==reveal_before,"Live state refresh preserves current open progress")
	await create_timer(.80).timeout;scene._sync_drawer_visuals()
	check(is_equal_approx(scene.drawer_alpha,1) and is_equal_approx(scene.paper_reveal,1),"Open tween settles fully despite refresh")
	check(scene.buttons.drawer_close.mouse_filter==Control.MOUSE_FILTER_STOP,"Visible controls receive pointer input")
	press("wardrobe_technique")
	check(scene.content_alpha<1 and scene.content_offset>0,"Changing tabs leaves a visible ink transition")
	var old_alpha:float=scene.content_alpha
	scene._refresh_drawer();check(scene.content_alpha==old_alpha,"Numbers refreshing do not reset tab transition")
	await create_timer(.80).timeout
	check(is_equal_approx(scene.content_alpha,1) and is_zero_approx(scene.content_offset),"Ink and its hit regions settle at identical coordinates")
	for i in range(40):
		scene._close_drawer()
		var stale=scene.buttons.get("drawer_close")
		scene._toggle_drawer("practice" if i%2==0 else "wardrobe")
		if is_instance_valid(stale):stale.pressed.emit()
		scene._refresh_drawer()
		await process_frame
		check(not scene.drawer_name.is_empty() and is_instance_valid(scene.drawer),"Stale close callback cannot kill replacement %d"%i)
	await create_timer(.80).timeout
	check(is_instance_valid(scene.drawer) and scene.drawer_alpha==1,"Last rapid-toggle target remains open")
	press("drawer_close");await create_timer(.8).timeout
	check(scene.drawer==null and scene.drawer_alpha==0,"Closed controls are removed exactly once")
	# Loot reveal is presentation time, so a paused opening remains visible.
	scene.paused=true;scene.state.gear.chests=1;scene._open_treasure();advance(.5)
	check(scene.chest_time==4.0 and scene.chest_reveal_age>=.49,"Paused chest still reveals without advancing gameplay time")
	scene.paused=false
	# Notice entrance and loot/equipment feedback do not mutate gameplay state.
	scene._notice("test","loot");check(scene.toast_age==0 and scene.reward_pulse==1,"Rewards begin a fresh soft feedback pulse")
	advance(.15);check(scene.toast_age>0 and scene.reward_pulse<1,"Notice and reward entrance animate")
	scene._toggle_drawer("settings");await create_timer(.80).timeout
	scene._safe_restore();await create_timer(.8).timeout
	check(not scene.strip and scene.drawer_name.is_empty(),"Escape recovery cancels all page activity safely")
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("Motion transitions: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
