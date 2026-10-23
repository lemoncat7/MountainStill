extends SceneTree
const MonsterRig=preload("res://scripts/monster_pose_renderer.gd")
const New=preload("res://scripts/melee_contact_geometry.gd")
const Rig=preload("res://scripts/character_sidewalk.gd")
var checks=0
var failures=0
func eq(a,b,label):
 checks+=1
 if a!=b:
  failures+=1
  if failures<10:push_error(label+" "+str([a,b]))
func _initialize():
 var rng=RandomNumberGenerator.new();rng.seed=929143
 var cache={}
 for i in range(220):
  var route="bamboo_pass" if i%2==0 else "cloud_slope"
  var family="moss_pounce" if i%2==0 else "crane_dive"
  var def={"route_id":route,"boss":i%3==0,"engagement_distance":rng.randf_range(70,150),"feet_y_delta":rng.randf_range(-12,12)}
  var enemy={"move_family":family,"combat_phase":"strike","phase_progress":rng.randf(),"monster_pose":{"step_cycle":rng.randf_range(-1,1)},"visual_rotation":rng.randf_range(-.5,.5),"visual_offset":Vector2(rng.randf_range(-15,15),rng.randf_range(-15,15))}
  var data=New._body_data(enemy,def)
  for k in range(-50,15):
   for eps in [-.000001,0.0,.000001]:
    var y=data.origin.y+k*4.0+eps
    eq(reference_front(y,data),New._front_at_y(y,data),"bin boundary "+str(i))
  eq(New._deformed_fronts.size()<=96,true,"bounded fronts")
  eq(New._deformed_front_bins.size(),New._deformed_fronts.size(),"paired bins")
 for i in range(100):
  var motion={"action_kind":"basic","attack_style":["sword","fan","unarmed"][i%3],"combat_phase":"contact","phase_progress":0.0,"attack_amount":1.0,"combat_stance":1.0,"strike_aim":rng.randf_range(-1.2,1.2),"aim_crouch":rng.randf_range(0,10),"approach_origin":rng.randf_range(-70,110),"entry_pose":{"shift":Vector2(i,i)},"entry_blend":0.0}
  eq(New._contact_pose(motion,cache),Rig.sample_contact_pose(motion),"pose original")
  motion.entry_pose.shift=Vector2(-i,i)
  motion.strike_aim+=.4
  eq(New._contact_pose(motion,cache),Rig.sample_contact_pose(motion),"pose mutation")
 for i in range(1300):
  var motion={"action_kind":"basic","combat_phase":"contact","phase_progress":float(i)/1300.0,"strike_aim":float(i)*.0001,"attack_amount":1.0,"combat_stance":1.0}
  eq(New._contact_pose(motion,cache),Rig.sample_contact_pose(motion),"pose eviction")
  eq(cache.size()<=1024,true,"pose bound")
 for route in ["bamboo_pass","creek_bridge","cloud_slope","ember_ruins","moon_marsh","summit_gate"]:
  for i in range(30):
   var def={"route_id":route,"boss":i%2==0,"engagement_distance":100.0,"feet_y_delta":0.0}
   var enemy={"pose_key":"attack","move_family":"moss_pounce" if route=="bamboo_pass" else "crane_dive","combat_phase":"contact","phase_progress":.7,"visual_offset":Vector2(0,-1),"visual_rotation":0.0,"clearance_weights":{"idle":.37,"windup":0.0,"attack":.83}}
   if route in ["bamboo_pass","cloud_slope"]:enemy.monster_pose={"step_cycle":.5}
   var preview=enemy.duplicate(true);preview.visual_offset=Vector2(4,-7)
   enemy.clearance_previews=[{"motion":preview,"weight":.33},{"motion":preview.duplicate(true),"weight":.81},{"motion":preview.duplicate(true),"weight":0.0}]
   var hero={"action_kind":"basic","attack_style":["sword","fan","unarmed"][i%3],"combat_phase":"contact","attack_amount":1.0,"combat_stance":1.0,"reaction_amount":.6,"defense_action":"hit","strike_aim":.2,"aim_crouch":5.0,"approach_origin":float(i)}
   eq(New.separate(enemy,hero,def),reference_separate(enemy,hero,def),"weighted preview "+route)
 print("PLANNING_CACHE_REGRESSION ",checks," checks ",failures," failures")
 quit(1 if failures else 0)

