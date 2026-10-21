extends SceneTree
## Native same-fixture visual comparison. Preset checkpoint and HP prolong observation.
## Never loads/writes the player's save; no production combat update is replaced.
var scene
var clock:=0.0
var label:Label
var technique:='mist'
var tag:='species'
var route:='moon_marsh'
var done:=false
var prepared:=false
var fight_started:=false
var fight_age:=0.0
var samples:Array=[]
var last_phase:=''
var last_contact:=''
var capture_root:='user://revision-captures'
func _initialize():call_deferred('start')
func start():
 for argument in OS.get_cmdline_user_args():
  if str(argument).begins_with('--style='):technique=str(argument).trim_prefix('--style=')
  if str(argument).begins_with('--tag='):tag=str(argument).trim_prefix('--tag=')
  if str(argument).begins_with('--route='):route=str(argument).trim_prefix('--route=')
  if str(argument).begins_with('--capture-root='):capture_root=str(argument).trim_prefix('--capture-root=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_root))
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://revision_capture_isolated.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false;scene.state.realm=12;scene.state.technique=technique;scene.state.technique_levels[technique]=1
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
 for template in ['weapon_fan' if technique=='petal' else 'weapon_sword','chest_blue','legs_jade','feet_boots','head_pin']:
  var id:int=scene.state.gear._allocate_id();scene.state.gear.inventory.append(scene.state.gear._make_item(id,template,'common',1));scene.state.equip_item(id)
 # Same real chapter checkpoint in both revisions. No reward or final-win claim.
 scene.state._adventure_rng.seed=377
 for prior in scene.state.Content.CHAPTER_ORDER:
  if prior==route:break
  scene.state.select_stage(prior)
  var previous:Dictionary=scene.state.start_stage()
  scene.state.defeat_stage_monster(previous.run_id,0);scene.state.defeat_stage_monster(previous.run_id,1)
  scene.state.check_route_opportunity(previous.run_id)
  if scene.state.stage_status().opportunity_pending:scene.state.choose_opportunity('gather_gift')
  scene.state.defeat_stage_monster(previous.run_id,2)
 scene.state.select_stage(route)
 var started:Dictionary=scene.state.start_stage()
 scene.state.defeat_stage_monster(started.run_id,0);scene.state.defeat_stage_monster(started.run_id,1)
 scene.state.check_route_opportunity(started.run_id)
 if scene.state.stage_status().opportunity_pending:scene.state.choose_opportunity('gather_gift')
 scene.state.pause_stage(started.run_id)
 label=Label.new();label.position=Vector2(18,8);label.add_theme_font_size_override('font_size',11);label.add_theme_color_override('font_color',Color('#405549'));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(label)
 label.text=scene.state.Content.STAGES[route].name+' · '+scene.state.Content.TECHNIQUES[technique].name+' · 同场测试配置 / 原生 1200×320 / 正常速度'
 scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0;scene.meditation_settle=2.0;scene.toast_time=0
 await create_timer(1.0).timeout
 scene._start_encounter()
func _process(delta:float):
 if done or not is_instance_valid(scene):return
 clock+=delta
 if scene.encounter_phase=='travel' and not prepared:
  prepared=true
  scene.route_enemy_definition.hp=500;scene.route_enemy_definition.max_hp=500;scene.route_enemy_definition.attack=8;scene.route_enemy_definition.defense=1
  scene.enemy_hp=500;scene.enemy_max_hp=500
 if scene.encounter_phase=='fight':
  if not fight_started:
   fight_started=true
   var definition:Dictionary=scene.route_enemy_definition.duplicate(true)
   scene.duel.start({'hp':100,'max_hp':100,'attack':11,'defense':1,'technique_level':1},definition,technique,'fan' if technique=='petal' else 'sword',377)
   scene.vitality=100;scene.vitality_max=100;scene.duel_pose=scene.duel.pose()
   print('COMPARISON_FIGHT_START '+JSON.stringify({'tag':tag,'technique':technique,'time':clock,'route_distance':scene.route_distance,'seed':377}))
  fight_age+=delta
 if scene.encounter_phase!=last_phase:
  last_phase=scene.encounter_phase;print('COMPARISON_PHASE '+JSON.stringify({'time':clock,'phase':last_phase,'route_distance':scene.route_distance}))
 var p:Dictionary=scene.duel_pose
 samples.append({'time':snappedf(clock,.00001),'phase':scene.encounter_phase,'distance':scene.route_distance,'enemy_x':scene.encounter_enemy_x,'gait_velocity':scene.side_motion.get('velocity',0),'hero_phase':p.get('hero',{}).get('combat_phase',''),'enemy_phase':p.get('enemy',{}).get('combat_phase',''),'hero_hp':scene.vitality,'enemy_hp':scene.enemy_hp})
 if fight_age>=14.0 or clock>=42.0:
  done=true
  call_deferred('_finish_capture')
func _finish_capture():
 var out=FileAccess.open(capture_root+'/'+tag+'-'+route+'-'+technique+'-samples.json',FileAccess.WRITE);out.store_string(JSON.stringify(samples));out.close()
 if DisplayServer.get_name()!='headless':await RenderingServer.frame_post_draw;root.get_texture().get_image().save_png(capture_root+'/'+tag+'-'+route+'-'+technique+'-last.png')
 print('COMPARISON_COMPLETE '+tag+' '+technique+' '+str(clock))
 scene.queue_free();await process_frame;await process_frame;call_deferred('quit')
