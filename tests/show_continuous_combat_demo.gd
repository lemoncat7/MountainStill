extends SceneTree
## Two native-HP boss bouts from fully earned, valid checkpoints.
## The production host owns action selection, damage, effects, hitstop and audio.
## This recorder logs every returned engine event, not only the last contact.
const Sans = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const Plan = preload("res://tests/campaign_build_plan.gd")
class AuditDuel extends "res://scripts/duel_timeline.gd":
 var observed_events: Array[Dictionary] = []
 func advance(delta: float) -> Array[Dictionary]:
  var result := super.advance(delta)
  observed_events.append_array(result)
  return result
var scene
var output := "/tmp/continuous-combat-demo"
var checkpoints := "/tmp/continuous-combat-checkpoints"
var events: Array = []
var frames: Array = []
var bouts: Array = []
var clock := 0.0
var bout_start := 0.0
var bout_index := -1
var route := ""
var running := false
var finished := false
var banner: Label
var details: Label
var initial_metadata: Dictionary
var failed := false
var caption := ""

func _initialize() -> void: call_deferred("start")
func start() -> void:
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with("--output="): output = arg.trim_prefix("--output=")
  if arg.begins_with("--checkpoints="): checkpoints = arg.trim_prefix("--checkpoints=")
  if arg.begins_with("--caption="): caption = arg.trim_prefix("--caption=")
 DirAccess.make_dir_recursive_absolute(output)
 initial_metadata = Plan.measurement_metadata()
 scene = load("res://main.tscn").instantiate()
 scene.state.save_path = "user://continuous_combat_qa_isolated.json"
 root.add_child(scene)
 await process_frame
 scene.demo = true
 scene.get_window().size = Vector2i(1200,320)
 scene.get_window().transparent_bg = false
 scene.strip = true
 scene.desktop.transparent_enabled = true
 scene.show_combat_move_labels = false
 RenderingServer.set_default_clear_color(Color("#e8e7df"))
 banner = Label.new(); banner.position = Vector2(17,5)
 banner.add_theme_font_override("font",Sans);banner.add_theme_font_size_override("font_size",11)
 banner.add_theme_color_override("font_color",Color("#354e43"));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE
 scene.add_child(banner)
 details = Label.new();details.position=Vector2(17,22)
 details.add_theme_font_override("font",Sans);details.add_theme_font_size_override("font_size",10)
 details.add_theme_color_override("font_color",Color("#506356"));details.mouse_filter=Control.MOUSE_FILTER_IGNORE
 scene.add_child(details)
 begin_bout()

func begin_bout() -> void:
 bout_index += 1
 if bout_index >= 2: finish(); return
 route = ["bamboo_pass", "cloud_slope"][bout_index]
 var setup: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(checkpoints.path_join(route + "-setup.json")))
 scene.state.save_path = checkpoints.path_join(route + "-checkpoint.json")
 var loaded: Dictionary = scene.state.load_game()
 if not loaded.get("loaded",false): failed=true;push_error("CHECKPOINT_LOAD_FAILED");finish();return
 scene.state.save_path = "user://continuous_combat_qa_isolated.json"
 scene.state.settings.paused=false;scene.paused=false;scene.state.auto_advance=false
 scene._volume()
 scene.duel = AuditDuel.new()
 scene.world_route=route;scene.encounter_run_id=int(setup.run_id);scene.encounter_index=2
 scene.encounter_active=true;scene.encounter_complete=false;scene.route_boss=true
 scene.route_distance=940.0;scene.route_target_distance=940.0
 scene.route_scroll_velocity=0.0;scene.route_frame_velocity=0.0
 scene.character_x=390.0;scene.character_y=230.0;scene.encounter_enemy_x=510.0
 scene.meditation_amount=0.0;scene.meditation_settle=0.0
 scene.encounter_enemy_name=str(setup.enemy.name);scene.encounter_stage_name=str(scene.state.Content.STAGES[route].name)
 scene.route_enemy_definition=setup.enemy.duplicate(true)
 scene.enemy_max_hp=float(setup.enemy.hp);scene.enemy_hp=scene.enemy_max_hp
 scene.vitality_max=float(setup.hero.max_hp);scene.vitality=float(setup.hp)
 scene.battle_resources=scene.state.stage_battle_resources()
 scene.hero_hit=0.0;scene.enemy_flash=0.0;scene.enemy_defeat=0.0;scene.toast_time=0.0
 scene._begin_duel()
 scene.duel_pose=scene.duel.pose();scene.side_motion.merge(scene.duel_pose.hero,true)
 bout_start=clock;running=true
 banner.text="连续实战 · %d / 2 · %s · 原生气血 / 正常速度%s" % [bout_index+1,scene.encounter_enemy_name,(" · "+caption) if not caption.is_empty() else ""]
 details.text="真实所得青锋剑 + 止水内功 + 护元诀；保留前战气血、真气与冷却；原生首领属性"
 bouts.append({"route":route,"start":clock,"setup":setup,"loaded_hero":scene.duel._hero.duplicate(true),"loaded_enemy":scene.duel._enemy.duplicate(true),"weapon":scene._attack_style()})
 if scene.state.equipped_actives.size()!=1 or scene._attack_style()!="sword" or scene.state.equipped_heart.is_empty():
  failed=true;push_error("ILLEGAL_REVIEW_LOADOUT")

