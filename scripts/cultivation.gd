extends Control

const PracticeHost = preload("res://scripts/practice_host.gd")
var practice_session = null
var practice_snapshot: Dictionary = {}
var practice_controls: Control = null
var practice_comparison: Dictionary = {}
var practice_previous_reports: Dictionary = {}

func practice_enemy_rows() -> Array: return PracticeHost.rows(self)
func practice_can_start() -> String: return PracticeHost.blocked(self)
func start_practice(enemy_id: String) -> bool: return PracticeHost.start(self, enemy_id)
func end_practice(): PracticeHost.finish(self)
func toggle_practice_pause():
	if practice_session == null: return
	if bool(practice_session.status().get("paused", false)): practice_session.resume()
	else: practice_session.pause()
	PracticeHost.controls(self)
	_refresh_drawer()

const CombatResponseCues = preload("res://scripts/combat_response_cues.gd")
const CorpsePresentation = preload("res://scripts/corpse_presentation.gd")
const State = preload("res://scripts/cultivation_state.gd")
const Desktop = preload("res://scripts/desktop_mode.gd")
const Readability = preload("res://scripts/readability_layout.gd")
const SceneArt = preload("res://scripts/scene_art_layout.gd")
var display_check_clock := 0.0
var last_display_scale := 1.0
var applying_readability := false
const QuietButton = preload("res://scripts/quiet_button.gd")
const InkHotspot = preload("res://scripts/ink_hotspot.gd")
const InkPaper = preload("res://scripts/ink_paper.gd")
const InkPages = preload("res://scripts/ink_pages.gd")
const CapacityPages = preload("res://scripts/capacity_pages.gd")
const RewardCapacity = preload("res://scripts/reward_capacity.gd")
const JournalPages = preload("res://scripts/journal_pages.gd")
const CharacterSidewalk = preload("res://scripts/character_sidewalk.gd")
const DuelTimeline = preload("res://scripts/duel_timeline.gd")
const RouteMotion = preload("res://scripts/route_motion.gd")
const BeastPresentation = preload("res://scripts/beast_presentation.gd")
const MonsterPoseRenderer = preload("res://scripts/monster_pose_renderer.gd")
const CombatImpact = preload("res://scripts/combat_impact.gd")
const CharacterWalk = preload("res://scripts/character_walk.gd")
const CharacterMeditation = preload("res://scripts/character_meditation.gd")
const CharacterPreview = preload("res://scripts/character_preview.gd")
const CharacterProjection = preload("res://scripts/character_projection.gd")
const PortalShader = preload("res://scripts/portal_dissolve.gdshader")
const SANS = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const SERIF = preload("res://assets/fonts/NotoSerifCJK-Regular.ttc")
const BRUSH = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const LATIN = preload("res://assets/fonts/DejaVuSans.ttf")
const PAPER = Color("f0e9d7")
const INK = Color("303b37")
const SUBTLE = Color("818579")
var GOLD = Color("9e4739")
var content_accent = Color(.36,.40,.29,.65)
const LINE = Color("d3ddd2")

var state=State.new()
var desktop=Desktop.new()
var scene_texture:Texture2D
var diorama_texture:Texture2D
var nav:Control
var drawer:Control
var drawer_name=""
var drawn_page=""
var drawer_alpha=0.0
var paper_reveal=0.0
var paper_width=700.0
var drawer_tween:Tween
var content_tween:Tween
var dialog_tweens:Dictionary={}
var content_alpha=1.0
var content_offset=0.0
var drawer_generation=0
var interaction_serial=0
var interaction_pulse=0.0
var interaction_rect=Rect2()
var equipment_pulse=0.0
var reward_pulse=0.0
var toast_age=0.0
var meditation_amount=0.0
var meditation_clock=0.0
var meditation_settle=0.0
var meditation_phase="standing"
var rendered_stage_scale=1.0
var preview_blend=0.0
var character_preview:Control
var paused=false
var strip=false
var elapsed=0.0
var save_clock=0.0
var repaint_clock=0.0
var toast=""
var toast_time=0.0
var breakthrough_glow=0.0
var qi_motes:Array=[]
var journal:Array[String]=[]
var music:AudioStreamPlayer
var audio:AudioStreamPlayer
var combat_audio:AudioStreamPlayer
var combat_audio_streams:Dictionary={}
var combat_voices:Array[AudioStreamPlayer]=[]
var combat_voice_cursor:=0
var combat_hitstop:=0.0
var combat_frame_delta:=0.0
var footstep_phase:=-1.0
var footstep_serial:=0
var show_combat_move_labels:=false
var tip:AcceptDialog
var reset_dialog:ConfirmationDialog
var salvage_dialog:ConfirmationDialog
var salvage_pending=-1
var demo=false
var capturing=false
var drag_active=false
var drag_start=Vector2i.ZERO
var mouse_start=Vector2i.ZERO
var last_size=Vector2.ZERO
var buttons:Dictionary={}
var capture_clock=0.0
var panel_last_values=""
var ui_alpha=0.0
var mouse_inside=false
var ui_hold=0.0
var character_x=520.0
var character_y=230.0
var avatar_assets:Dictionary={}
var side_weapon_assets:Dictionary={}
var wardrobe_tab="equipment"
var selected_item=-1
var selected_slot="chest"
var inventory_page=0
var equipment_assets:Dictionary={}
var equipment_icons:Dictionary={}
var encounter_assets:Dictionary={}
var route_assets:Dictionary={}
var beast_assets:Dictionary={}
var world_route=""
var route_distance=0.0
var route_scroll_velocity=0.0
var route_frame_velocity=0.0
var combat_impacts:Array[Dictionary]=[]
var route_target_distance=220.0
var route_scroll_assets:Dictionary={}
var bamboo_panorama:Texture2D
var route_panoramas:Dictionary={}
var vitality_max=100.0
var route_opportunity_at=680.0
var route_enemy_definition:Dictionary={}
var route_boss=false
var duel=DuelTimeline.new()
var duel_pose:Dictionary={}
var battle_resources:Dictionary={}
var duel_resolution=""
var combat_report_saved := false
var hero_resolution=""
var sidewalker=CharacterSidewalk.new()
var side_motion:Dictionary={}
const ROUTE_HERO_X=390.0
const ROUTE_EVENTS=[220.0,500.0,940.0]

var portal_viewport:SubViewport
var portal_projection:Node2D
var portal_material:ShaderMaterial
var portal_dissolve=0.0
var encounter_active=false
var encounter_clock=0.0
var encounter_phase="idle"
var encounter_run_id=0
var encounter_index=0
var encounter_stage_name=""
var encounter_enemy_x=705.0
var encounter_phase_age=0.0
var encounter_enemy_attack=3
var encounter_enemy_defense=0
var encounter_enemy_name="山野精怪"
var pickup_collect_started=-1.0
var pickup_claimed_at=-1.0
var pickup_save_bucket=-1
var pickup_status:Dictionary={}
var pickup_block_reason=""
var encounter_counter_hit=false
var encounter_reward:Dictionary={}
# A player-requested paused return may animate only the two homebound portals.
# This is presentation-only authority, never saved or shared with practice.
var paused_retreat_run_id:int=-1
var encounter_complete=false
var encounter_first_clear=false
var encounter_chapter_reward:Dictionary={}
var pickup_burst=0.0
var meridian_glow=0.0
var enemy_defeat=0.0
var defeat_enemy_motion:Dictionary={}
var finish_hero_motion:Dictionary={}
var hero_hit=0.0
var hero_damage=0
var hero_support_text=""
var hero_support_time=0.0
var encounter_hit=false
var enemy_hp=0.0
var enemy_max_hp=1.0
var enemy_kind="fox"
var enemy_flash=0.0
var vitality=100.0
var expedition_wait=0.0
var chest_time=0.0
var chest_reveal_age=0.0
var last_loot:Dictionary={}
var combat_number=""
var combat_number_time=0.0
var practice_time=0.0
var practice_duration=6.0
var cast_blend=0.0
var interface_clock=0.0
var closing=false
var completed_presented=false
var meditator=CharacterMeditation.new()
var walker=CharacterWalk.new()
var walk_motion:Dictionary={"phase":0.0,"blend":0.0,"facing":1.0,"bob":0.0,"body_tilt":0.0}

func _ready():
	clip_contents=true
	var theme_value=Theme.new();theme_value.default_font=SANS;theme_value.default_font_size=13;theme=theme_value
	var tooltip_style=InkPaper.paper_style(12,8)
	theme_value.set_stylebox("panel","TooltipPanel",tooltip_style);theme_value.set_color("font_color","TooltipLabel",INK);theme_value.set_font_size("font_size","TooltipLabel",12)
	for control in ["AcceptDialog","Window","PopupPanel"]:theme_value.set_stylebox("panel",control,InkPaper.paper_style(18,14))
	theme_value.set_font("title_font","Window",BRUSH);theme_value.set_font_size("title_font_size","Window",22);theme_value.set_color("title_color","Window",INK)
	theme_value.set_color("font_color","Label",INK)
	for state_name in ["normal","disabled"]:theme_value.set_stylebox(state_name,"Button",StyleBoxEmpty.new())
	for state_name in ["hover","pressed","focus"]:theme_value.set_stylebox(state_name,"Button",InkPaper.brush_style(.10 if state_name=="hover" else .18))
	theme_value.set_font("font","Button",SERIF)
	for color_name in ["font_color","font_hover_color","font_pressed_color","font_focus_color"]:theme_value.set_color(color_name,"Button",INK)

	texture_filter=CanvasItem.TEXTURE_FILTER_LINEAR
	demo="--demo" in OS.get_cmdline_user_args() or "--loot-demo" in OS.get_cmdline_user_args() or "--campaign-demo" in OS.get_cmdline_user_args()
	capturing="--capture" in OS.get_cmdline_user_args()
	if demo:
		state.save_path="user://cultivation_demo.json";state.new_game()
		if "--loot-demo" in OS.get_cmdline_user_args():state.gear.rng.seed=110;state.auto_advance=false
		if "--review" in OS.get_cmdline_user_args():
			state.qi=100;state.herbs=9;state.dew=2;state.pills=1;state.auto_advance=false
		if "--campaign-demo" in OS.get_cmdline_user_args():_prepare_campaign_demo()
	else:
		var offline=state.load_game()
		if float(offline.get("seconds",0))>60:_notice("你不在时，山中已过 %.1f 小时。修行所得已收入行囊。"%(float(offline.seconds)/3600))
		if offline.get("recovered",false):_notice("已从备份恢复山居存档。")
		elif offline.get("invalid_save",false):_notice("原存档无法读取，已保留原文件。先在此重新安居。")
		if offline.get("save_error",false):_notice("存档暂时无法写入，请检查本地权限。")
	for name in ["sword","fan","mist_slash","petal"]:
		var path="res://assets/cultivation/avatars/"+name+".png"
		if ResourceLoader.exists(path):avatar_assets[name]=load(path)
	for key in ["sword","fan"]:
		if avatar_assets.has(key):side_weapon_assets[key]=CharacterSidewalk.filtered_weapon(avatar_assets[key])
	for name in ["base","head_pin","head_crown","chest_blue","chest_jade","legs_blue","legs_jade","feet_cloth","feet_boots"]:
		var path="res://assets/cultivation/equipment/"+name+".png"
		if ResourceLoader.exists(path):
			equipment_assets[name]=load(path)
			var img:Image=equipment_assets[name].get_image()
			var used=img.get_used_rect()
			if used.has_area():equipment_icons[name]=ImageTexture.create_from_image(img.get_region(used))
	for name in ["fox_idle","fox_attack","boar_idle","boar_attack","chest_closed","chest_open"]:
		var path="res://assets/cultivation/encounters/"+name+".png"
		if ResourceLoader.exists(path):encounter_assets[name]=load(path)
	if ResourceLoader.exists("res://assets/cultivation/sanctuary-warm.png"):scene_texture=load("res://assets/cultivation/sanctuary-warm.png")
	if ResourceLoader.exists("res://assets/cultivation/sanctuary-diorama.png"):diorama_texture=load("res://assets/cultivation/sanctuary-diorama.png")
	for id in state.Content.STAGES:
		var path="res://assets/cultivation/routes/"+id+".png"
		if ResourceLoader.exists(path):route_assets[id]=load(path)
		var panorama_path="res://assets/cultivation/routes/"+id+"_panorama.png"
		if ResourceLoader.exists(panorama_path):route_panoramas[id]=load(panorama_path)
		var scroll_path="res://assets/cultivation/routes/"+id+"_scroll.png"
		if ResourceLoader.exists(scroll_path):route_scroll_assets[id]=load(scroll_path)
		for pose in ["idle","windup","attack","boss_idle","boss_windup","boss_attack","boss_retract","boss_settle"]:
			var beast_path="res://assets/cultivation/beasts/"+id+"_"+pose+".png"
			if ResourceLoader.exists(beast_path):beast_assets[id+"_"+pose]=load(beast_path)
	if ResourceLoader.exists("res://assets/cultivation/routes/bamboo_pass_panorama.png"):bamboo_panorama=load("res://assets/cultivation/routes/bamboo_pass_panorama.png")
	if ResourceLoader.exists("res://assets/cultivation/beasts/opportunity_cairn.png"):beast_assets.cairn=load("res://assets/cultivation/beasts/opportunity_cairn.png")
	_setup_portal_projection()
	desktop.attach(get_window())
	_setup_audio()
	_setup_dialogs()
	character_preview=CharacterPreview.new();character_preview.host=self;add_child(character_preview)
	_sync_character_preview(0.0)
	_build_nav()
	# The save gate and delayed audio/control teardown own native close requests.
	# Default auto-quit would bypass both immediately after close_requested.
	get_tree().auto_accept_quit=false
	get_window().close_requested.connect(_quit)
	get_window().mouse_entered.connect(func():mouse_inside=true)
	get_window().mouse_exited.connect(func():mouse_inside=false)
	get_viewport().size_changed.connect(_resized)
	_apply_settings()
	desktop.initialize(state.settings, "--expanded" in OS.get_cmdline_user_args())
	strip=desktop.strip_enabled
	desktop.set_transparent(bool(state.settings.transparent))
	_apply_readability()
	paused=bool(state.settings.get("paused",false))
	journal.append("初入青岚山，一灯一席，自此安居。")
	if capturing:_capture_later()
	elif not state.arrival_seen:
		set_meta("ink_journal_tab","guide")
		_notice("初入山中 · 下方入山札记会陪你走完这一卷，也可随时收起。")

	var update_service = get_tree().root.get_node_or_null("UpdateService")
	if update_service != null:
		update_service.content_applied.connect(_apply_hot_content)
		_apply_hot_content(update_service.content_data())
	get_tree().root.set_meta("update_gameplay_ready", true)

func _setup_dialogs():
	tip=AcceptDialog.new();tip.title="山居小记";tip.min_size=Vector2i(630,340)
	tip.dialog_text="山隐 · 归山一卷\n\n石台的修行札记含入山引导、目标和物华录。五大境各三期，最终归真。\n新档：静坐会积累灵气，突破先由你亲点。随缘可自行开启，自动静坐、采药与突破；手选活动后关闭。\n人物的行装册：五部位分别穿脱，白短裤始终保留。开启首箱开始收集。\n十种形制、四档品阶，每件装备可温养至 +5；分解前需确认。\n功法：十门书卷，三至七重上限。支付草露研习，计时后学成；心法、武式、主动与辅修分别装配。\n丹房：三种丹方随境界解锁。聚气增修为，回春与澄心提供限时增益。\n灵狐：选择青竹、听泉或眠云，游历归来自动带回资源与见闻。\n游历可离线进行；历练六章依序开放，须手选关卡、点击出发。每章三场后归山。\n每章首通获固定信物与成长赠礼；普通掉落仍为木箱12%、装备3%。机缘等你选择。\n任督六穴与四条支脉，共二十二穴；各脉可搭配，以灵气与草露温养，不阻境界突破。\n失败或归山保留已击退进度，点继续才重返；不扣行装修为。六章解结，归真后可读归山尾声。\n离线最多结算八小时，暂停时不积累；倒调时钟不会获益。\n\nI 行装 / A 丹方 / R 修行与引导 / G 采药 / M 小印设置。\n空格暂停；F2 切换小窗；Esc 或 F8 安全恢复普通窗口。\n拖动顶部空白区移动；位置、大小、音量与节能偏好都会保存。\n存档只在本地，并留有上一份备份；无云同步。\n透明和穿透取决于系统支持；Windows 暂不启用区域穿透。"
	add_child(tip)
	reset_dialog=ConfirmationDialog.new();reset_dialog.title="另起一段山居？";reset_dialog.dialog_text="这将清空境界、灵气、草药、丹药、全部装备与木箱，无法在游戏内撤销。";reset_dialog.ok_button_text="清空并重新开始";reset_dialog.cancel_button_text="保留山居"
	reset_dialog.confirmed.connect(func():
		if state.reset_save():_reset_presentation();_safe_restore();_apply_settings();_notice("一切如初。青山依旧在。","level");_refresh_drawer()
		else:_notice("暂时无法重置存档，请检查本地文件权限。"))
	add_child(reset_dialog)
	salvage_dialog=ConfirmationDialog.new();salvage_dialog.title="分解未穿戴装备？";salvage_dialog.ok_button_text="分解并收取灵草";salvage_dialog.cancel_button_text="保留"
	salvage_dialog.confirmed.connect(func():
		var result:Dictionary=state.salvage_item(salvage_pending)
		if result.get("ok",false):selected_item=-1;_notice("已分解，灵草收入行囊。","loot");_save_loadout();_refresh_drawer()
		elif str(result.get("reason",""))=="resource_full":CapacityPages.open(self,"salvage",{"id":salvage_pending},"resource_full")
		else:_notice("未分解：装备可能已穿戴或不存在，请重新选择。"))
	add_child(salvage_dialog)
	for dialog in [tip,reset_dialog,salvage_dialog]:
		dialog.about_to_popup.connect(func():_animate_dialog_contents(dialog))

func _animate_dialog_contents(dialog:Window):
	var id=dialog.get_instance_id()
	if dialog_tweens.has(id) and is_instance_valid(dialog_tweens[id]):dialog_tweens[id].kill()
	var tween=create_tween().set_parallel(true)
	for child in dialog.get_children(true):
		if child is CanvasItem:
			child.modulate.a=.15
			tween.tween_property(child,"modulate:a",1.0,.16).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	dialog_tweens[id]=tween

func _qbutton(parent:Control,key:String,label:String,rect:Rect2,fn:Callable,hint:String="",accent:bool=false,selected:bool=false)->Button:
	var b=QuietButton.new();b.text=label;b.position=rect.position;b.size=rect.size;b.hint=hint;b.accent=accent;b.selected=selected
	b.pressed.connect(func():
		if not is_instance_valid(b) or not b.is_inside_tree() or b.disabled:return
		_sound("equip",.12);_perform_page_action(key,rect,fn))
	parent.add_child(b);buttons[key]=b
	return b

func _hotspot(key:String,caption:String,rect:Rect2,fn:Callable,hint:String,seal=false):
	var b=InkHotspot.new();b.caption=caption;b.position=rect.position;b.size=rect.size;b.tooltip_text=hint;b.seal=seal
	b.pressed.connect(func():
		if practice_session != null or b.disabled: return
		_sound("equip",.08);fn.call())
	nav.add_child(b);buttons[key]=b
	if not seal:b.set_meta("scene_rect",rect)

