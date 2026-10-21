extends SceneTree
## Scripted native-Godot visual proof using the same production callbacks.
## Run with --write-movie ... --fixed-fps 30 -- --campaign-demo --record-cues.
var scene
var time=0.0
var next_cue=0
var cues=[
	[5.0,"key_r"],[6.5,"activity_gather"],[8.2,"activity_meditate"],
	[10.3,"journal_journal"],[11.6,"journal_collection"],[12.9,"key_i"],
	[14.0,"slot_legs"],[15.2,"unequip_slot"],[16.7,"equip_selected"],
	[18.1,"wardrobe_adventure"],[19.3,"open_chest"],[21.0,"wardrobe_equipment"],
	[22.6,"key_i"],[24.0,"key_g"],[26.2,"key_r"],[26.7,"journal_practice"],[27.4,"activity_meditate"],
	[29.3,"drawer_close"],[33.0,"finish"]]
func _initialize():call_deferred("start")
func start():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://motion_movie_%d.json"%OS.get_process_id()
	root.add_child(scene)
	await process_frame
	scene.demo=true;scene.state.new_game();scene._prepare_campaign_demo();scene.state.activity="meditate";scene.state.auto_advance=false;scene.state.journey={}
	scene.toast_time=0;scene.get_window().size=Vector2i(1200,320);scene.character_x=520;scene.character_y=230;scene.meditation_amount=0;scene.meditation_settle=0;scene.paused=false
	scene.set_meta("ink_journal_tab","practice");scene.wardrobe_tab="equipment"
func _process(delta):
	if not is_instance_valid(scene):return false
	time+=delta
	if next_cue<cues.size() and time>=float(cues[next_cue][0]):
		var cue:String=cues[next_cue][1];next_cue+=1
		print("MOTION_VIDEO_CUE %.3f %s"%[time,cue])
		if cue=="finish":
			finish.call_deferred();return false
		if cue.begins_with("key_"):
			var event=InputEventKey.new();event.pressed=true;event.keycode={"key_i":KEY_I,"key_r":KEY_R,"key_g":KEY_G}[cue]
			scene._input(event)
		else:
			var button=scene.buttons.get(cue)
			if is_instance_valid(button) and not button.disabled:button.pressed.emit()
			else:printerr("DEMO BUTTON UNAVAILABLE: "+cue)
	return false
func finish():
	scene.queue_free();scene=null
	await process_frame;await process_frame
	quit()
