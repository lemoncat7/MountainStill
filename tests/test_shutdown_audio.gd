extends SceneTree
var scene
func _initialize(): call_deferred("run")
func run():
 scene=load("res://main.tscn").instantiate()
 scene.state.save_path="user://shutdown_audio_%d.json"%OS.get_process_id()
 root.add_child(scene)
 await process_frame
 scene.demo=true
 scene.set_process(false)
 scene.state.new_game()
 scene._start_encounter()
 scene.encounter_phase="fight"
 scene._begin_duel()
 for i in range(90):scene.duel.advance(1.0/60.0)
 scene.music.play()
 scene.audio.stream=load("res://assets/audio/equip.wav");scene.audio.play()
 await create_timer(1.0).timeout
 # Model native Window close semantics: the engine otherwise auto-quits
 # after delivering close_requested, bypassing the host's deferred cleanup.
 var automatic:bool=auto_accept_quit
 print("Shutdown audio: auto_accept_quit=",automatic)
 root.close_requested.emit()
 if automatic:
  printerr("FAIL: native close bypasses save gate and delayed audio cleanup")
  quit(1)
 scene=null