func _build_nav():
	if is_instance_valid(nav):remove_child(nav);nav.queue_free()
	nav=Control.new();nav.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(nav)
	# A single discreet seal is always recoverable; other actions belong to the scenery.
	_hotspot("settings","山",Rect2(size.x-43,12,30,29),func():_toggle_drawer("settings"),"山居小印 · 设置、暂歇与离开 · M",true)
	_hotspot("wardrobe","行装",Rect2(0,0,95,144),func():_toggle_drawer("wardrobe"),"点人物翻阅行装册 · I")
	_hotspot("alchemy","丹房",Rect2(_world_x(879)-59,_world_y(227)-103,118,103),func():_toggle_drawer("alchemy"),"点香炉展开丹方 · A")
	_hotspot("practice","修行",Rect2(_world_x(520)-105,_world_y(230)-25,210,40),func():_toggle_drawer("practice"),"点石台查看修行札记 · R")
	_hotspot("companion","灵狐",Rect2(_world_x(686)-38,_world_y(245)-72,76,75),func():wardrobe_tab="adventure";_toggle_drawer("wardrobe"),"点灵狐查看游历与山间寻缘")
	_hotspot("garden","采药",Rect2(_world_x(145)-65,_world_y(213)-75,130,90),func():state.set_activity("gather");_notice("循药香而行，采一叶山间清气。");_refresh_drawer(),"点药圃采集灵草与灵露 · G")
	_hotspot("route_opportunity","机缘",Rect2(0,0,110,100),_open_route_opportunity,"点石龛回应机缘；它会一直等你")
	# A dismissible line of ink, not a permanent dashboard. Its visibility is
	# saved, while the complete guide always remains inside the stone journal.
	var note=QuietButton.new();note.position=Vector2(145,size.y-40);note.size=Vector2(247,28)
	note.text="入山札记 · 从这里开始 ↗" if not state.arrival_seen else "修行札记 · 看看眼下的一步 ↗"
	note.hint="从安顿、采药与研习，到突破、六章历练与归山。仅翻书，不代替你行动。"
	note.pressed.connect(func():set_meta("ink_journal_tab","guide");_toggle_drawer("practice"))
	nav.add_child(note);buttons.guide_note=note
	var dismiss=QuietButton.new();dismiss.text="×";dismiss.position=Vector2(393,size.y-40);dismiss.size=Vector2(24,28);dismiss.hint="收起这行提示；石台与R键仍能打开完整指引。"
	dismiss.pressed.connect(func():state.guidance_dismissed=true;_save_loadout();_build_nav())
	nav.add_child(dismiss);buttons.guide_dismiss=dismiss
	_update_hotspots()
	if practice_session != null: PracticeHost.lock_controls(self)

func _open_route_opportunity():
	wardrobe_tab="expedition";set_meta("expedition_view","opportunity")
	if drawer_name!="wardrobe":_toggle_drawer("wardrobe")
	else:_refresh_drawer()

func _update_hotspots():
	if not is_instance_valid(nav):return
	for key in ["wardrobe","alchemy","practice","garden","companion"]:
		var hotspot=buttons.get(key)
		if not is_instance_valid(hotspot):continue
		var source:Rect2=hotspot.get_meta("scene_rect",Rect2(hotspot.position,hotspot.size))
		if key=="wardrobe":source=Rect2(Vector2(_world_x(character_x)-46,_world_y((character_y+(16 if _diorama_active() or not world_route.is_empty() else 0)))-142),Vector2(95,144))
		hotspot.position=source.position;hotspot.size=source.size
	for key in ["wardrobe","alchemy","practice","garden","companion"]:
		if is_instance_valid(buttons.get(key)):
			buttons[key].visible=drawer_name.is_empty() and drawer_alpha<=.02 and (world_route.is_empty() or key=="wardrobe")
	if is_instance_valid(buttons.get("route_opportunity")):
		buttons.route_opportunity.visible=encounter_phase=="opportunity" and drawer_name.is_empty() and drawer_alpha<.02
		buttons.route_opportunity.position=Vector2(_world_x((ROUTE_HERO_X+130.0))-45,_world_y(246.0)-92)
	for key in ["guide_note","guide_dismiss"]:
		if is_instance_valid(buttons.get(key)):
			buttons[key].visible=not state.guidance_dismissed and drawer_name.is_empty() and drawer_alpha<=.02 and world_route.is_empty() and not encounter_active
	if desktop.desired_passthrough and drawer_name.is_empty():desktop.update_passthrough(Rect2(0,0,size.x,50),_interactive_regions())

func _interactive_regions()->Array:
	var regions:Array=[]
	for key in ["wardrobe","alchemy","practice","garden","companion","route_opportunity","guide_note","guide_dismiss"]:
		var b=buttons.get(key)
		if is_instance_valid(b) and (key!="route_opportunity" or encounter_phase=="opportunity"):regions.append(Rect2(b.position,b.size))
	return regions

func _perform_page_action(key:String,rect:Rect2,fn:Callable):
	if practice_session != null:
		if key.begins_with("practice_"): fn.call()
		return
	# Actions commit once immediately. Visual settling never queues stale commands.
	if drawer_name.is_empty() or closing:return
	var before_page=drawer_name
	var before_view=_page_view_key()
	interaction_serial+=1
	interaction_rect=rect;interaction_pulse=1.0
	fn.call()
	if key in ["equip_selected","unequip_slot","enhance_item"]:equipment_pulse=1.0
	if drawer_name==before_page and not drawer_name.is_empty():
		if before_view!=_page_view_key():_animate_content(true)
		elif key.begins_with("item_") or key.begins_with("slot_") or key in ["equip_selected","unequip_slot","enhance_item","first_chest","open_chest"]:_animate_content(false)

func _page_view_key()->String:
	return str([drawer_name,wardrobe_tab,inventory_page,get_meta("ink_journal_tab","practice"),get_meta("ink_journal_mode","quests"),get_meta("ink_journal_page",0),get_meta("ink_collection_category","realms"),get_meta("ink_collection_page",0),get_meta("ink_technique_id",""),get_meta("ink_journey_id",""),get_meta("ink_recipe_id",""),state.recipe,get_meta("meridian_id",""),get_meta("expedition_view","route"),get_meta("ink_stage_id",""),get_meta("ink_stage_page",0),get_meta("ink_guide_step",0),get_meta("bag_view","materials"),get_meta("craft_recipe","refine_stone"),get_meta("material_page",0),get_meta("enhancement_method","herbs")])

func _sync_drawer_visuals():
	if is_instance_valid(drawer):
		drawer.modulate.a=drawer_alpha*content_alpha
		drawer.position=Vector2(content_offset,(1.0-paper_reveal)*4.0)
		for control in drawer.get_children():
			if control is Control:
				var interactive=not drawer_name.is_empty() and paper_reveal>.97 and content_alpha>.5
				control.mouse_filter=Control.MOUSE_FILTER_STOP if interactive else Control.MOUSE_FILTER_IGNORE
				if not control.has_meta("ready_focus_mode"):control.set_meta("ready_focus_mode",control.focus_mode)
				control.focus_mode=int(control.get_meta("ready_focus_mode")) if interactive else Control.FOCUS_NONE

func _animate_content(turning:bool):
	if content_tween:content_tween.kill()
	# Ink soaks into the next leaf; paper and hit regions stay anchored together.
	content_alpha=.18 if turning else .62
	content_offset=7.0 if turning else 2.5
	content_tween=create_tween().set_parallel(true)
	content_tween.tween_property(self,"content_alpha",1.0,.24 if turning else .18).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	content_tween.tween_property(self,"content_offset",0.0,.28 if turning else .20).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sync_drawer_visuals()

func _toggle_drawer(value:String):
	if practice_session != null: return
	_record_cue("翻册："+value)
	if drawer_name==value:_close_drawer();return
	if value=="practice" and not state.arrival_seen:
		# _ready chooses the first-entry default. Explicit links to a quest,
		# breakthrough or ending must retain their chosen destination.
		state.arrival_seen=true;_save_loadout()
	drawer_name=value;drawn_page=value
	desktop.set_passthrough(false)
	_build_nav()
	_refresh_drawer(true)

func _close_drawer():
	CapacityPages.clear(self)
	if practice_session != null: end_practice(); return
	_record_cue("收册")
	if drawer_name.is_empty():return
	drawer_name="";drawer_generation+=1
	var generation=drawer_generation
	var closing_drawer=drawer
	_build_nav()
	if drawer_tween:drawer_tween.kill()
	if content_tween:content_tween.kill()
	# Closing controls cannot fire while the last ink trace fades away.
	if is_instance_valid(closing_drawer):
		for control in closing_drawer.get_children():
			if control is Control:control.mouse_filter=Control.MOUSE_FILTER_IGNORE;control.focus_mode=Control.FOCUS_NONE
		content_tween=create_tween().set_parallel(true)
		content_tween.tween_property(self,"content_alpha",0.0,.14)
		drawer_tween=create_tween().set_parallel(true)
		drawer_tween.tween_property(self,"paper_reveal",0.0,.48).set_delay(.10).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		drawer_tween.tween_property(self,"drawer_alpha",0.0,.18).set_delay(.42)
		drawer_tween.chain().tween_callback(func():
			if generation!=drawer_generation:return
			if is_instance_valid(closing_drawer):closing_drawer.queue_free()
			drawer=null
			if practice_session == null and strip and bool(state.settings.click_through):desktop.set_passthrough(true))

func _drawer_rect()->Rect2:
	var page=drawer_name if not drawer_name.is_empty() else drawn_page
	var width=700.0 if page in ["wardrobe","alchemy","practice","capacity"] else (460.0 if page in ["settings","display"] else 390.0)
	return Rect2(size.x-width-58,20,width,280)

func _refresh_drawer(animated=false):
	if drawer_name.is_empty():return
	var focus_key=""
	var focus_owner=get_viewport().gui_get_focus_owner()
	for key in buttons:
		if is_instance_valid(buttons[key]) and buttons[key]==focus_owner:focus_key=key;break
	if animated:
		drawer_generation+=1
		if drawer_tween:drawer_tween.kill()
		if content_tween:content_tween.kill()
	if is_instance_valid(drawer):
		for key in buttons.keys():
			if is_instance_valid(buttons[key]) and buttons[key].get_parent()==drawer:buttons.erase(key)
		remove_child(drawer);drawer.queue_free()
	drawer=Control.new();drawer.mouse_filter=Control.MOUSE_FILTER_IGNORE;add_child(drawer)
	panel_last_values=InkPages.state_signature(self)
	var r=_drawer_rect();var x=r.position.x+24;var y=r.position.y
	_qbutton(drawer,"drawer_close","合",Rect2(r.end.x-42,y+10,26,26),_close_drawer,"合上书页")
	CapacityPages.build_return(self,x,y)
	if drawer_name=="capacity":
		CapacityPages.build(self,x,y)
	elif drawer_name=="practice":
		JournalPages.build_practice(self,x,y,r)
	elif drawer_name=="alchemy":
		InkPages.build_alchemy(self,x,y,r)
	elif drawer_name=="bag":
		_qbutton(drawer,"bag_help","山居小记  ↗",Rect2(x,y+178,142,30),func():tip.popup_centered(),"查看完整玩法和快捷键")
	elif drawer_name=="wardrobe":
		_build_equipment_drawer(x,y,r)
	elif drawer_name=="settings":
		_check("置顶",Vector2(x,y+58),state.settings.always_on_top,func(v):state.settings.always_on_top=v;desktop.set_top(v))
		_check("节能 20 FPS",Vector2(x+194,y+58),state.settings.low_power,func(v):state.settings.low_power=v;Engine.max_fps=20 if v else 60)
		_slider(Vector2(x+65,y+105),120,float(state.settings.music),func(v):state.settings.music=v;_volume())
		_slider(Vector2(x+262,y+105),120,float(state.settings.sfx),func(v):state.settings.sfx=v;_volume())
		_qbutton(drawer,"width","窗口 / 字号",Rect2(x,y+145,100,30),func():_toggle_drawer("display"),"窗口尺寸与界面字号缩放")
		_qbutton(drawer,"recovery","恢复窗口",Rect2(x+110,y+145,92,30),_safe_restore,"Esc / F8 也能恢复")
		_qbutton(drawer,"save","保存",Rect2(x+204,y+145,72,30),func():_notice("山居已保存。" if _save_current() else "保存失败，请检查本地权限。"))
		_qbutton(drawer,"reset","重置…",Rect2(x+286,y+145,92,30),func():reset_dialog.popup_centered())
		_qbutton(drawer,"advanced","桌面小记",Rect2(x,y+186,112,28),func():_toggle_drawer("desktop"),"透明背景与景观区穿透的平台限制")
		_qbutton(drawer,"auto","随缘 · "+("开" if state.auto_advance else "关"),Rect2(x+130,y+186,112,28),func():state.auto_advance=not state.auto_advance;_refresh_drawer(),"自动安排静坐、采药和突破",false,state.auto_advance)
		_qbutton(drawer,"pause","继续修行" if paused else "暂歇片刻",Rect2(x,y+232,116,28),func():_set_paused(not paused);_refresh_drawer(),"空格也可暂停")
		_qbutton(drawer,"window","普通窗口" if strip else "桌面小窗",Rect2(x+126,y+232,116,28),_toggle_window,"F2 切换窗口模式")
		_qbutton(drawer,"quit","保存离山",Rect2(x+252,y+232,128,28),_quit,"保存并退出")
		_qbutton(drawer,"updates","版本更新",Rect2(x+260,y+186,118,28),_open_updates,"正式 / 测试频道，下载、校验与安全重启")
	elif drawer_name=="display":
		_qbutton(drawer,"scale_down","−",Rect2(x,y+78,38,32),func():_change_readability(-.25),"缩小界面与字号")
		_qbutton(drawer,"scale_up","＋",Rect2(x+210,y+78,38,32),func():_change_readability(.25),"放大界面与字号；空间不足时自动适配")
		_qbutton(drawer,"size_comfort","舒适窗口",Rect2(x,y+137,112,30),func():_resize_preset(Vector2i(1440,720)),"1440 × 720；自动适配当前屏幕")
		_qbutton(drawer,"size_large","宽阔窗口",Rect2(x+130,y+137,112,30),func():_resize_preset(Vector2i(1680,900)),"1680 × 900；自动适配当前屏幕")
		_qbutton(drawer,"display_restore","安全恢复",Rect2(x+260,y+137,118,30),_safe_restore,"Esc / F8 恢复普通窗口")
		_qbutton(drawer,"display_mode","普通窗口" if strip else "桌面小窗",Rect2(x,y+188,116,30),_toggle_window,"F2 切换；保留普通窗口大小")
		_qbutton(drawer,"display_back","返回设置",Rect2(x,y+232,116,28),func():_toggle_drawer("settings"))
	elif drawer_name=="desktop":
		_check("透明街景（支持时）",Vector2(x,y+65),state.settings.transparent,func(v):state.settings.transparent=v;desktop.set_transparent(v);_notice(desktop.status()))
		_check("景观区鼠标穿透",Vector2(x,y+107),state.settings.click_through,func(v):state.settings.click_through=v;_notice("收起书页后应用穿透；小印与场景入口仍可操作。" if v else "景观区穿透已关闭。"))
		_qbutton(drawer,"desktop_back","返回设置",Rect2(x,y+180,130,30),func():_toggle_drawer("settings"))
	if animated:
		# Retarget from the current paper, including interrupted closes and width changes.
		# Only the ink is replaced; a partially visible leaf never teleports.
		if drawer_alpha<=.01:paper_width=r.size.x;paper_reveal=0.0
		content_alpha=0.0;content_offset=5.0
		drawer_tween=create_tween().set_parallel(true)
		drawer_tween.tween_property(self,"paper_width",r.size.x,.38).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		drawer_tween.tween_property(self,"paper_reveal",1.0,.58).set_delay(.06).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN_OUT)
		drawer_tween.tween_property(self,"drawer_alpha",1.0,.18)
		content_tween=create_tween().set_parallel(true)
		content_tween.tween_property(self,"content_alpha",1.0,.22).set_delay(.56).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		content_tween.tween_property(self,"content_offset",0.0,.24).set_delay(.54).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	_sync_drawer_visuals()
	if practice_session != null: PracticeHost.lock_controls(self)
	if not focus_key.is_empty() and is_instance_valid(buttons.get(focus_key)) and buttons[focus_key].focus_mode!=Control.FOCUS_NONE:
		buttons[focus_key].grab_focus()

func _check(label:String,p:Vector2,v:bool,fn:Callable):
	var b=QuietButton.new();b.text=label+(" · 开" if v else " · 关");b.position=p;b.size=Vector2(185,31);b.selected=v
	b.pressed.connect(func():b.selected=not b.selected;b.text=label+(" · 开" if b.selected else " · 关");_sound("equip",.1);fn.call(b.selected))
	drawer.add_child(b)
func _slider(p:Vector2,width:float,value:float,fn:Callable):
	var s=HSlider.new();s.position=p;s.size=Vector2(width,22);s.min_value=0;s.max_value=1;s.step=.02;s.value=value;s.value_changed.connect(fn)
	var track=StyleBoxFlat.new();track.bg_color=LINE;track.content_margin_top=2;track.content_margin_bottom=2;track.set_corner_radius_all(2)
	var fill=track.duplicate();fill.bg_color=Color("676d61")
	s.add_theme_stylebox_override("slider",track);s.add_theme_stylebox_override("grabber_area",fill);s.add_theme_stylebox_override("grabber_area_highlight",fill)
	var knob=Image.new();knob.load_svg_from_string('<svg xmlns="http://www.w3.org/2000/svg" width="14" height="14"><circle cx="7" cy="7" r="5" fill="#9e4739"/></svg>')
	var knob_texture=ImageTexture.create_from_image(knob);s.add_theme_icon_override("grabber",knob_texture);s.add_theme_icon_override("grabber_highlight",knob_texture)
	drawer.add_child(s)

