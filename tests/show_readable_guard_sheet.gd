extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const OldRig=preload("res://tests/baseline_guard_rig.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var output:="/tmp/readable-guard-sheet.png"
class Sheet extends Node2D:
 var before=OldRig.new()
 var after=Rig.new()
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 func _draw():
  draw_rect(Rect2(0,0,1200,760),Color("eeeadd"))
  draw_string(Sans,Vector2(22,28),"格挡姿态对照 · 同一输入 / 原生角色 2.3 倍 / 无特效",HORIZONTAL_ALIGNMENT_LEFT,-1,21,Color("334b43"))
  draw_string(Sans,Vector2(22,51),"姿态检查样本：接住来袭 → 肩臂承压 → 保持架势；不以光效代替格挡。",HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("6d786b"))
  for row in range(2):
   for col in range(3):
    var x:=40+col*400
    var feet:=Vector2(x+125,390+row*350)
    draw_string(Sans,Vector2(x,82+row*350),("修改前 · " if row==0 else "修改后 · ")+["接住来袭","沉肩承压","持架卸力"][col],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("38534a"))
    draw_line(feet+Vector2(-70,0),feet+Vector2(170,0),Color("acb5a4"),1)
    var m:={"action_kind":"basic","basic_style":"sword","attack_style":"sword","combat_move":"basic_sword_thrust","combat_phase":"recovery","phase_progress":.8,"combat_stance":1.0,"attack_amount":1.0,"facing":1.0,"defense_action":"guard","reaction_amount":1.0,"reaction_age":[0.0,.07,.17][col],"contact_id":"qa_guard_pose","impact_profile":{"reaction_duration":.34,"reaction_magnitude":1.0,"knockback":1.0}}
    var r=OldRig if row==0 else Rig
    var avatar=before if row==0 else after
    var weapon:Dictionary=r.weapon_pose(m,2.3,0.0,"sword")
    avatar.draw_avatar_layers(self,feet,{}, {"head":"head_pin","chest":"chest_blue","legs":"legs_blue","weapon":"weapon_sword"},m,2.3)
    if row==1:Rig.draw_grip_back(self,feet,m,2.3,0.0,"sword")
    draw_set_transform(feet+Vector2(weapon.offset),float(weapon.rotation)+.22,Vector2.ONE*2.3)
    if row==0:draw_texture_rect(sword,Rect2(-7.8,-53.7,26,76),false)
    else:Rig.draw_held_weapon(self,sword,Rect2(-7.8,-53.7,26,76),"sword")
    draw_set_transform(Vector2.ZERO)
    r.draw_grip_front(self,feet,m,2.3,0.0,"sword")
func _initialize():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 root.size=Vector2i(1200,760);root.add_child(Sheet.new());call_deferred("capture")
func capture():
 await process_frame;root.size=Vector2i(1200,760);await process_frame;await RenderingServer.frame_post_draw
 var e:=root.get_texture().get_image().save_png(output)
 print("GUARD_SHEET_SAVED ",e," ",output);quit(0 if e==OK else 1)
