extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const OldRig=preload("res://tests/old_garment_registration.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var output:="/tmp/sleeve-socket-sheet.png"
var diagnostic:=false
var forward:=false
class PosePanel extends Control:
 var old:=false
 var garment:="chest_blue"
 var diagnostic:=false
 var forward:=false
 var rig
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 func _ready():
  rig=OldRig.new() if old else Rig.new();clip_contents=true
 func _draw():
  draw_rect(Rect2(Vector2.ZERO,size),Color("eeeadd"))
  var m:={"action_kind":"basic","basic_style":"sword","attack_style":"sword","combat_move":"basic_sword_thrust","combat_phase":"recovery","phase_progress":.8,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0,"defense_action":"guard","reaction_amount":1.0,"reaction_age":.06,"contact_id":"qa_guard_pose","impact_profile":{"reaction_duration":.34,"reaction_magnitude":1.0,"knockback":1.0}}
  if forward:m.defense_action="ready";m.reaction_amount=0.0;m.combat_phase="contact";m.phase_progress=0.0
  var r=Rig
  var feet:=Vector2(160,390)
  var visual:={"chest":garment,"legs":"legs_blue","weapon":"weapon_sword"}
  rig.draw_avatar_layers(self,feet,{},visual,m,5.2)
  var weapon:Dictionary=r.weapon_pose(m,5.2,0.0,"sword")
  r.draw_grip_back(self,feet,m,5.2,0.0,"sword")
  draw_set_transform(feet+Vector2(weapon.offset),float(weapon.rotation)+.22,Vector2.ONE*5.2)
  Rig.draw_held_weapon(self,sword,Rect2(-7.8,-53.7,26,76),"sword");draw_set_transform(Vector2.ZERO)
  r.draw_grip_front(self,feet,m,5.2,0.0,"sword")
  if diagnostic:
   var pose:Dictionary=r.sample_pose(m)
   for arm in [pose.far_arm,pose.near_arm]:
    var pts:=PackedVector2Array()
    for point in [arm.shoulder,arm.elbow,arm.wrist]:pts.append(feet+Vector2(point)*Rig.PIXEL_SCALE*5.2)
    draw_polyline(pts,Color("dd7d49"),1.5,true)
    for point in pts:draw_circle(point,3.0,Color("d05135"))
  draw_rect(Rect2(0,size.y-30,size.x,30),Color("eeeadd"))
  draw_string(Sans,Vector2(15,size.y-9),("旧袖口注册 · " if old else "修正袖口注册 · ")+{"chest_blue":"竹影蓝衣","chest_jade":"玉纹锦衣","":"赤膊肩部"}[garment],HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("334b43"))
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg=="--diagnostic":diagnostic=true
  if arg=="--forward":forward=true
 root.size=Vector2i(1200,720)
 var background:=ColorRect.new();background.color=Color("eeeadd");background.size=Vector2(1200,720);root.add_child(background)
 var title:=Label.new();title.position=Vector2(18,8);title.add_theme_font_override("font",Sans);title.add_theme_font_size_override("font_size",19);title.add_theme_color_override("font_color",Color("334b43"));title.text="袖口检查 · 同一骨架 / 仅对比服装注册 / 无特效";root.add_child(title)
 for row in range(2):
  for col in range(3):
   var panel:=PosePanel.new();panel.old=row==0;panel.garment=["chest_blue","chest_jade",""][col];panel.diagnostic=diagnostic;panel.forward=forward;panel.position=Vector2(col*400,45+row*335);panel.size=Vector2(390,330);root.add_child(panel)
 call_deferred("capture")
func capture():
 await process_frame;root.size=Vector2i(1200,720);await process_frame;await RenderingServer.frame_post_draw
 var e:=root.get_texture().get_image().save_png(output);print("SLEEVE_SOCKET_SHEET ",e);quit(0 if e==OK else 1)