func _process(delta):
	if practice_session != null:
		PracticeHost.advance(self, delta); return
	display_check_clock+=delta
	if display_check_clock>=.5:
		display_check_clock=0.0
		if not is_equal_approx(last_display_scale,desktop.display_scale()):
			if strip:desktop.prepare_strip_scale(float(state.settings.get("ui_scale",1.5))*desktop.display_scale())
			_apply_readability();_build_nav();_refresh_drawer()
	var before_screen_x=_world_x(character_x)
	var before_route_distance=route_distance
	elapsed+=delta
	interface_clock+=delta
	toast_age+=delta
	chest_reveal_age+=delta
	interaction_pulse=maxf(0.0,interaction_pulse-delta*3.3)
	equipment_pulse=maxf(0.0,equipment_pulse-delta*1.8)
	reward_pulse=maxf(0.0,reward_pulse-delta*.8)
	_sync_drawer_visuals()
	_update_encounter(delta)
	var target_x=_encounter_target_x() if encounter_active else (520.0 if practice_time>0 else float({"meditate":520.0,"gather":160.0,"brew":879.0}.get(state.activity,520.0)))
	if not paused and meditation_amount<.02:practice_time=maxf(0,practice_time-delta)
	var attack_phase=fposmod(encounter_clock if encounter_active else practice_duration-practice_time,1.6)
	var cast_target=1.0 if meditation_amount<.02 and (practice_time>0 or (encounter_active and encounter_phase=="fight")) and attack_phase>.65 and attack_phase<1.35 else 0.0
	cast_blend=move_toward(cast_blend,cast_target,delta*8)
	var must_stand=absf(character_x-target_x)>1.0 or state.activity!="meditate" or practice_time>0 or encounter_active
	if not paused:
		meditation_clock+=delta
		if must_stand:meditation_settle=0.0
		else:meditation_settle+=delta
		var meditation_target=1.0 if not must_stand and meditation_settle>.35 else 0.0
		meditation_amount=move_toward(meditation_amount,meditation_target,delta/(.85 if meditation_target>meditation_amount else .58))
		meditation_phase="seated" if meditation_amount>=.999 else ("entering" if meditation_target>meditation_amount else ("leaving" if meditation_amount>0.0 else "standing"))
	# A page is an overlay: it never changes world movement, pose, pause or scale.
	if not paused and meditation_amount<.02:
		var movement_speed=48.0
		character_x=move_toward(character_x,target_x,delta*movement_speed)
		var target_y=230.0 if practice_time>0 or encounter_active else float({"meditate":230.0,"gather":213.0,"brew":222.0}.get(state.activity,230.0))
		character_y=move_toward(character_y,target_y,delta*8)
	var actual_velocity=(_world_x(character_x)-before_screen_x)/maxf(delta,.000001)
	_sync_character_preview(delta)
	if preview_blend<=0.0 and drawer_name.is_empty() and drawer_alpha<=0.0:drawn_page=""
	rendered_stage_scale=1.0
	walk_motion=walker.update_motion(0.0 if paused else delta,actual_velocity,1.0)
	route_frame_velocity=(route_distance-before_route_distance)/maxf(delta,.000001) if not world_route.is_empty() and not _portal_active() else 0.0
	var virtual_velocity=route_frame_velocity if encounter_active and not world_route.is_empty() else actual_velocity
	side_motion=sidewalker.update_motion(0.0 if paused else delta,virtual_velocity,1.0)
	side_motion.technique=state.technique
	_update_travel_footsteps()
	if encounter_active:
		walk_motion.facing=1.0;side_motion.facing=1.0
	if encounter_active and encounter_phase=="fight":
		side_motion.merge(duel_pose.get("hero",{}),true)
	if encounter_active and encounter_phase=="pickup" and encounter_phase_age<.30 and not finish_hero_motion.is_empty():
		side_motion.merge(finish_hero_motion,true)
		side_motion.combat_phase="recovery";side_motion.phase_progress=clampf(encounter_phase_age/.30,0.0,1.0)
	if encounter_active and encounter_phase=="pickup" and pickup_collect_started>=0.0:
		var reach_age=maxf(0.0,encounter_phase_age-pickup_collect_started)
		var search_amount=smoothstep(0.0,.30,reach_age)
		if pickup_claimed_at>=0.0:search_amount*=1.0-smoothstep(0.0,.42,encounter_phase_age-pickup_claimed_at)
		side_motion.pickup_amount=search_amount*.9
		side_motion.search_amount=search_amount
		side_motion.search_phase=clampf(reach_age/2.0,0.0,1.0)
	ui_hold=maxf(0,ui_hold-delta)
	var target_alpha=1.0 if mouse_inside or not drawer_name.is_empty() or ui_hold>0 else 0.0
	ui_alpha=move_toward(ui_alpha,target_alpha,delta*3.5)
	if is_instance_valid(nav):
		nav.modulate.a=1.0;nav.visible=true
		for child in nav.get_children():child.modulate.a=ui_alpha
		if is_instance_valid(buttons.get("settings")):buttons.settings.modulate.a=maxf(.55,ui_alpha)
		for key in ["guide_note","guide_dismiss"]:
			if is_instance_valid(buttons.get(key)):buttons[key].modulate.a=.82 if key=="guide_note" else .48
	_update_hotspots()
	toast_time=maxf(0,toast_time-delta)
	breakthrough_glow=maxf(0,breakthrough_glow-delta*.25)
	meridian_glow=maxf(0,meridian_glow-delta*.32)
	if not paused:
		var before=state.realm
		var events=state.step(delta)
		for e in events:
			journal.push_front(str(e));if journal.size()>5:journal.resize(5)
			if "丹" in str(e) or "归来" in str(e):_notice(str(e),"loot")
		if state.realm>before:_on_breakthrough();_refresh_drawer()
		if state.realm==state.MAX_REALM and not completed_presented:
			completed_presented=true;_notice("一心归真，山居长伴。石台札记已记下此刻。","level")
		save_clock+=delta
		if save_clock>10:
			save_clock=0
			if not demo and not _save_current():_notice("存档暂时无法写入，请检查本地权限。")
	if size!=last_size:
		last_size=size
		desktop.update_passthrough(Rect2(0,0,size.x,50),_interactive_regions())
	if not drawer_name.is_empty():
		var values=InkPages.state_signature(self)
		if values!=panel_last_values:panel_last_values=values;_refresh_drawer()
	queue_redraw()

func _landscape_rect()->Rect2:
	return Readability.landscape_rect(size)
func _world_x(value:float)->float:
	return _landscape_rect().position.x+value
func _world_y(value:float)->float:
	var rect=_landscape_rect()
	return rect.position.y+value

