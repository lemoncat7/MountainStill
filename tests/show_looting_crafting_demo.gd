extends SceneTree
## Production host playback from legally earned native-HP boss checkpoints.
## Only page/button inputs and chapter selection are directed; all fight rules,
## rendering, search movement/timers and inventory mutations remain production.
const Sans=preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const Plan=preload("res://tests/campaign_build_plan.gd")
class AuditDuel extends "res://scripts/duel_timeline.gd":
 var observed_events:Array[Dictionary]=[]
 func advance(delta:float)->Array[Dictionary]:
  var result:=super.advance(delta);observed_events.append_array(result);return result
var scene
var output:="/tmp/looting-crafting-demo"
var checkpoints:="/tmp/looting-crafting-checkpoints"
var events:Array=[]
var frames:Array=[]
var actions:Array=[]
var bouts:Array=[]
var clock:=0.0
var bout_index:=-1
var route:=""
var finished:=false
var failed:=false
var mode:=""
var mode_time:=0.0
var banner:Label
var details:Label
var metadata:Dictionary
var captured:Dictionary={}
var craft_step:=0
var crafted_id:=-1
var before_craft:Dictionary={}
var after_craft:Dictionary={}
var break_fixture:Dictionary={}
func _initialize():call_deferred("start")
func start():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="):output=arg.trim_prefix("--output=")
  if arg.begins_with("--checkpoints="):checkpoints=arg.trim_prefix("--checkpoints=")
 DirAccess.make_dir_recursive_absolute(output)
 metadata=Plan.measurement_metadata()
 scene=load("res://main.tscn").instantiate();scene.state.save_path="user://loot_native_qa_only.json";root.add_child(scene)
 await process_frame
 scene.demo=true;scene.get_window().size=Vector2i(1200,320);scene.size=Vector2(1200,320);scene.get_window().transparent_bg=false
 scene.strip=true;scene.desktop.transparent_enabled=true;scene.show_combat_move_labels=false
 RenderingServer.set_default_clear_color(Color("#e8e7df"))
 banner=Label.new();banner.position=Vector2(17,4);banner.add_theme_font_override("font",Sans);banner.add_theme_font_size_override("font_size",11);banner.add_theme_color_override("font_color",Color("#354e43"));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(banner)
 details=Label.new();details.position=Vector2(17,21);details.add_theme_font_override("font",Sans);details.add_theme_font_size_override("font_size",10);details.add_theme_color_override("font_color",Color("#506356"));details.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(details)
 begin_bout()
func begin_bout():
 bout_index+=1
 if bout_index>=2:start_crafting();return
 route=["bamboo_pass","cloud_slope"][bout_index]
 var setup:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(checkpoints.path_join(route+"-setup.json")))
 scene._reset_presentation();scene._close_drawer();scene.drawer_alpha=0.0
 scene.state.save_path=checkpoints.path_join(route+"-checkpoint.json")
 var loaded:Dictionary=scene.state.load_game()
 if not bool(loaded.get("loaded",false)):failed=true;finish();return
 scene.state.save_path="user://loot_native_qa_only.json";scene.state.settings.paused=false;scene.paused=false;scene.state.auto_advance=false
 scene.duel=AuditDuel.new();scene._volume();scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=0.0;scene.meditation_settle=0.0
 scene._start_encounter();scene.vitality=float(setup.hp)
 # This earned checkpoint is already past the first two enemies and route
 # opportunity. Frame the boss arena directly rather than replay home portals.
 # No combat clock, enemy definition, contact result or search timer is edited.
 scene.world_route=route;scene.route_distance=float(scene.ROUTE_EVENTS[2]);scene.character_x=scene.ROUTE_HERO_X
 scene._prepare_stage_monster();scene._begin_duel();scene.duel_pose=scene.duel.pose();scene.side_motion.merge(scene.duel_pose.hero,true)
 banner.text="真实所得存档 · %s · 原生气血 / 正常速度"%("普通格挡 → 反击（未装备主动护元）" if bout_index==0 else "主动护元 · 透明微光屏障 / 实际吸伤")
 details.text="实际战斗与搜寻所得；无注入材料或宝物，首领气血与伤害未改。" if bout_index==0 else "保留前战气血与真气；本段主动栏只带护元。胜后走近搜寻，再把材料做成可穿装备。"
 bouts.append({"route":route,"start":clock,"setup":setup,"materials_before":scene.state.materials.to_dict(),"hp_start":scene.vitality})
 mode="battle";mode_time=clock
 actions.append({"time":clock,"action":"explicit_start_earned_checkpoint","route":route,"native_enemy":setup.enemy,"hp":scene.vitality})
