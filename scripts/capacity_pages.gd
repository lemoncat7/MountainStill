extends RefCounted
## Transient navigation only. No save-schema fields, reward prediction or route selection.
const Capacity = preload("res://scripts/reward_capacity.gd")
const NAMES = {"chapter":"首通心意", "quest":"小记心意", "opportunity":"山间机缘", "corpse":"已搜遗物", "chest":"启封木箱", "salvage":"分解所得"}
const DESTINATIONS = {"wardrobe":"整理衣冠", "alchemy":"查看丹方用途", "chests":"查看现有木箱", "practice":"查看修行与经脉", "materials":"查看材料用途"}
const BODY_FONT_SIZE := 14

static func anchor(h) -> Dictionary: return h.get_meta("capacity_anchor", {})
static func active(h) -> bool: return not anchor(h).is_empty()
static func clear(h):
	h.set_meta("capacity_anchor", {})
	h.set_meta("capacity_nonce", int(h.get_meta("capacity_nonce", 0)) + 1)

static func _origin(h) -> Dictionary:
	var result := {"drawer":h.drawer_name, "wardrobe_tab":h.wardrobe_tab}
	for key in ["ink_stage_id","ink_stage_page","expedition_view","ink_journal_tab","ink_journal_mode","ink_journal_page","bag_view"]:
		if h.has_meta(key):result[key]=h.get_meta(key)
	return result

static func open(h, kind: String, target: Dictionary = {}, reason: String = ""):
	var previous: Dictionary = anchor(h)
	var context := {"kind":kind,"target":target.duplicate(true),"origin":_origin(h),"reason":reason}
	if kind in ["chest","salvage"] and not previous.is_empty(): context.parent=previous.duplicate(true)
	clear(h)
	h.set_meta("capacity_anchor", context)
	context.display_name=target_label(h)
	if kind=="corpse":
		context.origin.drawer="wardrobe";context.origin.wardrobe_tab="expedition"
		context.origin.ink_stage_id=str(target.get("stage_id",h.state.stage_status().get("id","")))
		context.origin.expedition_view="route"
		var chapter_rows: Array=h.state.stage_rows()
		for i in range(chapter_rows.size()):
			if str(chapter_rows[i].id)==str(context.origin.ink_stage_id):context.origin.ink_stage_page=i/3;break
	h.set_meta("capacity_anchor", context)
	h.set_meta("capacity_page", 0)
	_show(h,"capacity")

static func _show(h, page: String):
	# Deliberately not _inspect_chapter/select_stage or _toggle_drawer's onboarding side effect.
	h.set_meta("capacity_nonce",int(h.get_meta("capacity_nonce",0))+1)
	h.drawer_name=page;h.drawn_page=page
	h.desktop.set_passthrough(false)
	h._build_nav();h._refresh_drawer(true)

static func diagnostic(h) -> Dictionary:
	var context: Dictionary=anchor(h)
	var target: Dictionary=context.get("target", {})
	match str(context.get("kind", "")):
		"chapter":return Capacity.chapter(h.state,str(target.get("id","")))
		"quest":return Capacity.quest(h.state,str(target.get("id","")))
		"opportunity":return Capacity.opportunity(h.state,str(target.get("id","")))
		"corpse":return Capacity.corpse(h.state)
		"chest":return Capacity.chest(h.state)
		"salvage":return Capacity.salvage(h.state,int(target.get("id",-1)))
	return {"blockers":[],"destinations":[],"description":"","blocked":false}

static func valid(h) -> bool:
	var context: Dictionary=anchor(h)
	var target: Dictionary=context.get("target", {})
	match str(context.get("kind", "")):
		"chapter":return h.state.chapter_status().pending_rewards.has(str(target.get("id","")))
		"quest":
			for row in h.state.quest_rows():
				if str(row.id)==str(target.get("id","")):return not bool(row.claimed)
		"opportunity":
			var status: Dictionary=h.state.opportunity_status()
			return not status.is_empty() and int(status.run_id)==int(target.get("run_id",-1)) and str(status.stage_id)==str(target.get("stage_id",""))
		"corpse":
			var status: Dictionary=h.state.stage_corpse_status()
			return not status.is_empty() and int(status.run_id)==int(target.get("run_id",-1)) and int(status.monster_index)==int(target.get("monster_index",-1))
		"chest":return h.state.chest_count>0
		"salvage":return not h.state.gear.get_item(int(target.get("id",-1))).is_empty()
	return false

static func _safe_click(h, nonce: int) -> bool:
	return h.drawer_name=="capacity" and active(h) and int(h.get_meta("capacity_nonce",0))==nonce

static func return_pending(h):
	if not active(h):return
	h.set_meta("capacity_page",0)
	_show(h,"capacity")

static func return_origin(h):
	if not active(h):return
	var context: Dictionary=anchor(h).duplicate(true)
	var origin: Dictionary=context.get("origin",{})
	clear(h)
	if context.has("parent"):h.set_meta("capacity_anchor",context.parent)
	h.wardrobe_tab=str(origin.get("wardrobe_tab","equipment"))
	for key in origin:
		if key not in ["drawer","wardrobe_tab"]:h.set_meta(key,origin[key])
	var page: String=str(origin.get("drawer","wardrobe"))
	if page.is_empty() or page=="capacity":page="wardrobe"
	_show(h,page)