func _bottom_y()->float:return size.y-62
func _draw():
	var w=size.x;var h=size.y
	if not desktop.transparent_enabled:draw_rect(Rect2(0,0,w,h),PAPER)
	_draw_scene(_landscape_rect())
	# The landscape stays clear. A quiet ink inscription carries only essential progress.
	_text(_realm_name(),Vector2(25,h-23),12,Color("394c43"),SERIF)
	draw_line(Vector2(25,h-14),Vector2(112,h-14),Color(.30,.36,.28,.18),1,true)
	draw_line(Vector2(25,h-14),Vector2(25+87*clampf(state.stats().progress,0,1),h-14),content_accent,1.4,true)
	if paused:_text("暂歇",Vector2(128,h-23),12,Color("8e4436"),SERIF)
	if "--loot-demo" in OS.get_cmdline_user_args():_text("演示存档 · 固定随机种子",Vector2(w-178,h-12),10,Color(.93,.95,.85,.85))
	if "--campaign-demo" in OS.get_cmdline_user_args():_text("预置进度演示 · 非自然挂机时长",Vector2(w-238,h-12),10,Color(.22,.32,.25,.92))
	_draw_battle_strip()
	if practice_session != null and drawer_name.is_empty():
		var practice_label = "镜中试招 · 无奖励 · 固定种子17 · 正式山居已冻结"
		var practice_width = minf(size.x - 32.0, maxf(258.0, SANS.get_string_size(practice_label, HORIZONTAL_ALIGNMENT_LEFT, -1, 14).x + 24.0))
		# A local paper backing keeps trial controls readable over any desktop,
		# without making the scene/window background opaque.
		InkPaper.paint(self, Rect2(16, 10, practice_width, 68), .96, "leaf", 1.0)
		_text(practice_label, Vector2(24, 66), 14, INK)

	if drawer_alpha>0 and is_instance_valid(drawer):_draw_drawer()
	if toast_time>0:
		var alpha=clampf(toast_time/.45,0,1)*smoothstep(0.0,.22,toast_age)
		var available=_drawer_rect().position.x if not drawer_name.is_empty() else w
		var shown_toast=toast
		while SANS.get_string_size(shown_toast,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x>available-58 and shown_toast.length()>4:
			shown_toast=shown_toast.left(shown_toast.length()-2)+"…"
		var tw=minf(available-32,SANS.get_string_size(shown_toast,HORIZONTAL_ALIGNMENT_LEFT,-1,12).x+40)
		var notice_y=h-37 if preview_blend>.02 else 58.0
		var r=Rect2((available-tw)/2,notice_y+(1.0-smoothstep(0.0,.28,toast_age))*5.0,tw,31)
		InkPaper.paint(self,r,alpha,"leaf",1.0)
		InkPaper.seal(self,Vector2(r.position.x+9,r.position.y+15),4,alpha*.7)
		_center(shown_toast,r,12,Color(.20,.34,.29,alpha))

func _diorama_active()->bool:
	
	# Artwork/foot anchors do not change when the OS compositor is toggled.
	return SceneArt.texture("courtyard")!=null

func _draw_scene(r:Rect2):
	# Use original alpha artwork with one uniform source-to-world scale.
	# The old 2080×280 prepared panoramas compressed trees vertically; no
	# native resize policy can repair those baked-in proportions.
	var art_key=world_route if not world_route.is_empty() else "courtyard"
	var art_texture=SceneArt.texture(art_key)
	if art_texture:
		var destination=SceneArt.destination_rect(art_key,r,route_distance if not world_route.is_empty() else 0.0)
		draw_texture_rect_region(art_texture,destination,SceneArt.source_rect(art_key),Color(1,1,1,_route_reveal()))
	# Slow, nearly imperceptible wind; never a camera pan or screen shake.
	for i in range(14):
		var x=r.position.x+fposmod(i*103.7+elapsed*(2+i%3),r.size.x)
		var y=r.position.y+r.size.y*((.68 if _diorama_active() else .24)+(.19 if _diorama_active() else .63)*fposmod(i*.137,1))+sin(elapsed*.35+i)*5
		draw_circle(Vector2(x,y),1.1,Color(1,.98,.79,.15+.16*sin(elapsed+i)))
	if not world_route.is_empty():_draw_route_landmarks()
	var anchor_x=520.0 if practice_time>0 or encounter_active else {"meditate":520.0,"gather":160.0,"brew":879.0}.get(state.activity,520.0)
	var feet=Vector2(_world_x(character_x),_world_y(character_y+(16 if _diorama_active() or not world_route.is_empty() else 0)))
	var travelling=absf(character_x-float(anchor_x))>1
	if meditation_amount>0.01:_draw_meditation_qi(feet,1.0,false)
	if _portal_active():_draw_portal(feet,false)
	# A searched body rests behind the kneeling hero so hands and bent knees
	# remain readable; living enemies retain their established combat layering.
	if encounter_active and encounter_phase=="pickup":_draw_encounter(feet)
	if equipment_assets.has("base"):
		if _portal_active() and is_instance_valid(portal_viewport):draw_texture_rect(portal_viewport.get_texture(),Rect2(feet-Vector2(96,158),Vector2(192,184)),false)
		else:_draw_avatar(feet,travelling)
	if _portal_active():_draw_portal(feet,true)
	if meditation_amount>0.01:_draw_meditation_qi(feet,1.0,true)
	if not (encounter_active and encounter_phase=="pickup"):_draw_encounter(feet)
	# The near-hand sword crosses in front of the opponent at close contact.
	# Draw the real weapon once in this layer, not a replacement glow/outline.
	if _foreground_combat_sword():_draw_weapon(feet,cast_blend,1.0-sin(equipment_pulse*PI)*.015,0.0)
	# Foreground ink must remain visible at contact, above both painted actors.
	if encounter_active and encounter_phase in ["fight","pickup"]:_draw_combat_fx(feet)
	_draw_companion(r)

	var body_feet:Vector2=feet+Vector2(float(CharacterSidewalk.approach_footwork(side_motion).root) if _side_world_active() else 0.0,0)
	if not paused and meditation_amount<.01:
		for i in range(4):
			var phase=fposmod(elapsed*.25+i/7.0,1)
			var a=sin(phase*PI)*.45
			var p=body_feet+Vector2(sin(i*2.4+elapsed*.3)*(14+phase*22),-12-phase*75)
			draw_circle(p,1.2,Color(.96,.92,.62,a))
	if breakthrough_glow>0:
		var g=breakthrough_glow
		for i in range(24):
			var angle=i*TAU/24+elapsed*.15
			var radius=25+(1-g)*95
			draw_circle(body_feet+Vector2(cos(angle)*radius,sin(angle)*radius*.5-38),1.8,Color(.91,.83,.51,g*.6))
	if breakthrough_glow>0 or meridian_glow>0:
		var glow=maxf(breakthrough_glow,meridian_glow)
		for ring in range(3):
			var points=PackedVector2Array()
			for j in range(49):
				var angle=j*TAU/48.0;var radius=20+(1-glow)*34+ring*7
				points.append(body_feet+Vector2(cos(angle)*radius,sin(angle)*radius*.22-2-ring*3))
			draw_polyline(points,Color(.76,.79,.55,glow*(.24-ring*.05)),1.2,true)
		if meridian_glow>0:
			var points=PackedVector2Array([body_feet+Vector2(0,-27),body_feet+Vector2(0,-40),body_feet+Vector2(0,-57),body_feet+Vector2(0,-78)])
			draw_polyline(points,Color(.88,.80,.52,glow*.35),1.3,true)
	# Pause freezes the scene without painting over the transparent sky.

func _draw_meditation_qi(feet:Vector2,scale:float,foreground:bool):
	var amount=smoothstep(.30,1.0,meditation_amount)
	if amount<=0.0:return
	var breath=(sin(meditation_clock*TAU/CharacterMeditation.BREATH_PERIOD)+1.0)*.5
	var center=feet+Vector2(0,-23.0)*scale
	if not foreground:
		# Faint breath rings lie on the ground, never a neon halo around the head.
		for ring in range(2):
			var points=PackedVector2Array()
			var radius=(27.0+ring*12.0+breath*3.5)*scale
			for j in range(49):
				var a=j*TAU/48.0
				points.append(feet+Vector2(cos(a)*radius,sin(a)*radius*.22+2.0))
			draw_polyline(points,Color(.65,.73,.58,amount*(.13-ring*.035)),.9,true)
		return
	# Six quiet motes converge to the lower abdomen in staggered, curved breaths.
	for i in range(6):
		var phase=fposmod(meditation_clock/5.8+i/6.0,1.0)
		var side=-1.0 if i%2==0 else 1.0
		var start=center+Vector2(side*(46.0+(i%3)*8),-4.0-(i%3)*11.0)*scale
		var control=center+Vector2(side*25.0,-23.0-(i%2)*11.0)*scale
		var t=smoothstep(0.0,1.0,phase)
		var p=start.bezier_interpolate(control,center+Vector2(side*8,-3)*scale,center,t)
		var alpha=sin(phase*PI)*amount*.44
		var trail=PackedVector2Array()
		for j in range(7):
			var tt=maxf(0.0,t-j*.013)
			trail.append(start.bezier_interpolate(control,center+Vector2(side*8,-3)*scale,center,tt))
		draw_polyline(trail,Color(.70,.80,.65,alpha*.35),1.0,true)
		draw_circle(p,1.15*scale,Color(.89,.91,.67,alpha))
	if amount>.8:
		draw_circle(center,2.0*scale,Color(.86,.84,.56,(.04+breath*.045)*amount))
	if reward_pulse>0:
		for i in range(5):
			var a=i*TAU/5.0
			draw_circle(center+Vector2(cos(a),sin(a)*.65)*(18+(1-reward_pulse)*22)*scale,1.2,Color(.84,.74,.44,reward_pulse*.45))

func _draw_drawer():
	var r=_drawer_rect()
	var a=drawer_alpha
	var page=drawer_name if not drawer_name.is_empty() else drawn_page
	# The right edge is the book's hinge; paper arrives before its ink.
	var paper_rect=Rect2(r.end.x-paper_width,r.position.y,paper_width,r.size.y)
	draw_set_transform(Vector2(paper_rect.position.x+paper_rect.end.x,0),0,Vector2(-1,1))
	InkPaper.paint(self,paper_rect,a,"book" if page in ["wardrobe","practice"] else ("scroll" if page=="alchemy" else "leaf"),paper_reveal)
	draw_set_transform(Vector2.ZERO)
	a*=content_alpha
	var x=r.position.x+24+content_offset;var y=r.position.y+(1.0-paper_reveal)*4.0
	if interaction_pulse>0 and not drawer_name.is_empty() and r.encloses(interaction_rect):
		var p=interaction_rect.position+Vector2(content_offset,(1.0-paper_reveal)*4.0)
		InkPaper.brush(self,Rect2(p+Vector2(5,interaction_rect.size.y-2),Vector2(maxf(8,interaction_rect.size.x-10)*(1.0-interaction_pulse*.25),1.5)),Color(.56,.25,.17,interaction_pulse*.32*a))
	var titles={"bag":"随身行囊","settings":"山居小记","desktop":"桌面相伴","display":"窗口与字号"}
	if titles.has(page):_text(titles[page],Vector2(x,y+39),27,Color(INK,a),BRUSH)
	if page=="capacity":
		CapacityPages.draw(self,x,y,a)
	elif page=="practice":
		JournalPages.draw_practice(self,x,y,a)
	elif page=="alchemy":
		InkPages.draw_alchemy(self,x,y,a)
	elif page=="bag":
		var labels=["灵草","灵露","青灵丹"]
		var amounts=[state.herbs,state.dew,state.pills]
		for i in range(3):
			var xx=x+i*108
			_draw_leaf(Vector2(xx+16,y+81),[Color("7b9871"),Color("83aaa3"),GOLD][i])
			_text(labels[i],Vector2(xx,y+120),12,Color(SUBTLE,a))
			_text(str(amounts[i]),Vector2(xx,y+150),22,Color(INK,a),SERIF)
	elif page=="wardrobe":
		_draw_equipment_drawer(x,y,a)
	elif page=="settings":
		_text("山间乐音",Vector2(x,y+120),11,Color(SUBTLE,a));_text("轻柔音效",Vector2(x+197,y+120),11,Color(SUBTLE,a))
	elif page=="display":
		_text("界面 / 字号  %d%%" % roundi(float(state.settings.get("ui_scale",1.5))*100),Vector2(x+48,y+100),13,Color(INK,a))
		_text("字体、按钮等比放大；小窗口会自动适配。",Vector2(x,y+64),11,Color(SUBTLE,a))
		_text("普通窗口可拖动边框；大小与位置自动保存。",Vector2(x,y+124),11,Color(SUBTLE,a))
		_text("小窗适合桌面陪伴；阅读建议使用普通窗口。",Vector2(x,y+183),11,Color(SUBTLE,a))
	elif page=="desktop":
		_text("小印始终可点击；Esc / F8 恢复窗口。",Vector2(x,y+158),11,Color(SUBTLE,a))
		_text("Windows 暂不启用区域穿透。",Vector2(x,y+175),10,Color(SUBTLE,a))

func _draw_leaf(p:Vector2,c:Color):
	draw_line(p+Vector2(-10,12),p+Vector2(11,-12),c.darkened(.15),1.5,true)
	draw_colored_polygon(PackedVector2Array([p+Vector2(-3,6),p+Vector2(-17,-2),p+Vector2(-16,-10),p+Vector2(-5,-5)]),c)
	draw_colored_polygon(PackedVector2Array([p+Vector2(2,0),p+Vector2(6,-15),p+Vector2(17,-18),p+Vector2(14,-6)]),c.lightened(.08))
func _text(s:String,p:Vector2,fs:int=13,c:Color=INK,font:Font=SANS):draw_string(font,p,s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs,c)
func _center(s:String,r:Rect2,fs:int,c:Color):
	var tw=SANS.get_string_size(s,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x;_text(s,Vector2(r.position.x+(r.size.x-tw)/2,r.position.y+(r.size.y+fs)/2-3),fs,c)
func _realm_name()->String:return state.realm_name()
func _record_cue(label:String):
	if demo and "--record-cues" in OS.get_cmdline_user_args():print("DEMO_CUE %.3f %s"%[elapsed,label])

func _notice(value:String,sound:String=""):
	_record_cue(value)
	toast=value;toast_time=4.5;toast_age=0.0
	if sound=="loot" or sound=="level":reward_pulse=1.0
	if sound!="":_sound(sound,.30)
func _on_breakthrough():
	breakthrough_glow=1.0;_notice("气韵自成  ·  "+_realm_name(),"level");_build_nav()

func _setup_audio():
	music=AudioStreamPlayer.new();music.bus="Music";add_child(music)
	# Restart outside the finished signal: replaying inside audio teardown can
	# retain the completed WAV playback until process exit on native backends.
	music.stream=load("res://assets/audio/music.wav");music.finished.connect(func():
		if not closing:music.call_deferred("play"))
	if DisplayServer.get_name()!="headless":music.play()
	audio=AudioStreamPlayer.new();audio.bus="SFX";add_child(audio)
	combat_audio=AudioStreamPlayer.new();combat_audio.bus="SFX";add_child(combat_audio)
	combat_voices.append(combat_audio)
	for voice_index in range(5):
		var voice:=AudioStreamPlayer.new();voice.bus="SFX";add_child(voice);combat_voices.append(voice)
func _sound(n:String,volume:float):
	if DisplayServer.get_name()=="headless":return
	var p="res://assets/audio/"+n+".wav"
	if ResourceLoader.exists(p):audio.stream=load(p);audio.volume_db=linear_to_db(volume);audio.play()

func _basic_contact_stream(style:String)->AudioStreamWAV:
	if combat_audio_streams.has(style):return combat_audio_streams[style]
	# Short, self-authored physical contacts. No ambient/cultivation sound is
	# replaced: sword rings, fan brushes, and bare hands make a muted thump.
	var rate:=22050
	var duration:float={"sword":.082,"fan":.065,"unarmed":.090}.get(style,.090)
	var samples:=PackedByteArray()
	samples.resize(int(rate*duration)*2)
	for i in range(samples.size()/2):
		var t:=float(i)/rate
		var decay:=exp(-t*(46.0 if style=="fan" else 34.0))
		var envelope:=minf(1.0,t/.002)*decay*(1.0-smoothstep(duration*.75,duration,t))
		var wave:=sin(TAU*(140.0*t-160.0*t*t))*.78+sin(TAU*310.0*t)*.15
		if style=="sword":wave=sin(TAU*(1750.0*t-3600.0*t*t))*.48+sin(TAU*2940.0*t)*.24
		elif style=="fan":
			var noise:=fposmod(sin(float(i)*12.9898+78.233)*43758.5453,1.0)*2.0-1.0
			wave=noise*.65+sin(TAU*740.0*t)*.14
		samples.encode_s16(i*2,int(clampf(wave*envelope,-1.0,1.0)*18000.0))
	var stream:=AudioStreamWAV.new()
	stream.format=AudioStreamWAV.FORMAT_16_BITS;stream.mix_rate=rate;stream.stereo=false;stream.data=samples
	combat_audio_streams[style]=stream
	return stream

func _play_combat_profile(profile:Dictionary):
	if not bool(profile.get("active",true)) or DisplayServer.get_name()=="headless" or combat_voices.is_empty():return
	var voice:AudioStreamPlayer=combat_voices[combat_voice_cursor%combat_voices.size()]
	combat_voice_cursor+=1
	voice.stream=CombatImpact.stream(profile)
	# Profiles leave room for the player's SFX bus. Contacts need a clearer
	# foreground than travel soles, without raising music or UI notifications.
	voice.volume_db=float(profile.get("gain_db",-15.0))+(0.0 if str(profile.get("kind",""))=="footstep" else 4.5)
	voice.pitch_scale=1.0
	voice.play()

func _play_combat_contact(event:Dictionary):
	var profile:Dictionary=event.get("impact_profile",CombatImpact.describe(event))
	_play_combat_profile(profile)

func _push_combat_feedback(event:Dictionary):
	var profile:Dictionary=event.get("impact_profile",CombatImpact.describe(event))
	if not bool(profile.get("active",false)):return
	combat_hitstop=maxf(combat_hitstop,float(profile.get("hitstop",0.0)))
	var ground:=_enemy_feet() if str(event.target)=="enemy" else Vector2(_world_x(character_x),_world_y((character_y+16.0)))
	if str(profile.get("family",""))=="moss_slam":
		var enemy_motion:Dictionary=duel.pose().get("enemy",{})
		ground=_enemy_feet()+Vector2(float(enemy_motion.get("visual_offset",Vector2.ZERO).x)-32.0,0.0)
	combat_impacts.append({"age":0.0,"profile":profile,"target":str(event.target),"resolution":str(event.resolution),"position":_event_contact_point(event),"ground":ground})

func _update_travel_footsteps():
	if paused or not encounter_active or encounter_phase not in ["travel","pickup"] or absf(float(side_motion.get("velocity",0.0)))<8.0:
		footstep_phase=-1.0;return
	var next_phase:=fposmod(float(side_motion.get("phase",0.0)),1.0)
	if footstep_phase>=0.0 and (next_phase<footstep_phase or (footstep_phase<0.5 and next_phase>=0.5)):
		footstep_serial+=1
		_play_combat_profile(CombatImpact.footstep_profile("stone" if world_route in ["creek_bridge","ember_ruins","summit_gate"] else "earth",footstep_serial))
	footstep_phase=next_phase

func _stop_combat_audio():
	for voice in combat_voices:
		if is_instance_valid(voice):voice.stop();voice.stream=null

func _volume():
	AudioServer.set_bus_volume_db(1,linear_to_db(maxf(.001,float(state.settings.music))))
	AudioServer.set_bus_volume_db(2,linear_to_db(maxf(.001,float(state.settings.sfx))))
func _apply_settings():
	Engine.max_fps=30 if "--review" in OS.get_cmdline_user_args() else (20 if state.settings.low_power else 60)
	desktop.set_top(state.settings.always_on_top);_volume()
func _toggle_window():
	_close_drawer();strip=not strip
	if strip:desktop.prepare_strip_scale(float(state.settings.get("ui_scale",1.5))*desktop.display_scale())
	desktop.set_strip(strip)
	if strip:
		desktop.set_top(state.settings.always_on_top);desktop.set_transparent(state.settings.transparent);desktop.set_passthrough(state.settings.click_through)
	_apply_readability();_build_nav();_save_loadout()
func _safe_restore():
	_close_drawer();strip=false;desktop.safe_restore();state.settings.always_on_top=false;state.settings.transparent=false;state.settings.click_through=false;_apply_readability();_build_nav();_save_loadout()
func _change_readability(amount:float):
	state.settings.ui_scale=clampf(float(state.settings.get("ui_scale",1.5))+amount,1.0,1.75)
	if strip:desktop.prepare_strip_scale(float(state.settings.ui_scale)*desktop.display_scale())
	_apply_readability();_build_nav();_refresh_drawer();_save_loadout()

func _resize_preset(dimensions:Vector2i):
	strip=false;desktop.set_normal_preset(Vector2i(Vector2(dimensions)*desktop.display_scale()))
	_apply_readability();_build_nav();_refresh_drawer();_save_loadout()

func _apply_readability():
	if applying_readability:return
	applying_readability=true
	var window=get_window()
	var requested=float(state.settings.get("ui_scale",1.5))
	var display_scale=desktop.display_scale()
	last_display_scale=display_scale
	# Never resize the native window from a viewport size_changed callback.
	# X11/Windows may deliver older configure events after a newer request;
	# feeding those sizes back to the OS creates an asynchronous resize storm.
	# Disabled stretch + content scale renders text at native resolution rather
	# than enlarging a low-resolution viewport bitmap. Runtime setting also
	# applies when an older immutable launcher mounts this update pack.
	if window.content_scale_mode!=Window.CONTENT_SCALE_MODE_DISABLED:window.content_scale_mode=Window.CONTENT_SCALE_MODE_DISABLED
	if window.content_scale_size!=Vector2i.ZERO:window.content_scale_size=Vector2i.ZERO
	var next_scale=Readability.effective_scale(window.size,requested,display_scale)
	if not is_equal_approx(window.content_scale_factor,next_scale):window.content_scale_factor=next_scale
	applying_readability=false
	queue_redraw()

func _resized():
	if applying_readability:return
	_apply_readability()
	if is_instance_valid(nav):_build_nav()
	if drawer_name!="":_refresh_drawer()
func _input(event):
	if practice_session != null:
		if event is InputEventKey and event.pressed and not event.echo:
			if event.keycode in [KEY_ESCAPE, KEY_F8]: end_practice()
			elif event.keycode == KEY_SPACE: toggle_practice_pause()
			get_viewport().set_input_as_handled()
		return
	if event is InputEventKey and event.keycode in [KEY_ESCAPE,KEY_F8,KEY_F2,KEY_SPACE,KEY_I,KEY_TAB,KEY_A,KEY_R,KEY_M,KEY_G,KEY_F9]:
		# A global shortcut must not also activate the focused paper button.
		get_viewport().set_input_as_handled()
	if event is InputEventKey and event.pressed and not event.echo:
		ui_hold=3.0
		match event.keycode:
			KEY_ESCAPE,KEY_F8:_safe_restore()
			KEY_F2:_toggle_window()
			KEY_SPACE:_set_paused(not paused);_refresh_drawer()
			KEY_I,KEY_TAB:_toggle_drawer("wardrobe")
			KEY_A:_toggle_drawer("alchemy")
			KEY_R:_toggle_drawer("practice")
			KEY_M:_toggle_drawer("settings")
			KEY_G:state.set_activity("gather");_notice("循着药香，去山间走走。")
			KEY_F9:
				if demo:_capture_now()
	if event is InputEventMouseMotion:mouse_inside=true
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_RIGHT and event.pressed:
		ui_hold=5.0;_toggle_drawer("settings")
	if event is InputEventMouseButton and event.button_index==MOUSE_BUTTON_LEFT:
		if is_instance_valid(character_preview) and character_preview.visible and character_preview.get_rect().has_point(event.position):
			if not event.pressed:drag_active=false
			get_viewport().set_input_as_handled();return
		if event.pressed:
			if event.position.y<50 and event.position.x<size.x-60 and (drawer_name.is_empty() or not _drawer_rect().has_point(event.position)):
				drag_active=true;drag_start=get_window().position;mouse_start=DisplayServer.mouse_get_position()
			elif drawer_name!="" and not _drawer_rect().has_point(event.position) and event.position.y>50 and event.position.y<_bottom_y():_close_drawer()
		else:drag_active=false
	if event is InputEventMouseMotion and drag_active:get_window().position=drag_start+DisplayServer.mouse_get_position()-mouse_start
func _quit():
	if practice_session != null: end_practice()
	if closing:return
	if not demo and not _save_current():
		_notice("保存未成功，已留在山中。请检查本地权限后再离山。")
		return
	closing=true
	music.stop();audio.stop();music.stream=null;audio.stream=null
	_stop_combat_audio()
	# Tear down scene-owned controls/tooltips while the native root Window still
	# exists. Quitting the root in the same teardown can race popup connections.
	var tree=get_tree()
	hide();set_process(false)
	tree.create_timer(.12).timeout.connect(queue_free)
	tree.create_timer(.35).timeout.connect(tree.quit)
func _capture_later():
	await get_tree().create_timer(4.5).timeout
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://builds/MountainStill-preview.png"))

func _exit_tree():
	desktop.dispose()
	if is_instance_valid(music):music.stop();music.stream=null
	if is_instance_valid(audio):audio.stop();audio.stream=null
	_stop_combat_audio()
	if drawer_tween:drawer_tween.kill()
	if content_tween:content_tween.kill()
	for tween in dialog_tweens.values():
		if is_instance_valid(tween):tween.kill()
	dialog_tweens.clear()

func _start_practice():
	if _preview_stage_active() and is_instance_valid(character_preview):
		character_preview.play_technique()
		return
	if encounter_active:return
	# Practising at home cannot clear a retained route or refresh battle qi/CDs.
	state.expedition_auto=false
	practice_time=practice_duration;character_y=230.0
	_close_drawer()
	_notice("随心一式 · 不耗灵气","equip")

func _fit_texture(texture:Texture2D,box:Rect2,color:Color=Color.WHITE):
	var ts=texture.get_size();var sc=minf(box.size.x/ts.x,box.size.y/ts.y);var ss=ts*sc
	draw_texture_rect(texture,Rect2(box.position+(box.size-ss)/2,ss),false,color)

func _side_world_active()->bool:
	return meditation_amount<=.0001 and (not world_route.is_empty() or state.activity!="meditate" or float(side_motion.get("blend",0.0))>.02)

func _foreground_combat_sword()->bool:
	return encounter_active and encounter_phase=="fight" and _side_world_active() and _attack_style()=="sword" and not bool(CharacterSidewalk.weapon_pose(side_motion,1.0,0.0,"sword").stowed)

func _draw_avatar(feet:Vector2,travelling:bool,target:CanvasItem=null):
	if target==null:target=self
	var stage_scale=1.0*(1.0-sin(equipment_pulse*PI)*.015)
	var tilt=0.0 if encounter_active else .015*cast_blend
	target._scene_set_transform(feet+Vector2(float(CharacterSidewalk.approach_footwork(side_motion).root)*stage_scale if _side_world_active() else 0.0,2),0,Vector2(stage_scale,.18*stage_scale));target.draw_circle(Vector2.ZERO,22,Color(.30,.28,.19,.13));target._scene_set_transform(Vector2.ZERO)
	var visual=state.gear.visual_loadout()
	var stowed=_side_world_active() and bool(CharacterSidewalk.weapon_pose(side_motion,1.0,0.0,_attack_style()).stowed)
	if stowed and not str(visual.get("weapon","")).is_empty():_draw_weapon(feet,cast_blend,stage_scale,tilt,target)
	if meditation_amount>0.0001:
		meditator.facing=float(walk_motion.get("facing",1.0))
		meditator.draw_avatar_layers(target,feet,equipment_assets,visual,meditation_amount,meditation_clock,stage_scale)
	elif _side_world_active():
		sidewalker.draw_avatar_layers(target,feet,equipment_assets,visual,side_motion,stage_scale,tilt)
	else:
		walker.draw_avatar_layers(target,feet,equipment_assets,visual,walk_motion,stage_scale,tilt)
	if equipment_pulse>0:
		var shimmer=sin(equipment_pulse*PI)*.18
		for side in [-1,1]:
			var points=PackedVector2Array()
			for j in range(16):
				var t=j/15.0
				points.append(feet+Vector2(side*(28+sin(t*PI)*6),-15-t*75)*stage_scale)
			target.draw_polyline(points,Color(.81,.75,.49,shimmer),1.1,true)
	var weapon_id=str(visual.get("weapon",""))
	if not weapon_id.is_empty() and not stowed and not (target==self and _foreground_combat_sword()):_draw_weapon(feet,cast_blend,stage_scale,tilt,target)
	if practice_time>0:
		var t=fposmod(practice_duration-practice_time,1.6)/1.6
		var center=feet+Vector2(60+t*90,-64)
		if t>.35 and t<.85:
			if avatar_assets.has("mist_slash"):_fit_texture(avatar_assets.mist_slash,Rect2(center-Vector2(37,37),Vector2(74,74)),Color(1,1,1,sin((t-.35)/.5*PI)*.7))

func _draw_weapon(feet:Vector2,power:float,stage_scale:float=1.0,cast_tilt:float=0.0,target:CanvasItem=null):
	if target==null:target=self
	var key=str(state.gear.visual_loadout().get("weapon","")).trim_prefix("weapon_")
	if not avatar_assets.has(key):return
	var is_sword=key=="sword"
	var facing=float(walk_motion.get("facing",1.0))
	var p=feet+(CharacterSidewalk.attachment_offset(Vector2(318,414),side_motion,stage_scale,cast_tilt) if _side_world_active() else CharacterWalk.attachment_offset(Vector2(318,414),walk_motion,stage_scale,cast_tilt))
	var angle=.22 if is_sword else sin(elapsed*1.5)*.04
	var fan_open:=1.0
	if power>=.5 and not encounter_active:angle=1.05 if is_sword else -.28
	angle+=(CharacterSidewalk.attachment_rotation(side_motion,cast_tilt) if _side_world_active() else CharacterWalk.attachment_rotation(walk_motion,cast_tilt))
	if _side_world_active():
		var grip=CharacterSidewalk.weapon_pose(side_motion,stage_scale,cast_tilt,key)
		p=feet+Vector2(grip.offset);angle=float(grip.rotation)+(.22 if is_sword and not bool(grip.stowed) else 0.0);facing=float(grip.facing)
		fan_open=clampf(float(grip.get("fan_open",1.0)),0.0,1.0)
	if meditation_amount>0.0001:
		var seat=smoothstep(0.0,1.0,meditation_amount)
		p=p.lerp(feet+CharacterMeditation.resting_weapon_offset(stage_scale,key),seat)
		angle=lerpf(angle,.43 if is_sword else -.32,seat);facing=1.0
	if _side_world_active():CharacterSidewalk.draw_grip_back(target,feet,side_motion,stage_scale,cast_tilt,key)
	target._scene_set_transform(p,angle*facing,Vector2(facing,1.0)*stage_scale)
	var weapon_rect:=Rect2(-7.8,-53.7,26,76) if is_sword else Rect2(-23.3,-25.6,48,40)
	if not is_sword:
		var fold:=lerpf(.17,1.0,fan_open)
		weapon_rect.position.x*=fold;weapon_rect.size.x*=fold
	if _side_world_active():
		CharacterSidewalk.draw_held_weapon(target,side_weapon_assets.get(key,avatar_assets[key]),weapon_rect,key,false,bool(CharacterSidewalk.weapon_pose(side_motion,stage_scale,cast_tilt,key).stowed))
	else:target.draw_texture_rect(avatar_assets[key],weapon_rect,false)
	target._scene_set_transform(Vector2.ZERO)
	if _side_world_active():CharacterSidewalk.draw_grip_front(target,feet,side_motion,stage_scale,cast_tilt,key)

const SLOT_LABELS={"head":"头饰","chest":"上衣","legs":"下装","feet":"鞋履","weapon":"兵器"}
const RARITY_LABELS={"common":"凡品","uncommon":"灵品","rare":"珍品","epic":"仙品"}
const RARITY_COLORS={"common":Color("738778"),"uncommon":Color("4d8e7b"),"rare":Color("557da2"),"epic":Color("a8759a")}

func _build_equipment_drawer(x:float,y:float,r:Rect2):
	InkPages.build_wardrobe(self,x,y,r)

func _draw_equipment_drawer(x:float,y:float,a:float):
	InkPages.draw_wardrobe(self,x,y,a)

func _save_loadout():
	if not demo and not _save_current():_notice("存档暂时无法写入。")

func _open_treasure(confirmed: bool = false):
	if encounter_active and encounter_phase=="fight":_notice("交锋中暂不启封木箱，请待此敌结束。");return
	var warning: Dictionary=RewardCapacity.chest(state)
	if not confirmed and (bool(warning.get("equipment_full",false)) or not str(warning.get("resource_warning","")).is_empty()):
		CapacityPages.open(self,"chest");return
	var reward:Dictionary=state.open_chest()
	if not reward.get("ok",false):_notice("暂时没有可开启的木箱。");return
	chest_time=4.0;chest_reveal_age=0.0
	_accept_reward(reward,"木箱")
	_refresh_drawer()

func _accept_reward(reward:Dictionary,source:String):
	var item:Dictionary=reward.get("item") if reward.get("item") is Dictionary else {}
	if not item.is_empty():
		last_loot=item;selected_item=int(item.id);selected_slot=str(item.slot)
		inventory_page=maxi(0,(state.gear.inventory.size()-1)/3)
		_notice(source+"所得 · "+str(item.get("name","装备"))+" · 已收入行装","loot")
	else:
		var detail: String="%s所得 · 灵草 %d · 灵露 %d"%[source,int(reward.get("herbs",0)),int(reward.get("dew",0))]
		if str(reward.get("reason",""))=="inventory_full":detail+=" · 装备满，已按规则转换"
		var overflow: Dictionary=reward.get("resource_overflow",{})
		if int(overflow.get("herbs",0))+int(overflow.get("dew",0))>0:detail+=" · 超额未保留：草%d/露%d"%[int(overflow.get("herbs",0)),int(overflow.get("dew",0))]
		_notice(detail,"loot")
	_save_loadout()

func _attack_style()->String:
	var key=str(state.gear.visual_loadout().get("weapon",""))
	return "sword" if key=="weapon_sword" else ("fan" if key=="weapon_fan" else "unarmed")

func _encounter_target_x()->float:
	if not world_route.is_empty():return ROUTE_HERO_X
	return character_x

func _start_encounter():
	if encounter_active or paused:return
	paused_retreat_run_id=-1
	var result:Dictionary=state.start_stage()
	if not bool(result.get("ok",false)):
		var reason:=str(result.get("reason",""))
		_notice("心法尚在调息转换，待气息安定后再出发。" if reason=="heart_adjusting" else ("暂歇中，继续修行后再出发。" if reason=="paused" else "此路暂未开放，请先选一处已解锁的山径。"))
		return
	encounter_run_id=int(result.get("run_id",0));encounter_index=int(result.get("kills",0))
	battle_resources=state.stage_battle_resources()
	encounter_stage_name=str(state.stage_status().get("name","青竹小径"))
	vitality_max=float(state.stats().get("max_hp",100));vitality=vitality_max
	encounter_active=true;encounter_complete=false;encounter_first_clear=false;encounter_chapter_reward={};practice_time=0;duel_pose={}
	hero_support_text="";hero_support_time=0.0
	state.expedition_auto=false
	route_scroll_velocity=0.0;route_frame_velocity=0.0;combat_impacts.clear()
	route_distance=0.0 if encounter_index==0 else float(ROUTE_EVENTS[encounter_index-1])
	if encounter_index==2 and bool(state.stage_status().get("opportunity_checked",false)):route_distance=route_opportunity_at
	var pending_body:Dictionary=state.stage_corpse_status()
	if not pending_body.is_empty():
		route_distance=float(ROUTE_EVENTS[encounter_index])
		if float(pending_body.get("search_seconds",0.0))>0.0:route_distance=_route_enemy_world_x(encounter_index)-ROUTE_HERO_X-35.0
	encounter_phase="prepare_portal";encounter_phase_age=0.0
	_close_drawer();_save_loadout()
	_notice("动身 · "+encounter_stage_name+" · 循径前行，击退镇关灵兽后归山")

func _prepare_stage_monster():
	var status:Dictionary=state.stage_status()
	# Resolve the one-time chance before the approach. An empty shrine is a
	# passing landmark, never an artificial stop followed by another restart.
	if int(status.get("kills",0))==2 and not bool(status.get("opportunity_checked",false)):
		state.check_route_opportunity(encounter_run_id)
		_save_loadout()
		status=state.stage_status()
	var corpse:Dictionary=state.stage_corpse_status()
	var enemy:Dictionary=corpse.get("monster",status.get("next_monster",{})) if not corpse.is_empty() else status.get("next_monster",{})
	encounter_index=int(status.get("kills",0));route_enemy_definition=enemy.duplicate(true)
	route_enemy_definition.route_id=world_route;route_boss=bool(enemy.get("boss",false))
	DuelTimeline.MeleeGeometry.prewarm(route_enemy_definition)
	route_target_distance=float(ROUTE_EVENTS[mini(2,encounter_index)])
	encounter_phase="travel";encounter_phase_age=0.0;encounter_clock=0.0;duel_pose={}
	enemy_flash=0.0;enemy_defeat=0.0;enemy_max_hp=float(enemy.get("hp",30));enemy_hp=enemy_max_hp
	encounter_enemy_attack=int(enemy.get("attack",3));encounter_enemy_defense=int(enemy.get("defense",0))
	encounter_enemy_name=str(enemy.get("name","山野精怪"));pickup_collect_started=-1.0;pickup_claimed_at=-1.0;pickup_save_bucket=-1;encounter_reward={};pickup_status={};pickup_block_reason=""
	_update_enemy_route_position()
	if not corpse.is_empty():
		encounter_phase="pickup";enemy_hp=0.0;enemy_defeat=1.0;pickup_status=corpse
		defeat_enemy_motion={};finish_hero_motion={}
		if bool(corpse.get("search_ready",false)):
			# A restored completed search may have been capacity-blocked before
			# saving. Derive a transient hold from existing data, no new schema.
			set_meta("capacity_corpse_hold",{"run_id":int(corpse.run_id),"monster_index":int(corpse.monster_index),"stage_id":str(corpse.stage_id)})
			pickup_block_reason="awaiting_claim"
			_notice("搜寻已满2秒 · 遗物保留；翻开历练册，亲点收取。")
		else:_notice("重返原处 · 倒地守灵仍在，搜寻进度已保留。")
		return
	if bool(status.get("opportunity_pending",false)) and route_distance>=route_opportunity_at-.001:
		encounter_phase="opportunity"

func _route_enemy_world_x(index:int)->float:
	return ROUTE_HERO_X+(120.0 if index==2 else 88.0)+float(ROUTE_EVENTS[clampi(index,0,2)])

func _route_landmark_feet(world_x:float)->Vector2:
	return Vector2(_world_x((world_x-route_distance)),_world_y(246.0))

func _draw_beast(texture:Texture2D,key:String,p:Vector2,display_size:float,color:Color=Color.WHITE,rotation:float=0.0,offset:Vector2=Vector2.ZERO):
	_scene_set_transform(p+offset,rotation,Vector2.ONE)
	draw_texture_rect(texture,BeastPresentation.draw_rect(key,texture.get_size(),display_size),false,color)
	_scene_set_transform()

func _draw_route_landmarks():
	if practice_session != null: return
	# Every unclaimed creature has a fixed world address from arrival onwards.
	# Preparing the next duel changes ownership only; nothing spawns onscreen.
	var active_visible:=encounter_active and encounter_phase in ["travel","fight","pickup"]
	var first:int=encounter_index+1 if active_visible else int(state.stage_status().get("kills",encounter_index))
	if encounter_complete:first=3
	for index in range(first,3):
		var boss:=index==2
		var p:=_route_landmark_feet(_route_enemy_world_x(index))
		var display_size:=174.0 if boss else 112.0
		if p.x < -display_size or p.x > size.x+display_size:continue
		var key:String=world_route+("_boss" if boss else "")+"_idle"
		var texture:Texture2D=beast_assets.get(key)
		if texture:
			var rendered:=MonsterPoseRenderer.draw(self,beast_assets,key,p,display_size,{"combat_phase":"idle"},Color(1,1,1,_route_reveal()))
			if not rendered:_draw_beast(texture,key,p,display_size,Color(1,1,1,_route_reveal()))
	# The same stone remains visible during approach, choice and departure.
	_draw_route_opportunity(Vector2.ZERO)

func _update_enemy_route_position():
	encounter_enemy_x=_route_enemy_world_x(encounter_index)-route_distance

func _begin_duel():
	combat_report_saved = false
	encounter_phase="fight";encounter_phase_age=0.0;encounter_clock=0.0;route_scroll_velocity=0.0;combat_hitstop=0.0;combat_impacts.clear()
	var hero:Dictionary=state.stats().duplicate(true)
	# A legal between-encounter passive change updates the next snapshot's HP
	# ceiling too. Raising the ceiling never heals; removing a bonus clamps HP.
	vitality_max=maxf(1.0,float(hero.get("max_hp",100)))
	vitality=clampf(vitality,0.0,vitality_max)
	hero.hp=int(vitality);hero.max_hp=int(vitality_max)
	hero.technique_level=int(state.technique_levels.get(state.technique,1))
	hero.battle_resources=battle_resources.duplicate(true)
	route_enemy_definition.engagement_distance=(encounter_enemy_x-character_x)
	var attack_key:String=world_route+("_boss" if route_boss else "")+"_attack"
	route_enemy_definition.enemy_front_extent=maxf(24.0,-BeastPresentation.visible_bounds(attack_key,174.0 if route_boss else 112.0).position.x)
	duel.start(hero,route_enemy_definition,state.technique,_attack_style(),encounter_run_id*1337+encounter_index*79+17)
	duel_pose=duel.pose()
	_persist_battle_resources()

func _persist_battle_resources():
	if practice_session != null: return
	# Capture before cancelling, changing phase, claiming the last reward, or
	# writing disk. The state API rejects a stale or no-longer-active run.
	if not encounter_active:return
	if encounter_phase=="fight":battle_resources=duel.battle_resource_snapshot()
	if battle_resources.is_empty():return
	state.update_stage_battle_resources(encounter_run_id,battle_resources)

func _advance_field_battle_resources(delta:float):
	# Only time actually spent travelling/collecting on the active route counts.
	# Portals, waiting for a choice, pause, home and offline time never recharge.
	if not encounter_active or paused or not encounter_phase in ["travel","pickup"]:return
	var effective:Dictionary=state.stats()
	battle_resources=DuelTimeline.rest_resource_snapshot(battle_resources,delta,float(effective.get("combat_qi_max",40.0)),float(effective.get("combat_qi_regen",2.0)))
	_persist_battle_resources()

func _can_retreat_encounter()->bool:
	# Space pauses simulation, unlike a recovery/update transaction or a trial.
	# Recheck at the action boundary; a stale paper control is not authority.
	if practice_session!=null or closing or get_meta("update_transaction",false):return false
	if not is_inside_tree() or get_tree().paused or not encounter_active:return false
	if encounter_run_id<=0 or encounter_phase not in ["prepare_portal","teleport_out","teleport_arrive","travel","fight","pickup","opportunity","teleport_return_out","teleport_home_in"]:return false
	var returning:bool=encounter_phase in ["teleport_return_out","teleport_home_in"]
	if not state.stage_run.is_empty():
		if int(state.stage_run.get("run_id",0))!=encounter_run_id:return false
		var status:Dictionary=state.stage_status()
		return bool(status.get("active",false)) or (returning and bool(status.get("paused",false)))
	# The final real search atomically clears stage_run before its receipt and
	# homeward presentation finish. It is not a stale or abandoned encounter.
	return bool(encounter_reward.get("stage_finished",false)) and int(encounter_reward.get("run_id",0))==encounter_run_id and pickup_claimed_at>=0.0 and (encounter_phase=="pickup" or (returning and encounter_complete))

func _retreat_encounter(defeated:bool=false):
	if not _can_retreat_encounter():return
	if paused:paused_retreat_run_id=encounter_run_id
	# A second click may authorize a paused existing return, never restart it,
	# duplicate its report, or discard its completed-chapter presentation.
	if encounter_phase in ["teleport_return_out","teleport_home_in"]:return
	var finished:bool=state.stage_run.is_empty() and bool(encounter_reward.get("stage_finished",false))
	if encounter_phase == "fight": _record_combat_report("defeat" if defeated else "retreat")
	_persist_battle_resources()
	duel.cancel();duel_pose={};route_scroll_velocity=0.0;combat_impacts.clear()
	# Going home keeps the next unclaimed enemy. Resuming still needs an explicit click.
	if not finished:
		if defeated and state.has_method("fail_stage"):state.fail_stage(encounter_run_id)
		elif state.has_method("pause_stage"):state.pause_stage(encounter_run_id)
		elif state.has_method("fail_stage"):state.fail_stage(encounter_run_id)
		else:state.cancel_stage()
	state.expedition_auto=false
	encounter_phase="teleport_return_out" if not world_route.is_empty() else "teleport_home_in";encounter_phase_age=0.0
	encounter_complete=finished
	if not finished:_notice("调息归山 · 行装修为无损，已击退守灵不会重打。" if defeated else "收步归山 · 收获保留，下次从此处继续")
	# Keep a failed write visible; it must not be covered by a success notice.
	_save_loadout()

func _update_encounter(delta:float):
	if paused:
		# Only an explicit request for this formal run may cross the pause and
		# seated-pose gates. No fight, field resources or outward portal ticks.
		if paused_retreat_run_id==encounter_run_id and encounter_phase in ["teleport_return_out","teleport_home_in"] and _can_retreat_encounter():
			encounter_phase_age+=delta
			_update_portal(delta)
		return
	# Only the two combatants and contact effects stop. The window, book,
	# landscape wind, interface and cultivation clock continue normally.
	combat_frame_delta=delta
	if encounter_phase=="fight" and combat_hitstop>0.0:
		var held:=minf(delta,combat_hitstop)
		combat_hitstop=maxf(0.0,combat_hitstop-held)
		combat_frame_delta=maxf(0.0,delta-held)
	for impact in combat_impacts:impact.age=float(impact.age)+combat_frame_delta
	combat_impacts=combat_impacts.filter(func(impact:Dictionary)->bool:return float(impact.age)<float(impact.get("profile",{}).get("duration",.38)))
	chest_time=maxf(0,chest_time-delta);enemy_flash=maxf(0,enemy_flash-delta*3.0)
	combat_number_time=maxf(0,combat_number_time-delta);hero_hit=maxf(0,hero_hit-delta*2.5)
	hero_support_time=maxf(0.0,hero_support_time-delta)
	pickup_burst=maxf(0,pickup_burst-delta*.9)
	# Manual departure is the only way in. No idle or offline stage scheduler.
	if not encounter_active or meditation_amount>.02:return
	encounter_phase_age+=delta
	if encounter_phase=="prepare_portal":
		encounter_phase="teleport_out";encounter_phase_age=0.0;return
	if _portal_active():_update_portal(delta);return
	if encounter_phase=="opportunity":
		if not bool(state.stage_status().get("opportunity_pending",false)):
			encounter_phase="travel";encounter_phase_age=0.0
		return
	if encounter_phase=="travel":
		_advance_field_battle_resources(delta)
		var checkpoint=encounter_index==2 and bool(state.stage_status().get("opportunity_pending",false))
		var stop=route_opportunity_at if checkpoint else route_target_distance
		var motion:Dictionary=RouteMotion.advance(route_distance,route_scroll_velocity,stop,delta,1.0)
		route_distance=float(motion.distance);route_scroll_velocity=float(motion.velocity)
		_update_enemy_route_position()
		if bool(motion.arrived):
			if checkpoint:
				var checked:Dictionary=state.stage_status()
				if bool(checked.get("opportunity_pending",false)):
					encounter_phase="opportunity";encounter_phase_age=0.0
					_notice(str(state.opportunity_status().get("name","山间机缘"))+" · 点路边光印回应。此缘不会消失。")
			else:_begin_duel()
		return
	if encounter_phase=="pickup":
		_advance_field_battle_resources(delta)
		enemy_defeat=minf(1.0,enemy_defeat+delta/1.05)
		if pickup_claimed_at>=0.0:
			if encounter_phase_age-pickup_claimed_at>=3.0:
				if bool(encounter_reward.get("stage_finished",false)):
					encounter_phase="teleport_return_out";encounter_complete=true;encounter_phase_age=0.0
				else:_prepare_stage_monster()
			return
		if encounter_phase_age>.90 and pickup_collect_started<0.0:
			var stop:float=_route_enemy_world_x(encounter_index)-ROUTE_HERO_X-35.0
			var motion:Dictionary=RouteMotion.advance(route_distance,route_scroll_velocity,stop,delta,1.0)
			route_distance=float(motion.distance);route_scroll_velocity=float(motion.velocity)
			_update_enemy_route_position()
			if bool(motion.arrived):
				pickup_collect_started=encounter_phase_age
				_record_cue("走近尸体 · 开始两秒搜寻")
				return # Approach time is not counted as searching.
		if pickup_collect_started>=0.0:
			state.advance_stage_search(encounter_run_id,encounter_index,delta)
			pickup_status=state.stage_corpse_status()
			var bucket:int=int(float(pickup_status.get("search_seconds",0.0))*4.0)
			if bucket!=pickup_save_bucket:pickup_save_bucket=bucket;_save_loadout()
			if bool(pickup_status.get("search_ready",false)):
				_claim_searched_corpse()
		return
	if encounter_phase!="fight":return
	encounter_clock+=combat_frame_delta
	for event in duel.advance(combat_frame_delta):
		if str(event.type)=="contact":
			_present_duel_contact(event)
		elif str(event.type)=="finished":
			if bool(event.victory):_complete_duel()
			else:_retreat_encounter(true)
	duel_pose=duel.pose() if encounter_phase=="fight" else {}
	if encounter_phase=="fight":_persist_battle_resources()

func _present_duel_contact(event:Dictionary):
	_play_combat_contact(event)
	vitality=float(event.hero_hp);enemy_hp=float(event.enemy_hp)
	_push_combat_feedback(event)
	if str(event.target)=="enemy":
		duel_resolution=str(event.resolution);enemy_flash=1.0 if int(event.damage)>0 else 0.0
		combat_number=("反击 −" if bool(event.get("counter",false)) and str(event.resolution)=="hit" and int(event.damage)>0 else ("闪避 " if event.resolution=="dodge" else ("格挡 " if event.resolution=="guard" else "")))+str(event.damage)
		combat_number_time=0.0 if event.resolution=="whiff" else .8
	elif str(event.get("actor",""))=="hero":
		if int(event.get("heal",0))>0:
			hero_support_text="+%d"%int(event.heal);hero_support_time=.9
		elif int(event.get("shield_added",0))>0:
			hero_support_text="护身 +%d"%int(event.shield_added);hero_support_time=.9
	else:
		hero_resolution="shield" if float(event.get("shield_absorbed",0.0))>0 and int(event.damage)==0 else str(event.resolution)
		hero_hit=0.0 if str(event.resolution)=="whiff" else 1.0;hero_damage=int(event.damage)
		if str(event.resolution)=="guard" and bool(event.get("counter_earned",false)) and not bool(event.get("poise_broken",false)):
			hero_support_text="卸力 · 反击";hero_support_time=.9

func _complete_duel():
	_record_combat_report("victory")
	var finishing_pose:Dictionary=duel.pose()
	defeat_enemy_motion=finishing_pose.get("enemy",{}).duplicate(true)
	finish_hero_motion=finishing_pose.get("hero",{}).duplicate(true)
	_persist_battle_resources()
	var corpse:Dictionary=state.begin_stage_corpse(encounter_run_id,encounter_index)
	if not bool(corpse.get("ok",false)):_retreat_encounter();return
	encounter_reward={};pickup_status=state.stage_corpse_status()
	encounter_phase="pickup";encounter_phase_age=0.0;enemy_defeat=0.0;pickup_collect_started=-1.0;pickup_claimed_at=-1.0;pickup_save_bucket=-1;pickup_block_reason=""
	encounter_first_clear=false;encounter_chapter_reward={}
	route_scroll_velocity=0.0
	_record_cue("守灵倒地 · 收获尚未入囊")
	toast_time=0.0
	_save_loadout();_refresh_drawer()

func _claim_searched_corpse(explicit: bool = false):
	var held: Dictionary=get_meta("capacity_corpse_hold",{})
	if not explicit and int(held.get("run_id",-1))==encounter_run_id and int(held.get("monster_index",-1))==encounter_index:return
	var result:Dictionary=state.complete_stage_search(encounter_run_id,encounter_index)
	if not bool(result.get("ok",false)):
		var reason:String=str(result.get("reason",""))
		if reason!=pickup_block_reason:
			pickup_block_reason=reason
			if reason in ["inventory_full","material_full","materials_full","resource_full","chest_full"]:
				var target: Dictionary={"run_id":encounter_run_id,"monster_index":encounter_index,"stage_id":str(state.stage_status().get("id",""))}
				set_meta("capacity_corpse_hold",target)
				_notice(str(RewardCapacity.corpse(state).get("description","容量不足"))+" · 搜寻进度保留，整理后亲点收取。")
				if not explicit:CapacityPages.open(self,"corpse",target,reason)
			else:_notice("搜寻收取暂缓 · 进度保留，可归山后继续。")
		return
	pickup_block_reason=""
	set_meta("capacity_corpse_hold",{})
	encounter_reward=result;pickup_claimed_at=encounter_phase_age;pickup_burst=1.0
	encounter_first_clear=bool(result.get("first_clear",false));encounter_chapter_reward=result.get("chapter_reward",{})
	encounter_chapter_reward.recipe_unlocks=result.get("recipe_unlocks",[])
	var item:Dictionary=result.get("item",{}) if result.get("item") is Dictionary else {}
	if encounter_first_clear and encounter_chapter_reward.get("item") is Dictionary:item=encounter_chapter_reward.item
	if not item.is_empty():
		last_loot=item;selected_item=int(item.id);selected_slot=str(item.slot);inventory_page=maxi(0,(state.inventory.size()-1)/3)
	var names:Array[String]=[]
	for row in state.material_rows():
		var gained:int=int(result.get("materials",{}).get(str(row.id),0))
		if gained>0:names.append(str(row.name)+" ×%d"%gained)
	if not item.is_empty():names.append(str(item.name))
	if int(result.get("chests",0))>0:names.append("木箱 ×1")
	_record_cue("搜寻收好 · "+" · ".join(names))
	_sound("loot",.30);reward_pulse=1.0
	_save_loadout();_refresh_drawer()

func _enemy_feet()->Vector2:
	return Vector2(_world_x(encounter_enemy_x),_world_y((230.0+(16 if _diorama_active() or not world_route.is_empty() else 0))))

func _event_contact_point(event:Dictionary)->Vector2:
	var geometry:Dictionary=event.get("melee_contact",{})
	if str(event.get("target",""))=="hero":
		geometry=event.get("enemy_contact",{})
		if not geometry.is_empty():
			var feet:=Vector2(_world_x(character_x),_world_y((character_y+16.0)))
			return feet+Vector2(geometry.point)
	if not geometry.is_empty():
		var feet:=Vector2(_world_x(character_x),_world_y((character_y+16.0)))
		return feet+Vector2(geometry.target)
	return _combat_contact_point(str(event.target))

func _combat_contact_point(receiver:String)->Vector2:
	if receiver=="enemy" and duel_pose.has("melee_contact"):
		return Vector2(_world_x(character_x),_world_y((character_y+16.0)))+Vector2(duel_pose.melee_contact.target)
	if receiver=="hero":
		var feet:=Vector2(_world_x(character_x),_world_y((character_y+16.0)))
		var pose:Dictionary=CharacterSidewalk.sample_pose(side_motion)
		return feet+(Vector2(12,-168)+Vector2(pose.shift))*CharacterSidewalk.PIXEL_SCALE
	var visual:Dictionary=duel_pose.get("enemy",{})
	var pose_key:=str(visual.get("pose_key","idle"))
	if pose_key=="recovery":pose_key="idle"
	var key:String=world_route+("_boss" if route_boss else "")+"_"+pose_key
	if MonsterPoseRenderer.supports(key):
		key=world_route+("_boss" if route_boss else "")+"_"+MonsterPoseRenderer.source_pose(key,visual)
		var authored:Dictionary=MonsterPoseRenderer.landmarks(key)
		var head:Array=authored.get("head_landmark",[40,120,100,180])
		var anchor:Array=authored.get("ground_anchor",[128,232])
		var scale_value:float=(174.0 if route_boss else 112.0)/256.0*MonsterPoseRenderer.pose_scale(key)
		var head_point:=MonsterPoseRenderer.transform_point(Vector2(float(head[0])+3.0,(float(head[1])+float(head[3]))*.5),key,visual)
		var point:Vector2=(head_point-Vector2(float(anchor[0]),float(anchor[1])))*scale_value
		return _enemy_feet()+Vector2(visual.get("visual_offset",Vector2.ZERO))+point.rotated(float(visual.get("visual_rotation",0.0)))
	var data:Dictionary=BeastPresentation.landmarks(key)
	var skull:Array=data.get("head_landmark",[40,120,100,180])
	var rect:Rect2=BeastPresentation.draw_rect(key,Vector2(256,256),174.0 if route_boss else 112.0)
	var point:Vector2=rect.position+Vector2(float(skull[0])+3.0,(float(skull[1])+float(skull[3]))*.5)*rect.size.x/256.0
	return _enemy_feet()+Vector2(visual.get("visual_offset",Vector2.ZERO))+point.rotated(float(visual.get("visual_rotation",0.0)))

func _ink_trail(points:PackedVector2Array,color:Color,alpha:float,width:float=3.0,pigment:float=0.0):
	if points.size()<2 or alpha<=.001:return
	# Resample short straight strikes as well as arcs, so every ribbon tapers.
	var samples:=PackedVector2Array()
	for i in range(points.size()-1):
		var distance:float=points[i].distance_to(points[i+1])
		if distance<.25:continue
		var count:int=maxi(1,ceili(distance/5.0))
		for j in range(count):samples.append(points[i].lerp(points[i+1],float(j)/count))
	if samples.is_empty():return
	samples.append(points[-1])
	var upper:=PackedVector2Array();var lower:=PackedVector2Array()
	for i in range(samples.size()):
		var tangent:Vector2=samples[mini(i+1,samples.size()-1)]-samples[maxi(0,i-1)]
		var normal:=Vector2(-tangent.y,tangent.x).normalized()
		var q:float=float(i)/maxf(1.0,float(samples.size()-1))
		var thickness:float=.7+width*1.5*pow(sin(q*PI),.7)
		upper.append(samples[i]+normal*thickness);lower.append(samples[i]-normal*thickness)
	var pale:=color.lightened(.70).lerp(Color("fff1d2"),.30).lerp(color,pigment)
	var fill:=Color(pale,alpha*.95)
	# Individual triangles tolerate a curved or reversing wrist path. Passing
	# one self-crossing outline to polygon triangulation silently loses a slash.
	for i in range(samples.size()-1):
		for triangle in [PackedVector2Array([upper[i],upper[i+1],lower[i+1]]),PackedVector2Array([upper[i],lower[i+1],lower[i]])]:
			if absf((triangle[1]-triangle[0]).cross(triangle[2]-triangle[0]))>.01:
				draw_colored_polygon(triangle,fill)
	draw_polyline(upper,Color(color.darkened(.30),alpha*.9),1.4+pigment,true)
	draw_polyline(lower,Color(color,alpha*(.65+pigment*.3)),1.0+pigment*.6,true)
	draw_polyline(samples,Color(pale.lightened(.2),alpha*.9),maxf(1.5,width*.45),true)

func _draw_petal(point:Vector2,angle:float,alpha:float,scale_value:float=1.0):
	var points:=PackedVector2Array()
	for offset in [Vector2(-6,0),Vector2(-1,-3),Vector2(6,0),Vector2(-1,3)]:points.append(point+offset.rotated(angle)*scale_value)
	draw_colored_polygon(points,Color(.76,.43,.47,alpha))
	draw_line(point+Vector2(-4,0).rotated(angle)*scale_value,point+Vector2(4,0).rotated(angle)*scale_value,Color(.99,.83,.71,alpha*.9),1.1,true)

func _battle_strip_visible()->bool:
	return encounter_active and encounter_phase=="fight" and drawer_name.is_empty() and drawer_alpha<.02

func _battle_skill_status(ability:Dictionary,available_qi:float=-1.0)->String:
	if ability.is_empty() or str(ability.get("id","")).is_empty():return "未装备"
	if not bool(ability.get("available",false)):return "兵器不合" if str(ability.get("action_kind",""))=="weapon_art" else "不可用"
	var remaining:=float(ability.get("remaining",0.0))
	if remaining>.049:return "%.1fs"%remaining
	if bool(ability.get("ready",false)):return "就绪"
	if available_qi>=float(ability.get("qi_cost",0.0)):
		return "待疗伤" if str(ability.id)=="mending" else ("护体中" if str(ability.id)=="barrier" else "待机")
	return "战气不足"

func _battle_strip_slots(resources:Dictionary)->Array:
	var slots:Array=resources.get("active_skills",[]).duplicate(true)
	var weapon:Dictionary=resources.get("weapon_skill",{}).duplicate(true)
	if weapon.is_empty() and not str(resources.get("weapon_id","")).is_empty():
		weapon={"id":resources.weapon_id,"name":resources.get("weapon_name","兵器技"),"action_kind":"weapon",
			"qi_cost":resources.get("weapon_cost",0.0),"remaining":resources.get("weapon_cd",0.0),
			"ready":resources.get("weapon_ready",false),"available":resources.get("weapon_available",false)}
	# Keep the innate slot visible when unarmed, so its absence is explicit.
	if weapon.is_empty():weapon={"id":"","name":"兵器技","action_kind":"weapon","available":false}
	slots.append(weapon)
	return slots

func _draw_battle_skill_icon(p:Vector2,lane:String,color:Color):
	if lane=="weapon_art":
		draw_line(p+Vector2(-4,5),p+Vector2(4,-5),color,1.5,true)
		draw_line(p+Vector2(-5,1),p+Vector2(0,5),color,1.3,true)
	elif lane in ["spell","defense","utility"]:
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-7),p+Vector2(5,0),p+Vector2(0,6),p+Vector2(-5,0)]),Color(color,.32))
		draw_line(p+Vector2(0,-5),p+Vector2(0,4),color,1.2,true)
	else:
		draw_arc(p,5,-.5,PI*1.5,16,color,1.2,true)
		draw_line(p+Vector2(-3,4),p+Vector2(4,-3),color,1.4,true)

