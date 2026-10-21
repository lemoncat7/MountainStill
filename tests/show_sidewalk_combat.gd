extends SceneTree
## Side-pose contact/grip proof; uses the exact same renderer as the live actor.
const Walk=preload("res://scripts/character_sidewalk.gd")
class Proof extends Node2D:
	var rig=Walk.new()
	var sword=Walk.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
	var fan=Walk.filtered_weapon(preload("res://assets/cultivation/avatars/fan.png"))
	func _ready()->void:
		texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	func _draw()->void:
		draw_rect(Rect2(0,0,1080,720),Color("f1ecdf"))
		var font=ThemeDB.fallback_font
		draw_string(font,Vector2(24,30),"SIDE COMBAT | contact poses, independent weapons, grounded defense",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("294c49"))
		var cases:=[
			{"name":"Mist thrust / active sword","technique":"mist","combat_move":"mist_thrust","weapon":"sword","actor_lunge":19.0},
			{"name":"Petal counter / active fan","technique":"petal","combat_move":"petal_counter","weapon":"fan","actor_lunge":27.0},
			{"name":"Stillness palm / stowed sword","technique":"stillness","combat_move":"stillness_palm","weapon":"sword","actor_lunge":10.0},
			{"name":"Mist lifting cut / active sword","technique":"mist","combat_move":"mist_lift","weapon":"sword","actor_lunge":14.0},
			{"name":"Petal dodge / active fan","technique":"petal","combat_move":"","weapon":"fan","defense_action":"dodge","reaction_amount":1.0},
			{"name":"Stillness guard / stowed sword","technique":"stillness","combat_move":"","weapon":"sword","defense_action":"guard","reaction_amount":1.0},
		]
		for i in range(cases.size()):
			var data:Dictionary=cases[i]
			var motion:Dictionary={"blend":0.0,"facing":1.0,"attack_amount":1.0,"combat_phase":"contact","phase_progress":0.5,"attack_style":data.weapon}
			motion.merge(data,true)
			if data.has("defense_action"):motion.attack_amount=0.0
			var feet:=Vector2(135+(i%3)*360,327+(i/3)*335)
			draw_string(font,Vector2(20+(i%3)*360,65+(i/3)*335),data.name,HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("294c49"))
			draw_line(feet+Vector2(-90,0),feet+Vector2(160,0),Color("a5afa3"),1.0)
			var visual:Dictionary={"head":"head_pin","chest":"chest_blue","legs":"legs_jade","feet":"feet_boots"}
			var weapon:=Walk.weapon_pose(motion,1.70,0.0,data.weapon)
			if weapon.draw_behind:_weapon(feet,weapon,data.weapon)
			rig.draw_avatar_layers(self,feet,{},visual,motion,1.70)
			if not weapon.draw_behind:_weapon(feet,weapon,data.weapon)
			var grip:=feet+Walk.attachment_offset(Vector2.ZERO,motion,1.70)
			draw_circle(grip,1.4,Color("b77741"))
	func _weapon(feet:Vector2,pose:Dictionary,key:String)->void:
		var rotation:float=pose.rotation+(0.22 if key=="sword" and not pose.stowed else 0.0)
		draw_set_transform(feet+Vector2(pose.offset),rotation,Vector2.ONE*1.70)
		draw_texture_rect(sword if key=="sword" else fan,Rect2(-7.8,-53.7,26,76) if key=="sword" else Rect2(-23.3,-25.6,48,40),false)
		draw_set_transform(Vector2.ZERO)
func _initialize()->void:
	root.mode=Window.MODE_WINDOWED
	root.size=Vector2i(1080,720)
	root.add_child(Proof.new())
	_finish.call_deferred()
func _finish()->void:
	await process_frame
	root.size=Vector2i(1080,720)
	await process_frame
	await create_timer(0.25).timeout
	await RenderingServer.frame_post_draw
	var image:=root.get_texture().get_image()
	if image:print("SIDE_COMBAT_PROOF:",image.save_png("res://builds/full-v1/sidewalk-combat.png"))
	quit()
