extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
var clock:=0.0
var frames:Array=[]
var view
var output:="/tmp/original-fist-motion"
class FistMotionView extends Node2D:
 var owner_tree
 var rig=Rig.new()
 var sword=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/sword.png"))
 var fan=Rig.filtered_weapon(preload("res://assets/cultivation/avatars/fan.png"))
 func motion(style:String)->Dictionary:
  var t:=fposmod(float(owner_tree.clock),5.0)
  var m:={"action_kind":"basic","basic_style":style,"attack_style":style,"combat_move":"basic_sword_thrust" if style=="sword" else "basic_fan_sweep","combat_phase":"recovery","phase_progress":1.0,"combat_stance":1.0,"facing":1.0,"attack_amount":1.0,"defense_action":"ready","reaction_amount":0.0,"reaction_age":.06}
  if t<.6:m.combat_phase="windup";m.phase_progress=t/.6
  elif t<.9:m.combat_phase="strike";m.phase_progress=(t-.6)/.3
  elif t<1.15:m.combat_phase="contact";m.phase_progress=(t-.9)/.25
  elif t<2.3:m.combat_phase="recovery";m.phase_progress=(t-1.15)/1.15
  else:
   var weight:=smoothstep(2.3,2.7,t)*(1.0-smoothstep(4.2,5.0,t))
   m.defense_action="guard";m.reaction_amount=weight;m.contact_id="inspection_guard";m.impact_profile={"reaction_duration":.34,"reaction_magnitude":1.0,"knockback":1.0}
  return m
 func actor(style:String,feet:Vector2,scale_value:float,m:Dictionary):
  var visual:={"chest":"chest_blue" if style=="sword" else "chest_jade","legs":"legs_blue","feet":"feet_boots","weapon":"weapon_"+style}
  rig.draw_avatar_layers(self,feet,{},visual,m,scale_value)
  var w:=Rig.weapon_pose(m,scale_value,0,style)
  draw_set_transform(feet+Vector2(w.offset),float(w.rotation)+(.22 if style=="sword" else 0),Vector2.ONE*scale_value)
  var rect:=Rect2(-7.8,-53.7,26,76)
  if style=="fan":
   var fold:=lerpf(.17,1,float(w.fan_open));rect=Rect2(-23.3*fold,-25.6,48*fold,40)
  Rig.draw_held_weapon(self,sword if style=="sword" else fan,rect,style)
  draw_set_transform(Vector2.ZERO);Rig.draw_grip_front(self,feet,m,scale_value,0,style)
 func _draw():
  draw_rect(Rect2(0,0,1200,680),Color("eeeadd"))
  draw_string(Sans,Vector2(20,30),"原画拳头 · 原始大小 / 手腕连续转动 / 武器随握点移动",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("334b43"))
  draw_string(Sans,Vector2(20,56),"无特效动作检查：出手、回收、架起防守。此处展示动作相位，不是速度属性对比。",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("52665a"))
  for index in range(2):
   var style:="sword" if index==0 else "fan"
   var m:=motion(style)
   actor(style,Vector2(205+index*600,480),5.2,m)
   draw_rect(Rect2(index*600,480,600,200),Color("eeeadd"))
   actor(style,Vector2(180+index*600,652),1.0,m)
   draw_string(Sans,Vector2(20+index*600,510),("剑" if index==0 else "扇")+" · 上方 5.2× / 下方游戏原尺寸",HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("334b43"))
   var p:=Rig.sample_pose(m)
   var bend:=rad_to_deg(angle_difference(float(p.near_arm.lower_angle),float(p.near_arm.hand_angle)))
   draw_string(Sans,Vector2(295+index*600,610),"腕部弯曲 %.1f°"%bend,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color("52665a"))
  draw_line(Vector2(600,72),Vector2(600,665),Color("c4c7b8"),1)
  draw_rect(Rect2(0,0,1200,72),Color("eeeadd"))
  draw_string(Sans,Vector2(20,30),"原画拳头 · 原始大小 / 手腕连续转动 / 武器随握点移动",HORIZONTAL_ALIGNMENT_LEFT,-1,23,Color("334b43"))
  draw_string(Sans,Vector2(20,56),"无特效动作检查：出手、回收、架起防守。此处展示动作相位，不是速度属性对比。",HORIZONTAL_ALIGNMENT_LEFT,-1,17,Color("52665a"))
func _initialize():
 root.size=Vector2i(1200,680);root.position=Vector2i(30,80);root.mode=Window.MODE_WINDOWED
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
 DirAccess.make_dir_recursive_absolute(output)
 view=FistMotionView.new();view.owner_tree=self;root.add_child(view)
func _process(delta:float)->bool:
 if root.size!=Vector2i(1200,680):root.size=Vector2i(1200,680)
 clock+=delta
 if is_instance_valid(view):
  for style in ["sword","fan"]:
   var m:Dictionary=view.motion(style);var p:=Rig.sample_pose(m);var w:=Rig.weapon_pose(m)
   frames.append({"time":clock,"style":style,"motion":m,"hand_angle":p.near_arm.hand_angle,"forearm_angle":p.near_arm.lower_angle,"wrist":p.near_arm.wrist,"grip":w.offset})
  view.queue_redraw()
 if clock>=5.0:
  var file:=FileAccess.open(output.path_join("wrist-motion.json"),FileAccess.WRITE);file.store_string(JSON.stringify({"engine_time_scale":Engine.time_scale,"duration":clock,"frames":frames}));file.close();print("FIST_MOTION_DONE ",clock," root=",root.size," texture=",root.get_texture().get_size()," transform=",view.global_transform);quit()
 return false
