extends RefCounted
## Read-only combat evidence and explicit next-encounter decisions on existing paper.
## No preview simulates combat, grants resources, or changes equipment.
const Practice = preload("res://scripts/practice_pages.gd")
const VIEWS := ["attributes", "tactics", "reports", "enemies"]
const VIEW_NAMES := ["属性", "战术", "战报", "敌情"]
const TACTICS := ["balanced", "assault", "guarded", "frugal"]
const TACTIC_NAMES := {"balanced": "均衡", "assault": "强攻", "guarded": "守势", "frugal": "节气"}
const TACTIC_LINES := {
	"balanced": ["依照已装配技能轮转，穿插普攻。", "沿用原有节奏，适合先观察当前搭配。"],
	"assault": ["优先进攻；气血不高于65%时优先合法治疗。", "可能少用护盾；不加伤害，不保证更快取胜。"],
	"guarded": ["优先合法治疗、护盾，再进攻；仍穿插普攻。", "可能拉长交锋；须已装配，不赠送额外格挡。"],
	"frugal": ["通常保留25%真气；留气择招，不足时普攻。", "昂贵招式可攒满再用；濒危治疗可用保留真气。"],
}
const ATTRIBUTE_PAGE_SIZE := 2
const TACTIC_PAGE_SIZE := 2
const BODY_FONT_SIZE := 14
const NOTE_FONT_SIZE := 12

static func is_open(h) -> bool:
	return bool(h.get_meta("combat_insight_open", false)) and str(h.wardrobe_tab) == "equipment"

static func open(h):
	h.remove_meta("chapter_practice_return")
	h.set_meta("combat_insight_open", true)
	h.set_meta("combat_insight_view", "attributes")
	h.set_meta("combat_attribute_page", 0)
	h._refresh_drawer()

static func open_chapter(h, stage_id: String) -> bool:
	# Read the current catalogue, including locked placeholders. Never select,
	# start, cancel, save or simulate an expedition merely to inspect its enemy.
	if h.practice_session != null: return false
	var rows: Array = h.practice_enemy_rows()
	var page: int = -1
	for i in range(rows.size()):
		if str(rows[i].get("stage_id", "")) == stage_id:
			page = i; break
	if page < 0: return false
	h.set_meta("chapter_practice_return", {"id": stage_id, "page": int(h.get_meta("ink_stage_page", 0)), "view": str(h.get_meta("expedition_view", "route"))})
	h.set_meta("equipment_comparison_open", false)
	h.wardrobe_tab = "equipment"
	h.set_meta("combat_insight_open", true)
	h.set_meta("combat_insight_view", "enemies")
	h.set_meta("practice_enemy_page", page)
	h._refresh_drawer(true)
	return true

static func _back(h):
	if h.practice_session != null: return
	var origin: Dictionary = h.get_meta("chapter_practice_return", {})
	h.remove_meta("chapter_practice_return")
	h.set_meta("combat_insight_open", false)
	if not origin.is_empty():
		# Restore only the browsed paper, never State.selected_stage or a run.
		var rows: Array = h.state.stage_rows()
		for i in range(rows.size()):
			if str(rows[i].id) == str(origin.get("id", "")):
				h.wardrobe_tab = "expedition"
				h.set_meta("ink_stage_id", str(rows[i].id))
				h.set_meta("ink_stage_page", clampi(int(origin.get("page", i / 3)), 0, maxi(0, ceili(rows.size() / 3.0) - 1)))
				h.set_meta("expedition_view", "guide" if str(origin.get("view", "route")) == "guide" else "route")
				break
	h._refresh_drawer(true)

static func _view(h) -> String:
	var selected := str(h.get_meta("combat_insight_view", "attributes"))
	return selected if selected in VIEWS else "attributes"

static func _rows(h) -> Array:
	var result: Dictionary = h.state.combat_stat_breakdown()
	return result.get("rows", [])

static func _page(h, key: String, count: int, per_page: int = 1) -> int:
	return clampi(int(h.get_meta(key, 0)), 0, maxi(0, ceili(count / float(per_page)) - 1))

static func _reports(h) -> Array:
	var reports = h.state.get("combat_reports")
	return reports.slice(0, 5) if reports is Array else []

static func _choose_tactic(h, id: String):
	# Check again in the callback: a combat can start after controls were built.
	if h.InkPages._guard_live_loadout(h): return
	if h.state.set_combat_tactic(id):
		h._save_loadout()
		h._notice("已选" + str(TACTIC_NAMES.get(id, "均衡")) + " · 下次交锋按此战术出招，不改变属性。")
	h._refresh_drawer()

