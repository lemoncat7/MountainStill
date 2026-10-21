extends SceneTree
## Native book review. Preset resources are disclosed; unlocks use real buttons.
var scene
var label:Label
var output:='user://revision-captures'
func _initialize():call_deferred('start')
func click(key:String):
 var b=scene.buttons.get(key)
 if not is_instance_valid(b) or b.disabled:printerr('MERIDIAN_CAPTURE_BLOCKED '+key);return false
 b.pressed.emit();print('MERIDIAN_CAPTURE_CLICK '+key);return true
func capture(name:String):
 if DisplayServer.get_name()!='headless':
  await RenderingServer.frame_post_draw
  root.get_texture().get_image().save_png(output+'/meridian-'+name+'.png')
func start():
 for argument in OS.get_cmdline_user_args():
  if str(argument).begins_with('--capture-root='):output=str(argument).trim_prefix('--capture-root=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output))
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://meridian_visual_review.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state.auto_advance=false;scene.state.realm=9;scene.state.qi=10000;scene.state.herbs=400;scene.state.dew=120
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false;scene.strip=true;scene.desktop.transparent_enabled=true;RenderingServer.set_default_clear_color(Color('#e8e7df'))
 for template in ['weapon_sword','chest_blue','legs_jade','feet_boots','head_pin']:
  var id:int=scene.state.gear._allocate_id();scene.state.gear.inventory.append(scene.state.gear._make_item(id,template,'common',1));scene.state.equip_item(id)
 label=Label.new();label.position=Vector2(18,8);label.add_theme_font_size_override('font_size',10);label.add_theme_color_override('font_color',Color('#405549'));label.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(label)
 label.text='经脉修订 · 22 穴 / 原生界面 / 预置资源测试，解锁真实扣费'
 scene.character_x=520.0;scene.character_y=230.0;scene.meditation_amount=1.0;scene.meditation_settle=2.0;scene.toast_time=0
 await create_timer(1.0).timeout
 scene.wardrobe_tab='meridian';scene._toggle_drawer('wardrobe');scene._refresh_drawer()
 await create_timer(2).timeout;await capture('central')
 click('meridian_row_qihai');click('unlock_meridian');await create_timer(1.5).timeout
 for branch in ['edge','ward','flow','quiet']:
  click('meridian_branch_'+branch);await create_timer(1.8).timeout;await capture(branch)
  if branch=='edge':
   click('unlock_meridian');await create_timer(1).timeout
   click('meridian_row_hegu');await create_timer(1).timeout;click('unlock_meridian');await create_timer(1.5).timeout;await capture('edge-opened')
  if branch=='flow':
   click('meridian_row_fengchi');await create_timer(1.5).timeout;await capture('flow-locked')
 scene._close_drawer();await create_timer(1.5).timeout
 print('MERIDIAN_CAPTURE_DONE '+JSON.stringify({'nodes':scene.state.meridian_count,'qi':scene.state.qi,'herbs':scene.state.herbs,'dew':scene.state.dew,'stats':scene.state.stats()}))
 scene.queue_free();await process_frame;await process_frame;quit()