func _process(delta: float) -> bool:
 if finished or not is_instance_valid(scene):return false
 clock+=delta
 if running:
  for event in scene.duel.observed_events:
   var copy:Dictionary=event.duplicate(true);copy.capture_time=clock;copy.bout=bout_index;copy.route=route
   events.append(copy)
  scene.duel.observed_events.clear()
  var pose:Dictionary=scene.duel_pose
  frames.append({"frame":Engine.get_process_frames(),"time":clock,"bout":bout_index,"duel_time":scene.duel.elapsed,"held":scene.combat_hitstop,"hero_hp":scene.vitality,"enemy_hp":scene.enemy_hp,"hero":pose.get("hero",{}).duplicate(true),"enemy":pose.get("enemy",{}).duplicate(true)})
  if scene.duel.finished:
   running=false
   bouts[-1].end=clock;bouts[-1].seconds=clock-bout_start;bouts[-1].duel_seconds=scene.duel.elapsed
   bouts[-1].victory=scene.duel.victory;bouts[-1].hp_end=scene.duel.hero_hp;bouts[-1].battle_resources_end=scene.duel.battle_resource_snapshot()
   print("CONTINUOUS_BOUT_DONE "+JSON.stringify(bouts[-1]))
   if not scene.duel.victory:failed=true
   scene.set_process(false)
   complete_bout()
 if clock>120.0:failed=true;push_error("REVIEW_TIMEOUT");finish()
 return false

func complete_bout() -> void:
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output.path_join(route+"-victory.png"))
 await create_timer(0.75).timeout
 scene.set_process(true)
 begin_bout()

func finish() -> void:
 if finished:return
 finished=true
 var final_metadata:=Plan.measurement_metadata()
 if final_metadata!=initial_metadata:failed=true;push_error("REVIEW_SOURCE_CHANGED_DURING_RECORDING")
 var file:=FileAccess.open(output.path_join("continuous-combat-events.json"),FileAccess.WRITE)
 file.store_string(JSON.stringify(plain({"failed":failed,"seconds":clock,"bouts":bouts,"events":events,"frames":frames,"metadata":initial_metadata,"source_frozen":final_metadata==initial_metadata,"engine_time_scale":Engine.time_scale,"note":"Both boss arenas use real earned save checkpoints and unchanged native HP; each bout is continuous production-host playback. Preparation is simulated separately at real costs. No claims of human audiovisual audition."}),"\t"));file.close()
 print("CONTINUOUS_DEMO_DONE seconds=%.4f failed=%s" % [clock,failed])
 scene.queue_free();scene=null
 await process_frame
 await process_frame
 quit(1 if failed else 0)

func plain(value: Variant) -> Variant:
 if value is Dictionary:
  var result: Dictionary = {}
  for key in value:
   if str(key) in ["pose_provider","strike_provider"] or typeof(value[key]) == TYPE_OBJECT: continue
   result[key] = plain(value[key])
  return result
 if value is Array:
  var result: Array = []
  for item in value:
   if typeof(item) != TYPE_OBJECT: result.append(plain(item))
  return result
 return value