func _process(delta:float)->bool:
 if finished or not is_instance_valid(scene) or mode.is_empty():return false
 clock+=delta
 for event in scene.duel.observed_events:
  var copy:Dictionary=event.duplicate(true);copy.capture_time=clock;copy.bout=bout_index;copy.route=route;events.append(copy)
  if str(event.type)=="contact":
   if bout_index==0 and str(event.get("resolution",""))=="guard" and str(event.get("target",""))=="hero":snap_once("ordinary-guard")
   if bout_index==0 and bool(event.get("counter",false)) and int(event.get("damage",0))>0:snap_once("earned-counter")
   if int(event.get("shield_added",0))>0:snap_once("active-barrier")
   if int(event.get("shield_absorbed",0))>0:
    snap_once("barrier-absorption")
    if int(event.get("shield_after",-1))==0:snap_once("barrier-break")
 scene.duel.observed_events.clear()
 frames.append({"frame":Engine.get_process_frames(),"time":clock,"mode":mode,"bout":bout_index,"phase":scene.encounter_phase,"phase_age":scene.encounter_phase_age,"duel_time":scene.duel.elapsed,"held":scene.combat_hitstop,"hero_hp":scene.vitality,"enemy_hp":scene.enemy_hp,"hero":scene.duel_pose.get("hero",{}).duplicate(true),"enemy":scene.duel_pose.get("enemy",{}).duplicate(true),"resources":scene.duel.battle_resource_snapshot(),"search":scene.pickup_status.duplicate(true),"claim_time":scene.pickup_claimed_at,"hero_x":scene.character_x,"enemy_x":scene.encounter_enemy_x,"route_distance":scene.route_distance,"enemy_collapse":scene.enemy_defeat})
 if mode=="battle":
  if scene.encounter_phase=="pickup":
   if scene.enemy_defeat>.35 and scene.enemy_defeat<.8:snap_once(route+"-collapse")
   if scene.pickup_collect_started>=0.0 and scene.pickup_claimed_at<0.0 and float(scene.pickup_status.get("search_seconds",0))>.65:snap_once(route+"-searching")
   if scene.pickup_claimed_at>=0.0 and scene.encounter_phase_age-scene.pickup_claimed_at>.5:snap_once(route+"-materials-earned")
  if not scene.encounter_active and clock-mode_time>1.0:
   bouts[-1].end=clock;bouts[-1].materials_after=scene.state.materials.to_dict();bouts[-1].victories=scene.state.total_victories;bouts[-1].victory=scene.encounter_complete
   if not scene.encounter_complete:failed=true;push_error("NATIVE_BOUT_DID_NOT_WIN")
   mode="between";mode_time=clock
 elif mode=="between" and clock-mode_time>1.5:begin_bout()
 elif mode=="craft":advance_crafting()
 elif mode=="break_fixture" and clock-mode_time>=8.5:finish()
 if clock>120.0:failed=true;push_error("LOOT_DEMO_TIMEOUT");finish()
 return false
func snap_once(id:String):
 if captured.has(id):return
 captured[id]={"time":clock,"frame":Engine.get_process_frames()}
 save_snapshot(id)
func save_snapshot(id:String):
 if mode=="craft":await create_timer(.5).timeout
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(id+".png"))
func press(id:String):
 var button=scene.buttons.get(id)
 if not is_instance_valid(button) or button.disabled:failed=true;push_error("UNAVAILABLE_REAL_CONTROL "+id);return
 actions.append({"time":clock,"action":"press","control":id,"materials_before":scene.state.materials.to_dict()})
 button.pressed.emit()
 actions[-1].materials_after=scene.state.materials.to_dict();actions[-1].inventory=scene.state.inventory.duplicate(true)
func start_crafting():
 mode="craft";mode_time=clock;craft_step=0
 scene.wardrobe_tab="bag";scene.set_meta("bag_view","materials");scene._toggle_drawer("wardrobe");scene._refresh_drawer()
 banner.text="搜寻所得 → 合成淬炼石 → 制作竹影短衫 → 穿戴与灵材淬炼"
 details.text="实际库存扣料，成物入囊后亲手穿戴；攻击 / 防御预览随同一件装备更新。"
 before_craft={"stats":scene.state.stats(),"visuals":scene.state.gear.visual_loadout(),"materials":scene.state.materials.to_dict(),"inventory":scene.state.inventory.duplicate(true)}
func advance_crafting():
 var age:=clock-mode_time
 if craft_step==0 and age>2.0:press("bag_view_craft");craft_step=1
 elif craft_step==1 and age>4.0:press("craft_recipe_refine_stone");snap_once("combine-cost-preview");craft_step=2
 elif craft_step==2 and age>6.0:press("craft_selected");craft_step=3
 elif craft_step==3 and age>7.5:press("craft_selected");snap_once("real-stones-crafted");craft_step=4
 elif craft_step==4 and age>9.0:press("craft_recipe_weave_armor");snap_once("armor-recipe-preview");craft_step=5
 elif craft_step==5 and age>11.0:press("craft_selected");crafted_id=scene.selected_item;snap_once("real-armor-crafted");craft_step=6
 elif craft_step==6 and age>12.5:press("craft_to_equipment");snap_once("owned-armor-preview");craft_step=7
 elif craft_step==7 and age>15.0:press("equip_selected");snap_once("armor-visibly-equipped");craft_step=8
 elif craft_step==8 and age>17.0:press("enhance_item");snap_once("same-armor-enhanced");craft_step=9
 elif craft_step==9 and age>20.0:scene._close_drawer();craft_step=10
 elif craft_step==10 and age>22.0:snap_once("final-equipped-world");craft_step=11
 elif craft_step==11 and age>24.0:start_break_fixture()
