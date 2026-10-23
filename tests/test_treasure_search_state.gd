extends SceneTree
const State=preload("res://scripts/cultivation_state.gd")
const Registry=preload("res://scripts/material_registry.gd")
var checks:=0
var failures:=0
var path:="user://treasure_search_%d.json"%OS.get_process_id()
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;printerr("FAIL: "+label)
func valid_keys(s,materials:Dictionary,label:String):
 for key in materials:check(key is String,label+" String material key: "+str(key))
 check(s.materials.validate_delta(materials).is_empty(),label+" valid whole material delta")
func _initialize():
 var s=State.new()
 # Existing refinement_stone String keys must stay String when updated.
 for recipe_id in Registry.RECIPE_ORDER:
  var recipe:Dictionary=Registry.recipe(recipe_id)
  var selections:Array=recipe.get("alternatives",[""])
  for selected in selections:
   var quote:Dictionary=s.crafting_quote(recipe_id,str(selected))
   valid_keys(s,quote.output_materials,"craft output "+recipe_id+str(selected))
   for key in quote.delta:check(key is String,"craft delta String key "+str(key))
 # All six species, ordinary and boss slots, use the same rare reward producer.
 for stage_id in s.Content.STAGES:
  for index in range(3):
   s._adventure_rng.seed=12
   var reward:Dictionary=s._roll_stage_corpse_rewards(stage_id,index)
   check(reward.treasure_rolled and reward.materials.get("spirit_jade")==1,"seed12 rare roll "+stage_id+str(index))
   valid_keys(s,reward.materials,"rolled "+stage_id+str(index))
   # Recovery reconstructs trusted material payload instead of trusting saves.
   s.stage_run={"id":stage_id,"kills":index,"run_id":1}
   s._restore_stage_corpse({"monster_index":index,"search_seconds":2.0,"rewards":reward})
   valid_keys(s,s.stage_run.pending_corpse.rewards.materials,"restored "+stage_id+str(index))
 s.new_game();s.auto_advance=false;s.save_path=path;s._adventure_rng.seed=12
 var run:int=s.start_stage().run_id
 var corpse:Dictionary=s.begin_stage_corpse(run,0)
 s.advance_stage_search(run,0,2.0)
 var rng_state:int=s._adventure_rng.state
 check(corpse.rewards.treasure_rolled,"formal seed12 corpse has jade")
 check(s.save_game(),"save existing schema pending rare corpse")
 var restored=State.new();restored.save_path=path;restored.load_game()
 check(not restored.stage_status().active,"restored body waits for explicit resume")
 check(restored._adventure_rng.state==rng_state,"reload preserves loot RNG")
 check(restored.start_stage().ok,"resume retained rare corpse")
 valid_keys(restored,restored.stage_corpse_status().rewards.materials,"real save reload")
 restored.materials.apply_delta({"spirit_jade":Registry.MAX_STACK})
 var before:Dictionary=restored._snapshot()
 var result:Dictionary=restored.complete_stage_search(run,0)
 check(not result.ok and result.reason=="material_full","full jade stack defers transaction")
 check(restored._snapshot()==before,"blocked reward is atomic and does not reroll")
 check(restored.materials.apply_delta({"spirit_jade":-1}).ok,"make exactly one slot")
 check(restored.complete_stage_search(run,0).ok,"retry claims retained jade without new roll")
 check(restored.material_count("spirit_jade")==Registry.MAX_STACK and restored.total_victories==1,"exactly one jade and victory credited")
 before=restored._snapshot()
 check(not restored.complete_stage_search(run,0).ok,"repeat claim rejected")
 check(restored._snapshot()==before,"repeat claim awards nothing")
 check(restored._adventure_rng.state==rng_state,"capacity retry/repeated claim never rerolls")
 # Keep ledger boundary strict, including rejecting StringName/untrusted IDs.
 check(restored.materials.validate_delta({&"spirit_jade":1})=="invalid_material","StringName is not silently accepted by ledger")
 check(restored.materials.validate_delta({"not_a_material":1})=="invalid_material","unknown ID stays rejected")
 for suffix in ["", ".bak", ".tmp"]:
  if FileAccess.file_exists(path+suffix):DirAccess.remove_absolute(path+suffix)
 print("Treasure search state: %d checks, %d failures"%[checks,failures])
 quit(1 if failures else 0)
