extends SceneTree
## Real host/buttons; seeded, isolated fixtures are not naturally earned progress.
const Adventure=preload("res://scripts/adventure_pages.gd")
const Insight=preload("res://scripts/combat_insight_pages.gd")
const Journey=preload("res://scripts/player_journey_pages.gd")
var scene
var checks:=0
var failures:=0
var save_path:="user://chapter_practice_navigation_%d.json"%OS.get_process_id()
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func snapshot()->String:
 var data:Dictionary=scene.state._snapshot()
 data.erase("saved_at")
 return JSON.stringify(data)
func mark()->Dictionary:
 # _snapshot itself touches the high-water clock. Capture AFTER that read,
 # then check the clock BEFORE the next snapshot to isolate navigation writes.
 var data:=snapshot()
 return {"data":data,"clock":scene.state._clock_high_water}
func unchanged(before:Dictionary,label:String):
 check(scene.state._clock_high_water==before.clock,label+" no clock-high-water write")
 check(snapshot()==before.data,label+" entire formal snapshot and RNG unchanged")
func press(key:String):
 var b=scene.buttons.get(key)
 check(is_instance_valid(b) and b is BaseButton,"button exists "+key)
 if not is_instance_valid(b):return
 check(not b.disabled,"button enabled "+key)
 if not b.disabled:b.pressed.emit()
func fresh():
 if scene.practice_session!=null:scene.end_practice()
 scene._reset_presentation();scene.state.new_game();scene.state.save_path=save_path
 scene.state.auto_advance=false;scene.demo=true;scene.paused=false
 scene.world_route="";scene.encounter_active=false
 if scene.has_meta("chapter_practice_return"):scene.remove_meta("chapter_practice_return")
 scene.set_meta("combat_insight_open",false)
 scene.set_meta("equipment_comparison_open",false)
func open_chapter(id:String,page:int):
 if scene.drawer_name!="wardrobe":scene._toggle_drawer("wardrobe")
 scene.wardrobe_tab="expedition"
 scene.set_meta("ink_stage_id",id);scene.set_meta("ink_stage_page",page)
 scene.set_meta("expedition_view","route");scene._refresh_drawer()
func target_page(id:String)->int:
 var rows:Array=scene.practice_enemy_rows()
 for i in range(rows.size()):
  if str(rows[i].stage_id)==id:return i
 return -1
func assert_enemy(id:String,label:String):
 check(scene.drawer_name=="wardrobe" and scene.wardrobe_tab=="equipment",label+" opens equipment paper")
 check(bool(scene.get_meta("combat_insight_open",false)) and str(scene.get_meta("combat_insight_view",""))=="enemies",label+" opens enemy insight")
 check(int(scene.get_meta("practice_enemy_page",-1))==target_page(id),label+" resolves chapter against current rows")
 check(not bool(scene.get_meta("equipment_comparison_open",false)),label+" equipment comparison closed")
 check(scene.practice_session==null and not scene.encounter_active,label+" no automatic practice or expedition")
func assert_return(id:String,page:int):
 check(scene.drawer_name=="wardrobe" and scene.wardrobe_tab=="expedition","returns to chapter paper")
 check(str(scene.get_meta("ink_stage_id",""))==id and int(scene.get_meta("ink_stage_page",-1))==page,"returns original chapter and page")
 check(str(scene.get_meta("expedition_view",""))=="route","returns route view")
 check(not scene.has_meta("chapter_practice_return"),"return source consumed")
func nav_signature()->String:
 return str([scene.drawer_name,scene.wardrobe_tab,scene.get_meta("ink_stage_id",""),scene.get_meta("ink_stage_page",-1),scene.get_meta("combat_insight_open",false),scene.get_meta("combat_insight_view",""),scene.get_meta("practice_enemy_page",-1),scene.get_meta("chapter_practice_return",{})])
func chapter_roundtrip(id:String,page:int):
 open_chapter(id,page)
 scene.set_meta("equipment_comparison_open",true)
 var before:=mark()
 var old_button=scene.buttons.get("chapter_enemies")
 var generation:int=scene.drawer_generation
 press("chapter_enemies");assert_enemy(id,id)
 var destination:=nav_signature()
 # The same rendered button and its original generation cannot navigate twice.
 if is_instance_valid(old_button):old_button.pressed.emit()
 Adventure._open_chapter_enemies(scene,id,generation)
 check(nav_signature()==destination,"duplicate callback does not replace return source")
 unchanged(before,"chapter entry/duplicate "+id)
 var rows:Array=scene.practice_enemy_rows()
 var row:Dictionary=rows[target_page(id)]
 check(scene.buttons.practice_start.disabled==(not bool(row.unlocked)),"locked chapter stays read-only "+id)
 before=mark();press("combat_back");assert_return(id,page);unchanged(before,"chapter return "+id)
