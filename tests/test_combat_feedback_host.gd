extends SceneTree
## Feedback is contact-driven and local. This does not judge animation quality.
const Impact=preload('res://scripts/combat_impact.gd')
var scene
var checks:=0
var failures:=0
func _initialize():call_deferred('run')
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func run():
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://feedback_host_isolated.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false;scene.set_process(false)
 scene._start_encounter()
 for i in range(2000):
  if scene.encounter_phase=='fight':break
  scene._process(.02)
 check(scene.encounter_phase=='fight','production route reaches duel')
 for i in range(2000):
  if scene.combat_hitstop>0.0:break
  scene._process(.01)
 check(scene.combat_hitstop>0.0,'actual resolved contact starts hitstop')
 var duel_time:float=scene.duel.elapsed
 var interface_time:float=scene.interface_clock
 var landscape_time:float=scene.elapsed
 var distance:float=scene.route_distance
 var resources:Dictionary=scene.duel.battle_resource_snapshot()
 var contact_id:String=str(scene.duel._last_contact.get('contact_id',''))
 var profile:Dictionary=scene.duel._last_contact.get('impact_profile',{})
 check(not profile.is_empty(),'resolved event has material and weight profile')
 var hold:float=minf(.005,scene.combat_hitstop*.5)
 var impact_age:float=float(scene.combat_impacts[-1].age)
 scene._process(hold)
 check(is_equal_approx(scene.duel.elapsed,duel_time),'hitstop holds actor timeline')
 check(scene.interface_clock>interface_time and scene.elapsed>landscape_time,'interface and ambient clock keep moving')
 check(is_equal_approx(scene.route_distance,distance),'battle has no camera or landscape jump')
 check(is_equal_approx(float(scene.combat_impacts[-1].age),impact_age),'contact strokes share local hold')
 check(str(scene.duel._last_contact.get('contact_id',''))==contact_id,'hitstop cannot replay contact')
 check(scene.duel.battle_resource_snapshot()==resources,'hitstop cannot recommit qi or cooldown')
 var old_count:int=scene.combat_impacts.size()
 scene._push_combat_feedback({'actor':'hero','target':'enemy','damage':0,'resolution':'dodge','move':'basic_sword_cut'})
 scene._push_combat_feedback({'actor':'hero','target':'enemy','damage':0,'resolution':'whiff','move':'basic_sword_cut'})
 check(scene.combat_impacts.size()==old_count,'dodge and whiff emit no contact burst')
 scene._process(scene.combat_hitstop+.03)
 check(scene.duel.elapsed>duel_time,'combat resumes after local hitstop')
 check(not scene.show_combat_move_labels,'silhouette remains readable without constant attack-name banner')
 var light:Dictionary=Impact.describe({'damage':3,'raw_damage':3,'resolution':'hit','move':'basic_unarmed_jab','actor':'hero','target':'enemy'})
 var heavy:Dictionary=Impact.describe({'damage':8,'raw_damage':8,'resolution':'hit','move':'moss_beast_boss_burst','actor':'enemy','target':'hero'})
 var blocked:Dictionary=Impact.describe({'damage':1,'raw_damage':8,'resolution':'guard','move':'basic_sword_cut','actor':'hero','target':'enemy'})
 var broken:Dictionary=Impact.describe({'damage':5,'raw_damage':5,'resolution':'guard','poise_broken':true,'move':'basic_sword_cut','actor':'hero','target':'enemy'})
 check(heavy.hitstop>light.hitstop and broken.hitstop>heavy.hitstop,'holds have genuinely distinct physical weight')
 check(blocked.kind=='block' and broken.kind=='guardbreak','guard and broken guard are separate events')
 scene.queue_free();await process_frame;await process_frame
 print('Combat feedback host: %d checks, %d failures'%[checks,failures]);quit(1 if failures else 0)
