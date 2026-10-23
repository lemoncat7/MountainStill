extends SceneTree
var scene
var checks:=0
var failures:=0
var save_path:="user://shutdown_lifecycle_%d.json"%OS.get_process_id()
func _initialize():call_deferred("run")
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func run():
 scene=load("res://main.tscn").instantiate()
 scene.state.save_path=save_path
 root.add_child(scene);await process_frame
 scene.set_process(false);scene.state.new_game();scene.demo=false
 check(not auto_accept_quit,"native close belongs to host save/cleanup gate")
 scene.state.save_path="user://missing_shutdown_directory_%d/save.json"%OS.get_process_id()
 root.close_requested.emit()
 check(not scene.closing,"failed save rejects close")
 await create_timer(.4).timeout
 check(is_instance_valid(scene) and scene.is_inside_tree(),"failed close keeps scene alive beyond shutdown timer")
 scene.state.save_path=save_path
 scene.world_route="";scene.encounter_active=false;scene.state.stage_run={}
 scene.paused=true
 var formal_duel=scene.duel
 check(scene.start_practice("bamboo_sprite"),"enter trial before close")
 scene._process(.1)
 root.close_requested.emit()
 check(scene.closing,"successful native close starts teardown")
 check(scene.practice_session==null and scene.duel==formal_duel,"close restores formal engine before saving")
 check(scene.paused,"close restores formal pause")
 check(FileAccess.file_exists(save_path),"formal save exists after trial close")
 var loaded=scene.State.new();loaded.save_path=save_path;loaded.load_game()
 check(loaded.combat_reports.is_empty(),"trial close saves no trial reward/report")
 loaded=null;formal_duel=null
 root.close_requested.emit()
 check(scene.closing,"repeated native close remains idempotent")
 await create_timer(.23).timeout
 check(not is_instance_valid(scene),"scene freed before final native quit")
 for path in [save_path,save_path+".bak",save_path+".tmp",save_path+".offline",save_path+".offline.bak"]:
  if FileAccess.file_exists(path):DirAccess.remove_absolute(path)
 print("Shutdown lifecycle: %d checks, %d failures"%[checks,failures])
 if failures:quit(1)
 # Successful case lets the production .35-second tree.quit timer finish.
