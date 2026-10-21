extends SceneTree
## Inventory closeups display the real equipped weapon in a separate lane.
## World grips remain owned by the battle renderer, never by this portrait.
const Walk=preload("res://scripts/character_walk.gd")
var scene
var checks:=0
var failures:=0

func check(ok:bool,label:String):
	checks+=1
	if not ok:failures+=1;printerr("FAIL: "+label)

func weapon_bounds(placement:Dictionary)->Rect2:
	var rect:Rect2=placement.rect
	var scale_value:float=placement.scale
	return Rect2(Vector2(placement.grip)+rect.position*scale_value,rect.size*scale_value)

func snapshot()->Array:
	return [scene.character_x,scene.character_y,scene.meditation_amount,scene.cast_blend,
		scene.state.qi,scene.state.activity,scene.state.stats().duplicate(true),scene.state.gear.to_dict().duplicate(true)]

func _initialize():call_deferred("run")

func run():
	scene=load("res://main.tscn").instantiate()
	scene.state.save_path="user://manual_portrait_%d.json"%OS.get_process_id()
	root.add_child(scene);await process_frame
	scene.set_process(false);scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
	scene._toggle_drawer("wardrobe");scene.wardrobe_tab="technique";scene._refresh_drawer()
	var preview=scene.character_preview
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);scene._refresh_drawer();scene._sync_character_preview(0.0)
		for weapon in ["sword","fan"]:
			var id:String="mist" if weapon=="sword" else "petal"
			var item:Dictionary=scene.state.gear._make_item(1,"weapon_"+weapon,"common",1)
			scene.state.gear.inventory=[item];scene.state.equip_item(1)
			scene.set_meta("preview_technique",id)
			preview.cancel_technique();preview.advance(0.0,true)
			var scale_value:float=preview._character_scale(weapon)
			var feet:Vector2=preview._feet_position(scale_value,weapon)
			var state_before:=snapshot()
			check(scale_value>1.5,"Portrait stays enlarged at %d: %s"%[width,weapon])
			check(feet.x-preview.PORTRAIT_HALF_WIDTH*scale_value>=11.9,"Hair/body stay inside left inset")
			for time in [0.0,0.25,0.5,0.8,1.2,1.7]:
				preview.play_technique();preview.advance(time,true)
				var placement:Dictionary=preview.weapon_placement(feet,scale_value,weapon,0.03)
				var bounds:=weapon_bounds(placement)
				check(placement.floating and not placement.stowed,"Displayed item never implies grip or stow")
				check(is_zero_approx(float(placement.rotation)),"Skill cannot rotate the floating item")
				check(not preview._motion.has("attack_phase"),"Weapon-art preview does not swing an empty hand")
				check(bounds.position.x-feet.x-preview.PORTRAIT_HALF_WIDTH*scale_value>=11.99,"Full art clears hair/body by at least 12 px")
				check(Rect2(Vector2(11.9,1),preview.size-Vector2(23.8,2)).encloses(bounds),"Entire weapon art fits %s/%d/%.2f"%[weapon,width,time])
				check(absf(Vector2(placement.grip).y-(feet.y-62.0*scale_value))<=preview.WEAPON_HOVER_HEIGHT+0.001,"Hover is gentle and vertical")
				var fixed_clock:float=preview._display_clock
				var changed:Dictionary=preview.weapon_placement(feet,scale_value,weapon,-0.2)
				check(changed==placement,"Placement is independent of body/cast tilt")
				preview._display_clock=fixed_clock
				check(snapshot()==state_before,"Preview leaves world, stats and gear unchanged")
			preview.cancel_technique()
			for id_spell in ["ember","frost","thunder","barrier","mending"]:
				scene.set_meta("preview_technique",id_spell);preview.play_technique();preview.advance(0.75,true)
				var placement:Dictionary=preview.weapon_placement(feet,scale_value,weapon)
				check(placement.floating and not placement.stowed,"Palm spell retains separate display: "+id_spell)
				check(preview._motion.get("attack_style","")=="unarmed","Spell uses the free palm")
				var hand:Vector2=feet+Walk.attachment_offset(Walk.GRIP_RIGHT,preview._motion,scale_value)
				check(hand.x+7.0*scale_value<weapon_bounds(placement).position.x,"Spell palm does not reach displayed item")
				check(snapshot()==state_before,"Spell inspection does not mutate gameplay")
				preview.cancel_technique();preview.advance(0.0,true)
			for passive in ["stillness","breath","body"]:
				scene.set_meta("preview_technique",passive);preview.play_technique();preview.advance(1.0,true)
				check(not preview._motion.has("attack_phase"),"Passive preview remains relaxed: "+passive)
				check(preview.weapon_placement(feet,scale_value,weapon).floating,"Passive aura retains separate item")
				preview.cancel_technique()
			# Source of truth is still the equipped item, including immediate removal.
			scene.state.gear.unequip_slot("weapon")
			preview.advance(0.0,true)
			check(str(scene.state.gear.visual_loadout().get("weapon",""))=="","Unequip immediately removes display source")
			check(preview._weapon_dimensions("")==Vector2.ZERO,"No fallback or phantom weapon for empty slot")
			check(preview._feet_position(preview._character_scale(""),"")==feet,"Unequipping preserves exact feet/root position")
			check(preview._character_scale("")==scale_value,"Unequipping preserves exact character scale")
	# Repeat actual equipment changes and drawer refreshes at each supported width.
	# Compare exact values, not a broad silhouette bound or approximate center.
	scene.wardrobe_tab="equipment";preview.cancel_technique()
	scene.state.gear.inventory=[scene.state.gear._make_item(1,"weapon_sword","common",1),scene.state.gear._make_item(2,"weapon_fan","common",1)]
	for width in [1000,1200,1360]:
		scene.size=Vector2(width,320);scene._refresh_drawer();scene._sync_character_preview(1.0)
		var fixed_scale:float=preview._character_scale("")
		var fixed_feet:Vector2=preview._feet_position(fixed_scale,"")
		var fixed_rect:Rect2=preview.get_rect()
		var fixed_world:Vector2=Vector2(scene.character_x,scene.character_y)
		var idle_pose:Dictionary=Walk.sample_pose(preview._motion)
		var fixed_ankle:Vector2=idle_pose.left.ankle
		for equipped_id in [1,2,0,2,1,0,1]:
			if equipped_id==0:scene.state.unequip_slot("weapon")
			else:scene.state.equip_item(equipped_id)
			for refresh in range(5):
				scene._refresh_drawer();scene._sync_character_preview(0.0 if refresh==0 else 1.0/60.0)
				var weapon:String=str(scene.state.gear.visual_loadout().get("weapon","")).trim_prefix("weapon_")
				check(preview._character_scale(weapon)==fixed_scale,"Exact body scale survives equipment change and refresh: %d/%d/%d"%[width,equipped_id,refresh])
				check(preview._feet_position(preview._character_scale(weapon),weapon)==fixed_feet,"Exact feet/root survives equipment change and refresh")
				check(preview.get_rect()==fixed_rect and preview.reveal==1.0,"Refresh cannot move portrait control or replay reveal zoom")
				check(Vector2(Walk.sample_pose(preview._motion).left.ankle)==fixed_ankle,"Standing soles do not float with idle clock")
				check(Vector2(scene.character_x,scene.character_y)==fixed_world,"Equipment display does not move world actor")
	check(scene._scene_camera_transform()==Transform2D.IDENTITY,"Portrait never transforms the world")
	preview.play_technique();preview.advance(0.1,true);preview.advance(0.1,false)
	check(preview.cast_time==0.0,"Closing clears local demonstration")
	var path:String=scene.state.save_path
	scene.queue_free();await process_frame;await process_frame
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
	print("Inventory weapon display: %d checks, %d failures"%[checks,failures])
	quit(1 if failures else 0)