static func build(h, x: float, y: float):
	var from_chapter: bool = not h.get_meta("chapter_practice_return", {}).is_empty()
	var back: Button = h._qbutton(h.drawer, "combat_back", "返回山路" if from_chapter else "返回衣冠", Rect2(x + 490, y + 13, 115, 28), func():_back(h), "仅返回原章纸页，不出发、不改变未完行程" if from_chapter else "仅返回衣冠，不改动战术或装备")
	back.disabled = h.get("practice_session") != null
	back.add_theme_font_size_override("font_size", 14)
	for i in range(VIEWS.size()):
		var id: String = VIEWS[i]
		h._qbutton(h.drawer, "combat_view_" + id, VIEW_NAMES[i], Rect2(x + i * 90, y + 60, 80, 27), func():
			if h.get("practice_session") != null: return
			h.set_meta("combat_insight_view", id); h._refresh_drawer(), "查看" + VIEW_NAMES[i], false, _view(h) == id).disabled = h.get("practice_session") != null
	match _view(h):
		"enemies": Practice.build(h, x, y)
		"attributes":
			var rows: Array = _rows(h)
			var page: int = _page(h, "combat_attribute_page", rows.size(), ATTRIBUTE_PAGE_SIZE)
			for i in range(ATTRIBUTE_PAGE_SIZE):
				var index: int = page * ATTRIBUTE_PAGE_SIZE + i
				if index >= rows.size(): break
				var row: Dictionary = rows[index]
				h.InkPages._hit(h, "combat_attribute_%d" % index, str(row.get("label", "属性")), Rect2(x, y + 94 + i * 74, 605, 68), func():
					h._notice(str(row.get("label", "属性")) + " · " + str(row.get("source", ""))), str(row.get("label", "属性")) + " " + str(row.get("value", "")) + "\n" + str(row.get("source", "")))
			h._qbutton(h.drawer, "combat_attribute_prev", "‹", Rect2(x + 484, y + 60, 32, 27), func():
				h.set_meta("combat_attribute_page", page - 1); h._refresh_drawer(), "上一页属性").disabled = page <= 0
			h._qbutton(h.drawer, "combat_attribute_next", "›", Rect2(x + 573, y + 60, 32, 27), func():
				h.set_meta("combat_attribute_page", page + 1); h._refresh_drawer(), "下一页属性").disabled = (page + 1) * ATTRIBUTE_PAGE_SIZE >= rows.size()
		"tactics":
			var locked: bool = h.InkPages._live_loadout_locked(h)
			var page: int = _page(h, "combat_tactic_page", TACTICS.size(), TACTIC_PAGE_SIZE)
			for i in range(TACTIC_PAGE_SIZE):
				var id: String = TACTICS[page * TACTIC_PAGE_SIZE + i]
				var lines: Array = TACTIC_LINES[id]
				var control: Button = h._qbutton(h.drawer, "combat_tactic_" + id, str(TACTIC_NAMES[id]), Rect2(x, y + 115 + i * 65, 108, 32), func():
					_choose_tactic(h, id), "\n".join(lines) + ("\n通常预留真气上限的25%；技能成本超过上限的75%时，预留降至上限减成本，允许攒满后施放。气血不高于65%时，合法治疗可使用保留真气。" if id == "frugal" else "") + "\n不改变已装配功法、属性、当前真气或冷却。", false, str(h.state.combat_tactic) == id)
				control.disabled = locked
				if locked: control.tooltip_text = h.InkPages.LIVE_LOADOUT_HINT
			h._qbutton(h.drawer, "combat_tactic_prev", "‹", Rect2(x + 484, y + 60, 32, 27), func():
				h.set_meta("combat_tactic_page", page - 1); h._refresh_drawer(), "前两种战术").disabled = page <= 0
			h._qbutton(h.drawer, "combat_tactic_next", "›", Rect2(x + 573, y + 60, 32, 27), func():
				h.set_meta("combat_tactic_page", page + 1); h._refresh_drawer(), "后两种战术").disabled = (page + 1) * TACTIC_PAGE_SIZE >= TACTICS.size()
		"reports":
			var reports: Array = _reports(h)
			var page: int = _page(h, "combat_report_page", reports.size())
			h._qbutton(h.drawer, "combat_report_prev", "‹", Rect2(x + 484, y + 60, 32, 27), func():
				h.set_meta("combat_report_page", page - 1); h._refresh_drawer(), "较新的交锋").disabled = page <= 0
			h._qbutton(h.drawer, "combat_report_next", "›", Rect2(x + 573, y + 60, 32, 27), func():
				h.set_meta("combat_report_page", page + 1); h._refresh_drawer(), "较早的交锋").disabled = page + 1 >= reports.size()
			if not reports.is_empty():
				var report: Dictionary = reports[page]
				h.InkPages._hit(h, "combat_report_title", "本场交锋", Rect2(x, y + 94, 605, 23), func(): pass, str(report.get("enemy_name", "守灵")) + " · " + str(report.get("stage_name", "山路")) + "\n" + _detail_hint(report))
				h.InkPages._hit(h, "combat_report_details", "真实结算", Rect2(x, y + 124, 605, 66), func(): pass, _detail_hint(report))
				h.InkPages._hit(h, "combat_report_skills", "本场施法", Rect2(x, y + 207, 605, 31), func(): pass, _skill_line(report))

