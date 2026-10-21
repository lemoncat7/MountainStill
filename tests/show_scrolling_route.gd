extends SceneTree
## Native, normal-speed route capture. Preset common gear and seed are disclosed.
var scene
var time=0.0
var step=0
var opportunity_at=-1.0
var finished_at=-1.0
var finish_step=0
var save_path="user://scrolling_route_proof_%d.json"%OS.get_process_id()
func _initialize():call_deferred("start")
func start():
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
	await process_frame
	scene.demo=true;scene.state.new_game();scene.state.auto_advance=false;scene.state._adventure_rng.seed=1271
	scene.state.qi=90;scene.state.herbs=6;scene.state.dew=2
	for key in ["chest_blue","legs_jade","feet_cloth","head_pin","weapon_sword"]:
		var item=scene.state.gear._make_item(scene.state.gear._next_id,key,"common",1)
		scene.state.gear._next_id+=1;scene.state.gear.inventory.append(item);scene.state.gear.equip_item(int(item.id))
	scene.paused=false;scene.character_x=520;scene.character_y=230;scene.meditation_amount=1;scene.meditation_settle=2
	scene.get_window().size=Vector2i(1200,320);scene.toast_time=0
	var caption=Label.new();caption.position=Vector2(18,7);caption.add_theme_font_size_override("font_size",10);caption.add_theme_color_override("font_color",Color("475b49"))
	caption.text="原生 Linux · 正常速度 · 预置普通混搭行装 / 样例种子 1271 · 非自然掉落频率";scene.add_child(caption)
func press(key:String):
	var b=scene.buttons.get(key)
	if is_instance_valid(b) and not b.disabled:b.pressed.emit();print("ROUTE_CUE %.3f %s"%[time,key])
	else:printerr("ROUTE_MISSING_BUTTON "+key)
func _process(delta):
	if not is_instance_valid(scene):return false
	time+=delta
	if step==0 and time>1.5:scene._toggle_drawer("wardrobe");press("wardrobe_expedition");step=1
	if step==1 and time>3.5:press("stage_bamboo_pass");press("depart_stage");step=2
	if scene.encounter_phase=="opportunity":
		if opportunity_at<0:opportunity_at=time
		if time>opportunity_at+3.0 and step==2:press("route_opportunity");step=3
		if time>opportunity_at+6.0 and step==3:press("opportunity_read_inscription");step=4
	if step>=2 and not scene.encounter_active and time>10:
		if finished_at<0:finished_at=time;print("ROUTE_RETURN %.3f victories=%d clears=%s"%[time,scene.state.total_victories,str(scene.state.stage_clears)])
		if time>finished_at+2.0 and finish_step==0:
			scene._toggle_drawer("wardrobe");press("wardrobe_meridian");finish_step=1
		if time>finished_at+4.5 and finish_step==1:press("unlock_meridian");finish_step=2
		if time>finished_at+7.0 and finish_step==2:
			press("wardrobe_equipment")
			if not scene.last_loot.is_empty():scene.selected_item=int(scene.last_loot.id);scene.selected_slot=str(scene.last_loot.slot);scene._refresh_drawer();press("equip_selected")
			finish_step=3
		if time>finished_at+9.5 and finish_step==3:scene._open_treasure();finish_step=4
		if time>finished_at+12.0 and finish_step==4:scene._close_drawer();finish_step=5
		if time>finished_at+14.0 and finish_step==5:scene._toggle_drawer("practice");finish_step=6
		if time>finished_at+16.0 and finish_step==6:press("breakthrough");scene._close_drawer();finish_step=7
		if time>finished_at+21.0 and finish_step==7:finish.call_deferred();step=-100
	if time>150 and step!=-100:printerr("ROUTE_TIMEOUT "+scene.encounter_phase);finish.call_deferred();step=-100
	return false
func finish():
	scene.queue_free();scene=null;await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	quit()
