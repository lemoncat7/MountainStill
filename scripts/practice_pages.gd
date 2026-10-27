extends RefCounted
## Read-only canonical enemy notes and an explicitly reward-free local mirror.
## All start eligibility is rechecked by the host, not trusted from stale controls.
const Loadout = preload("res://scripts/practice_loadout.gd")
const EnemyModule = preload("res://scripts/combat_modules/enemy_attack_module.gd")
const Registry = preload("res://scripts/attack_module_registry.gd")
const BODY := 14
const NOTE := 12
static var _notes_cache: Dictionary = {}

static func _rows(h) -> Array:
	return h.practice_enemy_rows()

static func _page(h, rows: Array) -> int:
	return clampi(int(h.get_meta("practice_enemy_page", 0)), 0, maxi(0, rows.size() - 1))

static func _status(h) -> Dictionary:
	return {} if h.practice_session == null else h.practice_session.status()

static func _active(h) -> bool:
	return h.practice_session != null

static func _report(h) -> Dictionary:
	return {} if h.practice_session == null else h.practice_session.report()

static func notes(row: Dictionary) -> Array[String]:
	if not bool(row.get("unlocked", false)): return ["尚未开放此山路。", "解锁后可查看守灵与尝试当前搭配。"]
	var key := hash(row)
	if _notes_cache.has(key): return _notes_cache[key].duplicate()
	var module_id := str(row.get("attack_module_id", ""))
	var species := module_id.trim_prefix("enemy.")
	var profile: Dictionary = EnemyModule.PROFILES.get(species, {})
	if profile.is_empty(): return ["暂无已核验的招式说明。", "试招使用实际战斗引擎，不提供胜率预测。"]
	var binding = Registry.default_registry().bind(module_id, {"enemy": row})
	var action: Dictionary = binding.select_action({"enemy": row, "action_index": 0, "roll": 0.5})
	var opening := "常见起手：%s · 蓄势%.2f秒" % [str(action.get("label", "蓄势")), float(action.get("windup", 0.0))]
	var mechanic := "根据实际招式轮转；格挡、闪避均非必定。"
	if bool(profile.get("shell_cycle", false)): mechanic = "石甲轮换：受击伤害倍率在0.90与1.12间变化。"
	elif bool(profile.get("landing_vulnerable", false)): mechanic = "行动后落地易受击；连啄多段，空中更易闪避。"
	elif bool(profile.get("weighted", false)): mechanic = "按距离与体力择招；近处扑击，拉远更偏向冲撞。"
	elif species == "ember_guardian": mechanic = "余烬末段穿透部分防御；首领半血后会觉醒。"
	elif species == "moon_wisp": mechanic = "连击分多段结算；首领半血后会觉醒。"
	elif species == "summit_keeper": mechanic = "镇击削弱格挡减伤；首领半血后会觉醒。"
	var result: Array[String] = [opening, mechanic]
	if _notes_cache.size() >= 128: _notes_cache.clear()
	_notes_cache[key] = result.duplicate()
	return result

static func comparison_text(current: Dictionary, previous: Dictionary) -> String:
	if previous.is_empty(): return "首次完成此敌试招；下次可比较耗时与承伤。"
	var seconds := float(current.get("elapsed", 0.0)) - float(previous.get("elapsed", 0.0))
	var damage := int(current.get("damage_taken", 0)) - int(previous.get("damage_taken", 0))
	var pace := "耗时相同" if absf(seconds) < 0.05 else "结束%s%.1f秒" % ["更快" if seconds < 0 else "更慢", absf(seconds)]
	var hurt := "承伤相同" if damage == 0 else "%s%d伤害" % ["少受" if damage < 0 else "多受", absi(damage)]
	var outcome: String = {"victory": "胜", "defeat": "败", "timeout": "超时"}.get(str(previous.get("outcome", "")), "结束")
	return "比上次（%s）：%s · %s" % [outcome, pace, hurt]

