extends RefCounted
## A read-only loadout quote, followed only by an explicit, guarded equip action.
## Cached per paper rebuild: no state cloning or stat evaluation in the draw loop.
const BODY_FONT_SIZE := 14
const NOTE_FONT_SIZE := 12
const ROWS_PER_PAGE := 2

static func is_open(h) -> bool:
	return bool(h.get_meta("equipment_comparison_open", false)) and str(h.wardrobe_tab) == "equipment"

static func open(h):
	h.set_meta("equipment_comparison_open", true)
	h.set_meta("combat_insight_open", false)
	h.set_meta("equipment_comparison_page", 0)
	h._refresh_drawer()

static func _name(item: Dictionary) -> String:
	if item.is_empty(): return "空槽"
	return "%s +%d" % [str(item.get("name", "装备")), int(item.get("enhancement", 0))]

static func _delta(value: float, decimals: int = 0, unit: String = "") -> String:
	if is_zero_approx(value): return "不变"
	if decimals == 2 and absf(value) < 0.005: return ("微增<0.01" if value > 0 else "微降<0.01") + unit
	return ("+" if value > 0 else "") + ("%.2f" % value if decimals == 2 else ("%.1f" % value if decimals == 1 else "%d" % roundi(value))) + unit

static func _method_state(method: Dictionary) -> String:
	if method.is_empty(): return "未装配"
	return "条件满足" if bool(method.get("active", false)) else "条件不满足"

static func _method_row(label: String, before: Dictionary, after: Dictionary) -> Dictionary:
	var name: String = str(after.get("name", "未装配"))
	var source := "满足已学、通习、境界与兵器条件；仍需足够真气且冷却结束。"
	if label == "武式": source = "条件满足时修饰普攻形态；此处不是主动栏，不额外施放招式。"
	if after.is_empty(): source = "比较不会自动装配功法；可到功法录亲自选择。"
	elif not bool(after.get("compatible", true)): source = ("扇招需持流云扇" if str(after.get("required_weapon", "")) == "weapon_fan" else "剑式需持青锋剑") + "；仍须已学、通习与境界达标。身法另按合法装配生效。"
	elif not bool(after.get("active", false)): source = "尚未满足已学、通习或境界条件；比较不会解锁功法。"
	return {"section": "招式", "label": label + " · " + name, "value": _method_state(before) + " → " + _method_state(after), "source": source}

static func rows(quote: Dictionary) -> Array:
	if not bool(quote.get("ok", false)): return []
	var b: Dictionary = quote.before
	var n: Dictionary = quote.after
	var bg: Dictionary = quote.before_gear
	var ng: Dictionary = quote.after_gear
	var result: Array = [
		{"section": "属性", "label": "攻击", "value": "%d → %d（%s）" % [b.attack, n.attack, _delta(float(n.attack) - float(b.attack))], "source": "全身装备 %d → %d；境界、云岚装配加成与经脉保持。数值不等于每击伤害。" % [bg.attack, ng.attack]},
		{"section": "属性", "label": "防御", "value": "%d → %d（%s）" % [b.defense, n.defense, _delta(float(n.defense) - float(b.defense))], "source": "全身装备 %d → %d；境界与经脉保持。不是百分比减伤。" % [bg.defense, ng.defense]},
		{"section": "属性", "label": "平常架势闪避", "value": "%.1f%% → %.1f%%（%s）" % [float(b.evasion_chance)*100, float(n.evasion_chance)*100, _delta((float(n.evasion_chance)-float(b.evasion_chance))*100, 1, "个百分点")], "source": "装备 %.1f → %.1f 个百分点；总值封顶72%%，出招/接触仅留15%%，失衡为0。" % [float(bg.evasion_bonus)*100, float(ng.evasion_bonus)*100]},
		{"section": "属性", "label": "吐纳修为 / 秒", "value": "%.2f → %.2f（%s）" % [b.qi_rate, n.qi_rate, _delta(float(n.qi_rate)-float(b.qi_rate), 2)], "source": "装备吐纳 %.1f%% → %.1f%%（封顶35%%）；含当前境界、功法、经脉与清心，不是战斗真气。" % [float(bg.qi_bonus)*100, float(ng.qi_bonus)*100]},
	]
	var styles := {"weapon.sword": "剑", "weapon.fan": "扇", "weapon.unarmed": "空手"}
	result.append({"section": "招式", "label": "普攻形制", "value": str(styles.get(str(b.attack_module_id), b.attack_module_id)) + " → " + str(styles.get(str(n.attack_module_id), n.attack_module_id)), "source": "兵器改变实际普攻动作与接触范围；攻击数值较高也不保证更快取胜。"})
	result.append({"section": "招式", "label": "兵器自带招", "value": str(b.weapon_skill.get("name", "无")) + " → " + str(n.weapon_skill.get("name", "无")), "source": "由真实兵器形制提供；须足够真气与冷却就绪，不额外占主动功法栏。"})
	result.append(_method_row("武式", b.weapon_art, n.weapon_art))
	var before_actives: Array = b.active_skills
	var after_actives: Array = n.active_skills
	for i in range(maxi(1, after_actives.size())):
		result.append(_method_row("主动%d" % (i+1), before_actives[i] if i < before_actives.size() else {}, after_actives[i] if i < after_actives.size() else {}))
	# Keep sections on page boundaries, never show an orphaned heading.
	if result.size() % ROWS_PER_PAGE: result.append({"section": "招式", "label": "身法与招式分开", "value": "落英身法不要求持扇", "source": "合法装入武式或主动栏即提供身法；扇招仍需流云扇，两栏身法不叠加。"})
	result.append({"section": "须知", "label": "当前淬炼已计入", "value": "只换同一部位，不额外淬炼", "source": "比较包含两件物品现有淬炼；不消费材料、不增加属性，也不改变真气与冷却。"})
	result.append({"section": "须知", "label": "行箧 %d / %d" % [quote.inventory_count, quote.inventory_capacity], "value": "换装不需要空位", "source": "穿戴物仍计入行箧；替下的装备保留，容量满也可互换。交锋中只可比较，不排队自动穿戴。"})
	return result

