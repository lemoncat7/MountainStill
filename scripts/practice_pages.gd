extends RefCounted
## Read-only canonical enemy notes and an explicitly reward-free local mirror.
## All start eligibility is rechecked by the host, not trusted from stale controls.
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
		var pause_button = h._qbutton(h.drawer, "practice_pause", "继续" if bool(status.get("paused", false)) else "暂停试招", Rect2(x, y + 228, 116, 30), func():
			h.toggle_practice_pause(); h._refresh_drawer(), "只暂停镜中试招，不推进山居时间")
		pause_button.disabled = not running
		if bool(status.get("finished", false)):
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
	h.InkPages._txt(h, h.InkPages._ellipsis(title, 600, 16), Vector2(x, y + 110), 16, a)
	if _active(h):
		var report := _report(h)
		var status := _status(h)
		var outcome := str(report.get("outcome", ""))
		var label := "试招已暂停" if bool(status.get("paused", false)) else "镜中交锋"
		if bool(status.get("finished", false)):
			label = {"victory": "试招胜", "defeat": "试招败", "cancelled": "试招结束", "timeout": "达到试招时限"}.get(outcome, "试招结束")
		h.InkPages._txt(h, "%s · %.1f秒 · 固定种子，非胜率" % [label, float(report.get("elapsed", 0.0))], Vector2(x, y + 137), BODY, a, h.InkPages.JADE)
		h.InkPages._txt(h, "伤害%d · 承伤%d · 治疗%d" % [int(report.get("damage_dealt", 0)), int(report.get("damage_taken", 0)), int(report.get("healing", 0))], Vector2(x, y + 161), BODY, a)
		h.InkPages._txt(h, "真气消耗%.1f · 气血%d/%d" % [float(report.get("qi_spent", 0.0)), int(report.get("hero_hp", 0)), int(report.get("hero_max_hp", 0))], Vector2(x, y + 185), BODY, a)
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