# Exhaustive row scan retained as an independent oracle for the exact Y bins.
# Shape construction itself is unchanged by this optimization.
func reference_front(y:float,data:Dictionary)->Dictionary:
 New._deformed_front_at_y(y,data)
 var shape_key:=str(data.key)+(str(data.motion.get("monster_pose",{})) if "_authored_" not in str(data.key) else "")+str(data.rotation)
 var shape:PackedVector2Array=New._deformed_fronts[shape_key]
 var origin:Vector2=data.origin
 var local_y:=y-origin.y
 var best:=Vector2(INF,y)
 for row in range(1,shape.size()):
  var a:=shape[row-1];var b:=shape[row]
  if not a.is_finite() or not b.is_finite():continue
  if local_y<minf(a.y,b.y)-.3 or local_y>maxf(a.y,b.y)+.3:continue
  var fraction:=clampf((local_y-a.y)/(b.y-a.y),0.0,1.0) if absf(b.y-a.y)>.001 else 0.0
  var x:=lerpf(a.x,b.x,fraction)+origin.x
  if x<best.x:best=Vector2(x,y)
 return {"point":best if best.is_finite() else Vector2(origin.x+Rect2(data.rect).position.x,y),"valid":best.is_finite()}

# Original per-probe weighted separation retained as the equivalence oracle.
func reference_separate(enemy:Dictionary,hero:Dictionary,definition:Dictionary)->Dictionary:
 var result:=enemy.duplicate()
 var articulated:=enemy.has("monster_pose") and MonsterRig.supports(str(definition.get("route_id","bamboo_pass")))
 var probes:=New.hero_body_fronts(hero) if articulated else PackedVector2Array([New.hero_front(hero)])
 if articulated and float(hero.get("reaction_amount",0.0))>0.0:
  # A hit bends the defender's head/chest but does not instantly free its
  # physical stance for the attacker to teleport into. Retain the ready
  # body envelope through that local recoil, alongside the visible body.
  var planted:=hero.duplicate();planted.reaction_amount=0.0;planted.defense_action="ready";planted.guard_broken=false
  probes.append_array(New.hero_body_fronts(planted))
 var correction:=0.0
 var weights:Dictionary=enemy.get("clearance_weights",{str(enemy.get("pose_key","idle")):1.0})
 # Articulated creatures have one actual source and deformed silhouette; the
 # old texture crossfade union is only needed for untouched legacy species.
 if articulated:
  weights={str(enemy.get("pose_key","idle")):1.0}
 for key in weights:
  if float(weights[key])<=0.0:continue
  var sample:=result.duplicate();sample.pose_key=key
  var source:=New._body_data(sample,definition)
  for nose in probes:
   var front:=New._front_at_y(nose.y,source)
   if bool(front.valid):correction=maxf(correction,maxf(0.0,nose.x+3.0-Vector2(front.point).x)*float(weights[key]))
 # Reserve/release the solid head/torso landing envelope smoothly. These
 # pure time samples anticipate a painted keypose or descending skull before
 # it reaches the body plane, rather than teleporting the root at that frame.
 var immediate_correction:=correction
 for preview in enemy.get("clearance_previews",[]):
  var sample:Dictionary=preview.motion.duplicate()
  sample.visual_offset=Vector2(Vector2(enemy.get("visual_offset",Vector2.ZERO)).x,Vector2(sample.visual_offset).y)
  var weight:=float(preview.weight)
  var source:=New._body_data(sample,definition)
  for nose in probes:
   var front:=New._front_at_y(nose.y,source)
   if bool(front.valid):correction=maxf(correction,maxf(0.0,nose.x+3.0-Vector2(front.point).x)*weight)
 result.visual_offset=Vector2(result.get("visual_offset",Vector2.ZERO))+Vector2(correction,0)
 result.body_separation=correction
 result.body_reservation=correction-immediate_correction
 var clearance:=INF
 var solid:=New._body_data(result,definition)
 for nose in probes:
  var current:=New._front_at_y(nose.y,solid)
  if bool(current.valid):clearance=minf(clearance,Vector2(current.point).x-nose.x)
 if is_finite(clearance):result.body_clearance=clearance
 return result
