extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
class GripPosePanel extends Control:
 var index:=0
 var rig=Rig.new()
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 var fan=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/fan.png"))
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("eeeadd"))
  var style:="sword" if index<3 else ("fan" if index<5 else "unarmed")
  var m:={"action_kind":"basic","basic_style":style,"attack_style":style,"combat_move":"basic_sword_thrust" if style=="sword" else ("basic_fan_sweep" if style=="fan" else "basic_unarmed_jab"),"combat_phase":"recovery","phase_progress":.8,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0,"defense_action":"guard","reaction_amount":1.0,"reaction_age":.06,"contact_id":"qa_guard_pose","impact_profile":{"reaction_duration":.34,"reaction_magnitude":1.0,"knockback":1.0}}
  if index==1:m.guard_contact_valid=true;m.guard_contact_point=Vector2(18,-31)
  if index in [2,4,5]:m.defense_action="ready";m.reaction_amount=0.0;m.combat_phase="contact";m.phase_progress=0.0
  var feet:=Vector2(155,390)
  var visual:={"chest":"chest_blue" if index<3 else "chest_jade","legs":"legs_blue","weapon":"weapon_"+style if style!="unarmed" else ""}
  rig.draw_avatar_layers(self,feet,{},visual,m,5.2)
  if style!="unarmed":
   var weapon:=Rig.weapon_pose(m,5.2,0,style)
   Rig.draw_grip_back(self,feet,m,5.2,0,style)
   draw_set_transform(feet+Vector2(weapon.offset),float(weapon.rotation)+(.22 if style=="sword" else 0.0),Vector2.ONE*5.2)
   var rect:=Rect2(-7.8,-53.7,26,76)
   if style=="fan":
    var fold:=lerpf(.17,1.0,float(weapon.fan_open));rect=Rect2(-23.3*fold,-25.6,48*fold,40)
   Rig.draw_held_weapon(self,sword if style=="sword" else fan,rect,style);draw_set_transform(Vector2.ZERO)
   Rig.draw_grip_front(self,feet,m,5.2,0,style)
  draw_rect(Rect2(0,size.y-31,size.x,31),Color("eeeadd"))
  draw_string(Sans,Vector2(15,size.y-9),["架剑握持","低位拦截握持","出剑握持","合扇防守握持","展扇出手握持","空手拳形（对照）"][index],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("334b43"))
func _initialize():
 root.size=Vector2i(1200,720)
 var back:=ColorRect.new();back.size=Vector2(1200,720);back.color=Color("eeeadd");root.add_child(back)
 var title:=Label.new();title.text="握持检查 · 实际角色 / 无特效 / 近侧手背 · 前臂与腕线";title.position=Vector2(18,8);title.add_theme_font_override("font",Sans);title.add_theme_font_size_override("font_size",19);title.add_theme_color_override("font_color",Color("334b43"));root.add_child(title)
 for index in range(6):
  var p:=GripPosePanel.new();p.index=index;p.clip_contents=true;p.position=Vector2((index%3)*400,45+(index/3)*335);p.size=Vector2(390,330);root.add_child(p)
 call_deferred("capture")
func capture():
 await process_frame;root.size=Vector2i(1200,720);await process_frame;await RenderingServer.frame_post_draw
 var path:="/tmp/integrated-grips.png"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):path=arg.trim_prefix("--output=")
 var err:=root.get_texture().get_image().save_png(path);print("INTEGRATED_GRIPS ",err);quit(0 if err==OK else 1)
