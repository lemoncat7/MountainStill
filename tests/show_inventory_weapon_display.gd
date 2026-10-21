extends SceneTree
## Native game-width inventory proof. Temporary gear is a labeled test fixture.
## Run: godot --path . --script tests/show_inventory_weapon_display.gd -- --output=/absolute/folder
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var scene
var banner:Label
var output := "/tmp/inventory-weapon-display"
var save_path := "user://inventory_weapon_display_%d.json"%OS.get_process_id()

func _initialize():call_deferred("run")

func run():
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(output)
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path=save_path
	root.add_child(scene);await process_frame
	scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene.paused=true;scene.state.settings.paused=true
	scene.get_window().transparent_bg=false
	scene.strip=true;scene.desktop.transparent_enabled=true
	scene.character_x=520.0;scene.character_y=230.0
	scene.meditation_amount=1.0;scene.meditation_settle=1.0
	scene.toast_time=0.0
	RenderingServer.set_default_clear_color(Color("#e8e7df"))
	for template in ["head_pin","chest_blue","legs_blue","feet_cloth","weapon_sword","weapon_fan"]:
		var id:int=scene.state.gear.inventory.size()+1
		scene.state.gear.inventory.append(scene.state.gear._make_item(id,template,"common",1))
		if id<6:scene.state.gear.equip_item(id)
	banner=Label.new();banner.position=Vector2(15,4)
	banner.add_theme_font_override("font",Sans);banner.add_theme_font_size_override("font_size",11)
	banner.add_theme_color_override("font_color",Color("#354e43"))
	banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
	scene.add_child(banner)
	scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320)
	scene.wardrobe_tab="equipment";scene.selected_slot="weapon";scene.selected_item=5
	scene._toggle_drawer("wardrobe")
	await show_case("1200-sword",1200,5,"行囊兵器展示 · 独立悬浮，与头发和双手留白 · 测试夹具")
	await show_case("1200-fan",1200,6,"行囊兵器展示 · 换装即时显示折扇 · 测试夹具")
	await show_case("1200-unequipped",1200,0,"行囊兵器展示 · 卸下兵器后无残留，人物位置和大小固定 · 测试夹具")
	await show_case("1000-sword",1000,5,"最窄 1000 像素窗口 · 青锋剑完整显示 · 测试夹具")
	await show_case("1000-fan",1000,6,"最窄 1000 像素窗口 · 折扇不碰头发、不贴纸页 · 测试夹具")
	await show_case("1360-fan",1360,6,"宽 1360 像素窗口 · 同一原画人物与独立兵器 · 测试夹具")
	scene.wardrobe_tab="technique";scene.set_meta("ink_technique_id","mist");scene.set_meta("preview_technique","mist")
	await show_case("1200-sword-art",1200,5,"功法试演 · 兵器独立展示，不随空手挥动 · 测试夹具",true)
	scene.set_meta("ink_technique_id","ember");scene.set_meta("preview_technique","ember")
	await show_case("1200-fan-spell",1200,6,"功法试演 · 空手施法，折扇保持独立悬浮 · 测试夹具",true)
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
	print("INVENTORY_WEAPON_NATIVE_CAPTURE_COMPLETE "+output)
	quit()

func show_case(label:String,width:int,item:int,caption:String,technique:bool=false):
	scene.character_preview.cancel_technique()
	if item==0:scene.state.gear.unequip_slot("weapon")
	else:scene.state.gear.equip_item(item)
	scene.selected_item=item if item>0 else 5
	scene.get_window().size=Vector2i(width,320);scene.size=Vector2(width,320)
	scene._resized();scene._refresh_drawer();scene._sync_character_preview(0.0)
	banner.text=caption
	if technique:scene.character_preview.play_technique()
	await create_timer(1.5).timeout
	await RenderingServer.frame_post_draw
	var image:Image=root.get_texture().get_image()
	var result:=image.save_png(output+"/"+label+".png")
	print("INVENTORY_CAPTURE "+label+" "+str(image.get_size())+" result="+str(result))
