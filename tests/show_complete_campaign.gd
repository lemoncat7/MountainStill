extends SceneTree
## A single fresh-save journey through real UI callbacks and real host combat.
## No realms, resources, gear or victories are injected. Seed only makes QA reproducible.
var scene
var banner:Label
var failed=false
var proof=('--fast-proof' in OS.get_cmdline_user_args())
var events:Array=[]
var capture_prefix='user://campaign-capture'
func _initialize():call_deferred('start')
func cue(kind:String,detail:String=''):
 var entry={'time':snappedf(scene.elapsed,.001),'kind':kind,'detail':detail,'realm':scene.state.realm,'qi':scene.state.qi,'herbs':scene.state.herbs,'victories':scene.state.total_victories}
 events.append(entry);print('CAMPAIGN_CUE '+JSON.stringify(entry))
func hold(seconds:float):await create_timer(seconds).timeout
func press(key:String,required:bool=true)->bool:
 var b=scene.buttons.get(key)
 if not is_instance_valid(b) or b.disabled:
  if required:printerr('CAMPAIGN_CONTROL_BLOCKED '+key);failed=true
  return false
 b.pressed.emit();cue('button',key);return true
func page(name:String):
 if scene.drawer_name!=name:scene._toggle_drawer(name)
 else:scene._refresh_drawer()
func title(text:String):
 banner.text=text
 cue('section',text)
func manual_row(id:String)->Dictionary:
 for row in scene.state.technique_rows():
  if str(row.id)==id:return row
 return {}
func train_and_equip(id:String,target:int,slots:Array):
 var row:Dictionary=manual_row(id)
 if row.is_empty() or not row.get('unlocked',false):return
 var category:String=str(row.get('category','all'))
 press('tech_category_'+category);await hold(.4);press('equip_'+id);await hold(.5)
 for attempt in range(7):
  row=manual_row(id)
  if int(row.level)>=target or not row.get('can_upgrade',false):break
  var duration:float=float(row.get('training_duration',8.0))
  if not press('train_technique',false):break
  title('展卷研习 · 实际支付草露，等候参悟完成')
  await hold(duration+.25);cue('training_complete',id)
 row=manual_row(id)
 if not row.get('attuned',false):press('attune_technique',false);await hold(.3)
 for slot in slots:
  row=manual_row(id)
  if slot in row.get('equipped_slots',[]):continue
  if not press('manual_slot_'+str(slot),false):continue
  await hold(.6)
  if slot=='heart':
   if press('confirm_heart_switch',false):
    while not scene.state.pending_heart_switch.is_empty():await hold(.5)
   await hold(.6)
