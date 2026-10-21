extends SceneTree
## Ten-second native 1200x320 proof. All switches use actual UI button callbacks.
## The red foot reference is placed once and never follows the portrait afterward.
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
class FootReference extends Node2D:
	func _draw():
		draw_line(Vector2(-39,3),Vector2(39,3),Color("#a65340"),1.0,true)
		draw_line(Vector2(0,-5),Vector2(0,8),Color("#a65340"),1.0,true)
		draw_line(Vector2(-39,0),Vector2(-39,6),Color("#a65340"),1.0,true)
		draw_line(Vector2(39,0),Vector2(39,6),Color("#a65340"),1.0,true)
var scene
var banner:Label
var output:="/tmp/inventory-weapon-stability"
var width:=1200
var save_path:="user://inventory_weapon_stability_%d.json"%OS.get_process_id()
var fixed_feet:Vector2
var fixed_scale:float
var samples:Array=[]
var failed:=false

func _initialize():call_deferred("run")

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
		if arg.begins_with("--width="):width=int(arg.trim_prefix("--width="))
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path
	root.add_child(scene);await process_frame
	scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene.paused=true;scene.state.settings.paused=true
	scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true
	scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0;scene.meditation_settle=1.0
	scene.toast_time=0.0
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	for template in ["head_pin","chest_blue","legs_blue","feet_cloth","weapon_sword","weapon_fan"]:
		var id:int=scene.state.gear.inventory.size()+1
		scene.state.gear.inventory.append(scene.state.gear._make_item(id,template,"common",1))
		if id<6:scene.state.gear.equip_item(id)
	scene.get_window().size=Vector2i(width,320);scene.size=Vector2(width,320)
	scene.wardrobe_tab="equipment";scene.selected_slot="weapon";scene.selected_item=5;scene.inventory_page=1
	scene._toggle_drawer("wardrobe")
	banner=Label.new();banner.position=Vector2(15,4)
	banner.add_theme_font_override("font",Sans);banner.add_theme_font_size_override("font_size",11)
	banner.add_theme_color_override("font_color",Color("#354e43"));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	banner.text="换装稳定性 · 测试夹具 / 真实穿脱按钮 / 红色脚线固定在初始位置"
	scene.add_child(banner)
	await create_timer(0.9).timeout
	var preview=scene.character_preview
	fixed_scale=preview._character_scale("sword")
	fixed_feet=preview.position+preview._feet_position(fixed_scale,"sword")
	var reference=FootReference.new();reference.position=fixed_feet;scene.add_child(reference)
	var note=Label.new();note.position=fixed_feet+Vector2(-27,9)
	note.add_theme_font_override("font",Sans);note.add_theme_font_size_override("font_size",10)
	note.add_theme_color_override("font_color",Color("#a65340"));note.text="固定脚线";scene.add_child(note)
	var sequence:=[5,6,0,5,6,0]
	for i in range(sequence.size()):
		var id:int=sequence[i]
		if i>0:
			if id==0:
				scene.buttons.unequip_slot.pressed.emit()
			else:
				scene.selected_item=id;scene.selected_slot="weapon";scene._refresh_drawer()
				scene.buttons.equip_selected.pressed.emit()
		var weapon_name:String={5:"青锋剑",6:"流云扇",0:"卸下兵器"}[id]
		banner.text="换装稳定性 · %s · 人物脚点 (%.2f, %.2f) / 缩放 %.5f · 固定红线不跟随人物"%[weapon_name,fixed_feet.x,fixed_feet.y,fixed_scale]
		await create_timer(0.10).timeout
		await capture("%02d-%s"%[i,{5:"sword",6:"fan",0:"none"}[id]])
		await create_timer(1.35).timeout
		verify_sample()
	var file=FileAccess.open(output+"/anchor-samples.json",FileAccess.WRITE)
	file.store_string(JSON.stringify({"width":width,"fixed_feet":[fixed_feet.x,fixed_feet.y],"fixed_scale":fixed_scale,"failed":failed,"samples":samples},"  "));file.close()
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("INVENTORY_STABILITY_COMPLETE failed="+str(failed))
	quit(1 if failed else 0)

func verify_sample():
	var preview=scene.character_preview
	var weapon:String=str(scene.state.gear.visual_loadout().get("weapon","")).trim_prefix("weapon_")
	var current_scale:float=preview._character_scale(weapon)
	var current_feet:Vector2=preview.position+preview._feet_position(current_scale,weapon)
	var stable:bool=current_scale==fixed_scale and current_feet==fixed_feet and preview.reveal==1.0
	failed=failed or not stable
	samples.append({"weapon":weapon,"feet":[current_feet.x,current_feet.y],"scale":current_scale,"stable":stable})
	if not stable:push_error("PORTRAIT_DRIFT "+str(samples.back()))

func capture(label:String):
	verify_sample()
	await RenderingServer.frame_post_draw
	var result:=root.get_texture().get_image().save_png(output+"/"+label+".png")
	if result!=OK:failed=true
	print("STABILITY_CAPTURE "+label+" result="+str(result))