static func organize(h, destination: String):
	if not active(h):return
	h.set_meta("equipment_comparison_open",false);h.set_meta("combat_insight_open",false)
	match destination:
		"wardrobe":h.wardrobe_tab="equipment";_show(h,"wardrobe")
		"alchemy":_show(h,"alchemy")
		"chests":h.wardrobe_tab="adventure";_show(h,"wardrobe")
		"practice":h.wardrobe_tab="meridian";_show(h,"wardrobe")
		"materials":h.wardrobe_tab="bag";h.set_meta("bag_view","materials");_show(h,"wardrobe")

static func held_corpse(h) -> Dictionary:
	var held: Dictionary=h.get_meta("capacity_corpse_hold",{})
	var status: Dictionary=h.state.stage_corpse_status()
	if not held.is_empty() and not status.is_empty() and int(held.get("run_id",-1))==int(status.run_id) and int(held.get("monster_index",-1))==int(status.monster_index):return held
	return {}

static func build_return(h, x: float, y: float):
	if not active(h) and not held_corpse(h).is_empty() and h.drawer_name in ["wardrobe","alchemy","practice"]:
		h._qbutton(h.drawer,"capacity_return","返回待收遗物",Rect2(x+148,y+12,123,30),func():open(h,"corpse",held_corpse(h)),"遗物与2秒搜寻进度保留；整理后需亲点收取。",true)
		return
	if not active(h) or h.drawer_name not in ["wardrobe","alchemy","practice"]:return
	h._qbutton(h.drawer,"capacity_return","返回待领心意",Rect2(x+148,y+12,123,30),func():return_pending(h),"回到原目标；只翻页，不自动领取、开箱或分解。",true)

static func _chest_fingerprint(h) -> String:
	return str([h.state.gear.inventory.size(),h.state.chest_count,h.state.gear.starter_chest_unopened,h.state.herbs,h.state.dew])

static func _retry(h, nonce: int, fingerprint: String):
	if not _safe_click(h,nonce):return
	if not valid(h):h._notice("原目标已变化；不会重复领取。请返回原页查看。");h._refresh_drawer();return
	if h.encounter_active and h.encounter_phase=="fight" and str(anchor(h).get("kind",""))!="salvage":h._notice("交锋中暂不处理收取；请待此敌结束。");return
	var context: Dictionary=anchor(h).duplicate(true)
	var target: Dictionary=context.target
	var kind: String=str(context.kind)
	var result: Dictionary={}
	match kind:
		"chapter":result=h.state.claim_chapter_reward(str(target.id))
		"quest":result=h.state.claim_quest(str(target.id))
		"opportunity":result=h.state.choose_opportunity(str(target.id))
		"corpse":
			if not h.encounter_active or h.encounter_phase!="pickup" or h.encounter_run_id!=int(target.run_id) or h.encounter_index!=int(target.monster_index):
				h._notice("请回原章亲点继续，重返已保留的搜寻处。");return
			h._claim_searched_corpse(true)
			if h.pickup_claimed_at>=0.0:return_origin(h)
			else:h._refresh_drawer()
			return
		"chest":
			if fingerprint!=_chest_fingerprint(h):h._notice("行囊已变化，请重新查看本页再确认。");h._refresh_drawer();return
			# The confirmation authorizes exactly one chest, not a sticky bypass.
			return_origin(h)
			h._open_treasure(true)
			return
		"salvage":
			return_origin(h)
			h._notice("回到衣冠后，仍需亲点分解并确认；不会自动分解。")
			return
	if bool(result.get("ok",false)):
		h._save_loadout();h._notice(str(NAMES.get(kind,"心意"))+"已收入行囊。","loot")
		return_origin(h)
	else:
		var current: Dictionary=anchor(h);current.reason=str(result.get("reason",""));h.set_meta("capacity_anchor",current)
		h._notice(str(diagnostic(h).get("description","")) if bool(diagnostic(h).get("blocked",false)) else "暂不能领取，原奖励保留；返回原页查看当前条件。")
		h._refresh_drawer()

static func rows(h) -> Array:
	if not valid(h):return [{"title":"原目标已变化或已领取","detail":"不会转去其他奖励或重复领取。请返回原页查看当前目标。","destination":""}]
	var result: Array=[]
	var quote: Dictionary=diagnostic(h)
	if str(anchor(h).get("kind",""))=="chest":
		if bool(quote.get("equipment_full",false)):
			result.append({"title":"衣冠装备 100 / 100 · 可先留 1 位","detail":str(quote.conversion_warning),"destination":"wardrobe"})
		else:result.append({"title":"装备已有空位","detail":"木箱按原有规则开启；仅首箱保证一件装备。","destination":""})
		if not str(quote.get("resource_warning","")).is_empty():result.append({"title":"草露极限容量边界","detail":str(quote.resource_warning),"destination":"alchemy"})
	else:
		for row in quote.get("blockers",[]):
			var detail: String="本次新增 %s；至少腾出 %s%s。"%[str(int(row.add)),str(int(ceil(row.need))),"位" if row.id=="equipment" else ""]
			if row.id=="merit":detail+="归真功德暂无消耗途径；奖励保留。"
			elif row.id=="equipment":detail+="只整理不自动分解；穿戴中的装备受保护。"
			else:detail+="查看用途不自动消耗；资源与堆叠属于极限边界。"
			result.append({"title":"%s · %s / %s"%[row.name,str(int(row.current)),str(int(row.cap))],"detail":detail,"destination":row.destination})
	if result.is_empty():result.append({"title":"当前未发现容量阻塞" if valid(h) else "原目标已变化或已领取","detail":"仍需亲点领取；若尚未满足领取条件，目标会继续保留。" if valid(h) else "不会转去其他奖励或重复领取。可返回原页查看。","destination":""})
	return result

