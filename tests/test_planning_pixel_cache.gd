extends SceneTree
const MonsterRig=preload("res://scripts/monster_pose_renderer.gd")
const New=preload("res://scripts/melee_contact_geometry.gd")
var checks:=0
func eq(a:bool,b:bool):
 checks+=1
 assert(a==b,"opaque mismatch "+str(checks))
func _initialize():
 var rng=RandomNumberGenerator.new();rng.seed=929143
 for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
  for boss in [false,true]:
   for phase in ["idle","windup","strike","contact","recovery","defeated"]:
    for articulated in [false,true]:
     var enemy={"pose_key":"attack","combat_phase":phase,"phase_progress":.67,"defeat_amount":.8,"move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","visual_offset":Vector2(2.35,-1.22),"visual_rotation":.19}
     if articulated:enemy.monster_pose={"step_cycle":.5}
     var data=New._body_data(enemy,{"route_id":route,"boss":boss,"engagement_distance":123.456,"feet_y_delta":1.234})
     for i in range(512):
      var point=Vector2(rng.randf_range(-60,220),rng.randf_range(-220,40))
      var expected=reference_opaque(point,data)
      eq(New._opaque(point,data),expected)
      eq(New._opaque(point,data),expected)
     assert(New._pixel_masks.size()<=96)
 # Force cache eviction without changing the independently evaluated geometry.
 var data=New._body_data({"pose_key":"idle"},{"route_id":"bamboo_pass","boss":true})
 for i in range(110):
  data.pixel_mask_key="eviction-test-"+str(i)
  for j in range(20):
   var point=Vector2(rng.randf_range(0,180),rng.randf_range(-180,0))
   eq(New._opaque(point,data),reference_opaque(point,data))
  assert(New._pixel_masks.size()<=96)
 for route in ["bamboo_pass","cloud_slope"]:
  for style in ["unarmed","sword","fan"]:
   for phase in ["windup","strike","contact","recovery"]:
    var definition={"route_id":route,"boss":true,"engagement_distance":123.456}
    var enemy={"pose_key":"attack","combat_phase":phase,"phase_progress":.67,"move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","monster_pose":{"step_cycle":.5},"visual_offset":Vector2(2.35,-1.22),"visual_rotation":0.0}
    var preview=enemy.duplicate(true);preview.visual_offset=Vector2(4,-7)
    enemy.clearance_previews=[{"motion":preview,"weight":.8},{"motion":preview.duplicate(true),"weight":.5}]
    var hero={"action_kind":"basic","attack_style":style,"combat_phase":"contact","attack_amount":1.0,"combat_stance":1.0}
    checks+=1
    assert(New.fit_approach(hero,enemy,definition,0.0)==reference_fit(hero,enemy,definition,0.0),"fit diagnostic parity")
 print("PLANNING_PIXEL_CACHE ",checks," checks 0 failures")
 quit()

# Independent pre-cache opacity oracle. Keep operation order and thresholds.
func reference_opaque(world:Vector2,data:Dictionary)->bool:
 var local:Vector2=(world-Vector2(data.origin)).rotated(-float(data.rotation))
 var source:Vector2=(local-Rect2(data.rect).position)/Rect2(data.rect).size*256.0
 if "_authored_" in str(data.key):
  source-=Vector2(data.registration)
 elif bool(data.get("articulated",false)):
  var desired:=source
  # Invert the same local skin transform that paints the actual source pixels.
  # Core head/body mappings are rigid; joint blends converge within eight steps.
  for iteration in range(8):
   var error:=desired-MonsterRig.transform_point(source,str(data.key),data.motion)
   source+=error*.85
   if error.length_squared()<.04:break
 var uv:=source/256.0
 var image:Image=data.image
 var x:=int(floor(uv.x*image.get_width()));var y:=int(floor(uv.y*image.get_height()))
 # Decorative antlers, wings and detached missiles are not body contacts.
 if (not bool(data.get("articulated",false)) and x<int(data.skull[0])-3) or y<int(data.skull[1])-2:return false
 if bool(data.get("articulated",false)) and not MonsterRig.is_body_point(Vector2(x,y),str(data.key),data.motion):return false
 return x>=0 and x<image.get_width() and y>=0 and y<image.get_height() and image.get_pixel(x,y).a>=0.65

# Complete diagnostic path versus optimized fit-only omission.
func reference_fit(hero:Dictionary,enemy:Dictionary,definition:Dictionary,origin:float)->Dictionary:
 var best:={"cost":INF,"target":origin,"aim":0.0,"crouch":0.0}
 for crouch in [0.0,5.0,10.0]:
  for ai in [0,-1,1,-2,2,-3,3,-4,4,-5,5,-6,6]:
   var candidate:=hero.duplicate();candidate.strike_aim=float(ai)*0.2;candidate.aim_crouch=crouch
   var measured:=New.measure(candidate,enemy,definition)
   if not bool(measured.vertical_valid):continue
   var target:=clampf(float(measured.gap)+0.5,-70.0,110.0)
   candidate.approach_origin=target
   var final_enemy:=New.separate(enemy,candidate,definition)
   var final:=New.measure(candidate,final_enemy,definition)
   var residual:=absf(float(final.gap)) if bool(final.vertical_valid) else 100.0
   var cost:float=maxf(0.0,residual-2.0)*20.0+absf(float(ai))*0.45+crouch*0.16+absf(target-origin)*0.015
   if bool(final.contact):
    cost-=5.0
    if ai==0 and crouch==0.0:return {"cost":cost,"target":target,"aim":0.0,"crouch":0.0}
   if cost<float(best.cost):best={"cost":cost,"target":target,"aim":candidate.strike_aim,"crouch":crouch}
 return best