static func _detail_hint(report: Dictionary) -> String:
	return "伤害为实际气血差，不含溢出；命中和落空为接触判定次数，不是出招次数或命中率。\n我方命中 %d · 落空 %d · 被闪避 %d · 被格挡 %d\n受到命中 %d · 敌方落空 %d\n护盾生成 %d · 实际吸收 %d（不计入承受气血伤害）\n施法次数按已提交起手计入；包含被打断，普攻不计。" % [int(report.get("hits", 0)), int(report.get("misses", 0)), int(report.get("enemy_dodges", 0)), int(report.get("enemy_guards", 0)), int(report.get("incoming_hits", 0)), int(report.get("incoming_misses", 0)), int(report.get("shield_added", 0)), int(report.get("shield_absorbed", 0))]

static func _skill_line(report: Dictionary) -> String:
	var skills: Dictionary = report.get("skill_casts", {})
	var parts: Array[String] = []
	for key in skills:
		parts.append("%s×%d" % [str(key), int(skills[key])])
	return "未施放技能" if parts.is_empty() else " · ".join(parts)

static func draw(h, x: float, y: float, a: float):
	match _view(h):
		"attributes": _draw_attributes(h, x, y, a)
		"tactics": _draw_tactics(h, x, y, a)
		"reports": _draw_reports(h, x, y, a)
		"enemies": Practice.draw(h, x, y, a)

static func _draw_attributes(h, x: float, y: float, a: float):
	var rows: Array = _rows(h)
	var page: int = _page(h, "combat_attribute_page", rows.size(), ATTRIBUTE_PAGE_SIZE)
	for i in range(ATTRIBUTE_PAGE_SIZE):
		var index: int = page * ATTRIBUTE_PAGE_SIZE + i
		if index >= rows.size(): break
		var row: Dictionary = rows[index]
		var yy := y + 110 + i * 74
		h.InkPages._txt(h, str(row.get("label", "")), Vector2(x + 4, yy), BODY_FONT_SIZE, a)
		h.InkPages._txt(h, h.InkPages._ellipsis(str(row.get("value", "")), 450, BODY_FONT_SIZE), Vector2(x + 112, yy), BODY_FONT_SIZE, a, h.InkPages.JADE)
		h.InkPages._wrap(h, str(row.get("source", "")), Vector2(x + 4, yy + 22), 597, BODY_FONT_SIZE, a, h.InkPages.INK, 2)
		h.InkPages._rule(h, Vector2(x, yy + 51), Vector2(x + 605, yy + 51), a * .5)
	h.InkPages._txt(h, "当前搭配的实值，不是战力评分；交锋开始时锁定。", Vector2(x, y + 265), NOTE_FONT_SIZE, a, h.InkPages.FADED)
	h.InkPages._center(h, "%d / %d" % [page + 1, maxi(1, ceili(rows.size() / float(ATTRIBUTE_PAGE_SIZE)))], Rect2(x + 518, y + 67, 53, 17), NOTE_FONT_SIZE, a, h.InkPages.FADED)

