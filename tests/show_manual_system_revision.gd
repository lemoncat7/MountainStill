extends SceneTree
## Native UI proof. Preset study resources are explicitly disclosed on screen.
var scene
var banner:Label
var prefix:='user://revision-captures/manuals'
var quick:=false
var weapon:='sword'
var events:Array=[]
func _initialize():call_deferred('start')
func press(key:String)->bool:
 var b=scene.buttons.get(key)
 if not is_instance_valid(b) or b.disabled:
  printerr('MANUAL_CONTROL_BLOCKED '+key);return false
 b.pressed.emit();events.append({'time':scene.elapsed,'button':key,'heart':scene.state.equipped_heart,'qi':scene.state.qi,'herbs':scene.state.herbs,'dew':scene.state.dew});return true
func shot(name:String):
 await RenderingServer.frame_post_draw
 root.get_texture().get_image().save_png(prefix+'-'+name+'.png')
func hold(seconds:float):await create_timer(seconds).timeout
func start():
 for arg in OS.get_cmdline_user_args():
  if str(arg).begins_with('--capture-prefix='):prefix=str(arg).trim_prefix('--capture-prefix=')
  if arg=='--quick':quick=true
  if str(arg).begins_with('--weapon='):weapon=str(arg).trim_prefix('--weapon=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(prefix.get_base_dir()))
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://manual_visual_review.json';root.add_child(scene);await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false;scene.state.realm=9;scene.state.qi=50000;scene.state.herbs=600;scene.state.dew=180
 for id in scene.state.Content.TECHNIQUES:scene.state.technique_levels[id]=1
 scene.state.technique_levels.breath=2
 var form:String='petal' if weapon=='fan' else 'mist'
 scene.state.attuned_techniques.assign([form,'breath','stillness','ember','frost','body','barrier'])
 for template in ['weapon_'+weapon,'chest_blue','legs_jade','feet_boots','head_pin']:
  var id:int=scene.state.gear._allocate_id();scene.state.gear.inventory.append(scene.state.gear._make_item(id,template,'common',1));scene.state.equip_item(id)
 var quote:Dictionary=scene.state.quote_heart_switch('breath');scene.state.confirm_heart_switch(quote)
 scene.state.equipped_weapon_art='';scene.state.equip_technique(form,'weapon_art');scene.state.unequip_technique('mist','active');scene.state.equip_technique('ember','active');scene.state.equip_technique('frost','active');scene.state.equip_technique('body','passive')
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true;RenderingServer.set_default_clear_color(Color('#e8e7df'))
 scene.toast_time=0;scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0;scene.meditation_settle=2.0
 banner=Label.new();banner.position=Vector2(18,8);banner.add_theme_font_size_override('font_size',10);banner.add_theme_color_override('font_color',Color('#405549'));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(banner)
 banner.text='功法修订 · 原生界面 / 预置养成资源测试 / 装配、参悟、换修均走真实规则'
 scene.wardrobe_tab='technique';scene._toggle_drawer('wardrobe');await hold(2);await shot('all')
 for filter in ['weapon_art','spell','defense','movement','body','support']:
  press('tech_category_'+filter);await hold(1.4);await shot(filter)
  if filter=='weapon_art':press('equip_'+form);press('practice_preview');await hold(1.0);await shot('sword-preview')
  if filter=='spell':press('equip_frost');press('practice_preview');await hold(1.0);await shot('frost-preview')
 if not quick:
  press('tech_category_heart');press('equip_stillness');await hold(1.0);press('manual_slot_heart');await hold(3.0);await shot('heart-cost')
  press('confirm_heart_switch');await hold(2.0);await shot('heart-adjusting')
  var guard:=0
  while not scene.state.pending_heart_switch.is_empty() and guard<60:
   await hold(.5);guard+=1
  await hold(1.0);await shot('heart-complete')
  press('tech_category_body');press('equip_body');press('train_technique');await hold(3.0);await shot('training')
 var file=FileAccess.open(prefix+'-events.json',FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({'events':events,'heart':scene.state.equipped_heart,'pending':scene.state.pending_heart_switch,'training':scene.state.technique_training,'attuned':scene.state.attuned_techniques},'  '));file.close()
 print('MANUAL_CAPTURE_COMPLETE '+str(scene.elapsed))
 scene.queue_free();scene=null;await process_frame;await process_frame;call_deferred('quit')
