extends SceneTree
const PoseRenderer=preload('res://scripts/monster_pose_renderer.gd')
const Moves=preload('res://scripts/monster_move_library.gd')
var scene
var canvas
var timer:=0.0
var saved:Dictionary={}
var output:='user://qa/anatomy'
class AnatomyCanvas extends Control:
 var textures:Dictionary={}
 var motion:Dictionary={}
 var key:='cloud_slope_boss_idle'
 var size_px:=174.0
 func _draw():
  PoseRenderer.draw(self,textures,key,Vector2(690,280),size_px,motion,Color.WHITE)
func _initialize():call_deferred('start')
func start():
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://anatomy_review_isolated.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false;scene.strip=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
 scene.character_x=470;scene.character_y=230;scene.set_process(false)
 canvas=AnatomyCanvas.new();canvas.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT);scene.add_child(canvas)
 for prefix in ['bamboo_pass','bamboo_pass_boss','cloud_slope','cloud_slope_boss']:
  for pose in ['idle','windup','attack']:canvas.textures[prefix+'_'+pose]=load('res://assets/cultivation/beasts/'+prefix+'_'+pose+'.png')
func _process(delta:float):
 if canvas==null:return
 timer+=delta
 var families:Array=['moss_pounce','moss_rush','moss_slam','crane_peck','crane_sweep','crane_dive']
 var segment:int=mini(5,int(timer/3.0))
 var family:String=families[segment]
 var local:float=fmod(timer,3.0)
 var phase:Dictionary={'name':'idle','progress':0.0,'index':0}
 if local<.8:phase={'name':'windup','progress':local/.8,'index':0}
 elif local<1.3:phase={'name':'strike','progress':(local-.8)/.5,'index':0}
 elif local<1.45:phase={'name':'contact','progress':(local-1.3)/.15,'index':0}
 elif local<2.35:phase={'name':'recovery','progress':(local-1.45)/.9,'index':0}
 var action:Dictionary={'move_family':family,'start':0.0,'windup':.8}
 var sample:Dictionary=Moves.sample(action,phase,local)
 sample.combat_phase=phase.name;sample.phase_progress=phase.progress;sample.visual_offset=sample.root_offset;sample.strike_index=0
 canvas.motion=sample;canvas.key=('bamboo_pass_boss_idle' if segment<3 else 'cloud_slope_boss_idle');canvas.queue_redraw()
 if local>.68 and not saved.has(str(segment)+'wind'):
  saved[str(segment)+'wind']=true;call_deferred('save_frame',family+'-wind')
 if local>1.28 and not saved.has(str(segment)+'hit'):
  saved[str(segment)+'hit']=true;call_deferred('save_frame',family+'-hit')
 if timer>18.1:quit()
func save_frame(tag:String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(output+'/'+tag+'.png')