func _draw_battle_strip():
	if not _battle_strip_visible():return
	var resources:Dictionary=duel.battle_resource_snapshot()
	var slots:=_battle_strip_slots(resources)
	var width:=120.0+108.0*slots.size()
	var rect:=Rect2(size.x-width-22.0,size.y-49.0,width,38)
	InkPaper.paint(self,rect,.83,"leaf",1.0)
	var origin:=rect.position+Vector2(10,13)
	var available_qi:=float(resources.get("qi",0.0))
	var maximum:=maxf(1.0,float(resources.get("max_qi",40.0)))
	_text("战气 %d/%d"%[int(floor(available_qi)),int(maximum)],origin,10,Color("425b58"),SERIF)
	draw_line(origin+Vector2(0,11),origin+Vector2(87,11),Color("bbc8bd"),3,true)
	draw_line(origin+Vector2(0,11),origin+Vector2(87*clampf(available_qi/maximum,0.0,1.0),11),Color("507f80"),3,true)
	for i in range(slots.size()):
		var ability:Dictionary=slots[i]
		var lane:=str(ability.get("action_kind","spell"))
		var x:=origin.x+105+i*108
		var status:=_battle_skill_status(ability,available_qi)
		var ready:=bool(ability.get("ready",false))
		var color:=Color("456c5d") if ready else Color("8a8577")
		draw_line(Vector2(x-7,rect.position.y+8),Vector2(x-7,rect.end.y-7),Color("d0cabc"),1,true)
		_draw_battle_skill_icon(Vector2(x+4,origin.y-3),lane,color)
		var label:=str(ability.get("name","主动技"))
		if label.is_empty():label="兵器技" if lane=="weapon" else "主动技"
		if label.length()>6:label=label.left(5)+"…"
		_text(label,Vector2(x+14,origin.y),10,color,SERIF)
		var cost:=float(ability.get("qi_cost",0.0))
		_text(status+(" · %d气"%int(ceil(cost)) if bool(ability.get("available",false)) else ""),Vector2(x,origin.y+13),9,color)

