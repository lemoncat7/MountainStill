extends SceneTree
const Content=preload("res://scripts/cultivation_content.gd")
class ProbeHost extends "res://scripts/cultivation.gd":
 var checks:=0
 var failures:=0
 var early_enemy:=0
 var early_hero:=0
 var expired:=0
 var contacts:Array=[]
 func check(ok:bool,label:String):
  checks+=1
  if not ok:failures+=1;push_error(label)
 func _present_duel_contact(e:Dictionary):
  var previous:Array=[combat_number,combat_number_time,hero_damage,hero_resolution,hero_poise_broken,hero_hit]
  super._present_duel_contact(e)
  contacts.append([e.contact_id,e.time,e.actor,e.target,e.resolution,e.damage,e.hero_hp,e.enemy_hp,e.get("poise_broken",false)])
  check(vitality==float(e.hero_hp) and enemy_hp==float(e.enemy_hp),"HP remains authoritative even on whiff")
  if e.resolution=="whiff":
   if e.target=="enemy":
    check([combat_number,combat_number_time]==previous.slice(0,2),"whiff preserves enemy label and exact remaining lifetime")
    if float(previous[1])>0:early_enemy+=1
    else:expired+=1;check(combat_number_time==0,"expired enemy popup stays expired")
   else:
    check([hero_damage,hero_resolution,hero_poise_broken,hero_hit]==previous.slice(2,6),"whiff preserves hero label and exact remaining lifetime")
    if float(previous[5])>0:early_hero+=1
    else:expired+=1;check(hero_hit==0,"expired hero popup stays expired")
  elif e.target=="enemy":check(combat_number_time==.8 and combat_number.contains(str(e.damage)),"new real enemy outcome replaces prior label")
  elif e.actor=="enemy":check(hero_hit==1 and hero_damage==e.damage,"new real hero outcome replaces prior label")
 func _complete_duel():encounter_phase="qa_finished"
 func _persist_battle_resources():pass # Isolated display replay does not write a formal campaign.
func _initialize():call_deferred("run")
func run():
 var data:Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://tests/fixtures/whiff_feedback_replays.json"))
 var checks:=0;var failures:=0;var early_enemy:=0;var early_hero:=0;var expired:=0
 for row in data.encounters:
  var native:Dictionary={}
  for e in Content.STAGES[row.route].monsters:
   if e.id==row.enemy_id:native=e
  var h=ProbeHost.new();h.state.save_path="user://whiff_feedback_test.json";root.add_child(h);await process_frame;h.set_process(false);h.demo=true;h.paused=false
  for key in ["id","hp","attack","defense","attack_module_id"]:h.check(native.get(key)==row.enemy_definition.get(key),"replay uses current real enemy: "+key)
  h.encounter_active=true;h.encounter_phase="fight";h.meditation_amount=0;h.world_route=row.route;h.route_boss=bool(row.boss);h.route_enemy_definition=row.enemy_definition.duplicate(true)
  h.character_x=390;h.character_y=230;h.encounter_enemy_x=390+float(row.enemy_definition.engagement_distance)
  h.duel.start(row.hero_stats,row.enemy_definition,row.technique,str(row.equipment.get("weapon","")),int(row.duel_seed));h.duel_pose=h.duel.pose()
  for tick in range(7200):
   if h.duel.finished:break
   h._update_encounter(1.0/60.0)
  h.check(h.duel.victory and absf(h.duel.elapsed-float(row.seconds))<.00011,"earned replay outcome and duration unchanged")
  h.encounter_active=false;h._update_encounter(2.0)
  h.check(h.combat_number_time==0 and h.hero_hit==0,"all labels still expire through unchanged host clock")
  print("WHIFF_TRACE ",row.enemy_id," ",JSON.stringify(h.contacts).sha256_text()," seconds=",h.duel.elapsed)
  checks+=h.checks;failures+=h.failures;early_enemy+=h.early_enemy;early_hero+=h.early_hero;expired+=h.expired
  h.queue_free();await process_frame;await process_frame
 checks+=1
 if early_enemy<2 or early_hero<1 or expired<1:failures+=1;push_error("real two-sided early and expired cases must execute")
 print("WHIFF_FEEDBACK checks=%d failures=%d early_enemy=%d early_hero=%d expired=%d"%[checks,failures,early_enemy,early_hero,expired]);quit(1 if failures else 0)
