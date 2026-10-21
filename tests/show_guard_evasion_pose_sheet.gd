extends SceneTree
## Native enlarged rig-only inspection of poses sampled from real contacts.
## This is an explicitly labeled QA pose sheet, never gameplay footage.
const Rig = preload("res://scripts/character_sidewalk.gd")
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var output := "/tmp/guard-evasion-proof"
var input_path := ""

class Sheet extends Node2D:
	var rig = Rig.new()
	var sword = Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
	var samples: Dictionary = {}
	func _ready() -> void:
		texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 880), Color("eeeadd"))
		draw_string(Sans, Vector2(24, 26), "QA 姿态检查 · 真实交锋采样 / 原生角色渲染 2.4 倍 / 去除怪物与特效", HORIZONTAL_ALIGNMENT_LEFT, -1, 20, Color("334b43"))
		draw_string(Sans, Vector2(24, 51), "本图为关节、握持与脚步的放大检查，不是玩法截图；不修改采样动作与兵器姿态。", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color("6d786b"))
		var keys := ["basic_sword_cut", "basic_sword_thrust", "basic_sword_lift", "guard", "guard_brace", "dodge"]
		var names := ["平斩 · 接触", "直刺 · 接触", "挑锋 · 接触", "首个格挡 · 实际状态", "完整持剑格挡 · 非出招承诺段", "真实闪避 · 零伤害"]
		for index in range(keys.size()):
			var sample: Dictionary = samples.get(keys[index], {})
			var column := index % 3
			var row := index / 3
			var feet := Vector2(139 + column * 400, 430 + row * 420)
			draw_string(Sans, Vector2(24 + column * 400, 90 + row * 420), names[index], HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("38534a"))
			if sample.is_empty():
				draw_string(Sans, feet + Vector2(-80, -120), "该样本未出现", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color("8c5c4b"))
				continue
			var phase := str(sample.get("combat_phase", ""))
			draw_string(Sans, Vector2(24 + column * 400, 110 + row * 420), "阶段 %s · 防御 %s · 强度 %.2f" % [phase, str(sample.get("defense_action", "")), float(sample.get("reaction_amount", 0.0))], HORIZONTAL_ALIGNMENT_LEFT, -1, 11, Color("727b6b"))
			draw_line(feet + Vector2(-80, 0), feet + Vector2(180, 0), Color("acb5a4"), 1.0)
			var visual := {"head": "head_pin", "chest": "chest_blue", "legs": "legs_blue"}
			var weapon: Dictionary = Rig.weapon_pose(sample, 2.4, 0.0, "sword")
			if weapon.draw_behind: draw_weapon(feet, weapon)
			rig.draw_avatar_layers(self, feet, {}, visual, sample, 2.4)
			if not weapon.draw_behind: draw_weapon(feet, weapon)
			Rig.draw_grip_front(self, feet, sample, 2.4, 0.0, "sword")
	func draw_weapon(feet: Vector2, pose: Dictionary) -> void:
		draw_set_transform(feet + Vector2(pose.offset), float(pose.rotation) + .22, Vector2.ONE * 2.4)
		draw_texture_rect(sword, Rect2(-7.8, -53.7, 26, 76), false)
		draw_set_transform(Vector2.ZERO)

func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
		if arg.begins_with("--input="): input_path = arg.trim_prefix("--input=")
	if input_path.is_empty(): input_path = output.path_join("pose-samples.bin")
	root.size = Vector2i(1200, 880)
	var file := FileAccess.open(input_path, FileAccess.READ)
	if file == null:
		push_error("MISSING_NATIVE_POSE_SAMPLES " + input_path)
		quit(1)
		return
	var sheet := Sheet.new()
	sheet.samples = file.get_var(true)
	file.close()
	root.add_child(sheet)
	call_deferred("capture")

func capture() -> void:
	await process_frame
	root.size = Vector2i(1200, 880)
	await process_frame
	await RenderingServer.frame_post_draw
	var result := root.get_texture().get_image().save_png(output.path_join("native-rig-inspection-2x4.png"))
	print("NATIVE_POSE_SHEET " + str(result))
	for child in root.get_children(): child.queue_free()
	await process_frame
	await process_frame
	call_deferred("quit", 0 if result == OK else 1)