static func build(h, x: float, y: float):
	var entries: Array=rows(h)
	var page: int=clampi(int(h.get_meta("capacity_page",0)),0,entries.size()-1)
	h.set_meta("capacity_page",page)
	h.set_meta("capacity_rows",entries)
	var nonce: int=int(h.get_meta("capacity_nonce",0))
	var row: Dictionary=entries[page]
	var destination: String=str(row.destination)
	if not destination.is_empty():
		h._qbutton(h.drawer,"capacity_organize",str(DESTINATIONS.get(destination,"查看用途")),Rect2(x,y+177,215,31),func():
			if _safe_click(h,nonce):organize(h,destination),"只打开对应书页，不消费任何物品。",true)
	h._qbutton(h.drawer,"capacity_prev","‹",Rect2(x+489,y+177,32,31),func():h.set_meta("capacity_page",page-1);h._refresh_drawer(),"上一项").disabled=page==0
	h._qbutton(h.drawer,"capacity_next","›",Rect2(x+572,y+177,32,31),func():h.set_meta("capacity_page",page+1);h._refresh_drawer(),"下一项").disabled=page==entries.size()-1
	var kind: String=str(anchor(h).get("kind",""))
	var label: String="确认启封 1 箱" if kind=="chest" else ("返回衣冠再确认" if kind=="salvage" else "亲点重试收取")
	var fingerprint: String=_chest_fingerprint(h)
	var retry: Button=h._qbutton(h.drawer,"capacity_retry",label,Rect2(x+312,y+235,292,31),func():_retry(h,nonce,fingerprint),"本次只处理所示原目标；失败仍保留。",true)
	retry.disabled=not valid(h) or (h.encounter_active and h.encounter_phase=="fight" and kind!="salvage")
	h._qbutton(h.drawer,"capacity_cancel","暂不处理 · 回原页",Rect2(x,y+235,292,31),func():
		if _safe_click(h,nonce):return_origin(h),"不领取、不启封、不分解。")

static func target_label(h) -> String:
	var context: Dictionary=anchor(h)
	if context.has("display_name"):return str(context.display_name)
	var kind: String=str(context.get("kind",""))
	var target: Dictionary=context.get("target",{})
	if kind=="chapter":
		for row in h.state.stage_rows():
			if str(row.id)==str(target.get("id","")):return str(row.name)
	if kind=="quest":
		for row in h.state.quest_rows():
			if str(row.id)==str(target.get("id","")):return str(row.name)
	if kind=="opportunity":
		for choice in h.state.opportunity_status().get("choices",[]):
			if str(choice.id)==str(target.get("id","")):return str(choice.get("label",choice.get("name","机缘")))
	if kind=="corpse":return str(h.state.stage_corpse_status().get("monster",{}).get("name","原处遗物"))
	return ""

static func draw(h, x: float, y: float, a: float):
	var context: Dictionary=anchor(h)
	var entries: Array=h.get_meta("capacity_rows",[])
	if entries.is_empty():return
	var page: int=clampi(int(h.get_meta("capacity_page",0)),0,entries.size()-1)
	var row: Dictionary=entries[page]
	var title: String=str(NAMES.get(str(context.get("kind","")),"心意保留"))
	var target_name: String=target_label(h)
	if not target_name.is_empty():title+=" · "+target_name
	h._text(title,Vector2(x,y+39),24,Color(h.InkPages.INK,a),h.SERIF)
	h.InkPages._rule(h,Vector2(x,y+51),Vector2(x+605,y+51),a,true)
	h.InkPages._txt(h,str(row.title),Vector2(x,y+82),16,a,h.InkPages.INK,true)
	h.InkPages._wrap(h,str(row.detail),Vector2(x,y+111),604,BODY_FONT_SIZE,a,h.InkPages.FADED,3)
	h.InkPages._txt(h,"%d / %d"%[page+1,entries.size()],Vector2(x+531,y+198),12,a)
	var note: String="不开箱就不消耗木箱；合书会取消本次确认。" if context.get("kind","")=="chest" else "原目标保留 · 整理后返回此页，仍需亲点收取。"
	if not valid(h):note="原目标不再可处理 · 不会自动选择其他奖励。"
	h.InkPages._txt(h,note,Vector2(x,y+226),12,a,h.InkPages.FADED)
