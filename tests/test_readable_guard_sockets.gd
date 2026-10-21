extends SceneTree
const Rig=preload("res://scripts/character_sidewalk.gd")
const Before=preload("res://tests/baseline_guard_rig.gd")
var checks:=0
var errors:Array[String]=[]
func expect(ok:bool,label:String):
 checks+=1
 if not ok and errors.size()<30:errors.append(label)
func _initialize():
 var styles:={"sword":["basic_sword_cut","basic_sword_thrust","basic_sword_lift"],"fan":["basic_fan_sweep","basic_fan_flick"],"unarmed":["basic_unarmed_jab","basic_unarmed_palm"]}
 for style in styles:
  for move in styles[style]:
   for phase in ["idle","windup","strike","contact","recovery"]:
    for frame in range(41):
     for defense in ["ready","guard","hit","dodge"]:
      var m:={"action_kind":"basic","attack_style":style,"basic_style":style,"combat_move":move,"combat_phase":phase,"phase_progress":frame/40.0,"combat_stance":1.0,"attack_amount":1.0,"defense_action":defense,"reaction_amount":.72,"facing":1.0}
      var p:=Rig.sample_pose(m)
      var authority:=Rig.sample_contact_pose(m)
      var authority_geometry:=authority.duplicate(true)
      # New render-only annotations are not contact geometry. Compare every
      # established pose/combat field and all joints exactly as before.
      authority_geometry.combat.erase("wrist_flex")
      authority_geometry.combat.erase("contact_authority")
      expect(authority_geometry==Before.sample_pose(m),"all authority joints remain baseline")
      for key in ["near_arm","far_arm"]:
       var arm:Dictionary=p[key]
       expect(absf(Vector2(arm.shoulder).distance_to(arm.elbow)-42.0)<.002,"render upper arm never stretches")
       expect(absf(Vector2(arm.elbow).distance_to(arm.wrist)-Vector2(10,36).length())<.002,"render forearm never stretches")
       expect(absf(angle_difference(float(arm.lower_angle),float(arm.hand_angle)))<=.421,"re-solved wrist stays anatomical")
      var slot:=Rig.shoulder_surface_point(Vector2(-24,-160),p,true)
      expect(slot.distance_to(p.near_arm.shoulder)<.001,"garment armhole is exactly at visible shoulder joint")
      expect(Rig.shoulder_surface_point(Vector2(-18,-177),p,false).distance_to(p.near_arm.shoulder)<.001,"bare shoulder patch follows same anatomical joint")
      var grip:=Rig.weapon_pose(m,1,0,style,p)
      var active:Dictionary=p.far_arm if str(p.combat.attack_hand)=="far" else p.near_arm
      expect(Vector2(grip.offset).distance_to(Vector2(active.wrist)*Rig.PIXEL_SCALE)<.001,"visible weapon remains at the actual re-solved painted fist joint")
      expect(absf(float(p.near_leg.ankle.y)-float(authority.near_leg.ankle.y))<.002,"root presentation never lifts planted lead sole")
      # Actual local garment quads retain winding through raised/extended arms.
      for row in range(4):
       for col in range(4):
        var v:=Vector2(-44+col*23,-204+row*28)
        var a:=Rig.shoulder_surface_point(v,p,true)
        var b:=Rig.shoulder_surface_point(v+Vector2(23,0),p,true)
        var c:=Rig.shoulder_surface_point(v+Vector2(23,28),p,true)
        expect((b-a).cross(c-a)>0,"shoulder garment mesh never inverts")
 var images:={}
 for name in ["arm","sleeve_blue","sleeve_jade"]:images[name]=load(Rig.EquipmentTemplate.ASSET_ROOT+name+".png").get_image()
 var center:=alpha_center(images.arm,38)
 expect(absf(alpha_center(images.sleeve_blue,38)-center)<=.5,"blue sleeve cap registers to bare shoulder paint")
 expect(absf(alpha_center(images.sleeve_jade,38)-center)<=.5,"jade sleeve cap registers to bare shoulder paint")
 for error in errors:push_error(error)
 print("READABLE_GUARD_SOCKETS %d checks, %d recorded failures"%[checks,errors.size()]);quit(1 if not errors.is_empty() else 0)
func alpha_center(image:Image,y:int)->float:
 var first:=-1;var last:=-1
 for x in range(image.get_width()):
  if image.get_pixel(x,y).a>.5:
   if first<0:first=x
   last=x
 return (first+last)/2.0
