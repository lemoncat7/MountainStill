extends SceneTree
## Replay unmodified earned campaign measurements, with real paintings/geometry.
## First produce --report with test_encounter_balance.gd; pass --report=... here.
const Duel=preload("res://scripts/duel_timeline.gd")
var scene
var checks:=0
var failures:=0
func check(ok:bool,label:String):
 checks+=1
 if not ok:failures+=1;push_error(label)
func _initialize():call_deferred("run")
func run():
 var path:=""
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--report="):path=arg.trim_prefix("--report=")
 if path.is_empty():push_error("Provide earned encounter report");quit(2);return
 var report:Dictionary=JSON.parse_string(FileAccess.get_file_as_string(path))
 scene=load("res://main.tscn").instantiate();scene.state.save_path="user://poise_feedback_test.json";root.add_child(scene)
 await process_frame
 scene.set_process(false);scene.demo=true
 var broken_targets:Dictionary={};var broken_guards:=0;var shield_breaks:=0;var fights:=0;var ordinary:=0
 for row in report.encounters:
  if row.rng_seed!=61 or row.build not in ["sword","guard"]:continue
  var d=Duel.new();d.start(row.hero_stats,row.enemy_definition,row.technique,str(row.equipment.get("weapon","")),int(row.duel_seed))
  while not d.finished and d.elapsed<120:
   for e in d.advance(.1):
    if e.type!="contact":continue
    var before:Dictionary=e.duplicate(true)
    var label_before:Array=[scene.combat_number,scene.combat_number_time,scene.hero_damage,scene.hero_resolution,scene.hero_poise_broken,scene.hero_hit]
    scene._present_duel_contact(e)
    check(e==before,"presentation leaves resolved event unchanged")
    var broken:=bool(e.get("poise_broken",false))
    if broken:
     broken_targets[str(e.target)]=true
     if e.resolution=="guard":broken_guards+=1
     var label:String=scene.combat_number if e.target=="enemy" else (scene._hero_damage_text() if scene.has_method("_hero_damage_text") else "")
     check(label.begins_with("破势"),"real posture break is named: "+str(e.target)+"/"+str(e.resolution))
     if int(e.get("shield_absorbed",0))>0 and int(e.damage)==0:
      shield_breaks+=1;check(label.contains("护盾"),"shield absorption and posture break both remain readable")
     else:check(label.contains(str(e.damage)),"break label retains actual damage")
    elif e.target=="enemy" and e.resolution!="whiff":
     ordinary+=1
     var expected:String=("反击 −" if bool(e.get("counter",false)) and e.resolution=="hit" and int(e.damage)>0 else ("闪避 " if e.resolution=="dodge" else ("格挡 " if e.resolution=="guard" else "")))+str(e.damage)
     check(scene.combat_number==expected,"ordinary enemy label unchanged")
    elif e.actor=="enemy" and e.resolution!="whiff" and scene.has_method("_hero_damage_text"):
     var r:String="shield" if int(e.get("shield_absorbed",0))>0 and int(e.damage)==0 else str(e.resolution)
     var expected:String="闪避 0" if r=="dodge" else ("护盾" if r=="shield" else (("格挡 " if r=="guard" else "")+"−%d"%int(e.damage)))
     check(scene._hero_damage_text()==expected,"ordinary hero label resets after prior break")
    if e.resolution=="whiff":check([scene.combat_number,scene.combat_number_time,scene.hero_damage,scene.hero_resolution,scene.hero_poise_broken,scene.hero_hit]==label_before,"whiff creates no new label or lifetime and preserves prior feedback")
  check(d.victory and absf(d.elapsed-float(row.seconds))<.00011,"replayed outcome and duration match earned baseline")
  fights+=1
 check(fights==36 and broken_targets.size()==2 and broken_guards>0 and shield_breaks>0 and ordinary>0,"real two-sided guards, shields and ordinary contacts covered")
 for ch in "破势护盾−0123456789":check(scene.SANS.has_char(ch.unicode_at(0)),"bundled CJK font has glyph "+ch)
 print("POISE_FEEDBACK fights=%d broken_targets=%d broken_guards=%d shield_breaks=%d checks=%d failures=%d"%[fights,broken_targets.size(),broken_guards,shield_breaks,checks,failures])
 scene.queue_free();await process_frame;await process_frame;quit(1 if failures else 0)