func test_stale():
 for reason in ["detached_button","generation","chapter","tab","drawer"]:
  open_chapter("bamboo_pass",0)
  var generation:int=scene.drawer_generation
  var old_button=scene.buttons.get("chapter_enemies")
  match reason:
   "detached_button":scene._refresh_drawer()
   "generation":scene._refresh_drawer(true)
   "chapter":scene.set_meta("ink_stage_id","creek_bridge");scene._refresh_drawer()
   "tab":scene.wardrobe_tab="technique";scene._refresh_drawer()
   "drawer":scene._toggle_drawer("alchemy")
  var before:=mark();var navigation:=nav_signature()
  if is_instance_valid(old_button):old_button.pressed.emit()
  if reason!="detached_button":Adventure._open_chapter_enemies(scene,"bamboo_pass",generation)
  check(nav_signature()==navigation,"stale "+reason+" callback inert")
  unchanged(before,"stale "+reason)
func test_ordinary_entry():
 open_chapter("bamboo_pass",0);press("chapter_enemies")
 # Ordinary entry must explicitly clear any prior chapter return context.
 var before:=mark();Insight.open(scene)
 check(not scene.has_meta("chapter_practice_return"),"ordinary insight drops chapter source")
 press("combat_back")
 check(scene.wardrobe_tab=="equipment" and not bool(scene.get_meta("combat_insight_open",false)),"ordinary back returns to clothes, not chapter")
 unchanged(before,"ordinary insight/back")
func live_button(key:String)->bool:
 var button=scene.buttons.get(key)
 return is_instance_valid(button) and button is BaseButton and button.is_inside_tree() and not button.is_queued_for_deletion() and button.get_parent()==scene.drawer
func test_journal_destinations():
 for kind in ["equipment","route","technique"]:
  fresh();scene.state.arrival_seen=true
  open_chapter("bamboo_pass",0);press("chapter_enemies")
  check(scene.has_meta("chapter_practice_return"),"journal fixture begins in chapter detour")
  var before:=mark()
  scene._close_drawer()
  var input:=InputEventKey.new();input.keycode=KEY_R;input.pressed=true
  scene._input(input)
  check(scene.drawer_name=="practice","R opens journal after closing enemy paper")
  # Chapter-source context survives closing; the explicit destination owns cleanup.
  check(scene.has_meta("chapter_practice_return"),"journal retains source until explicit destination")
  var target:String="summit_gate" if kind=="route" else "mist" if kind=="technique" else ""
  Journey.navigate(scene,kind,target)
  check(not scene.has_meta("chapter_practice_return"),"journal "+kind+" clears obsolete chapter source")
  check(not bool(scene.get_meta("combat_insight_open",false)) and not bool(scene.get_meta("equipment_comparison_open",false)),"journal "+kind+" closes detour overlays")
  check(not live_button("practice_start") and not live_button("combat_back"),"journal "+kind+" does not show enemy-paper controls")
  check(scene.drawer_name=="wardrobe","journal "+kind+" opens explicit destination")
  match kind:
   "equipment":check(scene.wardrobe_tab=="equipment" and live_button("first_chest"),"explicit clothes link shows actual equipment controls")
   "route":check(scene.wardrobe_tab=="expedition" and str(scene.get_meta("ink_stage_id",""))==target and live_button("chapter_enemies"),"explicit route link shows requested chapter controls")
   "technique":check(scene.wardrobe_tab=="technique" and str(scene.get_meta("ink_technique_id",""))==target and live_button("tech_category_all"),"explicit manual link shows requested technique controls")
  unchanged(before,"journal destination "+kind)