static func control_summary(report: Dictionary) -> String:
	var version: Variant = report.get("control_metrics_version")
	if not (version is int or version is float) or not is_finite(float(version)) or float(version) != 1.0:
		return "控场统计：未记录"
	for key in ["slowed_enemy_starts", "enemy_action_interrupts"]:
		var value: Variant = report.get(key)
		if not (value is int or value is float) or not is_finite(float(value)) or float(value) < 0.0 or float(value) != floorf(float(value)):
			return "控场统计：未记录"
	return "霜滞起手%d · 中断动作%d" % [int(report.slowed_enemy_starts), int(report.enemy_action_interrupts)]

static func control_notes() -> String:
	return "霜滞：实际影响后续新起手，非施法次数。\n中断：确实中断敌动作，含收势；不等于破势次数、避免命中或节省秒数。\n同一霜滞起手可能随后中断，两项可重叠。\n只记本次固定种子试招，不代表普遍强弱。"

static func build(h, x: float, y: float):
	var rows := _rows(h)
	var page := _page(h, rows)
	var active := _active(h)
	h._qbutton(h.drawer, "practice_enemy_prev", "‹", Rect2(x + 484, y + 60, 32, 27), func():
		if _active(h): return
		h.set_meta("practice_enemy_page", page - 1); h._refresh_drawer(), "上一位守灵").disabled = active or page <= 0
	h._qbutton(h.drawer, "practice_enemy_next", "›", Rect2(x + 573, y + 60, 32, 27), func():
		if _active(h): return
		h.set_meta("practice_enemy_page", page + 1); h._refresh_drawer(), "下一位守灵").disabled = active or page + 1 >= rows.size()
	if rows.is_empty(): return
	var row: Dictionary = rows[page]
	if active:
		var status := _status(h)
		var running := bool(status.get("active", false))
		if bool(status.get("finished", false)):
			h._qbutton(h.drawer, "practice_loadout", "试招结果" if bool(h.get_meta("practice_show_loadout", false)) else "搭配对照", Rect2(x + 496, y + 228, 108, 30), func():
				if not _active(h) or not bool(_status(h).get("finished", false)): return
				h.set_meta("practice_show_loadout", not bool(h.get_meta("practice_show_loadout", false))); h._refresh_drawer(), "只读本次与同敌上次完成试招的出战记录。仅本次运行保留，退出游戏清空。")
			if bool(h.get_meta("practice_show_loadout", false)):
				_build_loadout(h, x, y)
				return
		var pause_button = h._qbutton(h.drawer, "practice_pause", "继续" if bool(status.get("paused", false)) else "暂停试招", Rect2(x, y + 228, 116, 30), func():
			h.toggle_practice_pause(); h._refresh_drawer(), "只暂停镜中试招，不推进山居时间")
		pause_button.disabled = not running
		if bool(status.get("finished", false)):
			h._qbutton(h.drawer, "practice_control_help", "控场说明", Rect2(x + 376, y + 228, 116, 30), func():
				h._notice("霜滞影响后续起手；中断含收势，不等于避免命中。"), control_notes())
			h._qbutton(h.drawer, "practice_retry", "同敌再试", Rect2(x + 248, y + 228, 116, 30), func():
				h.start_practice(str(row.get("id", ""))); h._refresh_drawer(), "同一固定种子、当前合法搭配；不是胜率预测")
		h._qbutton(h.drawer, "practice_end", "结束试招", Rect2(x + 124, y + 228, 116, 30), func():
			h.end_practice(); h._refresh_drawer(), "返回山居，不获得奖励，不改正式资源")
	else:
		var reason: String = h.practice_can_start()
		var unlocked := bool(row.get("unlocked", false))
		var hint := "镜中试招：当前合法搭配、满气血真气、固定种子。\n不消耗历练资源，不得奖励；山居计时暂停。\n单次结果不是胜率，退出后恢复原山居状态。"
		var button = h._qbutton(h.drawer, "practice_start", "镜中试招", Rect2(x, y + 228, 132, 30), func():
			if not h.start_practice(str(row.get("id", ""))): h._notice("当前无法试招，请先归山并结束未完历练。")
			h._refresh_drawer(), hint if reason.is_empty() else reason)
		button.disabled = not unlocked or not reason.is_empty()

