extends "res://tests/test_battle_resource_host.gd"
## The 1% treasure branch must not leave a fully searched body unclaimable.
func fixture(style:String="sword",actives:Array=[],realm:int=4):
 super.fixture(style,actives,realm)
 scene.state._adventure_rng.seed=12
func run():
 scene=load("res://main.tscn").instantiate();scene.state.save_path=save_path;root.add_child(scene)
 await process_frame;scene.set_process(false)
 test_checkpoint_flush()
 check(scene.state.material_count("spirit_jade")==1,"real seed12 combat/search awards rare jade")
 scene.queue_free();await process_frame;await process_frame
 for suffix in ["", ".bak", ".tmp"]:
  if FileAccess.file_exists(save_path+suffix):DirAccess.remove_absolute(save_path+suffix)
 print("Treasure search host: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