func test_blocked_context(kind:String):
 fresh()
 var run:int=scene.state.start_stage().run_id
 if kind=="corpse":
  scene.state._adventure_rng.seed=12
  check(scene.state.begin_stage_corpse(run,0).ok,"fixture earned corpse")
  scene.state.advance_stage_search(run,0,.75)
 elif kind=="opportunity":
  # Explicit checkpoint fixture, not evidence of naturally played kills.
  scene.state.stage_run.kills=2
  scene.state.stage_run.opportunity_checked=true
  scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":"bamboo_pass","run_id":run}
 scene.state.pause_stage(run)
 open_chapter("bamboo_pass",0)
 var before:=mark();press("chapter_enemies");assert_enemy("bamboo_pass",kind)
 check(not scene.practice_can_start().is_empty() and scene.buttons.practice_start.disabled,kind+" trial gate retained")
 # Even a stale forced signal/API cannot bypass host eligibility.
 scene.buttons.practice_start.pressed.emit()
 check(not scene.start_practice("bamboo_sprite") and scene.practice_session==null,kind+" cannot replace retained expedition")
 press("combat_back");assert_return("bamboo_pass",0)
 unchanged(before,kind+" retained run/body/choice")
func test_opportunity_direct_navigation():
 fresh();scene.state.arrival_seen=true
 var run:int=scene.state.start_stage().run_id
 scene.state.stage_run.kills=2;scene.state.stage_run.opportunity_checked=true
 scene.state.pending_opportunity={"id":"quiet_cairn","stage_id":"bamboo_pass","run_id":run}
 scene.state.pause_stage(run)
 open_chapter("bamboo_pass",0);press("chapter_enemies")
 check(scene.has_meta("chapter_practice_return"),"direct opportunity fixture has chapter source")
 var before:=mark()
 scene._open_route_opportunity()
 check(scene.wardrobe_tab=="expedition" and str(scene.get_meta("expedition_view",""))=="opportunity","direct opportunity opens choice page")
 check(not scene.has_meta("chapter_practice_return"),"direct expedition entry drops chapter source")
 check(not bool(scene.get_meta("combat_insight_open",false)) and not bool(scene.get_meta("equipment_comparison_open",false)),"direct expedition entry clears chapter overlays")
 unchanged(before,"direct pending opportunity entry")
 before=mark()
 Journey.navigate(scene,"equipment")
 check(scene.wardrobe_tab=="equipment" and live_button("first_chest"),"clothes after direct opportunity shows equipment")
 check(not live_button("practice_start") and not live_button("combat_back"),"clothes after direct opportunity does not resurrect enemy page")
 unchanged(before,"clothes after pending opportunity")
func test_trial_return(finish:bool):
 fresh();scene.paused=true
 open_chapter("bamboo_pass",0);press("chapter_enemies")
 var before:=mark();var formal_duel=scene.duel
 press("practice_start")
 check(scene.practice_session!=null,"chapter action explicitly starts trial")
 if scene.practice_session==null:return
 check(scene.buttons.combat_back.disabled,"cannot navigate back while trial owns scene")
 for i in range(1300 if finish else 3):scene._process(.1)
 if finish:check(scene.practice_session.status().finished,"trial reaches result")
 else:check(not scene.practice_session.status().finished,"cancel fixture is still running")
 # Exercise the completed-result button and live cancellation shortcut.
 if finish:press("practice_end")
 else:
  var escape:=InputEventKey.new();escape.keycode=KEY_ESCAPE;escape.pressed=true
  scene._input(escape)
 scene._refresh_drawer()
 check(scene.duel==formal_duel and scene.paused,"trial restores formal engine/pause")
 press("combat_back");assert_return("bamboo_pass",0)
 unchanged(before,"finished trial return" if finish else "cancelled trial return")
func run():
 scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
 await process_frame;scene.set_process(false);scene.size=Vector2(960,540)
 fresh()
 var stages:Array=scene.state.stage_rows()
 for i in range(stages.size()):chapter_roundtrip(str(stages[i].id),i/Adventure.CHAPTERS_PER_PAGE)
 var locked_index:=target_page("summit_gate")
 # Unlock fixtures change the list length. Old fixed page indices are invalid.
 scene.state.realm=scene.state.MAX_REALM
 for id in scene.state.Content.STAGES:scene.state.stage_clears[id]=1
 check(target_page("summit_gate")!=locked_index,"enemy list expands as chapters unlock")
 for i in range(stages.size()):chapter_roundtrip(str(stages[i].id),i/Adventure.CHAPTERS_PER_PAGE)
 test_stale();test_ordinary_entry();test_journal_destinations()
 for kind in ["pending","corpse","opportunity"]:test_blocked_context(kind)
 test_opportunity_direct_navigation()
 test_trial_return(false);test_trial_return(true)
 scene.queue_free();await process_frame;await process_frame
 for suffix in ["", ".bak", ".tmp"]:
  if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
 print("Chapter practice navigation: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