static func draw(h, x: float, y: float, a: float):
	var rows := _rows(h)
	if rows.is_empty():
		h.InkPages._txt(h, "暂无敌情", Vector2(x, y + 122), BODY, a)
		return
	var page := _page(h, rows)
	var row: Dictionary = rows[page]
	h.InkPages._center(h, "%d / %d" % [page + 1, rows.size()], Rect2(x + 518, y + 67, 53, 17), NOTE, a, h.InkPages.FADED)
	var title := "%s · %s" % [str(row.get("stage_name", "山路")), str(row.get("name", "守灵"))] if bool(row.get("unlocked", false)) else str(row.get("stage_name", "山路")) + " · 尚未开放"
	if _active(h) and bool(_status(h).get("finished", false)) and bool(h.get_meta("practice_show_loadout", false)):
		title = Loadout.comparison(_report(h).get("practice_loadout", {}), h.practice_comparison.get("practice_loadout", {}))
	h.InkPages._txt(h, h.InkPages._ellipsis(title, 600, 16), Vector2(x, y + 110), 16, a)
	if _active(h):
		var report := _report(h)
		var status := _status(h)
		if bool(status.get("finished", false)) and bool(h.get_meta("practice_show_loadout", false)):
			_draw_loadout(h, x, y, a, report)
			return
		var outcome := str(report.get("outcome", ""))
		var label := "试招已暂停" if bool(status.get("paused", false)) else "镜中交锋"
		if bool(status.get("finished", false)):
			label = {"victory": "试招胜", "defeat": "试招败", "cancelled": "试招结束", "timeout": "达到试招时限"}.get(outcome, "试招结束")
		h.InkPages._txt(h, "%s · %.1f秒 · 固定种子，非胜率" % [label, float(report.get("elapsed", 0.0))], Vector2(x, y + 137), BODY, a, h.InkPages.JADE)
		h.InkPages._txt(h, "伤害%d · 承伤%d · 治疗%d" % [int(report.get("damage_dealt", 0)), int(report.get("damage_taken", 0)), int(report.get("healing", 0))], Vector2(x, y + 161), BODY, a)
		h.InkPages._txt(h, "真气消耗%.1f · 气血%d/%d" % [float(report.get("qi_spent", 0.0)), int(report.get("hero_hp", 0)), int(report.get("hero_max_hp", 0))], Vector2(x, y + 185), BODY, a)
		if bool(status.get("finished", false)):
			h.InkPages._txt(h, control_summary(report), Vector2(x + 316, y + 185), BODY, a, h.InkPages.JADE)
		var comparison: String = comparison_text(report, h.practice_comparison) if bool(status.get("finished", false)) else "不获得奖励；完成后可比较同敌的上次试招。"
		h.InkPages._txt(h, h.InkPages._ellipsis(comparison, 600, BODY), Vector2(x, y + 211), BODY, a, h.InkPages.FADED)
	else:
		if bool(row.get("unlocked", false)):
			h.InkPages._txt(h, "气血%d · 攻击%d · 防御%d" % [int(row.get("hp", 0)), int(row.get("attack", 0)), int(row.get("defense", 0))], Vector2(x, y + 136), BODY, a, h.InkPages.JADE)
		var lines := notes(row)
		h.InkPages._wrap(h, lines[0], Vector2(x, y + 160), 600, BODY, a, h.InkPages.INK, 2)
		h.InkPages._wrap(h, lines[1], Vector2(x, y + 202), 600, BODY, a, h.InkPages.INK, 1)
		var reason: String = h.practice_can_start()
		h.InkPages._txt(h, h.InkPages._ellipsis(reason if not reason.is_empty() else "无奖励、无消耗；固定种子结果并非胜率。", 455, NOTE), Vector2(x + 142, y + 248), NOTE, a, h.InkPages.FADED)

