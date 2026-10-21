extends SceneTree
## Native proof of an independent portrait. No scene/camera transform is applied.
var scene
var time=0.0
var next=0
var cues=[[2.0,"open"],[4.3,"close"],[6.5,"wardrobe"],[8.8,"technique"],[9.8,"try"],[13.8,"settings"],[16.0,"open"],[18.1,"close"],[19.5,"open"],[19.7,"close"],[19.9,"settings"],[20.1,"open"],[22.5,"close"],[24.0,"finish"]]
func _initialize():call_deferred("start")
func start():
	scene=load("res://main.tscn").instantiate();scene.state.save_path="user://book_portrait_%d.json"%OS.get_process_id();root.add_child(scene)
	await process_frame
	scene.demo=true;scene.state.new_game();scene._prepare_campaign_demo();scene.state.journey={};scene.state.activity="meditate";scene.state.auto_advance=false;scene.paused=false
	scene.toast_time=0;scene.get_window().size=Vector2i(1200,320);scene.character_x=520;scene.character_y=230;scene.meditation_amount=1;scene.meditation_settle=2
	scene.set_meta("ink_journal_tab","practice")
func _process(delta):
	if not is_instance_valid(scene):return false
	time+=delta
	if next<cues.size() and time>=float(cues[next][0]):
		var action=cues[next][1];next+=1
		print("BOOK_PORTRAIT_CUE %.3f %s world=(%.3f,%.3f)"%[time,action,scene.character_x,scene.character_y])
		match action:
			"open":scene._toggle_drawer("practice")
			"close":scene._close_drawer()
			"settings":scene._toggle_drawer("settings")
			"wardrobe":scene._toggle_drawer("wardrobe")
			"technique":scene.buttons.wardrobe_technique.pressed.emit()
			"try":scene.buttons.practice_preview.pressed.emit()
			"finish":finish.call_deferred()
	return false
func finish():
	scene.queue_free();scene=null;await process_frame;await process_frame;quit()
