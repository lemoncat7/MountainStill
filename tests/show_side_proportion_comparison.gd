extends SceneTree
## Original and revised native renderers, identical clocks/anchors. QA, not gameplay.
const Before = preload("res://tests/character_sidewalk_before.gd")
const After = preload("res://scripts/character_sidewalk.gd")
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var output := "/tmp/side-proportion-proof"
var samples := {}

class Sheet extends Node2D:
	var before = Before.new()
	var after = After.new()
	var sword = After.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
	var samples := {}
	var bare := false
	var native := false
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	func _draw() -> void:
		var height := 320 if native else 750
		draw_rect(Rect2(0,0,1200,height),Color("eeeadd"))
		var outfit := "素体" if bare else "混搭衣装"
		draw_string(Sans,Vector2(20,27),"侧身比例 · %s · %s · 原生渲染对照" % [outfit,"实际角色尺寸" if native else "2.1 倍关节检查"],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("334b43"))
		var keys := ["idle","walk","attack","guard"]
		var labels := ["站立","步行","出招","格挡"]
		var visual := {} if bare else {"head":"head_pin","chest":"chest_jade","legs":"legs_blue","feet":"feet_boots"}
		for row in range(2):
			var script = Before if row==0 else After
			var rig = before if row==0 else after
			var text := "调整前" if row==0 else "调整后：短颈衔接 · 头 −14% / 胸背 +30% / 手臂 +20% / 腿 +18%"
			draw_string(Sans,Vector2(20+600*row if native else 20,55 if native else 56+355*row),text,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("6d786b"))
			for column in range(4):
				var scale_value := 1.0 if native else 2.1
				var feet := Vector2(55+150*column+600*row,265) if native else Vector2(105+300*column,344+355*row)
				var caption := Vector2(20+150*column+600*row,100) if native else Vector2(20+300*column,82+355*row)
				draw_string(Sans,caption,labels[column],HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("38534a"))
				draw_line(feet+Vector2(-42 if native else -80,0),feet+Vector2(82 if native else 175,0),Color("acb5a4"),1)
				var motion := motion_for(keys[column])
				if not bare:
					var weapon:Dictionary=script.weapon_pose(motion,scale_value,0.0,"sword")
					if weapon.draw_behind:draw_weapon(feet,weapon,scale_value)
					rig.draw_avatar_layers(self,feet,{},visual,motion,scale_value)
					if not weapon.draw_behind:draw_weapon(feet,weapon,scale_value)
					script.draw_grip_front(self,feet,motion,scale_value,0.0,"sword")
				else:rig.draw_avatar_layers(self,feet,{},visual,motion,scale_value)
	func motion_for(key:String)->Dictionary:
		if key=="idle":return {"phase":0.0,"blend":0.0,"facing":1.0,"attack_style":"unarmed" if bare else "sword","attack_amount":0.0}
		if key=="walk":return {"phase":0.16,"blend":1.0,"facing":1.0,"attack_style":"unarmed" if bare else "sword","attack_amount":0.0}
		var motion:Dictionary=samples.get("basic_sword_thrust" if key=="attack" else "guard_brace",{}).duplicate(true)
		motion.approach_origin=0.0;motion.approach_distance=0.0;motion.erase("frozen_approach")
		if bare:
			motion.attack_style="unarmed";motion.basic_style="unarmed";motion.combat_move="basic_fist_jab";motion.action_kind="basic"
		return motion
	func draw_weapon(feet:Vector2,pose:Dictionary,scale_value:float)->void:
		draw_set_transform(feet+Vector2(pose.offset),float(pose.rotation)+.22,Vector2.ONE*scale_value)
		draw_texture_rect(sword,Rect2(-7.8,-53.7,26,76),false)
		draw_set_transform(Vector2.ZERO)

func _initialize()->void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
	var input_path := "res://docs/qa/side-proportion-revision/baseline-pose-samples.bin"
	var file:=FileAccess.open(input_path,FileAccess.READ)
	samples=file.get_var(true);file.close()
	call_deferred("capture")

func capture()->void:
	for bare in [false,true]:
		for native in [false,true]:
			root.size=Vector2i(1200,320 if native else 750)
			var sheet:=Sheet.new();sheet.samples=samples;sheet.bare=bare;sheet.native=native
			root.add_child(sheet)
			await process_frame
			root.size=Vector2i(1200,320 if native else 750)
			await process_frame
			await RenderingServer.frame_post_draw
			var path:=output.path_join(("bare" if bare else "mixed")+("-native" if native else "-zoom")+".png")
			var result:=root.get_texture().get_image().save_png(path)
			print("NATIVE_PROPORTION_SHEET "+path+" "+str(result))
			sheet.queue_free();await process_frame;await process_frame
	call_deferred("quit",0)