func start():
 for argument in OS.get_cmdline_user_args():
  if str(argument).begins_with('--capture-prefix='):capture_prefix=str(argument).trim_prefix('--capture-prefix=')
 DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(capture_prefix.get_base_dir()))
 scene=load('res://main.tscn').instantiate();scene.state.save_path='user://complete_campaign_capture.json';root.add_child(scene)
 await process_frame
 scene.demo=true;scene.state.new_game();scene.state._adventure_rng.seed=1271;scene.state.gear.rng.seed=110
 scene.state.save_path='user://complete_campaign_capture.json'
 scene.get_window().size=Vector2i(1200,320);scene.get_window().transparent_bg=false
 scene.strip=true;scene.desktop.transparent_enabled=true
 RenderingServer.set_default_clear_color(Color('#e8e7df'))
 scene.toast_time=0
 banner=Label.new();banner.position=Vector2(17,7);banner.add_theme_font_size_override('font_size',10);banner.add_theme_color_override('font_color',Color('#445a49'));banner.mouse_filter=Control.MOUSE_FILTER_IGNORE;scene.add_child(banner)
 if proof:Engine.time_scale=30.0
 title('山隐 · 归山一卷   原生实机 / 新建存档 / 正常游戏速度')
 await hold(3)
 page('practice');scene.set_meta('ink_journal_tab','guide');scene._refresh_drawer();await hold(3)
 press('guide_step_1');await hold(1);press('guide_action');await hold(2)
 press('first_chest');await hold(2);press('equip_selected');await hold(2);scene._close_drawer();await hold(2)
 title('草木入炉 · 实际炼丹与服用，培养资源均来自游戏')
 page('alchemy');await hold(2);press('start_brew');scene._close_drawer();await hold(21)
 page('alchemy');await hold(2);press('use_pill');await hold(2)
 page('practice');scene.set_meta('ink_journal_tab','practice');scene._refresh_drawer()
 if not scene.state.auto_advance:press('practice_auto')
 await hold(2);scene._close_drawer();await hold(2)
 for chapter in range(6):
  var id:String=scene.state.Content.CHAPTER_ORDER[chapter]
  var stage_name:String=scene.state.Content.STAGES[id].name
  title('第%d章 · %s   手动出发 / 遇敌停步 / 真实交锋'%( [chapter+1,stage_name]))
  scene.wardrobe_tab='expedition';scene.set_meta('ink_stage_page',int(chapter/3));scene.set_meta('ink_stage_id',id);page('wardrobe');await hold(2)
  press('stage_'+id);await hold(2);press('depart_stage');cue('depart',id)
  var wait_time=0.0;var seen_phase='';var seen_index=-1;var retries=0
  while int(scene.state.stage_clears.get(id,0))==0 or scene.encounter_active:
   await hold(.2);wait_time+=.2
   if scene.encounter_phase!=seen_phase or scene.encounter_index!=seen_index:
    if not proof and scene.encounter_phase=='fight' and scene.encounter_index==2:
     await RenderingServer.frame_post_draw
     root.get_texture().get_image().save_png(capture_prefix+'-'+id+'-boss.png')
    seen_phase=scene.encounter_phase;seen_index=scene.encounter_index;cue('phase','%s:%d:%s'%[id,seen_index,seen_phase])
   if scene.encounter_phase=='opportunity':
    title('山间机缘 · 停步等你选择，没有倒计时')
    await hold(2);press('route_opportunity');await hold(3);press('opportunity_gather_gift');await hold(1)
    title('第%d章 · %s   机缘已决，继续前往守关者'%[chapter+1,stage_name])
   if not scene.encounter_active and int(scene.state.stage_clears.get(id,0))==0:
    retries+=1
    if retries>3:failed=true;break
    title('回山调息 · 已过路段保留，修为与行装无损')
    await hold(2);scene.wardrobe_tab='expedition';page('wardrobe');await hold(2);press('depart_stage');cue('retry',id)
   if wait_time>300:failed=true;printerr('CAMPAIGN_ROUTE_TIMEOUT '+id);break
  if failed:break
  cue('home',id);await hold(2)
  title('首通心意 · 固定山印与行装入囊，再亲手穿上')
  scene.wardrobe_tab='equipment';page('wardrobe');await hold(2);press('equip_selected');await hold(2)
  press('wardrobe_technique');await hold(1)
  await train_and_equip('mist',mini(6,chapter+2),['weapon_art','active'])
  if chapter>=1:await train_and_equip('body',1,['passive'])
  if chapter>=2:await train_and_equip('ember',mini(3,chapter),['active'])
  if chapter==0 or chapter==2:press('practice_preview');await hold(3)
  press('wardrobe_meridian');await hold(1)
  for point in scene.state.meridian_rows():
   # Recheck paid prerequisites, then reveal the actual branch before clicking.
   var fresh:Dictionary={}
   for current in scene.state.meridian_rows():
    if current.id==point.id:fresh=current
   if fresh.get('can_unlock',false):
    press('meridian_branch_'+str(point.branch));await hold(.2)
    press('meridian_row_'+str(point.id));await hold(.6);press('unlock_meridian');await hold(1)
  scene._close_drawer();await hold(2)
  if chapter==1:
   title('衣冠五部位独立 · 淬炼与经脉都使用真实所得')
   scene.wardrobe_tab='equipment';page('wardrobe');await hold(1);press('enhance_item',false);await hold(2);scene._close_drawer();await hold(1)
 if not failed:
  title('六印归一 · 守灵与山路俱已安定，归家写下尾声')
  page('practice');scene.set_meta('ink_journal_tab','ending');scene._refresh_drawer();await hold(4)
  press('ending_action');await hold(5);cue('ending',str(scene.state.chapter_status()))
  # Persist this real earned complete-save fixture, isolated from player saves.
  scene.state.settings.paused=true;scene.state.save_game()
  scene._close_drawer();scene.state.settings.paused=false;scene.state.set_activity('meditate');await hold(6)
  title('山路有终，山居长在。   固定随机种子复现 / 录制采用中性底色')
  await hold(5)
 var file=FileAccess.open(capture_prefix+'-events.json',FileAccess.WRITE)
 if file:file.store_string(JSON.stringify({'failed':failed,'events':events,'ending':scene.state.chapter_status(),'total_seconds':scene.elapsed},'  '));file.close()
 print('CAMPAIGN_CAPTURE_DONE failed=%s victories=%d realm=%d ending=%s seconds=%.1f'%[failed,scene.state.total_victories,scene.state.realm,scene.state.chapter_status().ending_complete,scene.elapsed])
 scene.queue_free();scene=null;await process_frame;await process_frame;quit(1 if failed else 0)