static func build(h, x: float, y: float):
	var quote: Dictionary = h.state.equipment_comparison(int(h.selected_item))
	h.set_meta("equipment_comparison_quote", quote)
	var entries: Array = rows(quote)
	h.set_meta("equipment_comparison_rows", entries)
	var page: int = clampi(int(h.get_meta("equipment_comparison_page", 0)), 0, maxi(0, ceili(entries.size()/float(ROWS_PER_PAGE))-1))
	h.set_meta("equipment_comparison_page", page)
	h._qbutton(h.drawer, "comparison_back", "返回衣冠", Rect2(x+490,y+13,115,28), func():
		h.set_meta("equipment_comparison_open", false); h._refresh_drawer(), "返回并保留所选物品；不自动穿戴")
	if not bool(quote.get("ok", false)): return
	for i in range(ROWS_PER_PAGE):
		var index: int = page*ROWS_PER_PAGE+i
		if index >= entries.size(): break
		var row: Dictionary = entries[index]
		h.InkPages._hit(h, "comparison_row_%d" % i, str(row.label), Rect2(x,y+110+i*61,605,58), func(): pass, str(row.label)+" · "+str(row.value)+"\n"+str(row.source))
	h._qbutton(h.drawer, "comparison_prev", "‹", Rect2(x,y+238,32,27), func():
		h.set_meta("equipment_comparison_page",page-1); h._refresh_drawer(), "上一页比较").disabled=page<=0
	h._qbutton(h.drawer, "comparison_next", "›", Rect2(x+178,y+238,32,27), func():
		h.set_meta("equipment_comparison_page",page+1); h._refresh_drawer(), "下一页比较").disabled=(page+1)*ROWS_PER_PAGE>=entries.size()
	var candidate_id: int = int(quote.item.id)
	var locked: bool = h.InkPages._live_loadout_locked(h)
	var equip: Button = h._qbutton(h.drawer,"comparison_equip", "已穿戴此物" if bool(quote.same_item) else ("交锋后再穿戴" if locked else "穿上此物"),Rect2(x+464,y+238,141,27),func():
		if h.InkPages._guard_live_loadout(h): return
		if h.state.equip_item(candidate_id):
			h._save_loadout(); h._notice("已穿上 · "+str(quote.item.name),"equip")
		h._refresh_drawer(),"只替换此物部位，旧物保留；不会消耗材料",true)
	equip.disabled=locked or bool(quote.same_item)
	if locked: equip.tooltip_text=h.InkPages.LIVE_LOADOUT_HINT

static func draw(h, x: float, y: float, a: float):
	var quote: Dictionary = h.get_meta("equipment_comparison_quote", {})
	if not bool(quote.get("ok", false)):
		h.InkPages._txt(h,"此物已不在行箧，请返回重新选择。",Vector2(x+4,y+132),BODY_FONT_SIZE,a)
		return
	var entries: Array = h.get_meta("equipment_comparison_rows", [])
	var page: int = int(h.get_meta("equipment_comparison_page", 0))
	var slot: String = str(h.InkPages.SLOT_NAMES.get(str(quote.item.slot), "衣物"))
	h.InkPages._txt(h,"当前"+slot+"："+_name(quote.equipped_item),Vector2(x+4,y+74),BODY_FONT_SIZE,a)
	h.InkPages._txt(h,"候选"+slot+"："+_name(quote.item)+( "（同一件）" if bool(quote.same_item) else ""),Vector2(x+4,y+97),BODY_FONT_SIZE,a,h.InkPages.JADE)
	for i in range(ROWS_PER_PAGE):
		var index: int = page*ROWS_PER_PAGE+i
		if index>=entries.size(): break
		var row: Dictionary = entries[index]
		var yy: float = y+125+i*61
		h.InkPages._txt(h,str(row.label),Vector2(x+4,yy),BODY_FONT_SIZE,a)
		h.InkPages._txt(h,h.InkPages._ellipsis(str(row.value),390,BODY_FONT_SIZE),Vector2(x+213,yy),BODY_FONT_SIZE,a,h.InkPages.JADE)
		h.InkPages._wrap(h,str(row.source),Vector2(x+4,yy+20),597,BODY_FONT_SIZE,a,h.InkPages.INK,2)
	h.InkPages._center(h,"%s · %d / %d" % [str(entries[page*ROWS_PER_PAGE].section),page+1,ceili(entries.size()/float(ROWS_PER_PAGE))],Rect2(x+36,y+241,137,21),NOTE_FONT_SIZE,a,h.InkPages.FADED)
	h.InkPages._txt(h,"交锋中只读" if h.InkPages._live_loadout_locked(h) else "未自动换装",Vector2(x+238,y+256),NOTE_FONT_SIZE,a,h.InkPages.FADED)
