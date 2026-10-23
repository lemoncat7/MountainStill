extends RefCounted
## Presentation adapter. Formal state is read only; never invokes adventure APIs.
const Session = preload("res://scripts/practice_session.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const FIELDS := ["duel", "paused", "encounter_active", "encounter_phase", "encounter_phase_age", "encounter_clock", "world_route", "route_distance", "route_scroll_velocity", "route_frame_velocity", "route_boss", "encounter_index", "encounter_enemy_x", "encounter_enemy_name", "encounter_stage_name", "encounter_enemy_attack", "encounter_enemy_defense", "enemy_hp", "enemy_max_hp", "enemy_flash", "enemy_defeat", "vitality", "vitality_max", "duel_pose", "side_motion", "walk_motion", "character_x", "character_y", "meditation_amount", "meditation_settle", "meditation_phase", "practice_time", "cast_blend", "combat_impacts", "combat_hitstop", "hero_hit", "combat_number_time", "combat_number", "duel_resolution", "hero_resolution", "hero_damage", "hero_support_text", "hero_support_time", "route_enemy_definition"]

static func rows(h) -> Array:
	var result: Array = []
	for route in h.state.stage_rows():
		var id: String = str(route.id)
		if not bool(route.unlocked):
			result.append({"id": "locked:" + id, "stage_id": id, "stage_name": str(route.name), "name": "尚未踏足", "unlocked": false, "locked_reason": str(route.locked_reason)})
			continue
		var enemies: Array = Content.STAGES[id].monsters
		for index in range(enemies.size()):
			var row: Dictionary = enemies[index].duplicate(true)
			row.merge({"stage_id": id, "stage_name": str(route.name), "index": index, "unlocked": true})
			result.append(row)
	return result

static func blocked(h) -> String:
	if h.practice_session != null: return "请先结束当前试招。"
	if h.encounter_active or not h.world_route.is_empty() or not h.state.stage_run.is_empty(): return "请先结束或放弃未完成的历练，再在山居试招。"
	if not h.state.pending_heart_switch.is_empty(): return "心法调息完成后才可试招。"
	if h.get_meta("update_transaction", false) or h.closing: return "当前正在保存或更新，请稍后再试。"
	for dialog in [h.tip, h.reset_dialog, h.salvage_dialog]:
		if is_instance_valid(dialog) and dialog.visible: return "请先关闭当前确认窗口。"
	return ""

static func start(h, enemy_id: String) -> bool:
	if h.practice_session != null:
		if not bool(h.practice_session.status().get("finished", false)): return false
		finish(h)
	var reason: String = blocked(h)
	if not reason.is_empty(): h._notice(reason); return false
	var enemy: Dictionary = {}
	for row in rows(h):
		if str(row.id) == enemy_id and bool(row.unlocked): enemy = row; break
	if enemy.is_empty(): h._notice("此敌情尚未开放。"); return false
	var hero: Dictionary = h.state.stats().duplicate(true)
	hero.technique_level = int(h.state.technique_levels.get(h.state.technique, 1))
	enemy.route_id = str(enemy.stage_id)
	enemy.engagement_distance = 120.0 if bool(enemy.get("boss", false)) else 88.0
	var key: String = str(enemy.stage_id) + ("_boss" if bool(enemy.get("boss", false)) else "") + "_attack"
	enemy.enemy_front_extent = maxf(24.0, -h.BeastPresentation.visible_bounds(key, 174.0 if bool(enemy.get("boss", false)) else 112.0).position.x)
	var session = Session.new()
	if not bool(session.start(hero, enemy, str(h.state.technique), h._attack_style(), 17).get("ok", false)): return false
	h._close_drawer()
	h.practice_snapshot.clear()
	for field in FIELDS:
		var value = h.get(field)
		h.practice_snapshot[field] = value.duplicate(true) if value is Dictionary or value is Array else value
	h.practice_comparison = h.practice_previous_reports.get(enemy_id, {}).duplicate(true)
	h.practice_session = session
	h.desktop.set_passthrough(false)
	h.set_meta("practice_enemy_id", enemy_id)
	h.duel = session.duel
	h.encounter_active = true; h.encounter_phase = "fight"; h.encounter_phase_age = 0.0; h.encounter_clock = 0.0
	h.world_route = str(enemy.stage_id); h.route_distance = 0.0; h.route_scroll_velocity = 0.0; h.route_frame_velocity = 0.0
	h.route_boss = bool(enemy.get("boss", false)); h.encounter_index = int(enemy.index)
	h.character_x = 470.0; h.character_y = 230.0; h.encounter_enemy_x = h.character_x + float(enemy.engagement_distance)
	h.encounter_stage_name = "镜中试招 · " + str(enemy.stage_name)
	h.encounter_enemy_name = str(enemy.name); h.route_enemy_definition = enemy.duplicate(true)
	h.enemy_hp = float(enemy.hp); h.enemy_max_hp = float(enemy.hp); h.enemy_flash = 0.0; h.enemy_defeat = 0.0
	h.vitality_max = float(hero.get("max_hp", 100)); h.vitality = h.vitality_max
	h.meditation_amount = 0.0; h.meditation_settle = 0.0; h.meditation_phase = "standing"; h.practice_time = 0.0
	h.cast_blend = 0.0; h.combat_impacts.clear(); h.combat_hitstop = 0.0; h.hero_hit = 0.0; h.combat_number_time = 0.0; h.hero_support_time = 0.0
	h.duel_pose = session.pose(); h.side_motion = {"facing": 1.0, "blend": 0.0, "phase": 0.0}; h.side_motion.merge(h.duel_pose.get("hero", {}), true)
	if is_instance_valid(h.character_preview): h.character_preview.visible = false
	controls(h)
	return true

static func controls(h):
	if is_instance_valid(h.practice_controls): h.practice_controls.queue_free()
	h.practice_controls = Control.new(); h.practice_controls.mouse_filter = Control.MOUSE_FILTER_IGNORE; h.add_child(h.practice_controls)
	h._qbutton(h.practice_controls, "practice_live_pause", "继续试招" if bool(h.practice_session.status().get("paused", false)) else "暂停试招", Rect2(24, 18, 112, 30), h.toggle_practice_pause, "仅暂停镜中战斗，正式山居始终冻结")
	h._qbutton(h.practice_controls, "practice_live_end", "结束试招", Rect2(146, 18, 112, 30), h.end_practice, "退出无奖励试招；Esc 也可结束")
	h.practice_controls.visible = h.drawer_name.is_empty()
	lock_controls(h)

static func lock_controls(h):
	for key in h.buttons:
		var button = h.buttons[key]
		if not is_instance_valid(button): continue
		if button is BaseButton and not str(key).begins_with("practice_"): button.disabled = true

static func advance(h, delta: float):
	var was_finished: bool = bool(h.practice_session.status().get("finished", false))
	var step: float = 0.0 if bool(h.practice_session.status().get("paused", false)) else delta
	if step > 0.0 and h.combat_hitstop > 0.0:
		var held: float = minf(step, h.combat_hitstop)
		h.combat_hitstop = maxf(0.0, h.combat_hitstop - held)
		step -= held
	h.enemy_flash = maxf(0.0, h.enemy_flash - step * 3.0)
	h.hero_hit = maxf(0.0, h.hero_hit - step * 2.5)
	h.combat_number_time = maxf(0.0, h.combat_number_time - step)
	h.hero_support_time = maxf(0.0, h.hero_support_time - step)
	for impact in h.combat_impacts: impact.age = float(impact.age) + step
	h.combat_impacts = h.combat_impacts.filter(func(impact: Dictionary) -> bool: return float(impact.age) < float(impact.get("profile", {}).get("duration", .38)))
	for event in h.practice_session.advance(step):
		if str(event.get("type", "")) == "contact": h._present_duel_contact(event)
	h.duel_pose = h.practice_session.pose()
	h.side_motion = {"facing": 1.0, "blend": 0.0, "phase": 0.0}; h.side_motion.merge(h.duel_pose.get("hero", {}), true)
	var report: Dictionary = h.practice_session.report()
	h.vitality = float(report.get("hero_hp", h.vitality)); h.enemy_hp = float(h.duel.enemy_hp)
	h.encounter_clock = float(report.get("elapsed", 0.0))
	h.interface_clock += delta; h.toast_age += delta; h.toast_time = maxf(0.0, h.toast_time - delta)
	h._sync_drawer_visuals()
	if is_instance_valid(h.practice_controls): h.practice_controls.visible = h.drawer_name.is_empty()
	if not was_finished and bool(h.practice_session.status().get("finished", false)):
		h.drawer_name = "wardrobe"; h.drawn_page = "wardrobe"; h.wardrobe_tab = "equipment"
		h.set_meta("combat_insight_open", true); h.set_meta("combat_insight_view", "enemies")
		h._refresh_drawer(true)
		if is_instance_valid(h.practice_controls): h.practice_controls.visible = false
	if h.size != h.last_size:
		h.last_size = h.size; h._refresh_drawer()
	h.queue_redraw()

static func finish(h):
	if h.practice_session == null: return
	if bool(h.practice_session.status().get("finished", false)) and str(h.practice_session.status().get("outcome", "")) in ["victory", "defeat", "timeout"]:
		h.practice_previous_reports[str(h.get_meta("practice_enemy_id", ""))] = h.practice_session.report()
	h.practice_session.cancel()
	h.practice_session = null
	for field in h.practice_snapshot: h.set(field, h.practice_snapshot[field])
	h.practice_snapshot.clear()
	if is_instance_valid(h.practice_controls): h.practice_controls.queue_free()
	h.practice_controls = null
	h.desktop.set_passthrough(false)
	h._build_nav()
	h.drawer_name = "wardrobe"; h.drawn_page = "wardrobe"; h.wardrobe_tab = "equipment"
	h.set_meta("combat_insight_open", true); h.set_meta("combat_insight_view", "enemies")
	h._refresh_drawer(true); h.queue_redraw()