static func _build_loadout(h, x: float, y: float):
	var pages: Array = Loadout.rows(_report(h).get("practice_loadout", {}))
	var page: int = clampi(int(h.get_meta("practice_loadout_page", 0)), 0, maxi(0, pages.size() - 1))
	h._qbutton(h.drawer, "practice_adjust", "回山调整", Rect2(x, y + 228, 116, 30), func():
		if not _active(h) or not bool(_status(h).get("finished", false)): return
		h.end_practice()
		h.set_meta("combat_insight_open", false)
		h.set_meta("equipment_comparison_open", false)
		h.remove_meta("chapter_practice_return")
		h.wardrobe_tab = "equipment"; h._refresh_drawer(true), "结束试招，保留本次记录并打开现有衣冠页。自行调整后，从属性详解→敌情再次手动试招；不会自动换装或出发。")
	h._qbutton(h.drawer, "practice_end", "结束试招", Rect2(x + 124, y + 228, 116, 30), func():h.end_practice(); h._refresh_drawer(), "返回敌情，不改正式资源。")
	h._qbutton(h.drawer, "practice_loadout_prev", "‹", Rect2(x + 264, y + 228, 36, 30), func():
		if not _active(h) or not bool(_status(h).get("finished", false)): return
		h.set_meta("practice_loadout_page", page - 1); h._refresh_drawer(), "上一页搭配").disabled = page <= 0
	h._qbutton(h.drawer, "practice_loadout_next", "›", Rect2(x + 366, y + 228, 36, 30), func():
		if not _active(h) or not bool(_status(h).get("finished", false)): return
		h.set_meta("practice_loadout_page", page + 1); h._refresh_drawer(), "下一页搭配").disabled = page + 1 >= pages.size()
	h._qbutton(h.drawer, "practice_loadout_help", "说明", Rect2(x + 420, y + 228, 64, 30), func():h._notice("记录含境界、装备温养与战斗输入；单次结果不代表强弱。"), "同敌上次只保留已完成的胜、败或超时；取消不会覆盖。\n相同指记录输入相同，展示为摘要；未全面控制运行条件。\n不同可能含境界、属性、温养或多项配置变化，不应归因于单一换装。\n固定种子单次试招，不代表胜率；无奖励、无消耗。")

static func _draw_loadout(h, x: float, y: float, a: float, report: Dictionary):
	var current: Dictionary = report.get("practice_loadout", {})
	var previous: Dictionary = h.practice_comparison.get("practice_loadout", {})
	var rows: Array = Loadout.rows(current)
	var old_rows: Array = Loadout.rows(previous)
	var page: int = clampi(int(h.get_meta("practice_loadout_page", 0)), 0, maxi(0, rows.size() - 1))
	var label: String = str(rows[page].label) if not rows.is_empty() else "出战记录"
	h.InkPages._txt(h, "本次 · " + label, Vector2(x, y + 133), BODY, a, h.InkPages.JADE)
	h.InkPages._txt(h, "同敌上次", Vector2(x + 310, y + 133), BODY, a, h.InkPages.JADE)
	for column in range(2):
		var value: String = str(rows[page].value) if column == 0 and not rows.is_empty() else (str(old_rows[page].value) if page < old_rows.size() else "尚无记录\n完成一次试招后可对照")
		h.InkPages._wrap(h, value, Vector2(x + column * 310, y + 155), 294, BODY, a, h.InkPages.INK, 4)
	h.InkPages._center(h, "搭配%d/%d" % [page + 1, maxi(1, rows.size())], Rect2(x + 304, y + 235, 58, 18), NOTE, a, h.InkPages.FADED)
