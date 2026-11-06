extends SceneTree
const Pages=preload("res://scripts/adventure_pages.gd")
class SaveProbe extends "res://scripts/cultivation.gd":
 var save_calls=0
 func _save_loadout():save_calls+=1

var scene
var checks=0
var failures=0
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func press(key:String):
 check(scene.buttons.has(key),"exists "+key)
 if scene.buttons.has(key):scene.buttons[key].pressed.emit()
func resources()->Array:return [scene.state.qi,scene.state.merit,scene.state.herbs,scene.state.dew,scene.state.meridian_node_ids()]
func run():
 scene=SaveProbe.new();scene.state.save_path="user://meridian_guidance_test.json";root.add_child(scene);await process_frame
 scene.set_process(false);scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
 scene.state.realm=14;scene.state.qi=10000;scene.state.herbs=1000;scene.state.dew=100
 scene.wardrobe_tab="meridian";scene._toggle_drawer("wardrobe")
 press("meridian_branch_edge");press("meridian_row_jianjing")
 var save_calls=scene.save_calls
 var before=resources()
 var old=scene.buttons.meridian_prerequisite
 press("meridian_prerequisite");check(scene.get_meta("meridian_id")=="hegu","first unmet diamond parent")
 old.pressed.emit();check(scene.get_meta("meridian_id")=="hegu","stale prior link ignored")
 press("meridian_prerequisite");press("meridian_prerequisite")
 check(scene.get_meta("meridian_id")=="qihai" and scene.get_meta("meridian_branch")=="central","chain reaches cross-branch root")
 check(resources()==before,"chain has no progression or resource effects")
 press("meridian_return");check(scene.get_meta("meridian_id")=="shangyang","return root to branch")
 press("meridian_return");press("meridian_return");check(scene.get_meta("meridian_id")=="jianjing","return original diamond")
 check(not scene.buttons.has("meridian_return"),"empty trail removes return")
 check(scene.save_calls==save_calls,"read-only chain and returns never request save")
 scene.state.meridian_opened={"hegu":true}
 check(str(Pages._meridian_missing_target(scene,Pages._selected_meridian(scene)).id)=="quchi","after first parent active links second parent")
 scene.state.meridian_opened={}
 check(Pages._meridian_missing_target(scene,{"prerequisites":["unknown","qihai"]}).is_empty(),"unknown first gate does not skip ahead")
 scene.set_meta("meridian_trail",[{"id":"hegu"}]);press("meridian_prerequisite")
 check(scene.get_meta("meridian_id")=="jianjing","visited-target cycle safely stops")
 scene.set_meta("meridian_trail",[])
 scene.set_meta("meridian_selected_central","baihui")
 press("meridian_prerequisite");press("meridian_branch_quiet")
 check(not scene.buttons.has("meridian_return"),"manual branch navigation clears trail")
 press("meridian_prerequisite")
 var stale_buy=scene.buttons.unlock_meridian
 press("meridian_return");stale_buy.pressed.emit()
 check(resources()==before,"stale root buy cannot charge after returning")
 check(scene.get_meta("meridian_selected_central")=="baihui","cross-branch inspection preserves previous branch selection")
 press("meridian_prerequisite")
 var stale_return=scene.buttons.meridian_return
 scene._close_drawer();stale_return.pressed.emit()
 check(scene.get_meta("meridian_trail",[]).is_empty(),"close clears trail and stale return cannot reopen")
 scene.closing=false;scene.wardrobe_tab="meridian";scene._toggle_drawer("wardrobe")
 press("meridian_branch_central");press("meridian_row_qihai")
 scene.state.qi=28.5;scene.state.herbs=1;scene.state.dew=0
 var row=Pages._selected_meridian(scene)
 check(Pages._meridian_resource_hint(scene,row)=="尚缺 2 灵气 · 2 灵草 · 1 晨露","ceil fractional energy, exact herbs and dew")
 scene.state.realm=scene.state.MAX_REALM;scene.state.merit=29.2;row=Pages._selected_meridian(scene)
 check(Pages._meridian_resource_hint(scene,row)=="尚缺 1 功德 · 2 灵草 · 1 晨露","max realm quotes merit, not qi")
 scene.state.merit=30-scene.state.EPSILON*0.5;scene.state.herbs=3;scene.state.dew=1;row=Pages._selected_meridian(scene)
 check(bool(row.can_unlock) and Pages._meridian_resource_hint(scene,row)=="资源齐备 · 必定成功","within EPSILON matches actual unlock quote")
 scene.state.merit=30-scene.state.EPSILON*2;row=Pages._selected_meridian(scene)
 check(not bool(row.can_unlock) and Pages._meridian_resource_hint(scene,row)=="尚缺 1 功德","outside EPSILON reports shortage")
 scene.state.merit=30;row=Pages._selected_meridian(scene)
 check(Pages._meridian_resource_hint(scene,row)=="资源齐备 · 必定成功","exact affordability")
 scene.state.realm=0;press("meridian_branch_flow");press("meridian_row_fengchi")
 row=Pages._selected_meridian(scene);check(Pages._meridian_resource_hint(scene,row).begins_with("先通"),"prerequisite remains ahead of resources")
 scene.state.meridian_opened={"qihai":true};press("meridian_row_taixi");row=Pages._selected_meridian(scene)
 check(Pages._meridian_resource_hint(scene,row).begins_with("需达"),"realm remains ahead of affordability")
 scene.encounter_active=true;scene.encounter_phase="fight";press("meridian_row_fengchi");before=resources()
 press("meridian_prerequisite");check(scene.buttons.unlock_meridian.disabled and resources()==before,"battle permits inspection but no buying")
 scene.encounter_active=false;scene.encounter_phase="idle"
 scene.wardrobe_tab="equipment";scene._refresh_drawer();check(scene.get_meta("meridian_trail",[]).is_empty(),"unrelated tab clears navigation trail")
 scene.wardrobe_tab="meridian"
 for height in [320,540]:
  scene.size=Vector2(960,height)
  for point in scene.state.Content.ACUPOINTS:
   scene.set_meta("meridian_trail",[{"id":"jianjing","branch":"edge","name":"肩井"}]);scene.set_meta("meridian_branch",point.branch);scene.set_meta("meridian_id",point.id);scene._refresh_drawer()
   var controls:Array=[]
   for child in scene.drawer.get_children():
    if child is BaseButton:
     check(scene._drawer_rect().encloses(Rect2(child.position,child.size)),"bounded "+str(point.id));controls.append(child)
   for i in range(controls.size()):
    for j in range(i+1,controls.size()):check(not Rect2(controls[i].position,controls[i].size).intersects(Rect2(controls[j].position,controls[j].size)),"distinct "+str(point.id))
 scene.queue_free();await process_frame;await process_frame
 for suffix in ["",".bak",".tmp"]:
  DirAccess.remove_absolute("user://meridian_guidance_test.json"+suffix)
 print("Meridian guidance: %d checks, %d failures"%[checks,failures]);quit(1 if failures else 0)
