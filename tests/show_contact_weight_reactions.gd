extends SceneTree
## Native review fixture, not gameplay evidence. Uses the actual renderer and
## resolved-profile path at ordinary display size, with staged contact regions.
const Rig=preload("res://scripts/monster_pose_renderer.gd")
const Impact=preload("res://scripts/combat_impact.gd")
const Moves=preload("res://scripts/monster_move_library.gd")

class Sheet extends Node2D:
	func _draw()->void:
		draw_rect(Rect2(0,0,1200,1120),Color("f0ebdd"))
		draw_string(ThemeDB.fallback_font,Vector2(24,32),"LOCAL CONTACT WEIGHT | production creature renderer",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("34493e"))
		draw_string(ThemeDB.fallback_font,Vector2(24,57),"Staged receiver samples at native 174px display size. Intact skull, planted support, delayed recovery.",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("68765e"))
		for col in range(5):
			draw_string(ThemeDB.fallback_font,Vector2(200+col*196,88),["Ready","Contact","50 ms","130 ms","250 ms"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("40584b"))
		for row in range(6):
			var crane:bool=row>=3
			var key:String="cloud_slope_boss" if crane else "bamboo_pass_boss"
			var kind:String=["light","heavy","block"][row%3]
			var region:String="head" if kind=="heavy" else "torso"
			var line_y:float=235+row*169
			draw_string(ThemeDB.fallback_font,Vector2(24,line_y-71),("Crane" if crane else "Moss")+" / "+kind,HORIZONTAL_ALIGNMENT_LEFT,-1,15,Color("40584b"))
			draw_string(ThemeDB.fallback_font,Vector2(24,line_y-49),"Region: "+region,HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("68765e"))
			for col in range(5):
				var at:=Vector2(243+col*196,line_y)
				draw_line(at+Vector2(-83,0),at+Vector2(87,0),Color("c6ccbb"),1)
				var age:float=[-1.0,0.0,.05,.13,.25][col]
				var contact:Dictionary={"type":"contact","actor":"hero","target":"enemy","resolution":"guard" if kind=="block" else "hit",
					"move":"thunder_strike" if kind=="heavy" else "basic_unarmed_jab","damage":12,"raw_damage":16,
					"contact_region":region,"contact_region_measured":true,"enemy_visual_type":"cloud_crane" if crane else "moss_beast"}
				var profile:Dictionary=Impact.describe(contact)
				var amount:float=0.0 if age<0.0 else 1.0-smoothstep(minf(.05,float(profile.reaction_duration)*.2),float(profile.reaction_duration),age)
				var motion:Dictionary={"combat_phase":"idle","monster_pose":Moves.neutral_pose(),"reaction_age":age,"reaction_amount":amount,
					"reaction_strength":profile.reaction_magnitude,"recoil_distance":profile.knockback,"impact_profile":profile,
					"defense_action":"guard" if kind=="block" else "hit",
					"visual_offset":Vector2.ZERO if kind=="block" else Vector2(float(profile.knockback)*amount,0),
					"visual_rotation":0.0 if kind=="block" else .035*amount*float(profile.reaction_magnitude)}
				Rig.draw(self,{},key,at,174.0,motion)

func _initialize()->void:
	root.size=Vector2i(1200,1120)
	root.add_child(Sheet.new())
	_finish.call_deferred()

func _finish()->void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory:="/tmp/mountain-contact-weight"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):directory=arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	var error:int=root.get_texture().get_image().save_png(directory.path_join("contact-weight-reactions.png"))
	print("CONTACT_WEIGHT_SHEET: ",error," ",directory)
	quit(0 if error==OK else 1)