func _combat_effect_kind(hero:Dictionary)->String:
	var kind:=str(hero.get("action_kind",duel_pose.get("action_kind","basic")))
	if kind=="basic":return "basic"
	if kind=="weapon":return "weapon"
	return str(hero.get("skill_id",duel_pose.get("skill_id",state.technique)))

func _combat_effect_color(effect:String,style:String="sword")->Color:
	if effect=="basic":return {"sword":Color("7a8882"),"fan":Color("968365"),"unarmed":Color("a1886b")}.get(style,Color("7a8882"))
	if effect=="weapon":return Color("9a9455") if style=="fan" else Color("568aa0")
	return {"mist":Color("7faaa1"),"petal":Color("ad526f"),"ember":Color("c76b2e"),"frost":Color("548ea9"),"thunder":Color("8565b1"),"barrier":Color("c2a762"),"mending":Color("78a56f"),"stillness":Color("398a95")}.get(effect,Color("7faaa1"))

func _weapon_trail_in_front(points:PackedVector2Array,feet:Vector2,color:Color,alpha:float,width:float,pigment:float=0.0):
	# The ink wake is visually occluded by the large chibi head. It must not
	# draw a bright blade-shaped stripe through the face during a raised cut.
	var pose:Dictionary=CharacterSidewalk.sample_pose(side_motion)
	var center:Vector2=feet+CharacterSidewalk._body(Vector2(-16,-335),Vector2(pose.shift),float(pose.body_angle))*CharacterSidewalk.PIXEL_SCALE
	var radii:=Vector2(34,43)
	var visible:=PackedVector2Array()
	for index in range(points.size()-1):
		var a:Vector2=points[index];var b:Vector2=points[index+1]
		var count:=maxi(1,ceili(a.distance_to(b)/2.0))
		for sample_index in range(count+1):
			var point:=a.lerp(b,float(sample_index)/count)
			var relative:Vector2=(point-center)/radii
			if relative.length_squared()<1.0:
				if visible.size()>1:_ink_trail(visible,color,alpha,width,pigment)
				visible.clear()
			else:visible.append(point)
	if visible.size()>1:_ink_trail(visible,color,alpha,width,pigment)

func _draw_sword_edge_trace(feet:Vector2,alpha:float):
	# Steel leaves a thin disappearing edge, not a filled fan or half-shield.
	# Every point comes from the articulated blade; no circle is drawn here.
	var path:=CharacterSidewalk.sword_edge_trace(side_motion)
	if path.size()<2:return
	for i in range(path.size()-1):
		var q:=float(i+1)/float(path.size()-1)
		draw_line(feet+path[i],feet+path[i+1],Color("cad1bd",alpha*q*.62),.35+q*.75,true)

func _draw_basic_trail(feet:Vector2,hero:Dictionary,alpha:float):
	# A small physical trace remains on the actual hand/blade/fan tip. It never
	# bridges the gap to the enemy or borrows the equipped spell's effect.
	var style:=str(hero.get("basic_style",_attack_style()))
	if style=="sword":
		_draw_sword_edge_trace(feet,alpha*.68)
		return
	var grip:Dictionary=CharacterSidewalk.weapon_pose(side_motion,1.0,0.0,style)
	var pivot:=feet+Vector2(grip.offset)
	var rotation:=float(grip.rotation)+(.22 if style=="sword" else 0.0)
	var length:=54.0 if style=="sword" else (26.0 if style=="fan" else 10.0)
	var tip:=pivot+Vector2(0,-length).rotated(rotation)
	var points:=PackedVector2Array()
	var move:=str(hero.get("combat_move",""))
	if "thrust" in move or "jab" in move or "flick" in move or "knuckle" in move:
		var direction:=Vector2(0,-1).rotated(rotation)
		points.append(tip-direction*(17.0 if style=="sword" else 10.0));points.append(tip)
	else:
		for j in range(9):
			points.append(pivot+Vector2(0,-length).rotated(rotation-.42+float(j)/8.0*.48))
	_weapon_trail_in_front(points,feet,_combat_effect_color("basic",style),alpha*.62,1.05,.45)

func _draw_weapon_skill_fx(feet:Vector2,hand:Vector2,target:Vector2,progress:float,flight:float,alpha:float,style:String):
	var color:=_combat_effect_color("weapon",style)
	if style=="fan":
		# Returning fan: two compact opposing trajectories, distinct from petals.
		for direction in [-1.0,1.0]:
			var path:=PackedVector2Array()
			for j in range(19):
				var q:=float(j)/18.0*flight
				path.append(hand.lerp(target,q)+Vector2(0,sin(q*PI)*18.0*direction))
			_ink_trail(path,color,alpha*(.85 if direction>0 else .55),2.0,.5)
		var rim:=target if flight>=.99 else hand.lerp(target,flight)
		draw_arc(rim,9.0,-2.6+progress,.1+progress,16,Color(color,alpha),2.2,true)
	else:
		var point:=hand.lerp(target,flight)
		_ink_trail(PackedVector2Array([hand,point]),color,alpha,3.6,.55)
		var direction:=(target-hand).normalized()
		var normal:=direction.orthogonal()
		draw_colored_polygon(PackedVector2Array([point+direction*7,point-direction*9+normal*4,point-direction*6,point-direction*9-normal*4]),Color(color,alpha*.9))
		draw_line(hand,point,Color("eff4d7",alpha*.85),1.1,true)