func start_break_fixture():
 after_craft={"stats":scene.state.stats(),"visuals":scene.state.gear.visual_loadout(),"materials":scene.state.materials.to_dict(),"item":scene.state.gear.get_item(crafted_id).duplicate(true)}
 scene._close_drawer();scene.drawer_alpha=0.0;scene._reset_presentation()
 scene.state.save_path=checkpoints.path_join("cloud_slope-checkpoint.json");scene.state.load_game();scene.state.save_path="user://loot_native_qa_only.json"
 scene.state.settings.paused=false;scene.paused=false;scene.state.auto_advance=false
 var setup:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(checkpoints.path_join("cloud_slope-setup.json")))
 scene.state.start_stage();scene.duel=AuditDuel.new();scene.world_route="ember_ruins";route="ember_ruins"
 scene.encounter_run_id=int(setup.run_id);scene.encounter_index=2;scene.encounter_active=true;scene.encounter_complete=false;scene.route_boss=true
 scene.route_distance=940.0;scene.route_target_distance=940.0;scene.route_scroll_velocity=0.0;scene.route_frame_velocity=0.0
 scene.character_x=390.0;scene.character_y=230.0;scene.encounter_enemy_x=510.0;scene.meditation_amount=0.0;scene.meditation_settle=0.0
 scene.route_enemy_definition=Plan.prepare_enemy(scene.state.Content.STAGES.ember_ruins.monsters[2],"ember_ruins")
 scene.encounter_enemy_name=str(scene.route_enemy_definition.name);scene.encounter_stage_name="屏障耗尽 · QA对手场景"
 scene.enemy_max_hp=float(scene.route_enemy_definition.hp);scene.enemy_hp=scene.enemy_max_hp;scene.vitality_max=float(setup.hero.max_hp);scene.vitality=float(setup.hp)
 scene.battle_resources=scene.state.stage_battle_resources();scene.hero_hit=0.0;scene.enemy_flash=0.0;scene.enemy_defeat=0.0;scene.toast_time=0.0
 scene._begin_duel();scene.duel_pose=scene.duel.pose();scene.side_motion.merge(scene.duel_pose.hero,true)
 mode="break_fixture";mode_time=clock
 banner.text="独立 QA 对手场景 · 原生炎灵首领 · 护元屏障真实耗尽"
 details.text="使用真实所得的轻装与护元；对手原始属性未改。此小段只验吸伤与破障，不发放材料或关卡奖励。"
 break_fixture={"start":clock,"enemy":scene.route_enemy_definition.duplicate(true),"hero":scene.state.stats(),"hp":scene.vitality,"native_hp":scene.enemy_max_hp,"counts_as_campaign":false}
 actions.append({"time":clock,"action":"start_labeled_native_opponent_fixture","route":route,"enemy":scene.route_enemy_definition.duplicate(true),"hp":scene.vitality})
func finish():
 if finished:return
 finished=true
 var final_metadata:=Plan.measurement_metadata()
 if final_metadata!=metadata:failed=true;push_error("SOURCE_CHANGED_DURING_NATIVE_RECORDING")
 var result={"failed":failed,"seconds":clock,"bouts":bouts,"events":events,"frames":frames,"actions":actions,"captures":captured,"metadata":metadata,"source_frozen":final_metadata==metadata,"engine_time_scale":Engine.time_scale,"craft_before":before_craft,"craft_after":after_craft,"break_fixture":break_fixture,"note":"Both segments frame the boss arena directly from earned chapter checkpoints, omitting already-cleared travel and departure portals; preparation uses full native battles and actual search payouts separately. The recorder selects legal loadouts and presses production UI controls, with no enemy HP/damage/timing changes, resource injection, or guaranteed treasure. The active segment intentionally removes owned chest gear to show shield absorption. An explicitly labeled 8.5-second independent QA opponent scene uses the same earned light loadout against the original ember boss definition to demonstrate actual barrier depletion; it grants no campaign rewards. Every engine event is recorded. MovieWriter playback is normal game time at 60fps."}
 var file:=FileAccess.open(output.path_join("loot-loop-events.json"),FileAccess.WRITE);file.store_string(JSON.stringify(plain(result),"\t"));file.close()
 print("LOOT_LOOP_DEMO_DONE seconds=%.4f failed=%s"%[clock,failed]);scene.queue_free();scene=null;await process_frame;await process_frame;quit(1 if failed else 0)
func plain(value:Variant)->Variant:
 if value is Dictionary:
  var result:Dictionary={}
  for key in value:
   if str(key) in ["pose_provider","strike_provider"] or typeof(value[key])==TYPE_OBJECT:continue
   result[key]=plain(value[key])
  return result
 if value is Array:
  var result:Array=[]
  for item in value:
   if typeof(item)!=TYPE_OBJECT:result.append(plain(item))
  return result
 return value
