extends SceneTree
const Impact=preload("res://scripts/combat_impact.gd")
const Hero=preload("res://scripts/character_sidewalk.gd")
const Beast=preload("res://scripts/monster_pose_renderer.gd")
var checks:=0
var failures:=0
func check(ok:bool,label:String)->void:
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize()->void:
 for kind in ["light","heavy","block","guardbreak"]:
  var event={"type":"contact","actor":"hero","target":"enemy","move":"basic_unarmed_jab" if kind=="light" else "thunder_strike","resolution":"guard" if kind=="block" else "hit","poise_broken":kind=="guardbreak","damage":12,"raw_damage":16,"contact_id":"onset:0","action_id":1,"hit_index":0,"enemy_visual_type":"moss_beast"}
  var profile:Dictionary=Impact.describe(event)
  var start:Dictionary=Impact.reaction(profile,0.0)
  print("ONSET_SAMPLE ",kind," impulse_at_contact=",start.impulse," compression=",start.compression)
  check(start.impulse==0.0 and start.compression==0.0,"no instantaneous compression jump "+kind)
  var previous:=0.0
  for i in range(11):
   var age:=.02*i/10.0
   var response:Dictionary=Impact.reaction(profile,age)
   check(float(response.impulse)>=previous,"compression builds monotonically in first 20ms")
   previous=float(response.impulse)
   check(float(response.amount)==float(profile.reaction_magnitude),"reaction timing/strength unchanged")
  check(is_equal_approx(previous,float(profile.reaction_magnitude)),"full authored compression reached by 20ms")
  for age in [.03,.06,.12,.20]:
   var expected:float=(1.0-smoothstep(float(profile.reaction_duration)*.10,float(profile.reaction_duration)*.55,age))*float(profile.reaction_magnitude)
   check(is_equal_approx(float(Impact.reaction(profile,age).impulse),expected),"existing later envelope preserved")
  var motion={"combat_phase":"idle","defense_action":"guard" if kind=="block" else "hit","reaction_amount":1.0,"reaction_age":0.0,"impact_profile":profile,"contact_id":"onset:0"}
  var beast:Dictionary=Beast.contact_reaction("bamboo_pass",motion)
  check(Vector2(beast.head_offset)==Vector2.ZERO and Vector2(beast.chest_offset)==Vector2.ZERO,"beast local joints start at current pose")
  if kind!="block":
   var hero:Dictionary=Hero._presentation_hit(motion,Hero._combat(motion))
   check(float(hero.head_recoil)==0.0,"hero head starts at current pose")
 print("CONTACT_ONSET: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
