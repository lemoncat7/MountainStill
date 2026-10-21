extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
class GarmentPanel extends Control:
 var index:=0
 var rig=Rig.new()
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("eeeadd"))
  var frames:=["idle","windup","strike","contact","recovery","idle"]
  var m:={"action_kind":"basic","basic_style":"sword","attack_style":"sword","combat_move":"basic_sword_thrust","combat_phase":frames[index],"phase_progress":.7,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0,"defense_action":"guard" if index in [1,4] else "ready","reaction_amount":1.0 if index in [1,4] else 0.0}
  var feet:=Vector2(155,317)
  var visual:={"chest":"chest_blue" if index%2==0 else "chest_jade","legs":"legs_blue" if index%3!=1 else "legs_jade","feet":"feet_cloth" if index%3==0 else "feet_boots","head":"head_pin" if index%2==0 else "head_crown","weapon":"weapon_sword"}
  rig.draw_avatar_layers(self,feet,{},visual,m,2.35)
  var w:=Rig.weapon_pose(m,2.35,0,"sword")
  Rig.draw_grip_back(self,feet,m,2.35,0,"sword")
  draw_set_transform(feet+Vector2(w.offset),float(w.rotation)+.22,Vector2.ONE*2.35);Rig.draw_held_weapon(self,sword,Rect2(-7.8,-53.7,26,76),"sword");draw_set_transform(Vector2.ZERO)
  Rig.draw_grip_front(self,feet,m,2.35,0,"sword")
  draw_line(Vector2(55,320),Vector2(310,320),Color("aab3a3"),1)
  draw_string(Sans,Vector2(16,345),["蓝衣 × 蓝裤 × 布履","玉衣 × 玉裤 × 长靴","蓝衣 × 蓝裤 × 长靴","玉衣 × 蓝裤 × 布履","蓝衣 × 玉裤 × 长靴","玉衣 × 蓝裤 × 长靴"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("334b43"))
func _initialize():
 root.size=Vector2i(1200,780)
 var bg:=ColorRect.new();bg.color=Color("eeeadd");bg.size=Vector2(1200,780);root.add_child(bg)
 var title:=Label.new();title.text="统一装备模板 · 共用肩 / 肘 / 腕 / 腰 / 膝 / 踝 / 足底坐标";title.position=Vector2(18,8);title.add_theme_font_override("font",Sans);title.add_theme_font_size_override("font_size",21);title.add_theme_color_override("font_color",Color("334b43"));root.add_child(title)
 for i in range(6):
  var p:=GarmentPanel.new();p.index=i;p.clip_contents=true;p.position=Vector2((i%3)*400,45+(i/3)*360);p.size=Vector2(390,355);root.add_child(p)
 call_deferred("capture")
func capture():
 await process_frame;root.size=Vector2i(1200,780);await process_frame;await RenderingServer.frame_post_draw
 var output:="/tmp/equipment-template.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 var error:=root.get_texture().get_image().save_png(output);print("TEMPLATE_SHEET ",error);quit(0 if error==OK else 1)
