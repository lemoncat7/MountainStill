extends SceneTree
## Weapon-first free attack tracks, exact duel clock, UV-fold regression.
const Rig=preload("res://scripts/character_sidewalk.gd")
const BASICS:={
 "sword":["basic_sword_cut","basic_sword_thrust","basic_sword_lift"],
 "fan":["basic_fan_sweep","basic_fan_flick","basic_fan_return"],
 "unarmed":["basic_unarmed_jab","basic_unarmed_palm"],
}
var checks:=0
var failures:=0
func _initialize()->void:
 _test_distinct_forms()
 _test_weapon_priority()
 _test_contact_and_bones()
 _test_independent_guard()
 _test_cast_silhouettes()
 _test_grip_safety()
 _test_mesh_folds()
 print("Basic attack rig: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func motion(style:String,move:String,phase_name:String="contact",progress:float=0.5)->Dictionary:
 return {"action_kind":"basic","basic_style":style,"attack_style":style,"combat_move":move,"combat_phase":phase_name,"phase_progress":progress,"combat_stance":1.0,"attack_amount":1.0,"clock":0.0,"facing":1.0}
func _test_distinct_forms()->void:
 var global_signatures:={}
 for style in BASICS:
  for move in BASICS[style]:
   var m:=motion(style,move)
   var p:=Rig.sample_pose(m)
   var signature:=str([p.near_arm.wrist,p.far_arm.wrist,p.near_arm.hand_angle,p.far_arm.hand_angle,p.body_angle,p.shift,p.near_leg.ankle,p.far_leg.ankle])
   check(not global_signatures.has(signature),"every basic owns actual distinct joint tracks: "+move)
   global_signatures[signature]=true
 var sweep:=Rig.weapon_pose(motion("fan","basic_fan_sweep"),1.0,0.0,"fan")
 var jab:=Rig.weapon_pose(motion("fan","basic_fan_flick"),1.0,0.0,"fan")
 check(sweep.fan_open>0.99 and jab.fan_open<0.2,"fan sweep opens; jab folds actual host-consumed art")
 check(sweep.grip=="open" and jab.grip=="closed","fan grip state follows real geometry")
 var fist:=Rig.sample_pose(motion("unarmed","basic_unarmed_jab"))
 var palm:=Rig.sample_pose(motion("unarmed","basic_unarmed_palm"))
 check(fist.combat.attack_hand=="far" and palm.combat.attack_hand=="near","empty-hand chain alternates rear knuckle and lead palm")
 check(palm.near_arm.hand_form=="palm" and fist.far_arm.hand_form=="fist","palm replaces fist silhouette only for actual palm contact")
 check(preload("res://scripts/melee_contact_geometry.gd").attack_points(motion("unarmed","basic_unarmed_palm"))[0].x>preload("res://scripts/melee_contact_geometry.gd").attack_points(motion("unarmed","basic_unarmed_jab"))[0].x+2.0,"painted palm tip reaches farther than short rear knuckle")
func _test_weapon_priority()->void:
 for technique in ["mist","petal","ember","stillness","breath","frost","thunder","barrier","mending"]:
  for style in ["sword","fan"]:
   var m:=motion(style,BASICS[style][0]);m.technique=technique
   var neutral:=motion(style,BASICS[style][0])
   check(Rig.sample_pose(m)==Rig.sample_pose(neutral),"selected heart/spell cannot override basic grip "+technique+"/"+style)
   check(not Rig.weapon_pose(m,1.0,0.0,style).stowed,"basic retains equipped weapon "+technique+"/"+style)
 var sword:=motion("sword","basic_sword_thrust","windup",0.7)
 var fan:=motion("fan","basic_fan_sweep","windup",0.7)
 var wrong:=sword.duplicate();wrong.basic_form="petal"
 check(Rig.sample_pose(wrong)==Rig.sample_pose(sword),"incompatible basic form is ignored")
 var compatible:=sword.duplicate();compatible.basic_form="mist"
 check(Rig.sample_pose(compatible)!=Rig.sample_pose(sword),"explicit compatible sword art changes actual gathering joints")
 compatible=fan.duplicate();compatible.basic_form="petal"
 check(Rig.sample_pose(compatible)!=Rig.sample_pose(fan),"explicit compatible fan art changes actual gathering joints")
func _test_contact_and_bones()->void:
 for style in BASICS:
  for move in BASICS[style]:
   for phase_name in ["windup","strike","contact","recovery"]:
    for i in range(21):
     var m:=motion(style,move,phase_name,float(i)/20.0)
     var p:=Rig.sample_pose(m)
     for name in ["near_arm","far_arm"]:
      var arm:Dictionary=p[name]
      check(absf(arm.shoulder.distance_to(arm.elbow)-42.0)<0.0001,"basic upper arm never stretches")
      check(absf(arm.elbow.distance_to(arm.wrist)-Vector2(10,36).length())<0.0001,"basic forearm never stretches")
      check(arm.wrist.is_finite(),"all hand samples remain finite")
      check(absf(angle_difference(arm.lower_angle,arm.hand_angle))<=0.561,"anatomical fist never inherits inverted blade axis")
     for name in ["near_leg","far_leg"]:
      var leg:Dictionary=p[name]
      check(absf(leg.hip.distance_to(leg.knee)-Rig.UPPER_LENGTH)<0.001,"stance retains upper leg length")
      check(absf(leg.knee.distance_to(leg.ankle)-Rig.LOWER_LENGTH)<0.001,"stance retains lower leg length")
      check(absf(leg.ankle.y-Rig.REST_ANKLE.y)<0.001,"no-lunge stance keeps both soles grounded")
     var arm:Dictionary=p.far_arm if p.combat.attack_hand=="far" else p.near_arm
     check(Rig.attachment_offset(Vector2.ZERO,m).is_equal_approx(arm.wrist*Rig.PIXEL_SCALE),"attachment follows active near/far hand")
     if phase_name=="contact":check(is_equal_approx(p.combat.reach,1.0),"actual damage window holds full physical reach")
   for boundary in [["windup",1.0,"strike",0.0],["strike",1.0,"contact",0.0],["contact",1.0,"recovery",0.0]]:
    var a:=Rig.sample_pose(motion(style,move,boundary[0],boundary[1]))
    var b:=Rig.sample_pose(motion(style,move,boundary[2],boundary[3]))
    check(a.near_arm.wrist.distance_to(b.near_arm.wrist)<0.001 and a.far_arm.wrist.distance_to(b.far_arm.wrist)<0.001,"phase boundaries join without a limb jump "+move)
func _test_independent_guard()->void:
 for move in BASICS.unarmed:
  var base:=motion("unarmed",move)
  var guarding:=base.duplicate();guarding.defense_action="guard";guarding.reaction_amount=1.0
  var a:=Rig.sample_pose(base);var b:=Rig.sample_pose(guarding)
  var active:="far_arm" if a.combat.attack_hand=="far" else "near_arm"
  var free:="near_arm" if active=="far_arm" else "far_arm"
  check(a[active].wrist.distance_to(b[active].wrist)<a[free].wrist.distance_to(b[free].wrist),"concurrent guard preserves striking hand and uses free hand "+move)
func _test_cast_silhouettes()->void:
 var signatures:={}
 for move in ["ember_palm","frost_seal","thunder_strike","barrier_guard","mending_bloom"]:
  var m:=motion("sword",move);m.action_kind="defense" if move=="barrier_guard" else "utility" if move=="mending_bloom" else "spell"
  var p:=Rig.sample_pose(m)
  var signature:=str([p.near_arm.wrist,p.near_arm.hand_angle,p.far_arm.wrist])
  check(not signatures.has(signature),"each active cast has different physical gesture "+move)
  signatures[signature]=true
  check(Rig.weapon_pose(m).stowed,"two-hand and spell casts sheath equipped sword "+move)
  check(absf(p.body_angle)<0.16,"cast does not fling oversized head "+move)
func _test_grip_safety()->void:
 var head:Image=load("res://assets/cultivation/sidewalk/head.png").get_image()
 for move in BASICS.sword+["mist_thrust","mist_lift","mist_combo","weapon_sword_pierce"]:
  for phase_name in ["windup","strike","contact","recovery"]:
   for i in range(21):
    var progress:=float(i)/20.0
    var reach:=smoothstep(0.0,1.0,progress) if phase_name=="strike" else 1.0 if phase_name=="contact" else 1.0-smoothstep(0.0,1.0,progress) if phase_name=="recovery" else 0.0
    for defense in ["ready","guard","dodge","hit"]:
     var m:=motion("sword",move,phase_name,progress)
     if not move.begins_with("basic_"):m.action_kind="weapon_art"
     m.actor_lunge=23.0*reach;m.defense_action=defense;m.reaction_amount=1.0 if defense!="ready" else 0.0
     var pose:=Rig.sample_pose(m)
     var weapon:=Rig.weapon_pose(m)
     var intersects:=false
     # Read the actual painted head coverage. Sample the visible blade from
     # guard to tip, including a small width, under the exact body transform.
     for part in range(10,50,2):
      for edge in [-0.7,0.0,0.7]:
       var world:Vector2=(weapon.offset+Vector2(edge,-part).rotated(float(weapon.rotation)+0.22))/Rig.PIXEL_SCALE
       var body:Vector2=Rig.HIP+(world-pose.shift-Rig.HIP).rotated(-float(pose.body_angle))
       var uv:Vector2=(body-Vector2(-150,-489))/Vector2(267,300)
       if uv.x>=0.0 and uv.x<1.0 and uv.y>=0.0 and uv.y<1.0:
        intersects=intersects or head.get_pixel(int(uv.x*head.get_width()),int(uv.y*head.get_height())).a>0.7
     check(not intersects,"blade stays outside actual head/face art in "+move+"/"+phase_name+"/"+defense)
 var ready:=motion("sword","basic_sword_thrust","windup",0.0)
 var normal:=Rig.weapon_pose(ready)
 for phase_name in ["windup","recovery"]:
  var cast:=motion("sword","ember_palm",phase_name,0.0 if phase_name=="windup" else 1.0)
  cast.action_kind="spell"
  var stow:=Rig.weapon_pose(cast)
  check(stow.offset.distance_to(normal.offset)<0.001,"spell weapon transition meets ready grip without teleport")
  check(absf(angle_difference(stow.rotation,normal.rotation+0.22))<0.001,"spell draw/sheath rotation meets ready blade without snap")

func _test_mesh_folds()->void:
 var uv:=PackedVector2Array([Vector2.ZERO,Vector2.RIGHT,Vector2.ONE,Vector2.DOWN])
 for points in [PackedVector2Array([Vector2.ZERO,Vector2(40,0),Vector2(40,0.00000001),Vector2(0,0.00000001)]),PackedVector2Array([Vector2.ZERO,Vector2(40,8),Vector2(0,8),Vector2(40,0)]),PackedVector2Array([Vector2.ZERO,Vector2(40,0),Vector2(20,0),Vector2(0,8)])]:
  var triangles:=Rig._quad_triangles(points,uv)
  check(not triangles.is_empty(),"nearly collinear and folded strips keep visible texture coverage")
  for triangle in triangles:
   var vertices:PackedVector2Array=triangle.vertices
   check((vertices[1]-vertices[0]).cross(vertices[2]-vertices[0])>0.0,"explicit submitted triangles always nondegenerate and consistently wound")
   for i in range(3):check(uv[points.find(vertices[i])]==triangle.uv[i],"every visible triangle retains source UV at its own vertex")
 # Exhaust near-collinear/overlap IK poses including simultaneous defenses.
 var moves:=BASICS.sword+BASICS.fan+BASICS.unarmed+["mist_thrust","mist_lift","mist_combo","petal_step","petal_counter","ember_palm","frost_seal","thunder_strike","barrier_guard","mending_bloom"]
 for move in moves:
  var style:="fan" if "fan" in move or "petal" in move else "unarmed" if "unarmed" in move else "sword"
  for phase_name in ["windup","strike","contact","recovery"]:
   for i in range(13):
    for defense in ["ready","guard","dodge","hit"]:
     var m:=motion(style,move,phase_name,float(i)/12.0)
     if not move.begins_with("basic_"):m.action_kind="spell"
     m.defense_action=defense;m.reaction_amount=0.72;m.actor_lunge=23.0
     var p:=Rig.sample_pose(m)
     for name in ["near_arm","far_arm"]:
      for row in range(32):
       var top:=float(row)/32.0*396.0;var bottom:=float(row+1)/32.0*396.0
       var source:=PackedVector2Array([Vector2(0,top),Vector2(Rig.EquipmentTemplate.ARM_CANVAS.x,top),Vector2(Rig.EquipmentTemplate.ARM_CANVAS.x,bottom),Vector2(0,bottom)])
       var points:=PackedVector2Array()
       for point in source:points.append(Rig._skin_arm(point,p[name]))
       for triangle in Rig._quad_triangles(points,uv):
        var v:PackedVector2Array=triangle.vertices
        check(v[0].is_finite() and v[1].is_finite() and v[2].is_finite(),"folded limb mesh is finite")
        check((v[1]-v[0]).cross(v[2]-v[0])>0.0,"all articulated skin triangles are explicit and nonzero")