func _draw_combat_fx(feet:Vector2):
	var hero:Dictionary=duel_pose.get("hero",{})
	var enemy:Dictionary=duel_pose.get("enemy",{})
	var phase:=str(hero.get("combat_phase","idle"))
	var progress:=clampf(float(hero.get("phase_progress",0.0)),0.0,1.0)
	var move:=str(hero.get("combat_move",""))
	var body_feet:Vector2=feet+Vector2(float(CharacterSidewalk.approach_footwork(side_motion).root),0)
	var hand:=feet+CharacterSidewalk.attachment_offset(Vector2(318,414),side_motion)
	var target:=_combat_contact_point("enemy")
	var technique:=_combat_effect_kind(hero)
	var style:=str(hero.get("basic_style",_attack_style()))
	var color:=_combat_effect_color(technique,style)
	var supporting:=str(hero.get("action_kind","")) in ["defense","utility"]
	var attacking:=(float(hero.get("attack_amount",0.0))>.01 or supporting) and not move.is_empty()
	# Hearts are passive and never take a paid action slot. A low, quiet breath
	# ring acknowledges the selected heart without a repeated cast animation.
	if encounter_phase=="fight":
		var heart_id:=str(duel_pose.get("battle_resources",{}).get("heart_method_id",""))
		if not heart_id.is_empty():
			var breath_color:=Color("6f9b8a") if heart_id=="stillness" else Color("a49760")
			draw_arc(body_feet+Vector2(0,3),18.0+sin(encounter_clock*1.3),.12,PI-.12,20,Color(breath_color,.10),1.0,true)
		var ward_cast:=0.0
		if technique=="barrier" and attacking:
			if phase=="windup":ward_cast=progress*.45
			elif phase in ["strike","contact"]:ward_cast=.75
			elif phase=="recovery":ward_cast=.65*(1.0-progress)
		CombatResponseCues.draw_barrier(self,body_feet,duel_pose,ward_cast,combat_impacts)
		var ward_label:=CombatResponseCues.barrier_status(duel_pose)
		if not ward_label.is_empty():_text(ward_label,body_feet+Vector2(-26,30),9,Color("769276"),SANS)
		var slow_remaining:=float(duel_pose.get("enemy_slow_remaining",0.0))
		if slow_remaining>0.0:
			var ice:=_combat_effect_color("frost")
			var alpha:=minf(1.0,slow_remaining/.35)*.48
			for i in range(3):
				var point:=_enemy_feet()+Vector2(float(i-1)*13,-3)
				draw_polyline(PackedVector2Array([point+Vector2(-4,0),point+Vector2(0,-8),point+Vector2(4,0)]),Color(ice,alpha),1.3,true)
	if attacking and phase=="windup":
		if technique in ["barrier","mending"]:
			var center:=body_feet+Vector2(0,-35)
			for i in range(4):
				var angle:=float(i)/4.0*TAU+progress
				var point:=center+Vector2(cos(angle),sin(angle))*(22.0-progress*13.0)
				draw_line(point-Vector2(2,0),point+Vector2(2,0),Color(color,progress*.6),2,true)
		elif technique in ["ember","stillness","frost","thunder"]:
			for i in range(7):
				var angle:=i*TAU/7.0+progress*.8
				var radius:float=17.0-progress*10.0
				var point:=hand+Vector2(cos(angle),sin(angle))*radius
				if technique in ["frost","thunder"]:
					draw_line(point-Vector2(2,3),point+Vector2(2,3),Color(color,.3+progress*.5),1.3,true)
				else:draw_circle(point,1.8+progress*.5,Color(color,.3+progress*.5))
			if technique=="stillness":draw_arc(hand,9.0+progress*7,0,TAU,32,Color(color,.25+progress*.5),2,true)
		elif technique=="petal":
			for i in range(3):_draw_petal(body_feet+Vector2(-16-i*10,-11-progress*12),-.4+i*.6,progress*.65,.7)
		elif technique=="weapon":
			draw_line(hand+Vector2(-6,-4)*progress,hand+Vector2(6,4)*progress,Color(color,progress*.7),1.4,true)
	if attacking and phase in ["strike","contact","recovery"]:
		var alpha:=.82 if phase=="strike" else (.85*(1.0-progress*.35) if phase=="contact" else .65*(1.0-progress))
		var flight:=smoothstep(0.0,1.0,progress) if phase=="strike" else 1.0
		if phase=="recovery":alpha*=1.0-smoothstep(0.0,.55,progress)
		if technique=="basic":
			_draw_basic_trail(feet,hero,alpha)
		elif technique=="weapon":
			_draw_weapon_skill_fx(feet,hand,target,progress,flight,alpha,style)
		elif technique=="barrier":
			pass # The actual sustaining field is drawn once by CombatResponseCues.
		elif technique=="mending":
			# Leaves and inward motes return to the hero, never to the opponent.
			var center:=body_feet+Vector2(0,-36)
			for i in range(6):
				var angle:=float(i)/6.0*TAU+progress*.6
				var point:=center+Vector2(cos(angle)*27,sin(angle)*33)*(1.0-flight*.8)
				var direction:=Vector2.from_angle(angle+.7)
				draw_colored_polygon(PackedVector2Array([point-direction*5,point+direction.orthogonal()*2.5,point+direction*5,point-direction.orthogonal()*2.5]),Color(color,alpha*.75))
				draw_line(point-direction*3,point+direction*3,Color("e8edc4",alpha*.8),1.0,true)
			draw_circle(center,2.8,Color("d6e8b3",alpha*.7))
		elif technique=="frost":
			# Ice travels low, then closes a binding lattice around the legs.
			var ground:=_enemy_feet()+Vector2(0,-12)
			var point:=hand.lerp(ground,flight)
			_ink_trail(PackedVector2Array([hand,hand.lerp(ground,.52)+Vector2(0,14),point]),color,alpha*.7,2.0,.55)
			for i in range(5):
				var x:=float(i-2)*10.0
				var shard:=point+Vector2(x*flight,-absf(x)*.2)
				draw_colored_polygon(PackedVector2Array([shard+Vector2(-3,5),shard+Vector2(0,-12-float(i%2)*7),shard+Vector2(4,5)]),Color(color,alpha*.75*flight))
				draw_line(shard+Vector2(0,-10),shard+Vector2(1,4),Color("d7e6e6",alpha*.8*flight),1,true)
			if flight>.5:
				var ring:=PackedVector2Array()
				for j in range(25):
					var angle:=float(j)/24.0*TAU
					ring.append(ground+Vector2(cos(angle)*24,sin(angle)*7))
				_ink_trail(ring,color,alpha*.8,1.5,.6)
		elif technique=="thunder":
			# A kinked descending bolt targets posture at the upper body.
			var point:=hand.lerp(target,flight)
			var bolt:=PackedVector2Array([hand,hand.lerp(point,.24)+Vector2(0,-17),hand.lerp(point,.43)+Vector2(-4,-8),hand.lerp(point,.61)+Vector2(4,-27),hand.lerp(point,.78)+Vector2(-3,-10),point])
			_ink_trail(bolt,color,alpha,2.5,.65)
			draw_polyline(bolt,Color("f2e4d8",alpha*.9),1.0,true)
			if flight>.85:
				for direction in [-1.0,1.0]:
					draw_polyline(PackedVector2Array([target,target+Vector2(9*direction,-8),target+Vector2(5*direction,-15)]),Color(color,alpha*.8),1.7,true)
		elif technique=="ember":
			var point:=hand.lerp(target,flight)
			var points:=PackedVector2Array()
			for j in range(15):
				var q:float=j/14.0
				points.append(hand.lerp(point,q)+Vector2(0,sin(q*PI*2.0-progress*3.0)*5.0*sin(q*PI)*flight))
			_ink_trail(points,color,alpha,5.0,.42)
			for i in range(3):
				var flame:=point-Vector2(i*8,0)
				draw_colored_polygon(PackedVector2Array([flame+Vector2(-9,7),flame+Vector2(-5,-6-i*2),flame+Vector2(7,-2),flame+Vector2(12,1),flame+Vector2(-3,8)]),Color(color,alpha*(.9-i*.2)))
				draw_line(flame-Vector2(5,0),flame+Vector2(6,0),Color(1,.88,.55,alpha),2,true)
			if phase=="contact":
				for i in range(5):
					var direction:=Vector2.from_angle(float(i)/5.0*TAU)
					var burst:=target+direction*(8.0+progress*9.0)
					draw_line(burst-direction*4.0,burst+direction*5.0,Color(color,alpha*.8),3.2,true)
		elif technique=="stillness":
			var point:=hand.lerp(target,flight)
			for i in range(3):
				var center:=point-Vector2(i*10,0)
				var points:=PackedVector2Array()
				for j in range(25):
					var angle:float=-1.2+j*2.4/24.0
					points.append(center+Vector2(cos(angle)*7.0,sin(angle)*18.0)*(1.0-i*.15))
				_ink_trail(points,color,alpha*(1.0-i*.22),2.8,.50)
			_ink_trail(PackedVector2Array([hand,point]),color,alpha*.75,2.2,.45)
			# A contained blue qi core distinguishes an offensive water pulse
			# from the generic curved guard, without covering either body.
			var core=PackedVector2Array([point+Vector2(0,-6),point+Vector2(4,0),point+Vector2(0,6),point+Vector2(-4,0)])
			draw_colored_polygon(core,Color(color,alpha*.85))
			draw_circle(point,1.6,Color("eef8e7",alpha))
		elif style=="sword":
			# Sword arts also keep the visible blade clear. Spell screens belong
			# only to the actual barrier skill, never a generic steel swing.
			_draw_sword_edge_trace(feet,alpha*.92)
		else:
			# The equipped blade/fan pivot is the same hand used by the actual sprite.
			var grip:Dictionary=CharacterSidewalk.weapon_pose(side_motion,1.0,0.0,_attack_style())
			var pivot:Vector2=feet+Vector2(grip.offset)
			var rotation:float=float(grip.rotation)+(.22 if _attack_style()=="sword" else 0.0)
			var length:float=54.0 if _attack_style()=="sword" else (28.0 if _attack_style()=="fan" else 15.0)
			var tip:=pivot+Vector2(0,-length).rotated(rotation)
			var arc:=PackedVector2Array()
			if move=="mist_thrust":
				arc.append(pivot);arc.append(tip)
				# A short qi edge follows the real blade/finger rather than replacing it.
				var direction:Vector2=(tip-pivot).normalized()
				var extension:float=clampf((target-tip).dot(direction),0.0,28.0)*flight
				if extension>.25:arc.append(tip+direction*extension)
			else:
				for j in range(23):
					var angle:float=rotation-.95+float(j)/22.0*1.28
					arc.append(pivot+Vector2(0,-length).rotated(angle))
			_weapon_trail_in_front(arc,feet,color,alpha,3.5,.38 if technique=="petal" else 0.0)
			if technique=="petal":
				var ribbon:=PackedVector2Array()
				for j in range(21):
					var q:float=j/20.0
					ribbon.append(pivot.lerp(target,q*flight)+Vector2(0,sin(q*TAU-progress*2)*9.0*flight))
				_ink_trail(ribbon,color,alpha*.92,2.8,.45)
				for i in range(6):
					var q:float=fposmod(flight*.8+i*.13,1.0)
					_draw_petal(pivot.lerp(target,q)+Vector2(0,sin(q*TAU+i)*14.0),q*3.0,alpha,.75)
	# Independently sampled enemy lane can attack while the hero is recovering.
	var enemy_phase:=str(enemy.get("combat_phase","idle"))
	var enemy_move:=str(enemy.get("combat_move",""))
	var enemy_progress:=clampf(float(enemy.get("phase_progress",0.0)),0.0,1.0)
	if float(enemy.get("attack_amount",0.0))>.01 and enemy_phase in ["strike","contact"] and world_route not in ["bamboo_pass","cloud_slope"]:
		var origin:=_enemy_feet()+Vector2(enemy.get("visual_offset",Vector2.ZERO))+Vector2(-12,-50 if route_boss else -36)
		var aim:=body_feet+Vector2(15,-45)
		var flight:=enemy_progress if enemy_phase=="strike" else 1.0
		var alpha:float=.72 if enemy_phase=="strike" else .62*(1.0-enemy_progress)
		if "sweep" in enemy_move or "burst" in enemy_move:
			var trail:=PackedVector2Array()
			for j in range(21):
				var q:float=j/20.0*flight
				trail.append(origin.lerp(aim,q)+Vector2(0,-sin(q*PI)*(23.0 if "sweep" in enemy_move else 6.0)))
			_ink_trail(trail,Color("bca170"),alpha,3.4)
	# Contact bursts are sourced only from actual damage/guard events. A dodge
	# produces a travelling slash, never a fabricated hit flash on the target.
	for impact in combat_impacts:
		CombatImpact.draw(self,impact)
	var response:=str(hero.get("defense_action",""))
	var strength:=float(hero.get("reaction_amount",0.0))
	# Ordinary guard is only the physical arm/weapon response. Its one real
	# contact event already emitted localized metal sparks above. No dome.
	if response=="dodge" and str(hero.get("action_kind",""))=="weapon_art" and technique=="petal":
		for i in range(5):_draw_petal(body_feet+Vector2(15+i*8,-29+i*4),i*.7,strength*.85,.9)
	if show_combat_move_labels and not duel_pose.is_empty():
		var nameplate:=Rect2((feet.x+_enemy_feet().x)*.5-95,30,190,22)
		InkPaper.paint(self,nameplate,.78,"leaf",1.0)
		_center(str(duel_pose.get("telegraph","")),nameplate,11,Color("735943") if str(duel_pose.get("actor",""))=="enemy" else Color("4c6c59"))

func _draw_enemy_telegraph(p:Vector2,move:String,progress:float):
	var strength=.15+progress*.5
	var c=Color("b5905b")
	if "charge" in move:
		for i in range(3):
			var x=p.x-45-i*22
			draw_line(Vector2(x,p.y+3),Vector2(x+10,p.y-1),Color(c,strength*(1-i*.22)),1.6,true)
	elif "sweep" in move:
		var arc=PackedVector2Array()
		for i in range(25):
			var angle=PI*.55+i*PI*.9/24
			arc.append(p+Vector2(cos(angle)*84,sin(angle)*13+2))
		draw_polyline(arc,Color(c,strength),1.7,true)
	else:
		for i in range(8):
			var angle=i*TAU/8.0+progress
			draw_circle(p+Vector2(cos(angle)*(28-progress*13),sin(angle)*17-35),1.6,Color(c,strength))

## Read-only presentation of the simulator's current stone-shell state.
## No phase inference, independent clock, damage modifier, or state mutation.
func _stone_mechanic_view(p:Vector2) -> Dictionary:
	if not encounter_active or encounter_phase != "fight" or world_route != "creek_bridge": return {}
	if duel_pose.is_empty() or bool(duel_pose.get("finished", false)) or bool(duel_pose.get("cancelled", false)): return {}
	if float(duel_pose.get("enemy_hp", 0.0)) <= 0.0 or float(duel_pose.get("hero_hp", 0.0)) <= 0.0: return {}
	var mechanic:String = str(duel_pose.get("mechanic", ""))
	if mechanic not in ["river_shell", "river_exposed"]: return {}
	var shell:bool = mechanic == "river_shell"
	var beast_size:float = 174.0 if route_boss else 112.0
	# Beside, not over, the existing nameplate. The shared world transform
	# preserves scene proportions; the 14px text remains readable at 960px.
	var plate := Rect2(p + Vector2(72.0, -beast_size * 232.0 / 256.0 - 25.0), Vector2(76, 24))
	var mark_origin := p + Vector2(beast_size * .5 + 10.0, -beast_size * .55)
	var spread:float = 6.0 if shell else 11.0
	return {"id": mechanic, "text": "守壳" if shell else "露隙", "plate": plate,
		"color": Color("48616a") if shell else Color("87572f"), "mark_origin": mark_origin, "spread": spread}

func _draw_stone_mechanic(p:Vector2):
	var view:Dictionary = _stone_mechanic_view(p)
	if view.is_empty(): return
	var color:Color = view.color
	InkPaper.paint(self, view.plate, .96, "leaf", 1.0)
	_center(view.text, view.plate, 14, color)
	# Three local stone notches, close or separated. Not a body-wide shield.
	for i in range(3):
		var point:Vector2 = view.mark_origin + Vector2((i-1)*float(view.spread), abs(i-1)*3.0)
		draw_polyline(PackedVector2Array([point+Vector2(-3,-3), point+Vector2(3,-3), point+Vector2(4,2), point+Vector2(-2,3)]), Color(color,.8), 1.5, true)

func _draw_enemy_mechanic(p:Vector2,visual:Dictionary):
	if encounter_phase!="fight":return
	var kind:String=str(visual.get("effect_kind",""))
	if kind.is_empty() or world_route in ["bamboo_pass","cloud_slope"]:return
	var t:float=clampf(float(visual.get("effect_progress",visual.get("phase_progress",0.0))),0.0,1.0)
	var radius:float=float(visual.get("effect_radius",30.0))
	var phase:String=str(visual.get("combat_phase","idle"))
	var a:float=(.18+.35*sin(t*PI)) if phase=="windup" else .48*(1.0-t*.5)
	var feet:Vector2=Vector2(_world_x(character_x),_world_y((character_y+16.0)))+Vector2(float(CharacterSidewalk.approach_footwork(side_motion).root),0)
	if "ember" in kind or "erupt" in kind or "heat" in kind:
		for i in range(5):
			var q:float=i/4.0
			var base:Vector2=p+Vector2(-radius*(.3+q),1)
			var reach:float=(12.0+28.0*sin(q*PI))*sin(t*PI)
			draw_polyline(PackedVector2Array([base+Vector2(-5,0),base+Vector2(-3,-reach*.6),base+Vector2(2,-reach),base+Vector2(6,-reach*.2)]),Color(.83,.47,.20,a),1.5,true)
	elif "crane" in kind or "feather" in kind:
		for i in range(4):
			var progress:float=clampf(t*1.3-i*.08,0.0,1.0)
			var plume:Vector2=p+Vector2(-22.0-progress*(55.0+i*9),-68.0+i*12+sin(progress*PI)*18)
			draw_line(plume+Vector2(6,-3),plume+Vector2(-6,3),Color(.77,.82,.83,a),1.5,true)
			draw_line(plume,plume+Vector2(3,4),Color(.69,.76,.75,a*.7),1,true)
	elif "moon" in kind or "veil" in kind:
		draw_arc(p+Vector2(0,-55),maxf(25.0,radius),-.9,PI*1.55,36,Color(.65,.76,.85,a),1.4,true)
		for i in range(4):
			var angle:float=i*TAU/4+t
			draw_circle(p+Vector2(cos(angle)*radius,sin(angle)*radius*.6-50),2,Color(.76,.81,.91,a*.8))
	elif "seal" in kind or "summit" in kind:
		var center:Vector2=p.lerp(feet,.6)+Vector2(0,-25)
		var rr:float=17.0+radius*.28*t
		var diamond=PackedVector2Array([center+Vector2(0,-rr),center+Vector2(rr*.8,0),center+Vector2(0,rr),center+Vector2(-rr*.8,0),center+Vector2(0,-rr)])
		draw_polyline(diamond,Color(.75,.64,.34,a),1.6,true)
		draw_arc(center,rr*.55,0,TAU,32,Color(.80,.70,.42,a*.7),1,true)
	elif "armor" in kind or "tide" in kind:
		draw_arc(p+Vector2(-10,-37),maxf(23,radius),PI*.65,PI*1.6,26,Color(.45,.66,.69,a),1.8,true)
	elif "stomp" in kind:
		for i in range(2):draw_arc(p+Vector2(-radius*t,2),radius*(.4+t*.6)+i*8,0,PI,24,Color(.62,.64,.39,a*(1-i*.3)),1.3,true)

func _draw_route_opportunity(_feet:Vector2):
	var p:=_route_landmark_feet(ROUTE_HERO_X+route_opportunity_at+130.0)
	if p.x < -100 or p.x > size.x+100:return
	if beast_assets.has("cairn"):
		draw_texture_rect(beast_assets.cairn,Rect2(p-Vector2(48,87),Vector2(96,96)),false,Color(1,1,1,_route_reveal()))
	if encounter_phase!="opportunity":return
	for i in range(7):
		var t=fposmod(elapsed*.15+i*.17,1.0)
		draw_circle(p+Vector2(sin(i*2.4)*22,-18-t*44),1.3,Color(.85,.80,.51,sin(t*PI)*.7))
	var plate=Rect2(p+Vector2(-62,-104),Vector2(124,24))
	InkPaper.paint(self,plate,.92,"leaf",1.0);_center(str(state.opportunity_status().get("name","山间机缘"))+" · 点此回应",plate,10,INK)
	_text("此缘常留",p+Vector2(-24,22),10,Color("667862"),SERIF)

