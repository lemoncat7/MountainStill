extends SceneTree
const NewRig=preload("res://scripts/character_sidewalk.gd")
const OldRig=preload("res://tests/fixtures/character_sidewalk_comparison_current.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
static func motion(index:int)->Dictionary:
 var style:="fan" if index==2 else "sword"
 var m:={"action_kind":"basic","basic_style":style,"attack_style":style,"combat_move":"basic_sword_thrust" if style=="sword" else "basic_fan_sweep","combat_phase":"recovery","phase_progress":.8,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0,"defense_action":"guard","reaction_amount":1.0,"reaction_age":.06,"contact_id":"qa_guard_pose","impact_profile":{"reaction_duration":.34,"reaction_magnitude":1.0,"knockback":1.0}}
 if index in [1,2]:m.defense_action="ready";m.reaction_amount=0.0;m.combat_phase="contact";m.phase_progress=0.0
 return m
class FistComparePanel extends Control:
 var index:=0
 var old:=false
 var rig
 var rig_script
 var sword=NewRig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 var fan=NewRig.filtered_weapon(preload("res://assets/cultivation/avatars/fan.png"))
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("eeeadd"))
  var style:="fan" if index==2 else "sword"
  var m:Dictionary=load("res://tests/show_original_fist_compare.gd").motion(index)
  var feet:=Vector2(155,390)
  var visual:={"chest":"chest_jade" if index==2 else "chest_blue","legs":"legs_blue","weapon":"weapon_"+style}
  rig.draw_avatar_layers(self,feet,{},visual,m,5.2)
  var weapon:Dictionary=rig_script.weapon_pose(m,5.2,0,style)
  rig_script.draw_grip_back(self,feet,m,5.2,0,style)
  draw_set_transform(feet+Vector2(weapon.offset),float(weapon.rotation)+(.22 if style=="sword" else 0.0),Vector2.ONE*5.2)
  var rect:=Rect2(-7.8,-53.7,26,76)
  if style=="fan":
   var fold:=lerpf(.17,1.0,float(weapon.fan_open));rect=Rect2(-23.3*fold,-25.6,48*fold,40)
  rig_script.draw_held_weapon(self,sword if style=="sword" else fan,rect,style);draw_set_transform(Vector2.ZERO)
  rig_script.draw_grip_front(self,feet,m,5.2,0,style)
  draw_rect(Rect2(0,size.y-32,size.x,32),Color("eeeadd"))
  draw_string(Sans,Vector2(15,size.y-10),("旧：额外手形 · " if old else "新：原画拳头 · ")+["架剑","出剑","持扇"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("334b43"))
func _initialize():
 root.size=Vector2i(1200,740)
 var back:=ColorRect.new();back.size=Vector2(1200,740);back.color=Color("eeeadd");root.add_child(back)
 var title:=Label.new();title.text="原画握拳对照 · 同一关节姿势 / 同一角色与画面倍率 / 武器在拳后";title.position=Vector2(18,8);title.add_theme_font_override("font",Sans);title.add_theme_font_size_override("font_size",19);title.add_theme_color_override("font_color",Color("334b43"));root.add_child(title)
 for index in range(3):
  var m:=motion(index)
  var a:=OldRig.sample_pose(m);var b:=NewRig.sample_pose(m)
  for side in ["near_arm","far_arm"]:
   for joint in ["shoulder","elbow","wrist"]:assert(Vector2(a[side][joint]).distance_to(b[side][joint])<.00001)
   assert(absf(float(a[side].hand_angle)-float(b[side].hand_angle))<.00001)
  for row in range(2):
   var p:=FistComparePanel.new();p.index=index;p.old=row==0;p.rig_script=OldRig if p.old else NewRig;p.rig=p.rig_script.new();p.clip_contents=true;p.position=Vector2(index*400,45+row*345);p.size=Vector2(390,340);root.add_child(p)
 call_deferred("capture")
func capture():
 await process_frame;root.size=Vector2i(1200,740);await process_frame;await RenderingServer.frame_post_draw
 var path:="/tmp/original-fist-compare.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):path=arg.trim_prefix("--output=")
 var err:=root.get_texture().get_image().save_png(path);print("ORIGINAL_FIST_COMPARE ",err," same_joint_pose=true scale=5.2");quit(0 if err==OK else 1)