static func _draw_tactics(h, x: float, y: float, a: float):
	var page: int = _page(h, "combat_tactic_page", TACTICS.size(), TACTIC_PAGE_SIZE)
	h.InkPages._txt(h, "只调整出招顺序与用气，不赠送属性或功法。", Vector2(x, y + 104), NOTE_FONT_SIZE, a, h.InkPages.FADED)
	for i in range(TACTIC_PAGE_SIZE):
		var lines: Array = TACTIC_LINES[TACTICS[page * TACTIC_PAGE_SIZE + i]]
		h.InkPages._txt(h, str(lines[0]), Vector2(x + 122, y + 132 + i * 65), BODY_FONT_SIZE, a)
		h.InkPages._txt(h, str(lines[1]), Vector2(x + 122, y + 153 + i * 65), BODY_FONT_SIZE, a, h.InkPages.INK)
	h.InkPages._center(h, "%d / 2" % [page + 1], Rect2(x + 518, y + 67, 53, 17), NOTE_FONT_SIZE, a, h.InkPages.FADED)
	h.InkPages._txt(h, "交锋中只可查看；此敌结束后再调整。" if h.InkPages._live_loadout_locked(h) else "选择后保存；下一场生效，不出发、不重置真气与冷却。", Vector2(x, y + 260), NOTE_FONT_SIZE, a, h.InkPages.JADE)

static func _draw_reports(h, x: float, y: float, a: float):
	var reports: Array = _reports(h)
	if reports.is_empty():
		h.InkPages._txt(h, "尚无交锋记录", Vector2(x + 16, y + 136), 18, a)
		h.InkPages._txt(h, "亲自走一段山路后，再来看看招式与属性发挥了多少作用。", Vector2(x + 16, y + 165), NOTE_FONT_SIZE, a, h.InkPages.FADED)
		h.InkPages._txt(h, "浏览不会开战，也不模拟或补发旧战绩。", Vector2(x + 16, y + 192), NOTE_FONT_SIZE, a, h.InkPages.FADED)
		return
	var page: int = _page(h, "combat_report_page", reports.size())
	var report: Dictionary = reports[page]
	var outcome: String = {"victory": "胜", "defeat": "败", "retreat": "归山"}.get(str(report.get("outcome", "")), "记录")
	h.InkPages._center(h, "%d / %d" % [page + 1, reports.size()], Rect2(x + 518, y + 67, 53, 17), NOTE_FONT_SIZE, a, h.InkPages.FADED)
	h.InkPages._txt(h, h.InkPages._ellipsis("%s · %s · %s" % [outcome, str(report.get("enemy_name", "守灵")), str(report.get("stage_name", "山路"))], 420, 16), Vector2(x, y + 111), 16, a)
	h.InkPages._txt(h, "%s · %.1f秒" % [str(TACTIC_NAMES.get(str(report.get("tactic", "balanced")), "均衡")), float(report.get("elapsed", 0.0))], Vector2(x + 440, y + 110), BODY_FONT_SIZE, a, h.InkPages.JADE)
	var left := ["伤害 %d · 命中%d / 落空%d" % [int(report.get("damage_dealt", 0)), int(report.get("hits", 0)), int(report.get("misses", 0))], "承受伤害 %d · 治疗 %d" % [int(report.get("damage_taken", 0)), int(report.get("healing", 0))], "结束气血 %d / %d" % [int(report.get("hero_hp", 0)), int(report.get("hero_max_hp", 0))]]
	var right := ["闪避 %d · 格挡 %d" % [int(report.get("dodges", 0)), int(report.get("guards", 0))], "护盾吸收 %d · 破势 %d" % [int(report.get("shield_absorbed", 0)), int(report.get("breaks", 0))], "消耗真气 %.1f" % float(report.get("qi_spent", 0.0))]
	for i in range(3):
		h.InkPages._txt(h, h.InkPages._ellipsis(str(left[i]), 300, BODY_FONT_SIZE), Vector2(x + 4, y + 139 + i * 22), BODY_FONT_SIZE, a)
		h.InkPages._txt(h, str(right[i]), Vector2(x + 316, y + 139 + i * 22), BODY_FONT_SIZE, a)
	h.InkPages._rule(h, Vector2(x, y + 197), Vector2(x + 605, y + 197), a)
	h.InkPages._txt(h, "施法次数 · 已起手即计入，含被打断；悬停看完整列表", Vector2(x + 4, y + 216), NOTE_FONT_SIZE, a, h.InkPages.FADED)
	h.InkPages._txt(h, h.InkPages._ellipsis(_skill_line(report), 597, BODY_FONT_SIZE), Vector2(x + 4, y + 233), BODY_FONT_SIZE, a, h.InkPages.JADE)
	h.InkPages._txt(h, "仅保留最近五场 · 本场记录，不代表胜率。", Vector2(x, y + 260), NOTE_FONT_SIZE, a, h.InkPages.FADED)
