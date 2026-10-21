extends SceneTree
## Normal-speed playback from a lawfully earned paused checkpoint.
## All departure, journey, contacts, rewards and return are production-host code.
var scene
var route:='bamboo_pass'
var folder:='user://impact-proof'
var output:='user://impact-proof'
var events:Array=[]
var frame_samples:Array=[]
var last_phase:=''
var last_contact:=''
var clock:=0.0
var done:=false
var began:=false
var home_age:=0.0
var fast:=false
var max_sfx_proof:=false
func _initialize():call_deferred('start')
func start():
 for arg in OS.get_cmdline_user_args():
  if arg.begins_with('--route='):route=arg.trim_prefix('--route=')
  if arg.begins_with('--checkpoints='):folder=arg.trim_prefix('--checkpoints=')
  if arg.begins_with('--output='):output=arg.trim_prefix('--output=')
  if arg=='--fast-proof':fast=true
  if arg=='--max-sfx-proof':max_sfx_proof=true
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://impact_journey_isolated.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.save_path=folder+'/'+route+'-checkpoint.json'
 var loaded:Dictionary=scene.state.load_game()
 if not loaded.get('loaded',false):push_error('CHECKPOINT_LOAD_FAILED');quit(1);return
 scene.state.settings.paused=false;scene.paused=false;scene.state.save_path='user://impact_playback_isolated.json'
 if max_sfx_proof:scene.state.settings.sfx=1.0
 scene._volume()
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
 scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0;scene.meditation_settle=2.0;scene.toast_time=0
 scene.show_combat_move_labels=false
 if fast:Engine.time_scale=15.0
 await create_timer(1.0).timeout
 scene.wardrobe_tab='expedition';scene.set_meta('ink_stage_id',route);scene._toggle_drawer('wardrobe')
 await create_timer(2.0).timeout
 var button=scene.buttons.get('depart_stage')
 if not is_instance_valid(button) or button.disabled:push_error('DEPART_DISABLED');quit(1);return
 button.pressed.emit();began=true
func _process(delta:float):
 if done or not is_instance_valid(scene):return
 clock+=delta
 if scene.encounter_phase!=last_phase:
  last_phase=scene.encounter_phase
  var entry:={'time':clock,'phase':last_phase,'index':scene.encounter_index,'route':route,'route_distance':scene.route_distance,'hero_hp':scene.vitality,'enemy_hp':scene.enemy_hp}
  events.append(entry);print('SLICE_PHASE '+JSON.stringify(entry))
 if scene.encounter_phase=='fight':
  var event:Dictionary=scene.duel._last_contact
  var contact:=str(event.get('contact_id',''))+':'+str(scene.encounter_index)
  if not str(event.get('contact_id','')).is_empty() and contact!=last_contact:
   last_contact=contact;var entry:=event.duplicate(true);entry.capture_time=clock;events.append(entry);print('SLICE_CONTACT '+JSON.stringify(entry))
  var pose:Dictionary=scene.duel_pose
  frame_samples.append({'time':clock,'duel_time':scene.duel.elapsed,'hold':scene.combat_hitstop,'move':pose.get('enemy',{}).get('move_family',''),'phase':pose.get('enemy',{}).get('combat_phase',''),'hero':pose.get('hero',{}),'enemy':pose.get('enemy',{})})
 if scene.encounter_phase=='opportunity':
  scene.state.choose_opportunity('gather_gift')
 if began and not scene.encounter_active:
  home_age+=delta
  if home_age>2.0:done=true;call_deferred('finish')
 if clock>150.0:push_error('SLICE_TIMEOUT');done=true;call_deferred('finish')
func finish():
 var path:=output+'/'+route+'-journey-events.json';var file:=FileAccess.open(path,FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({'events':events,'frames':frame_samples,'seconds':clock,'complete':int(scene.state.stage_clears.get(route,0))>0,'victories':scene.state.total_victories},'\t'));file.close()
 print('SLICE_DONE route='+route+' seconds='+str(clock)+' clear='+str(scene.state.stage_clears.get(route,0)))
 scene.queue_free();scene=null;await process_frame;await process_frame;call_deferred('quit')