func _draw_encounter(feet:Vector2):
	if encounter_active and encounter_phase in ["travel","fight","pickup"]:
		var enemy_visual:Dictionary=defeat_enemy_motion.duplicate(true) if encounter_phase=="pickup" else duel_pose.get("enemy",{})
		if encounter_phase=="pickup":enemy_visual.combat_phase="defeated";enemy_visual.defeat_amount=enemy_defeat
		var phase:=str(enemy_visual.get("combat_phase","idle"))
		var enemy_move:=str(enemy_visual.get("combat_move",""))
		var attacking:=encounter_phase=="fight" and float(enemy_visual.get("attack_amount",0.0))>.01 and phase in ["strike","contact"]
		var winding:=encounter_phase=="fight" and float(enemy_visual.get("attack_amount",0.0))>.01 and phase=="windup"
		var key=enemy_kind+("_attack" if attacking else "_idle")
		var authored_pose:String=str(enemy_visual.get("pose_key","attack" if attacking else ("windup" if winding else "idle")))
		if authored_pose=="recovery":authored_pose="idle"
		var route_key=world_route+("_boss" if route_boss and beast_assets.has(world_route+"_boss_idle") else "")+"_"+authored_pose
		if not beast_assets.has(route_key):route_key=world_route+("_attack" if attacking else "_idle")
		var texture:Texture2D=beast_assets.get(route_key,encounter_assets.get(key,null))
		var native_beast=beast_assets.has(route_key)
		var p=_enemy_feet()
		var corpse_fade=clampf((encounter_phase_age-pickup_claimed_at-2.0)/1.0,0.0,1.0) if pickup_claimed_at>=0.0 and encounter_phase=="pickup" else 0.0
		var retreat_alpha=1.0
		var lunge=float(enemy_visual.get("actor_lunge",0.0))
		var recoil=sin(enemy_flash*PI)*5.0
		# Encounter sprites share source shapes with wilderness fauna, but carry
		# ochre pigment, a hostile nameplate and a red health track; the pet is separate.
		var beast_size=174.0 if route_boss else 112.0
		var reaction:Dictionary=duel_pose.get("enemy",{})
		var dodge=15.0*float(reaction.get("reaction_amount",0.0)) if str(reaction.get("defense_action",""))=="dodge" else 0.0
		var offset:Vector2=enemy_visual.get("visual_offset",Vector2(-lunge+recoil+dodge,0))
		var rotation:float=float(enemy_visual.get("visual_rotation",0.0))
		if texture:
			var rendered:bool=false
			if encounter_phase=="pickup":
				rendered=CorpsePresentation.draw(self,beast_assets,world_route,route_boss,p,beast_size,enemy_defeat,corpse_fade)
			if not rendered and world_route in ["bamboo_pass","cloud_slope"]:
				var rendered_motion:=enemy_visual.duplicate(true)
				rendered_motion.visual_offset=offset+Vector2(0,enemy_defeat*8)
				rendered_motion.defeat_amount=enemy_defeat
				rendered=MonsterPoseRenderer.draw(self,beast_assets,route_key,p,beast_size,rendered_motion,Color(1,1,1,retreat_alpha))
			if not rendered:_draw_beast(texture,route_key,p,beast_size,Color(1.0+enemy_flash*.2,1.0,1.0,retreat_alpha),rotation,offset+Vector2(0,enemy_defeat*8))
		if encounter_phase!="pickup":
			_draw_enemy_mechanic(p,enemy_visual)
			_draw_stone_mechanic(p)
		if winding and world_route not in ["bamboo_pass","cloud_slope"]:_draw_enemy_telegraph(p,enemy_move,float(enemy_visual.get("phase_progress",0.0)))
		if encounter_phase!="pickup":
			draw_rect(Rect2(p+Vector2(-33,10),Vector2(66,3)),Color(.30,.41,.31,.23))
			draw_rect(Rect2(p+Vector2(-33,10),Vector2(66*enemy_hp/enemy_max_hp,3)),Color("a97051"))
			var nameplate=Rect2(p+Vector2(-67,-beast_size*232.0/256.0-23),Vector2(134,19))
			InkPaper.paint(self,nameplate,.88,"leaf",1.0)
			_center(("镇关 · " if route_boss else "精怪 · ")+encounter_enemy_name,nameplate,10,Color("775039"))
			_text("%d / 3"%(encounter_index+1),p+Vector2(-13,28),10,Color("667862"),SERIF)
		if combat_number_time>0:_text(combat_number,p+Vector2(1,-104-(.8-combat_number_time)*18),16,Color(.98,.98,.8,combat_number_time/.8),LATIN)
		if encounter_phase=="pickup":_draw_search_feedback(feet,p)
	feet+=Vector2(float(CharacterSidewalk.approach_footwork(side_motion).root),0)
	if encounter_active:
		var status=str({"travel":"循径", "fight":"交锋", "pickup":("材料入囊" if pickup_claimed_at>=0.0 else ("搜寻" if pickup_collect_started>=0.0 else "走近倒地守灵")), "opportunity":"待你回应", "teleport_return_out":"归山", "teleport_home_in":"归山"}.get(encounter_phase,"传送"))
		_text(status+" · "+encounter_stage_name,Vector2(155,size.y-23),11,Color("566a59"),SERIF)
		draw_line(feet+Vector2(-24,13),feet+Vector2(24,13),Color(.30,.41,.31,.15),2,true)
		draw_line(feet+Vector2(-24,13),feet+Vector2(-24+48*vitality/maxf(1.0,vitality_max),13),Color(.52,.64,.47,.65),2,true)
	if hero_hit>0 and encounter_active:
		_text("闪避 0" if hero_resolution=="dodge" else ("护盾" if hero_resolution=="shield" else (("格挡 " if hero_resolution=="guard" else "")+"−%d"%hero_damage)),feet+Vector2(-44,-72-(1-hero_hit)*15),12,Color(.82,.55,.39,hero_hit),SANS)
	if hero_support_time>0 and encounter_active:
		var support_alpha:float=minf(1.0,hero_support_time/.25)
		if hero_support_text=="卸力 · 反击":
			var response_plate:=Rect2(feet+Vector2(-83,-126),Vector2(95,23))
			InkPaper.paint(self,response_plate,support_alpha*.92,"leaf",1.0)
			_center(hero_support_text,response_plate,11,Color(Color("486951"),support_alpha))
		else:_text(hero_support_text,feet+Vector2(-20,-88-(.9-hero_support_time)*12),11,Color(.37,.59,.38,support_alpha),SANS)
	if pickup_burst>0:
		for i in range(8):
			var angle=i*TAU/8.0
			draw_circle(feet+Vector2(cos(angle)*22,sin(angle)*11-30)*(1.0+(1-pickup_burst)*.4),1.5,Color(.83,.77,.44,pickup_burst*.6))
	if chest_time>0:
		var texture:Texture2D=encounter_assets.get("chest_open",null)
		var reveal=smoothstep(0.0,.35,chest_reveal_age)
		if texture:_fit_texture(texture,Rect2(feet+Vector2(90,-78+(1.0-reveal)*6),Vector2(88,88)*(.92+.08*reveal)),Color(1,1,1,minf(1,chest_time)*reveal))

func _draw_search_feedback(feet:Vector2,p:Vector2):
	# Keep the fallen silhouette visible. A quiet, ground-side label carries
	# the search clock; the receipt sits beyond the body, never over its head.
	var plate:=Rect2(p+Vector2(146,-83),Vector2(234,83))
	if pickup_claimed_at<0.0:
		var progress:=float(pickup_status.get("search_progress",0.0))
		var searching:bool=pickup_collect_started>=0.0
		var status_plate:=Rect2(p+Vector2(146,-32),Vector2(174,31))
		InkPaper.paint(self,status_plate,.89,"leaf",1.0)
		var label:String="搜寻 %.1f / 2.0秒"%float(pickup_status.get("search_seconds",0.0)) if searching else "已倒地 · 走近搜寻"
		if not pickup_block_reason.is_empty():label="已搜满 · 册中亲点收取"
		_text(label,status_plate.position+Vector2(9,16),10,Color("586e52"),SANS)
		if searching:
			draw_line(status_plate.position+Vector2(9,24),status_plate.position+Vector2(164,24),Color(.43,.52,.38,.20),2,true)
			draw_line(status_plate.position+Vector2(9,24),status_plate.position+Vector2(9+155*progress,24),Color(.43,.61,.42,.90),2,true)
		return
	var age:float=encounter_phase_age-pickup_claimed_at
	var reveal:=minf(1.0,age/.20)
	InkPaper.paint(self,plate,reveal*.96,"leaf",1.0)
	_text("搜寻所得 · 已入行囊",plate.position+Vector2(12,21),13,Color(Color("475f49"),reveal),SERIF)
	var lines:Array[String]=[]
	for row in state.material_rows():
		var amount:int=int(encounter_reward.get("materials",{}).get(str(row.id),0))
		if amount>0:lines.append(str(row.name)+" ×%d"%amount)
	if int(encounter_reward.get("chests",0))>0:lines.append("木箱 ×1")
	var item:Variant=encounter_reward.get("item")
	if item is Dictionary and not item.is_empty():lines.append(str(item.get("name","装备")))
	_text(" · ".join(lines),plate.position+Vector2(12,42),10,Color(Color("5d7156"),reveal),SANS)
	_text("灵草 +%d · 晨露 +%d · 灵气 +%d"%[int(encounter_reward.get("herbs",0)),int(encounter_reward.get("dew",0)),int(encounter_reward.get("qi",0))],plate.position+Vector2(12,59),9,Color(Color("81846e"),reveal),SANS)
	_text("行囊 → 百工：合成 / 制作 / 淬炼",plate.position+Vector2(12,76),10,Color(Color("a06d43"),reveal),SANS)
	# A small material pouch moves into the searching hand only after the real
	# receipt commits. The opaque body remains for another two seconds.
	if age<.65:
		var t:=smoothstep(0.0,.65,age)
		var hand:=feet+CharacterSidewalk.attachment_offset(Vector2(318,414),side_motion)
		var from:=p+Vector2(-12,-20)
		var point:=from.lerp(hand,t)+Vector2(0,-sin(t*PI)*18)
		draw_colored_polygon(PackedVector2Array([point+Vector2(-7,-2),point+Vector2(-5,8),point+Vector2(6,8),point+Vector2(8,-2),point+Vector2(2,-5)]),Color(.61,.53,.34,1.0-t*.7))
		draw_line(point+Vector2(-5,-2),point+Vector2(5,-2),Color(.87,.80,.54,1.0-t),1.5,true)

func _capture_now():
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path("res://builds/MountainStill-equipment-preview.png"))

func _reset_presentation():
	paused_retreat_run_id=-1
	CapacityPages.clear(self);set_meta("capacity_corpse_hold",{})
	set_meta("ink_journal_tab","guide");set_meta("ink_stage_id","bamboo_pass");set_meta("ink_stage_page",0);set_meta("ink_guide_step",1);set_meta("expedition_view","route")
	battle_resources={};hero_support_text="";hero_support_time=0.0
	if is_instance_valid(character_preview):character_preview.cast_time=0.0
	encounter_active=false;encounter_phase="idle";pickup_status={};pickup_claimed_at=-1.0;pickup_collect_started=-1.0;world_route="";route_distance=0;route_scroll_velocity=0;route_frame_velocity=0;combat_impacts.clear();duel.cancel();duel_pose={};portal_dissolve=0;practice_time=0;expedition_wait=0;chest_time=0;selected_item=-1;selected_slot="chest";inventory_page=0;last_loot={};paused=false;vitality=100;cast_blend=0;breakthrough_glow=0;completed_presented=false;meditation_amount=0;meditation_settle=0;meditation_phase="standing";walker=CharacterWalk.new();walk_motion={"phase":0.0,"blend":0.0,"facing":1.0,"bob":0.0,"body_tilt":0.0}

func _capture_window_settings():
	state.settings.window_mode="strip" if strip else "window"
	state.settings.paused=paused
	desktop.capture_settings(state.settings)

func _save_current()->bool:
	if practice_session != null: return false
	if get_meta("update_transaction", false):return false
	_persist_battle_resources()
	_capture_window_settings()
	return state.save_game()

func _set_paused(value:bool):
	if practice_session != null: return
	_persist_battle_resources()
	paused=value
	if not value:paused_retreat_run_id=-1
	state.settings.paused=value
	_save_loadout()

func _draw_companion(r:Rect2):
	if encounter_active or not world_route.is_empty():return
	var info:Dictionary=state.journey_status()
	var texture:Texture2D=encounter_assets.get("fox_idle",null)
	var p=Vector2(_world_x(686),r.position.y+r.size.y*(252 if _diorama_active() else 238)/280.0)
	if bool(info.get("active",false)):
		# A little travelling knot marks the companion's place while away.
		draw_line(p+Vector2(-8,-7),p+Vector2(8,-7),Color(.44,.51,.35,.6),1.5,true)
		draw_colored_polygon(PackedVector2Array([p+Vector2(0,-19),p+Vector2(8,-8),p+Vector2(0,2),p+Vector2(-8,-8)]),Color(.58,.48,.31,.55))
		_text("游历中",p+Vector2(-18,14),9,Color(.34,.44,.32,.8),SERIF)
	elif texture:
		_fit_texture(texture,Rect2(p+Vector2(-33,-59+sin(elapsed*1.2)*.5),Vector2(66,66)),Color(1,1,1,.96))

func _prepare_campaign_demo():
	# Clearly disclosed review fixture, never loaded or written as a real save.
	state.realm=14 if "--chapter-ending" in OS.get_cmdline_user_args() else 9
	state.herbs=240;state.dew=80;state.auto_advance=false
	state.qi=float(state.QI_COSTS[state.realm])-60.0
	state.lifetime_seconds=28400.0
	state.technique_levels={"mist":3,"petal":3,"ember":3,"stillness":3}
	state.pill_stocks={"qi":3,"spring":2,"clarity":2}
	state.technique="petal"
	var items:Array=[]
	var i=1
	for template_id in state.gear.TEMPLATES:
		items.append({"id":i,"template_id":template_id,"rarity":"rare" if i%3==0 else "uncommon","level":10,"enhancement":1})
		i+=1
	state.gear.load_data({"inventory":items,"equipped":{"head":1,"chest":4,"legs":5,"feet":8,"weapon":10},"chests":3,"starter_chest_unopened":false})
	state.quest_claimed={}
	for quest in state.Content.QUESTS:
		if quest.id!="home":state.quest_claimed[quest.id]=true
	state.counters={"gathered":1200,"brewed":15,"pills_used":10,"chests_opened":15,"techniques_trained":11,"enhanced":10}
	state.journey_bond=28;state.journey_completed=14
	state.discoveries={"bamboo_leaf":true,"pine_cone":true,"moon_pebble":true,"stream_crystal":true,"cloud_feather":true}
	state.start_journey("ridge",false);state.journey.remaining=16.0
	state.journal_entries=[{"text":"预置进度演示：用于展示已解锁内容，不代表自然挂机时长。","time":28400.0}]
	selected_item=4;selected_slot="chest";inventory_page=1

func _preview_stage_active()->bool:
	return drawer_name in ["wardrobe","alchemy","practice"]

func _preview_stage_x()->float:
	return (_drawer_rect().position.x*.5)/size.x*1040.0

func _preview_stage_scale()->float:
	return minf(1.82,(_drawer_rect().position.x-40.0)/124.0) if _preview_stage_active() else 1.0

func _sync_character_preview(delta:float):
	var active=_preview_stage_active()
	preview_blend=move_toward(preview_blend,1.0 if active else 0.0,delta/(.46 if active else .28))
	if not is_instance_valid(character_preview):return
	# Preserve its own last rectangle while fading away beside a narrower settings leaf.
	if active or preview_blend<=0.0:
		var left=size.x-758.0
		character_preview.position=Vector2(12,14)
		character_preview.size=Vector2(maxf(160.0,left-24.0),278.0)
	character_preview.reveal=smoothstep(0.0,1.0,preview_blend)
	character_preview.visible=preview_blend>0.0
	character_preview.advance(delta,active)

func _scene_camera_transform()->Transform2D:
	# Kept as an explicit invariant for regression: opening UI never reframes the world.
	return Transform2D.IDENTITY

func _scene_set_transform(origin:Vector2=Vector2.ZERO,rotation:float=0.0,scale_value:Vector2=Vector2.ONE):
	draw_set_transform(origin,rotation,scale_value)

func _setup_portal_projection():
	portal_viewport=SubViewport.new();portal_viewport.size=Vector2i(192,184);portal_viewport.transparent_bg=true
	portal_viewport.disable_3d=true;portal_viewport.gui_disable_input=true;portal_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED
	portal_viewport.handle_input_locally=false;add_child(portal_viewport)
	portal_projection=CharacterProjection.new();portal_projection.host=self
	portal_material=ShaderMaterial.new();portal_material.shader=PortalShader;portal_projection.material=portal_material
	portal_viewport.add_child(portal_projection)

func _portal_active()->bool:
	return encounter_active and encounter_phase in ["teleport_out","teleport_arrive","teleport_return_out","teleport_home_in"]

func _route_reveal()->float:
	if encounter_phase in ["teleport_out","teleport_return_out"]:return 1.0-smoothstep(1.18,1.6,encounter_phase_age)
	if encounter_phase in ["teleport_arrive","teleport_home_in"]:return smoothstep(0.0,.34,encounter_phase_age)
	return 1.0

func _update_portal(_delta:float):
	var outgoing=encounter_phase in ["teleport_out","teleport_return_out"]
	portal_dissolve=smoothstep(.50,1.35,encounter_phase_age) if outgoing else 1.0-smoothstep(.24,1.08,encounter_phase_age)
	portal_material.set_shader_parameter("dissolve",portal_dissolve)
	portal_viewport.render_target_update_mode=SubViewport.UPDATE_ALWAYS;portal_projection.queue_redraw()
	if outgoing and encounter_phase_age>=1.6:
		if encounter_phase=="teleport_out":
			world_route=str(state.stage_status().id);character_x=ROUTE_HERO_X;encounter_phase="teleport_arrive"
		else:
			world_route="";character_x=520.0;encounter_phase="teleport_home_in"
		character_y=230.0;encounter_phase_age=0.0;_build_nav()
	elif not outgoing and encounter_phase_age>=1.35:
		portal_viewport.render_target_update_mode=SubViewport.UPDATE_DISABLED;portal_dissolve=0.0
		if encounter_phase=="teleport_arrive":_prepare_stage_monster()
		else:
			encounter_active=false;encounter_phase="idle";paused_retreat_run_id=-1
			if encounter_complete:
				var ending:Dictionary=state.chapter_status()
				if bool(ending.get("story_resolved",false)):_notice("六印归一 · 山路已解结，札记中可读归山尾声。","level")
				elif encounter_first_clear:
					var learned:Array=encounter_chapter_reward.get("recipe_unlocks",[])
					var recipe_hint:String=" · 百工新法："+"、".join(learned) if not learned.is_empty() else ""
					if bool(encounter_chapter_reward.get("ok",false)):_notice("此章已解 · "+encounter_stage_name+" · 首通赠礼已入行囊"+recipe_hint,"loot")
					else:_notice("此章已解 · 首通赠礼保留待领"+recipe_hint,"loot")
				else:_notice("此程已毕 · "+encounter_stage_name+" · 回山静修","loot")
			_save_loadout();_refresh_drawer()

func _draw_portal(feet:Vector2,foreground:bool):
	var outgoing=encounter_phase in ["teleport_out","teleport_return_out"]
	var duration=1.6 if outgoing else 1.35
	var t=clampf(encounter_phase_age/duration,0.0,1.0)
	var strength=sin(t*PI)*.80
	if not foreground:
		for ring in range(3):
			var points=PackedVector2Array()
			var radius=24+ring*10+sin(t*PI)*4
			for i in range(65):
				var a=i*TAU/64.0
				points.append(feet+Vector2(cos(a)*radius,sin(a)*radius*.25+3))
			draw_polyline(points,Color(.64,.77,.66,strength*(.65-ring*.11)),1.3,true)
		for i in range(8):
			var angle=i*TAU/8.0+t*.5
			var a=feet+Vector2(cos(angle)*30,sin(angle)*7.5+3)
			var b=feet+Vector2(cos(angle)*42,sin(angle)*10.5+3)
			draw_line(a,b,Color(.84,.78,.47,strength*.65),1.2,true)
		return
	for i in range(28):
		var q=fposmod(t+i*.137,1.0)
		var x=sin(i*2.399+t*5)*(9+q*27)
		var y=-q*128
		var p=feet+Vector2(x,y)
		var opacity=strength*sin(q*PI)*.75
		draw_circle(p,1.2+(i%3)*.35,Color(.88,.84,.57,opacity))
		if i%4==0:draw_line(p+Vector2(0,5),p+Vector2(0,-3),Color(.73,.82,.68,opacity*.4),1,true)

var update_panel: AcceptDialog
func _open_updates():
	if not is_instance_valid(update_panel):
		update_panel = preload("res://scripts/release_panel.gd").new()
		add_child(update_panel)
		update_panel.setup(self)
	update_panel.popup_centered()

func _apply_hot_content(data: Dictionary) -> void:
	if data.is_empty():
		return
	GOLD = Color(data.accent)
	content_accent = Color(GOLD, .65)
	queue_redraw()
	if not drawer_name.is_empty():
		_refresh_drawer()
	_notice(str(data.message))


func _record_combat_report(outcome: String) -> void:
	if practice_session != null: return
	if combat_report_saved or encounter_phase != "fight": return
	combat_report_saved = true
	var report: Dictionary = duel.combat_report()
	report.merge({"outcome": outcome, "stage_name": encounter_stage_name, "enemy_name": str(route_enemy_definition.get("name", "守灵"))}, true)
	state.record_combat_report(report)
