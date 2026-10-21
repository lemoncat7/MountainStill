extends SceneTree
## Native renderer proof: same sword at normal actor size and a magnified rig.
## Run without --headless. Writes user://basic-grip-proof/sword-grip-sheet.png.
const Rig=preload("res://scripts/character_sidewalk.gd")
class Proof extends Node2D:
 var rig=Rig.new()
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 var fan=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/fan.png"))
 var preview_style:="sword"
 func _ready()->void:
  for arg in OS.get_cmdline_user_args():
   if arg.begins_with("--style="):preview_style=arg.trim_prefix("--style=")
 func _draw()->void:
  draw_rect(Rect2(0,0,1440,860),Color("f1ecdf"))
  draw_string(ThemeDB.fallback_font,Vector2(24,28),preview_style.to_upper()+" | actual grip, shoulder / elbow / wrist tracks, full weight transfer",HORIZONTAL_ALIGNMENT_LEFT,-1,20,Color("294c49"))
  var sequence:=[
   ["Ready","basic_sword_thrust","recovery",1.0,0.0],
   ["Gather","basic_sword_thrust","windup",0.78,0.0],
   ["Extend","basic_sword_thrust","strike",0.65,15.0],
   ["Thrust","basic_sword_thrust","contact",0.3,23.0],
   ["Short cut","basic_sword_cut","contact",0.3,17.0],
   ["Lift","basic_sword_lift","contact",0.3,18.0],
   ["Recover","basic_sword_lift","recovery",0.65,5.1],
   ["Walking","","idle",0.0,0.0],
  ]
  if preview_style=="fan":
   sequence[0][1]="basic_fan_sweep";sequence[1][1]="basic_fan_sweep";sequence[2][1]="basic_fan_sweep";sequence[3][1]="basic_fan_sweep";sequence[3][0]="Open sweep"
   sequence[4][1]="basic_fan_flick";sequence[4][0]="Closed jab";sequence[5][1]="basic_fan_return";sequence[5][0]="Return";sequence[6][1]="basic_fan_return"
  for i in range(sequence.size()):
   var item:Array=sequence[i]
   var x:=90.0+float(i)*178.0
   draw_string(ThemeDB.fallback_font,Vector2(x-67,60),item[0],HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("294c49"))
   var motion:={"action_kind":"basic","basic_style":preview_style,"attack_style":preview_style,"combat_move":item[1],"combat_phase":item[2],"phase_progress":item[3],"actor_lunge":item[4],"combat_stance":1.0,"facing":1.0,"blend":0.0,"phase":0.0}
   if item[0]=="Walking":motion={"facing":1.0,"blend":1.0,"phase":0.3,"attack_style":preview_style}
   for row in range(2):
    var scale_value:=1.0 if row==0 else 2.4
    var feet:=Vector2(x,224 if row==0 else 682)
    draw_line(feet+Vector2(-65,0),feet+Vector2(95,0),Color("b7beb1"),1.0)
    rig.draw_avatar_layers(self,feet,{}, {"head":"head_pin","chest":"chest_blue","legs":"legs_jade","feet":"feet_boots"},motion,scale_value)
    var weapon:=Rig.weapon_pose(motion,scale_value,0.0,preview_style)
    var angle:float=weapon.rotation+(0.22 if preview_style=="sword" else 0.0)
    draw_set_transform(feet+Vector2(weapon.offset),angle,Vector2.ONE*scale_value)
    var rect:=Rect2(-7.8,-53.7,26,76)
    if preview_style=="fan":
     var open:=float(weapon.fan_open)
     rect=Rect2(-23.3*open,-25.6,48*open,40)
    draw_texture_rect(sword if preview_style=="sword" else fan,rect,false)
    draw_set_transform(Vector2.ZERO)
    Rig.draw_grip_front(self,feet,motion,scale_value,0.0,preview_style)
  draw_string(ThemeDB.fallback_font,Vector2(24,270),"Normal game size above / 2.4x rig inspection below. No trails or hit effects hide the pose.",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("52665a"))
  draw_string(ThemeDB.fallback_font,Vector2(24,820),"Fixed-length bones / original source art / actual phase-driven weapon module / hilt between rear palm and front fingers",HORIZONTAL_ALIGNMENT_LEFT,-1,16,Color("52665a"))
func _initialize()->void:
 root.size=Vector2i(1440,860);root.mode=Window.MODE_WINDOWED
 root.add_child(Proof.new());_finish.call_deferred()
func _finish()->void:
 await process_frame
 root.size=Vector2i(1440,860)
 await process_frame
 await create_timer(0.2).timeout
 await RenderingServer.frame_post_draw
 var image:=root.get_texture().get_image()
 var destination:="user://basic-grip-proof"
 var style:="sword"
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--capture-root="):destination=arg.trim_prefix("--capture-root=")
  if arg.begins_with("--style="):style=arg.trim_prefix("--style=")
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(destination))
 if image:print("BASIC_GRIP_PROOF:",image.save_png(destination+"/"+style+"-grip-sheet.png")," ",ProjectSettings.globalize_path(destination))
 quit()
