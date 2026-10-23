extends RefCounted
## Rice-paper field books. These pages only present the host's real state;
## loot rolls, equipment ownership, saves and confirmation remain in the host.

const SERIF = preload("res://assets/fonts/NotoSerifCJK-Regular.ttc")
const BRUSH = preload("res://assets/fonts/MaShanZheng-Regular.ttf")
const SANS = preload("res://assets/fonts/NotoSansCJK-Regular.ttc")
const INK = Color("343b32")
const FADED = Color("707365")
const RULE = Color("aaa48e")
const RED = Color("a44434")
const JADE = Color("6e876b")
const SLOT_NAMES = {"head":"头饰", "chest":"上衣", "legs":"下装", "feet":"鞋履", "weapon":"兵器"}
const RARITY_NAMES = {"common":"凡品", "uncommon":"灵品", "rare":"珍品", "epic":"仙品"}
const RARITY_INK = {"common":Color("777568"), "uncommon":Color("5c8266"), "rare":Color("60768b"), "epic":Color("976c89")}
const Adventure = preload("res://scripts/adventure_pages.gd")
const CombatTiming = preload("res://scripts/combat_timing.gd")
const EquipmentComparison = preload("res://scripts/equipment_comparison_pages.gd")
const CombatInsight = preload("res://scripts/combat_insight_pages.gd")
const TABS = ["equipment", "expedition", "adventure", "technique", "meridian", "bag"]
const TAB_NAMES = ["衣冠", "历练", "游历", "功法", "经脉", "行囊"]

const LIVE_LOADOUT_HINT := "交锋中仅可翻阅与试演；此敌结束后再穿脱或切换功法，不会自动替换。"

static func _live_loadout_locked(h) -> bool:
	return bool(h.encounter_active) and str(h.encounter_phase) == "fight"

static func _guard_live_loadout(h) -> bool:
	if not _live_loadout_locked(h):
		return false
	h._notice(LIVE_LOADOUT_HINT)
	return true

static func _hit(h, key:String, label:String, r:Rect2, fn:Callable, hint:String="") -> Button:
	var b:Button = h._qbutton(h.drawer,key,label,r,fn,hint)
	b.set_meta("ink_region",true)
	# The host paints this label. Invisible native text must not enlarge the
	# hit region (notably the 14px material toggle above the enhance button).
	b.add_theme_font_size_override("font_size",1)
	b.size=r.size
	return b

static func _txt(h, text:String, p:Vector2, size:int, a:float, color:Color=INK, serif:bool=false):
	h._text(text,p,size,Color(color,a),SERIF if serif else SANS)

static func _center(h, text:String, r:Rect2, size:int, a:float, color:Color=INK, serif:bool=false):
	var font:Font = SERIF if serif else SANS
	var width:float = font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x
	h._text(text,Vector2(r.position.x+(r.size.x-width)*.5,r.position.y+size),size,Color(color,a),font)

static func _rule(h, from:Vector2, to:Vector2, a:float, strong:bool=false):
	h.draw_line(from,to,Color(RULE,a*(.55 if strong else .25)),1.0,true)

static func _seal(h, letter:String, p:Vector2, a:float, side:float=21.0):
	var points = PackedVector2Array([p+Vector2(1,0),p+Vector2(side,1),p+Vector2(side-1,side),p+Vector2(0,side-1)])
	h.draw_colored_polygon(points,Color(RED,a*.87))
	h.draw_polyline(PackedVector2Array([p+Vector2(3,3),p+Vector2(side-3,3),p+Vector2(side-3,side-3),p+Vector2(3,side-3),p+Vector2(3,3)]),Color("e7dfc5",a*.65),.7,true)
	var fs:int = int(side*.71)
	var tw:float = BRUSH.get_string_size(letter,HORIZONTAL_ALIGNMENT_LEFT,-1,fs).x
	h._text(letter,p+Vector2((side-tw)*.5,side*.78),fs,Color("f6eed8",a),BRUSH)

static func _touch(h):
	h.set_meta("ink_specimen_time",float(h.elapsed))

static func _item_texture(h, item:Dictionary) -> Texture2D:
	var key:String = str(item.get("visual_id",""))
	return h.equipment_icons.get(key,h.avatar_assets.get(key.trim_prefix("weapon_"),null))

static func _item_art(h, item:Dictionary, r:Rect2, a:float):
	var texture:Texture2D = _item_texture(h,item)
	if texture:
		h._fit_texture(texture,r,Color(1,1,1,a))

static func _book_header(h, title:String, subtitle:String, x:float, y:float, width:float, a:float):
	h._text(title,Vector2(x+1,y+40),29,Color(INK,a),BRUSH)
	_txt(h,subtitle,Vector2(x+111,y+37),10,a,FADED)
	_rule(h,Vector2(x,y+51),Vector2(x+width,y+51),a,true)

static func build_wardrobe(h, x:float, y:float, _r:Rect2):
	for i in range(TABS.size()):
		var category:String = TABS[i]
		_hit(h,"wardrobe_"+category,TAB_NAMES[i],Rect2(x+621,y+65+i*33,29,30),func():
			h.wardrobe_tab=category;h.set_meta("combat_insight_open",false);h.set_meta("equipment_comparison_open",false);_touch(h);h._refresh_drawer(),"翻至"+TAB_NAMES[i])
	match str(h.wardrobe_tab):
		"equipment":
			if EquipmentComparison.is_open(h): EquipmentComparison.build(h,x,y)
			elif CombatInsight.is_open(h): CombatInsight.build(h,x,y)
			else: _build_equipment(h,x,y)
		"expedition": Adventure.build_expedition(h,x,y)
		"meridian": Adventure.build_meridian(h,x,y)
		"adventure": _build_adventure(h,x,y)
		"technique": _build_technique(h,x,y)
		_: _build_bag(h,x,y)

static func evasion_hint(h) -> String:
	var rates:Dictionary=h.state.evasion_stats()
	var timing:Dictionary=CombatTiming.from_stats(h.state.stats())
	var speed_text:="速度 %.0f（基准100） · 出手倍率 %.2f\n速度统一影响起手、出手、接触停留、连段、收势和招间衔接；轻重招保留各自节奏。\n速度范围65至160；经脉出招加成计入一次。技能冷却、受击停顿与状态持续时间独立。\n"%[float(timing.speed),float(timing.rate)]
	return speed_text+"闪避 %.1f%%（平常架势）\n基础 %.1f + 身法 %.1f + 装备 %.1f + 经脉 %.1f 个百分点；上限 %.0f%%。\n出招/接触阶段仅保留15%%，折算为 %.2f%%；失衡时为0%%。\n落英装入武式或主动栏即提供身法，持剑或空手也生效；两栏不叠加。扇招仍须持扇。\n鞋履：素布履 +2、踏云靴 +4 个百分点；每次淬炼再 +0.2。\n每次来招只做一次闪避/格挡判定：闪避为零伤害，未闪避才可能格挡减伤；普通落空不会补判闪避。"%[float(rates.chance)*100,float(rates.base)*100,float(rates.movement)*100,float(rates.equipment)*100,float(rates.meridian)*100,float(rates.cap)*100,float(rates.committed_chance)*100]

static func _draw_evasion_summary(h,x:float,y:float,a:float):
	var rates:Dictionary=h.state.evasion_stats()
	var timing:Dictionary=CombatTiming.from_stats(h.state.stats())
	_txt(h,"平常闪避 %.1f%% · 出招 %.2f%% · 失衡0%% · 闪避零伤害 / 格挡减伤"%[float(rates.chance)*100,float(rates.committed_chance)*100],Vector2(x+111,y+24),11,a,JADE)
	_txt(h,"速度%.0f（基准100） · 闪避：基础%.1f/身法%.1f/装备%.1f/经脉%.1f · 点开详解"%[float(timing.speed),float(rates.base)*100,float(rates.movement)*100,float(rates.equipment)*100,float(rates.meridian)*100],Vector2(x+111,y+41),10,a,FADED)

static func _build_equipment(h, x:float, y:float):
	var compare: Button = h._qbutton(h.drawer,"compare_selected","换装比较 ↗",Rect2(x+178,y+55,151,24),func():EquipmentComparison.open(h),"比较所选物品与当前同部位装备的实际属性和招式条件；不自动穿戴")
	compare.disabled=h.state.gear.get_item(h.selected_item).is_empty()
	_hit(h,"evasion_stat","战斗属性",Rect2(x+111,y+9,493,37),func():CombatInsight.open(h),"点开属性来源、战术与最近战报\n"+evasion_hint(h))
	var slots:Array = ["head","chest","legs","feet","weapon"]
	for i in range(5):
		var slot:String = slots[i]
		var item:Dictionary = h.state.gear.equipped_item(slot)
		var label:String = str(SLOT_NAMES[slot])+" · "+str(item.get("name","未穿戴"))
		_hit(h,"slot_"+slot,label,Rect2(x-2,y+78+i*29,157,28),func():
			h.selected_slot=slot;h.selected_item=int(h.state.gear.equipped.get(slot,-1));_touch(h);h._refresh_drawer(),"查看"+str(SLOT_NAMES[slot])+"；五个部位独立穿脱")
	var un:Button = h._qbutton(h.drawer,"unequip_slot","交锋后卸下" if _live_loadout_locked(h) else "卸下"+str(SLOT_NAMES[h.selected_slot]),Rect2(x,y+238,151,27),func():
		if _guard_live_loadout(h):return
		if h.state.unequip_slot(h.selected_slot):
			h._save_loadout();h._notice("已卸下"+str(SLOT_NAMES[h.selected_slot]),"equip");_touch(h);h._refresh_drawer(),"只卸下所选部位，其余衣物保留")
	un.disabled=_live_loadout_locked(h) or h.state.gear.equipped_item(h.selected_slot).is_empty()
	if _live_loadout_locked(h):un.tooltip_text=LIVE_LOADOUT_HINT
	var items:Array = h.state.gear.inventory
	h.inventory_page=clampi(int(h.inventory_page),0,maxi(0,int((items.size()-1)/3)))
	if items.is_empty():
		h._qbutton(h.drawer,"first_chest","启封随身木箱  ·  %d"%h.state.chest_count,Rect2(x+356,y+220,244,34),h._open_treasure,"第一只木箱保证随机获得一件入门装备",true).disabled=h.state.chest_count<=0
		return
	for i in range(3):
		var idx:int = int(h.inventory_page)*3+i
		if idx>=items.size(): break
		var item:Dictionary = items[idx]
		var id:int = int(item.id)
		var worn:bool = id in h.state.gear.equipped.values()
		var label:String = str(item.get("name","装备"))+" · "+str(RARITY_NAMES.get(item.rarity,"凡品"))+("  已穿戴" if worn else "")
		_hit(h,"item_"+str(i),label,Rect2(x+353,y+78+i*41,252,39),func():
			h.selected_item=id;h.selected_slot=str(item.slot);_touch(h);h._refresh_drawer(),"查看此物的形制与属性，再选择穿上")
	h._qbutton(h.drawer,"items_prev","‹",Rect2(x+353,y+202,30,31),func():h.inventory_page=maxi(0,int(h.inventory_page)-1);_touch(h);h._refresh_drawer(),"前一页").disabled=h.inventory_page<=0
	h._qbutton(h.drawer,"items_next","›",Rect2(x+575,y+202,30,31),func():h.inventory_page+=1;_touch(h);h._refresh_drawer(),"后一页").disabled=(h.inventory_page+1)*3>=items.size()
	var selected:Dictionary = h.state.gear.get_item(h.selected_item)
	var equip:Button = h._qbutton(h.drawer,"equip_selected","已穿戴" if h.selected_item in h.state.gear.equipped.values() else ("交锋后穿戴" if _live_loadout_locked(h) else "穿上此物"),Rect2(x+530,y+238,74,27),func():
		if _guard_live_loadout(h):return
		if h.state.equip_item(h.selected_item):
			h._save_loadout();h._notice("已穿上 · "+str(selected.get("name","装备")),"equip");_touch(h);h._refresh_drawer(),"只替换同一部位，其他装备保持原样",true)
	equip.disabled=_live_loadout_locked(h) or selected.is_empty() or h.selected_item in h.state.gear.equipped.values()
	if _live_loadout_locked(h):equip.tooltip_text=LIVE_LOADOUT_HINT
	var salvage:Button = h._qbutton(h.drawer,"salvage_item","分解…",Rect2(x+354,y+238,74,27),func():
		h.salvage_pending=h.selected_item
		h.salvage_dialog.dialog_text="分解「"+str(selected.get("name","装备"))+"」后获得 %d 灵草。此物无法找回。"%h.state.gear.salvage_value(h.selected_item)
		h.salvage_dialog.popup_centered(),"分解前会确认；穿戴中的物品受到保护")
	salvage.disabled=selected.is_empty() or h.selected_item in h.state.gear.equipped.values()
	var enhancement:int = int(selected.get("enhancement",0))
	var method:String=str(h.get_meta("enhancement_method","herbs"))
	var quote:Dictionary=h.state.enhancement_quote(h.selected_item,method)
	_hit(h,"enhancement_method","切换淬炼材料",Rect2(x+388,y+222,180,14),func():
		h.set_meta("enhancement_method","materials" if method=="herbs" else "herbs");h._refresh_drawer(),"点击在草露温养与灵材淬炼间切换。两者提升同一件装备，必定成功，不消耗原装备。")
	var enhance:Button = h._qbutton(h.drawer,"enhance_item","已淬满" if enhancement>=5 else "淬炼 +%d"%(enhancement+1),Rect2(x+437,y+238,84,27),func():
		if h.selected_item in h.state.gear.equipped.values() and _guard_live_loadout(h):return
		var result:Dictionary=h.state.enhance_item(h.selected_item,method)
		if bool(result.get("ok",false)):
			h._save_loadout();h._notice(str(selected.get("name","装备"))+" · 淬炼 +%d"%int(result.get("enhancement",enhancement+1)),"equip");_touch(h);h._refresh_drawer(),_enhancement_hint(quote),true)
	enhance.disabled=(_live_loadout_locked(h) and h.selected_item in h.state.gear.equipped.values()) or selected.is_empty() or enhancement>=5 or not bool(quote.get("can_enhance",false))
	if _live_loadout_locked(h) and h.selected_item in h.state.gear.equipped.values():enhance.tooltip_text="交锋中的穿戴装备，待此敌结束后再淬炼。"

static func _cost_text(costs:Array,owned:bool=false)->String:
	var names:Array[String]=[]
	for cost in costs:names.append(str(cost.get("name",cost.get("id","材料")))+" %d"%int(cost.get("count",0))+(" / 有%d"%int(cost.get("owned",0)) if owned else ""))
	return " · ".join(names)

static func _enhancement_hint(quote:Dictionary)->String:
	var before:Dictionary=quote.get("before",{})
	var after:Dictionary=quote.get("after",{})
	return "消耗："+_cost_text(quote.get("costs",[]),true)+"\n攻击 %d → %d · 防御 %d → %d\n同一件装备 +%d → +%d，必定成功。"%[int(before.get("attack",0)),int(after.get("attack",0)),int(before.get("defense",0)),int(after.get("defense",0)),int(quote.get("from_rank",0)),int(quote.get("to_rank",0))]

static func draw_wardrobe(h, x:float, y:float, a:float):
	if h.wardrobe_tab=="technique":
		var attuned:Array=h.state.get("attuned_techniques") if h.state.get("attuned_techniques") is Array else []
		var training:Array=h.state.get("technique_training") if h.state.get("technique_training") is Array else []
		var pending:Dictionary=h.state.get("pending_heart_switch") if h.state.get("pending_heart_switch") is Dictionary else {}
		var subtitle:String="通习 %d/%d · 同修 %d/%d · 战斗真气与修为灵气分开"%[attuned.size(),h.state.attunement_capacity(),training.size(),h.state.training_capacity()]
		if not pending.is_empty():subtitle="调息重修 %.0f秒 · 旧心法生效 · 通习 %d/%d · 同修 %d/%d"%[ceilf(float(pending.get("remaining",0))),attuned.size(),h.state.attunement_capacity(),training.size(),h.state.training_capacity()]
		_book_header(h,"功 法 录",subtitle,x,y,605,a)
	elif h.wardrobe_tab=="equipment":
		if EquipmentComparison.is_open(h):
			_book_header(h,"换 装 比","",x,y,605,a)
			_txt(h,"当前搭配 → 候选搭配，仅替换同一部位",Vector2(x+111,y+37),12,a,FADED)
		elif CombatInsight.is_open(h):
			_book_header(h,"交 锋 札","",x,y,605,a)
			_txt(h,"看清搭配，选择下一场的打法",Vector2(x+111,y+37),12,a,FADED)
		else:
			_book_header(h,"行 装 谱","",x,y,605,a)
			_draw_evasion_summary(h,x,y,a)
	elif h.wardrobe_tab=="bag":
		_book_header(h,"百 工 囊","搜寻所得各有去处  ·  合成灵材，制作衣冠，再淬炼随身之物",x,y,605,a)
	else:
		_book_header(h,"山 路 卷" if h.wardrobe_tab=="expedition" else "行 装 谱","六章山路  ·  每一程都亲自启程" if h.wardrobe_tab=="expedition" else ("交锋中可翻阅试演 · 此敌结束后再换装与切换功法" if _live_loadout_locked(h) else "一物一身  ·  衣冠随缘"),x,y,605,a)
	for i in range(TABS.size()):
		var p:Vector2 = Vector2(x+621,y+65+i*33)
		var chosen:bool = h.wardrobe_tab==TABS[i]
		if chosen:
			h.draw_colored_polygon(PackedVector2Array([p+Vector2(0,1),p+Vector2(29,0),p+Vector2(28,30),p+Vector2(1,29)]),Color(RED,a*.08))
			h.draw_line(p+Vector2(29,1),p+Vector2(28,29),Color(RED,a*.78),2.0,true)
		else: _rule(h,p+Vector2(29,2),p+Vector2(29,29),a)
		var label:String = TAB_NAMES[i]
		_txt(h,label.substr(0,1),p+Vector2(7,13),12,a,RED if chosen else FADED,true)
		_txt(h,label.substr(1,1),p+Vector2(7,26),12,a,RED if chosen else FADED,true)
	match str(h.wardrobe_tab):
		"equipment":
			if EquipmentComparison.is_open(h): EquipmentComparison.draw(h,x,y,a)
			elif CombatInsight.is_open(h): CombatInsight.draw(h,x,y,a)
			else: _draw_equipment(h,x,y,a)
		"expedition": Adventure.draw_expedition(h,x,y,a)
		"meridian": Adventure.draw_meridian(h,x,y,a)
		"adventure": _draw_adventure(h,x,y,a)
		"technique": _draw_technique(h,x,y,a)
		_: _draw_bag(h,x,y,a)

static func _draw_equipment(h, x:float, y:float, a:float):
	_txt(h,"身 上",Vector2(x,y+71),10,a,FADED)
	_txt(h,"行 箧",Vector2(x+358,y+71),10,a,FADED)
	_rule(h,Vector2(x+164,y+63),Vector2(x+164,y+265),a)
	_rule(h,Vector2(x+337,y+63),Vector2(x+337,y+265),a)
	var slots:Array = ["head","chest","legs","feet","weapon"]
	for i in range(5):
		var slot:String = slots[i]
		var item:Dictionary = h.state.gear.equipped_item(slot)
		var yy:float = y+78+i*29
		if h.selected_slot==slot:
			h.draw_line(Vector2(x-5,yy+4),Vector2(x-4,yy+23),Color(RED,a*.8),2,true)
		if not item.is_empty(): _item_art(h,item,Rect2(x+1,yy+1,27,25),a)
		else:
			h.draw_arc(Vector2(x+14,yy+13),8,.1,TAU-.24,22,Color(RULE,a*.25),.7,true)
		_txt(h,str(SLOT_NAMES[slot]),Vector2(x+36,yy+12),11,a,INK,true)
		_txt(h,str(item.get("name","未穿戴")),Vector2(x+36,yy+25),9,a,FADED)
		if not item.is_empty(): _txt(h,"着",Vector2(x+137,yy+17),10,a,RED,true)
		_rule(h,Vector2(x+35,yy+28),Vector2(x+150,yy+28),a*.6)
	var item:Dictionary = h.state.gear.get_item(h.selected_item)
	if not item.is_empty():
		var age:float = maxf(0,float(h.elapsed)-float(h.get_meta("ink_specimen_time",-1.0)))
		var reveal:float = minf(1.0,.3+age*3.5)
		var rarity:Color = RARITY_INK.get(str(item.rarity),FADED)
		# A specimen rests on a pale, irregular ink pool, not a dashboard card.
		for i in range(7):
			h.draw_arc(Vector2(x+250+i*.35,y+154-i*.17),54+i*1.4,.27,TAU-.5,64,Color(JADE,a*.014),8.0,true)
		_item_art(h,item,Rect2(x+181,y+83+(1-reveal)*3,138,111),a*reveal)
		_center(h,str(item.get("name","山中所得"))+(" +%d"%int(item.get("enhancement",0)) if int(item.get("enhancement",0))>0 else ""),Rect2(x+172,y+192,157,24),16,a,INK,true)
		_center(h,str(RARITY_NAMES.get(item.rarity,"凡品"))+" · "+str(SLOT_NAMES.get(item.slot,"衣物"))+" · 一阶" if int(item.get("level",1))==1 else str(RARITY_NAMES.get(item.rarity,"凡品"))+" · "+str(SLOT_NAMES.get(item.slot,"衣物"))+" · %d阶"%item.get("level",1),Rect2(x+170,y+216,161,16),9,a,rarity)
		_center(h,"攻 +%d    御 +%d"%[item.get("attack",0),item.get("defense",0)],Rect2(x+169,y+235,162,16),11,a)
		_center(h,"吐纳 +%.0f%% · 闪避 +%.1f点"%[float(item.get("qi_bonus",0))*100,h.state.gear.item_evasion_bonus(item)*100],Rect2(x+168,y+253,164,14),10,a,FADED)
		if h.selected_item in h.state.gear.equipped.values(): _seal(h,"着",Vector2(x+301,y+84),a,21)
	else:
		_herb(h,Vector2(x+251,y+153),.58,a*.24)
		_center(h,"虚 席",Rect2(x+178,y+197,147,25),18,a*.6,FADED,true)
		_center(h,"点选行箧，细看一物。",Rect2(x+170,y+229,162,18),10,a,FADED)
		_center(h,"下装留白，短裤常在。",Rect2(x+168,y+249,166,16),9,a*.8,FADED)
	var items:Array = h.state.gear.inventory
	if items.is_empty():
		var chest:Texture2D = h.encounter_assets.get("chest_closed",null)
		if chest: h._fit_texture(chest,Rect2(x+426,y+81,100,81),Color(1,1,1,a))
		_center(h,"初来山中，身无长物。",Rect2(x+354,y+165,250,23),16,a,INK,true)
		_center(h,"启封一箱，结下一物之缘。",Rect2(x+354,y+193,250,18),11,a,FADED)
		return
	for i in range(3):
		var idx:int = int(h.inventory_page)*3+i
		if idx>=items.size(): break
		var entry:Dictionary = items[idx]
		var yy:float = y+78+i*41
		var selected:bool = h.selected_item==int(entry.id)
		if selected:
			h.draw_colored_polygon(PackedVector2Array([Vector2(x+353,yy+2),Vector2(x+603,yy),Vector2(x+604,yy+38),Vector2(x+355,yy+39)]),Color(JADE,a*.055))
		_item_art(h,entry,Rect2(x+358,yy+3,36,34),a)
		_txt(h,str(entry.get("name","装备")),Vector2(x+405,yy+18),13,a,INK,true)
		var rarity:Color = RARITY_INK.get(str(entry.rarity),FADED)
		_txt(h,str(RARITY_NAMES.get(entry.rarity,"凡品"))+" · "+str(SLOT_NAMES.get(entry.slot,"衣物"))+(" · 已穿戴" if int(entry.id) in h.state.gear.equipped.values() else ""),Vector2(x+405,yy+33),9,a,rarity)
		if selected: _seal(h,"选",Vector2(x+579,yy+10),a,19)
		_rule(h,Vector2(x+355,yy+40),Vector2(x+604,yy+40),a*.7)
	_center(h,"第 %d / %d 页  ·  %d 件"%[h.inventory_page+1,maxi(1,ceili(items.size()/3.0)),items.size()],Rect2(x+389,y+207,180,15),10,a,FADED)
	if not item.is_empty() and int(item.get("enhancement",0))<5:
		var quote:Dictionary=h.state.enhancement_quote(h.selected_item,str(h.get_meta("enhancement_method","herbs")))
		_center(h,_ellipsis(_cost_text(quote.get("costs",[]))+"  ↔ 切换",176,9),Rect2(x+388,y+222,180,13),9,a,JADE if bool(quote.get("can_enhance",false)) else FADED)

static func state_signature(h) -> String:
	# Progress is painted every frame; only control availability rebuilds paper.
	var status:Dictionary = h.state.journey_status()
	var stats:Dictionary = h.state.stats()
	var result:String = "%d/%d/%d/%d/%s/%s/%d/"%[h.state.herbs,h.state.dew,h.state.realm,int(h.state.qi>=float(stats.need_qi)),h.state.activity,h.state.technique,h.state.chest_count]
	result += str(h.state.technique_levels)+str(h.state.recipe)+str(h.state.pill_stocks)+str(h.state.auto_advance)
	var journey:Dictionary=h.state.player_journey_status()
	result += str(journey.id)+str(journey.kind)+str(journey.target)+str(h.state.journey_skipped)+str(h.state.guidance_dismissed)
	result += str(h.state.get("pending_heart_switch").is_empty()) if h.state.get("pending_heart_switch") is Dictionary else ""
	result += str(h.state.get("equipped_heart"))+str(h.state.get("equipped_weapon_art"))+str(h.state.get("equipped_actives"))+str(h.state.get("equipped_passives"))+str(h.state.get("attuned_techniques"))
	for manual in h.state.technique_rows():result+=str(manual.get("training",false))+str(manual.get("can_upgrade",false))+str(manual.get("can_attune",false))
	result += str(status.get("active",false))+str(status.get("completed",0))+str(status.get("repeat",false))
	result += str(h.state.gear.equipped)+str(h.state.buff_rows().size())+str(h.state.materials.inventory)
	if h.state.has_method("chapter_status"):result+=str(h.state.chapter_status())
	result += str(h.state.stage_status())+str(h.state.opportunity_status())+str(h.state.meridian_rows())+str(h.encounter_active)+str(_live_loadout_locked(h))
	for buff in h.state.buff_rows(): result += str(float(buff.seconds)>=3600.0-.000001)
	for item in h.state.gear.inventory: result += "/%d+%d"%[int(item.id),int(item.get("enhancement",0))]
	for quest in h.state.quest_rows(): result += str(quest.ready)+str(quest.claimed)+str(quest.unlocked)
	return result

static func _ellipsis(text:String,width:float,size:int) -> String:
	if SANS.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x<=width:return text
	var result:String=text
	while not result.is_empty() and SANS.get_string_size(result+"…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width:
		result=result.substr(0,result.length()-1)
	return result+"…" if width>=SANS.get_string_size("…",HORIZONTAL_ALIGNMENT_LEFT,-1,size).x else ""

static func _wrapped_lines(text:String,width:float,size:int,limit:int=2) -> Array[String]:
	# Preserve whole visible lines and mark overflow, including explicit newlines.
	# A paper excerpt never silently drops the end of a prerequisite or reward.
	var result:Array[String]=[]
	if limit<=0 or width<=0.0:return result
	var line:String=""
	for index in range(text.length()):
		var letter:String=text[index]
		if letter=="\n" or (not line.is_empty() and SANS.get_string_size(line+letter,HORIZONTAL_ALIGNMENT_LEFT,-1,size).x>width):
			if result.size()==limit-1:
				result.append(_ellipsis(line+"…",width,size));return result
			# Keep closing punctuation with its preceding character, never orphaned.
			if letter in "。，、！？：；）》】」』〕〉”’.,!?:;" and line.length()>1:
				result.append(line.substr(0,line.length()-1))
				line=line.substr(line.length()-1)+letter
			else:
				result.append(line)
				line="" if letter=="\n" else letter
		else:line+=letter
	if not line.is_empty():result.append(_ellipsis(line,width,size))
	return result

static func _wrap(h, text:String, p:Vector2, width:float, size:int, a:float, color:Color=FADED, lines:int=2):
	var rendered:Array[String]=_wrapped_lines(text,width,size,lines)
	for i in range(rendered.size()):_txt(h,rendered[i],p+Vector2(0,i*(size+6)),size,a,color)

static func _meter(h, r:Rect2, progress:float, a:float):
	_rule(h,r.position,r.end,a,true)
	h.draw_line(r.position,r.position+Vector2(r.size.x*clampf(progress,0,1),0),Color(RED,a*.7),1.7,true)

static func _duration(seconds:float) -> String:
	var n:int = maxi(0,ceili(seconds))
	return "%d分%02d秒"%[n/60,n%60] if n>=60 else "%d秒"%n

static func _reward_text(rewards) -> String:
	if rewards is String: return str(rewards)
	var parts:Array[String] = []
	for key in ["herbs","dew","qi","chests","bond"]:
		if float(rewards.get(key,0))>0:
			parts.append(str({"herbs":"草","dew":"露","qi":"灵气","chests":"木箱","bond":"羁绊"}[key])+" +"+str(int(rewards[key])))
	return " · ".join(parts)

static func _build_adventure(h, x:float, y:float):
	var rows:Array = h.state.journey_rows()
	var status:Dictionary = h.state.journey_status()
	var selected:String = str(h.get_meta("ink_journey_id","bamboo"))
	var chosen:Dictionary = {}
	for i in range(rows.size()):
		var entry:Dictionary = rows[i]
		var id:String = str(entry.id)
		if id==selected: chosen=entry
		_hit(h,"journey_"+id,str(entry.name),Rect2(x+211,y+64+i*43,393,42),func():
			h.set_meta("ink_journey_id",id);_touch(h);h._refresh_drawer(),str(entry.description)+" · "+_reward_text(entry.get("rewards",{})))
	var active:bool = bool(status.get("active",false))
	var can_go:bool = not active and bool(chosen.get("unlocked",false))
	var dispatch:Button = h._qbutton(h.drawer,"journey_dispatch","灵狐在途" if active else ("托狐远游" if can_go else "境界未至"),Rect2(x+211,y+201,183,29),func():
		var result:Dictionary = h.state.start_journey(selected,bool(h.get_meta("ink_journey_repeat",status.get("repeat",false))))
		if bool(result.get("ok",false)):
			h._notice("灵狐循山径而去，归来所得会自动收入行囊。","equip");h._save_loadout();h._refresh_drawer(),"远游与静修同时进行，归来自动带回物资与羁绊",true)
	dispatch.disabled=not can_go
	var repeat_value:bool = bool(status.get("repeat",false)) if active else bool(h.get_meta("ink_journey_repeat",status.get("repeat",false)))
	h._qbutton(h.drawer,"journey_repeat","往返游历 · "+("开" if repeat_value else "关"),Rect2(x+411,y+201,193,29),func():
		var value:bool = not repeat_value
		h.set_meta("ink_journey_repeat",value);h.state.set_journey_repeat(value);h._save_loadout();h._refresh_drawer(),"开启后灵狐归来会再去同一处；不启动切磋",false,repeat_value)
	h._qbutton(h.drawer,"show_expedition","亲自历练 ↗",Rect2(x,y+240,137,27),func():h.wardrobe_tab="expedition";h._refresh_drawer(),"手选关卡后亲点出发；不自动连关",true)
	h._qbutton(h.drawer,"open_chest","启封木箱 · %d"%h.state.chest_count,Rect2(x+298,y+240,148,27),h._open_treasure,"启封现有木箱；历练每击退有12%几率获得",true).disabled=h.state.chest_count<=0
	h._qbutton(h.drawer,"show_equipment","翻阅衣冠  ↗",Rect2(x+458,y+240,146,27),func():h.wardrobe_tab="equipment";_touch(h);h._refresh_drawer())

static func _draw_adventure(h, x:float, y:float, a:float):
	var status:Dictionary = h.state.journey_status()
	var active:bool = bool(status.get("active",false))
	_rule(h,Vector2(x+195,y+66),Vector2(x+195,y+225),a)
	var fox:Texture2D = h.encounter_assets.get("fox_idle",null)
	if fox: h._fit_texture(fox,Rect2(x+14,y+61,165,97),Color(1,1,1,a))
	_center(h,str(status.get("bond_name","初识"))+" · 羁绊 %d"%int(status.get("bond",0)),Rect2(x,y+157,185,19),12,a,INK,true)
	_center(h,(str(status.get("name","山间"))+" · "+_duration(float(status.get("seconds_left",0)))) if active else "灵狐在侧，静候远游。",Rect2(x,y+183,185,16),10,a,FADED)
	_meter(h,Rect2(x+12,y+208,160,0),float(status.get("progress",0)) if active else 0.0,a)
	_txt(h,"归来自动归囊 · 已游 %d 回"%int(status.get("completed",0)),Vector2(x+5,y+228),9,a,FADED)
	var rows:Array = h.state.journey_rows()
	var selected:String = str(h.get_meta("ink_journey_id","bamboo"))
	for i in range(rows.size()):
		var entry:Dictionary=rows[i]
		var yy:float=y+64+i*43
		var unlocked:bool=bool(entry.unlocked)
		if str(entry.id)==selected:
			h.draw_line(Vector2(x+210,yy+6),Vector2(x+210,yy+35),Color(RED,a*.75),2,true)
		_txt(h,str(entry.name),Vector2(x+223,yy+18),15,a,INK if unlocked else FADED,true)
		_txt(h,_duration(float(entry.seconds)) if unlocked else h.state.REALM_NAMES[int(entry.unlock_realm)]+"解锁",Vector2(x+498,yy+18),10,a,FADED)
		_txt(h,_reward_text(entry.get("rewards",{})),Vector2(x+223,yy+35),10,a,FADED)
		_rule(h,Vector2(x+222,yy+42),Vector2(x+604,yy+42),a*.7)

const MANUAL_FILTERS := ["all", "heart", "weapon_art", "spell", "defense", "movement", "body", "support"]
const MANUAL_FILTER_NAMES := {"all":"全部", "heart":"心法", "weapon_art":"武技", "spell":"术法", "defense":"护体", "movement":"身法", "body":"炼体", "support":"辅助功能"}
const MANUAL_SLOT_NAMES := {"heart":"心法", "weapon_art":"武式", "active":"主动", "passive":"辅修"}
const MANUALS_PER_PAGE := 3

static func _manual_filter(h) -> String:
	var id:String=str(h.get_meta("ink_manual_filter", "all"))
	return id if MANUAL_FILTERS.has(id) else "all"

static func _manual_rows(h) -> Array:
	var rows:Array=[]
	var filter:String=_manual_filter(h)
	for row in h.state.technique_rows():
		if filter=="all" or str(MANUAL_FILTER_NAMES[filter]) in row.get("tags", []):rows.append(row)
	return rows

static func _manual_page(h, rows:Array) -> int:
	return clampi(int(h.get_meta("ink_manual_page",0)),0,maxi(0,ceili(rows.size()/float(MANUALS_PER_PAGE))-1))

static func _technique_selected(h) -> Dictionary:
	var rows:Array=_manual_rows(h)
	var selected:String=str(h.get_meta("ink_technique_id",h.state.technique))
	var first:int=_manual_page(h,rows)*MANUALS_PER_PAGE
	for index in range(first,mini(first+MANUALS_PER_PAGE,rows.size())):
		if str(rows[index].id)==selected:return rows[index]
	return rows[first] if not rows.is_empty() else {}

static func _manual_name(h, id:String) -> String:
	return str(h.state.Content.TECHNIQUES.get(id,{}).get("name","未选"))

static func _manual_names(h, ids:Array) -> String:
	var names:Array[String]=[]
	for id in ids:names.append(_manual_name(h,str(id)))
	return "、".join(names) if not names.is_empty() else "未选"

static func _manual_loadout(h) -> Dictionary:
	return {"heart":str(h.state.get("equipped_heart")), "weapon_art":str(h.state.get("equipped_weapon_art")),
		"active":h.state.get("equipped_actives") if h.state.get("equipped_actives") is Array else [],
		"passive":h.state.get("equipped_passives") if h.state.get("equipped_passives") is Array else []}

static func _manual_loadout_text(h) -> String:
	var loadout:Dictionary=_manual_loadout(h)
	var weapon:Dictionary=h.state.stats().get("weapon_skill",{})
	return "心法 · "+_manual_name(h,loadout.heart)+"\n武式 · "+_manual_name(h,loadout.weapon_art)+"\n主动 · "+_manual_names(h,loadout.active)+"\n辅修 · "+_manual_names(h,loadout.passive)+"\n兵器自带 · "+str(weapon.get("name","无"))+"\n战斗真气用于出招；修为灵气用于突破与换修。"

static func _manual_is_slotted(row:Dictionary, slot:String) -> bool:
	return slot in row.get("equipped_slots",[])

static func _manual_inspect(h,id:String):
	h.set_meta("ink_technique_id",id);h.set_meta("preview_technique",id);h.set_meta("ink_heart_quote",{})
	if is_instance_valid(h.character_preview):h.character_preview.cancel_technique()
	_touch(h);h._refresh_drawer()

static func _manual_outcome(h,result:Variant,success:String):
	var ok:bool=bool(result.get("ok",false)) if result is Dictionary else bool(result)
	if ok:h._save_loadout();h._notice(success,"equip")
	elif result is Dictionary:
		var reason:String=str(result.get("message",result.get("detail",result.get("reason","当前无法操作"))))
		var reasons:Dictionary={"courtyard_only":"尚有未完之程；归山并放下此程后，再换修心法。", "not_attuned_or_learned":"此法需先纳入通习并完成初悟。", "already_passive":"此法正在辅修栏运转；先卸下辅修，再换为心法。", "active_slots_full":"主动栏已满；先从原功法页卸下一法。", "passive_slots_full":"辅修栏已满；先卸下当前辅修。", "attunement_full":"通习已满；先收起未装配、未参悟的功法。", "equipped":"正在装配中，先卸下后再收起。", "training":"正在参悟中，请待完成。", "heart_adjusting":"正在调息换修，完成后才能再次调整。", "stage_active":"山路尚未归结；归山并放下未完之程后再换心法。", "stage_pending":"尚有未完之程；放下后再换心法。", "not_attuned":"请先纳入通习。", "not_learned":"请先初悟此法。", "stale_quote":"状态已改变，请重新查看换修代价。", "resources":"修为或草露不足，请备齐所示代价。"}
		h._notice(str(reasons.get(reason,reason)))
	h._refresh_drawer()

static func _manual_training_text(h,row:Dictionary) -> String:
	if bool(row.get("training",false)):
		return "参悟中 · %.0f秒 · %d%%"%[ceilf(float(row.get("training_remaining",0))),roundi(float(row.get("training_progress",0))*100.0)]
	if int(row.get("level",0))>=int(row.get("max_level",1)):return "功行圆满 · 已至本法上限"
	var duration:float=float(row.get("next_training_duration",row.get("training_duration",0)))
	return "下重需 %d草 · %d露 · %.0f秒"%[int(row.get("cost_herbs",0)),int(row.get("cost_dew",0)),duration]

static func _manual_hint(h,row:Dictionary) -> String:
	var gate:int=clampi(int(row.get("next_rank_realm",row.get("unlock_realm",0))),0,h.state.MAX_REALM)
	return str(row.get("description",""))+"\n"+str(row.get("effect",""))+"\n"+_manual_training_text(h,row)+"\n下重境界 · "+str(h.state.REALM_NAMES[gate])+"\n"+str(row.get("prerequisite_text",""))+"\n"+str(row.get("locked_reason",""))+"\n"+str(row.get("inactive_reason",""))

static func _build_technique(h, x:float, y:float):
	for i in range(MANUAL_FILTERS.size()):
		var filter:String=MANUAL_FILTERS[i]
		h._qbutton(h.drawer,"tech_category_"+filter,str(MANUAL_FILTER_NAMES[filter]),Rect2(x+i*76,y+59,72,24),func():
			h.set_meta("ink_manual_filter",filter);h.set_meta("ink_manual_page",0);h.set_meta("ink_heart_quote",{});h._refresh_drawer(),"按标签翻阅；标签不限制装配栏位。",false,_manual_filter(h)==filter)
	var rows:Array=_manual_rows(h)
	var page:int=_manual_page(h,rows)
	var pages:int=maxi(1,ceili(rows.size()/float(MANUALS_PER_PAGE)))
	_hit(h,"manual_loadout_summary",_manual_loadout_text(h),Rect2(x+227,y+86,378,25),func():h._notice(_manual_loadout_text(h)),_manual_loadout_text(h))
	h._qbutton(h.drawer,"tech_prev","‹",Rect2(x,y+88,28,23),func():h.set_meta("ink_manual_page",maxi(0,page-1));h.set_meta("ink_heart_quote",{});h._refresh_drawer(),"前页").disabled=page<=0
	h._qbutton(h.drawer,"tech_next","›",Rect2(x+177,y+88,28,23),func():h.set_meta("ink_manual_page",mini(pages-1,page+1));h.set_meta("ink_heart_quote",{});h._refresh_drawer(),"后页").disabled=page>=pages-1
	for i in range(MANUALS_PER_PAGE):
		var index:int=page*MANUALS_PER_PAGE+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		var id:String=str(row.id)
		_hit(h,"equip_"+id,str(row.name),Rect2(x,y+116+i*38,205,37),func():_manual_inspect(h,id),_manual_hint(h,row))
	var selected:Dictionary=_technique_selected(h)
	if selected.is_empty():return
	var id:String=str(selected.id)
	h.set_meta("preview_technique",id)
	var training:bool=bool(selected.get("training",false))
	var full:bool=int(selected.get("level",0))>=int(selected.get("max_level",1))
	var train:Button=h._qbutton(h.drawer,"train_technique","参悟中" if training else ("功行圆满" if full else ("初悟此法" if int(selected.get("level",0))==0 else "参悟一重")),Rect2(x,y+240,112,28),func():
		if _guard_live_loadout(h):return
		var result:Dictionary=h.state.upgrade_technique(id)
		_manual_outcome(h,result,str(selected.name)+" · 已开始参悟，完成后保留已选装配。"),_manual_hint(h,selected),true)
	train.disabled=_live_loadout_locked(h) or not bool(selected.get("can_upgrade",false))
	if _live_loadout_locked(h):train.tooltip_text=LIVE_LOADOUT_HINT
	h._qbutton(h.drawer,"practice_preview","展卷试演",Rect2(x+120,y+240,85,28),func():
		h.set_meta("preview_technique",id)
		if is_instance_valid(h.character_preview):h.character_preview.play_technique(),"只演示书旁人物；不耗资源、不替换装配。兵器不合时只观气劲；心法、炼体只显被动灵息。")
	var quote:Dictionary=h.get_meta("ink_heart_quote",{})
	if not quote.is_empty() and str(quote.get("id",quote.get("new_id","")))==id:
		_build_heart_confirmation(h,x,y,quote);return
	var slots:Array=selected.get("slots",[])
	var count:int=slots.size()+1
	var width:float=(378.0-(count-1)*6.0)/maxi(count,1)
	var attuned:bool=bool(selected.get("attuned",false))
	var attune:Button=h._qbutton(h.drawer,"attune_technique","收起通习" if attuned else "纳入通习",Rect2(x+227,y+240,width,28),func():
		if _guard_live_loadout(h):return
		var result:Dictionary=h.state.unattune_technique(id) if attuned else h.state.attune_technique(id)
		_manual_outcome(h,result,str(selected.name)+(" · 已收起，重数保留。" if attuned else " · 纳入通习。")),"通习容量随境界增长；收起后已学重数保留。已装配或正在参悟时不可收起。")
	attune.disabled=_live_loadout_locked(h) or (attuned and (not selected.get("equipped_slots",[]).is_empty() or training)) or (not attuned and not bool(selected.get("can_attune",false)))
	for i in range(slots.size()):
		var slot:String=str(slots[i])
		var worn:bool=_manual_is_slotted(selected,slot)
		var label:String=("卸下" if worn else "装入")+str(MANUAL_SLOT_NAMES.get(slot,slot))
		if slot=="heart":label="现修心法" if worn else "换修心法…"
		var control:Button=h._qbutton(h.drawer,"manual_slot_"+slot,label,Rect2(x+227+(i+1)*(width+6),y+240,width,28),func():
			if _guard_live_loadout(h):return
			if slot=="heart":
				var result:Dictionary=h.state.quote_heart_switch(id)
				if bool(result.get("ok",false)):
					result["id"]=id;h.set_meta("ink_heart_quote",result);h._refresh_drawer()
				else:_manual_outcome(h,result,"")
				return
			var result:Variant=h.state.unequip_technique(id,slot) if worn else h.state.equip_technique(id,slot)
			_manual_outcome(h,result,str(selected.name)+(" · 已从" if worn else " · 已装入")+str(MANUAL_SLOT_NAMES.get(slot,slot))+"栏。"),_manual_hint(h,selected)+"\n"+_manual_slot_hint(h,slot),true,worn)
		control.disabled=_live_loadout_locked(h) or (slot=="heart" and worn) or (not worn and (int(selected.get("level",0))<1 or not attuned or not bool(selected.get("unlocked",false))))
		if not worn and slot=="active" and h.state.equipped_actives.size()>=h.state.active_capacity():
			control.disabled=true;control.text="主动已满";control.tooltip_text+="\n主动栏已满；请先从已装配功法页卸下一法。"
		if not worn and slot=="passive" and h.state.equipped_passives.size()>=h.state.passive_capacity():
			control.disabled=true;control.text="筑基启辅修" if h.state.passive_capacity()<=0 else "辅修已满";control.tooltip_text+="\n"+_manual_slot_hint(h,slot)
		if slot=="heart" and not h.state.pending_heart_switch.is_empty():
			control.disabled=true;control.text="调息重修中";control.tooltip_text="调息中不能再次换修；完成前旧心法继续生效。"
		elif slot=="heart" and not h.state.stage_run.is_empty():
			control.disabled=true;control.text="归山后换修";control.tooltip_text="需归山并放下未完之程，才可换修心法。"
		if _live_loadout_locked(h):control.tooltip_text=LIVE_LOADOUT_HINT

static func _manual_slot_hint(h,slot:String) -> String:
	if slot=="heart":return "心法仅在归山后换修；先查看旧法、新法、材料与调息时间，再亲自确认。"
	if slot=="weapon_art":return "武式改变相配兵器普攻；主动招式需另装主动栏。落英的身法跨兵器生效，扇招仍须持扇，不会自动换兵器。"
	if slot=="active":return "主动栏 %d 格；筑基初期增至 2 格。各法冷却独立。落英另有跨兵器身法，与武式栏不重复叠加。"%h.state.active_capacity()
	return "辅修栏 %d 格；筑基初期开启 1 格。与心法同时生效。"%h.state.passive_capacity()

static func _build_heart_confirmation(h,x:float,y:float,quote:Dictionary):
	h._qbutton(h.drawer,"cancel_heart_switch","暂不换修",Rect2(x+227,y+240,153,28),func():h.set_meta("ink_heart_quote",{});h._refresh_drawer(),"不支付、不改变当前心法。")
	h._qbutton(h.drawer,"confirm_heart_switch","确认代价 · 开始调息",Rect2(x+388,y+240,217,28),func():
		if _guard_live_loadout(h):return
		var result:Dictionary=h.state.confirm_heart_switch(quote)
		h.set_meta("ink_heart_quote",{})
		_manual_outcome(h,result,"已启用 · "+_manual_name(h,str(quote.get("to_id",""))) if h.state.pending_heart_switch.is_empty() else "已开始调息重修；完成前旧心法仍然生效。"),"支付已列代价并开始计时。调息中不能出发或再次换修；功法等级保留。\n代价依据："+str(quote.get("cost_reason","所选心法、境界与重数"))+"\n旧法："+str(quote.get("old_effect","无"))+"\n新法："+str(quote.get("new_effect","")),true).disabled=_live_loadout_locked(h)

static func _technique_art(h,id:String,r:Rect2,a:float):
	var texture:Texture2D=h.avatar_assets.get("mist_slash" if id=="mist" else "petal",null) if id in ["mist","petal"] else null
	if texture:h._fit_texture(texture,r,Color(1,1,1,a));return
	var c:Vector2=r.get_center()
	var color:Color=Color("b57b52") if id=="ember" else (Color("849cae") if id=="frost" else (Color("9c85af") if id=="thunder" else JADE))
	if id=="thunder":h.draw_polyline(PackedVector2Array([c+Vector2(4,-15),c+Vector2(-5,2),c+Vector2(5,-1),c+Vector2(-4,15)]),Color(color,a*.7),2,true)
	else:
		for i in range(3):h.draw_arc(c,7+i*4,.15+i*.2,TAU-.3-i*.2,30,Color(color,a*(.40-i*.08)),1.1,true)

static func _combat_description(h,id:String) -> String:
	return str(h.state.Content.TECHNIQUES.get(id,{}).get("description",""))

static func _draw_heart_confirmation(h,x:float,y:float,a:float,quote:Dictionary):
	var old_id:String=str(quote.get("from_id",h.state.get("equipped_heart")))
	var new_id:String=str(quote.get("to_id",quote.get("id","")))
	_txt(h,"换修心法 · 请先核对",Vector2(x+229,y+130),18,a,INK,true)
	_wrap(h,_manual_name(h,old_id)+" → "+_manual_name(h,new_id),Vector2(x+229,y+151),370,12,a,RED,1)
	var costs:Dictionary=quote.get("cost",quote.get("costs",{}))
	var qi:float=float(quote.get("cost_qi",costs.get("qi",0)))
	var herbs:int=int(quote.get("cost_herbs",costs.get("herbs",0)))
	var dew:int=int(quote.get("cost_dew",costs.get("dew",0)))
	var seconds:float=float(quote.get("duration",quote.get("seconds",0)))
	_txt(h,"支付 %d %s · %d 草 · %d 露 · 调息 %.0f秒"%[int(qi),"功德" if str(quote.get("energy_name",""))=="功德" else "修为灵气",herbs,dew,seconds],Vector2(x+229,y+171),11,a,RED)
	var delta:Dictionary=quote.get("stat_delta",{})
	var delta_text:String="气血%+.0f · 战气%+.0f · 回气%+.2f/秒 · 定力%+.0f"%[float(delta.get("max_hp",0)),float(delta.get("combat_qi_max",0)),float(delta.get("combat_qi_regen",0)),float(delta.get("poise_bonus",0))]
	_txt(h,delta_text,Vector2(x+229,y+190),10,a,JADE)
	_wrap(h,"旧 · "+str(quote.get("old_effect","无")),Vector2(x+229,y+208),373,10,a,FADED,1)
	_wrap(h,"新 · "+str(quote.get("new_effect","")),Vector2(x+229,y+226),373,10,a,INK,1)

static func _draw_technique(h, x:float, y:float, a:float):
	_rule(h,Vector2(x+215,y+115),Vector2(x+215,y+269),a)
	var rows:Array=_manual_rows(h)
	var selected:Dictionary=_technique_selected(h)
	var page:int=_manual_page(h,rows)
	_center(h,"%d / %d 页 · %d部"%[page+1,maxi(1,ceili(rows.size()/float(MANUALS_PER_PAGE))),rows.size()],Rect2(x+29,y+91,147,17),10,a,FADED)
	var loadout:Dictionary=_manual_loadout(h)
	var active_count:int=loadout.active.size()
	var passive_count:int=loadout.passive.size()
	_txt(h,_ellipsis("心法 "+_manual_name(h,loadout.heart)+" · 武式 "+_manual_name(h,loadout.weapon_art),373,10),Vector2(x+229,y+95),10,a,INK)
	var weapon:Dictionary=h.state.stats().get("weapon_skill",{})
	_txt(h,_ellipsis("主动 %d/%d · 辅修 %d/%d · 兵器技 %s"%[active_count,h.state.active_capacity(),passive_count,h.state.passive_capacity(),str(weapon.get("name","无"))],373,10),Vector2(x+229,y+109),10,a,FADED)
	for i in range(MANUALS_PER_PAGE):
		var index:int=page*MANUALS_PER_PAGE+i
		if index>=rows.size():break
		var row:Dictionary=rows[index]
		var yy:float=y+116+i*38
		if str(row.id)==str(selected.get("id","")):h.draw_line(Vector2(x-3,yy+5),Vector2(x-3,yy+32),Color(RED,a*.8),2,true)
		_txt(h,str(row.name),Vector2(x+5,yy+16),14,a,INK if bool(row.get("unlocked",false)) else FADED,true)
		var sub:String="第%d/%d重"%[int(row.get("level",0)),int(row.get("max_level",1))]
		if bool(row.get("training",false)):sub+=" · 参悟 %.0f秒"%ceilf(float(row.get("training_remaining",0)))
		elif not bool(row.get("unlocked",false)):sub+=" · 待启"
		elif not bool(row.get("attuned",false)):sub+=" · 藏书"
		elif not row.get("equipped_slots",[]).is_empty():sub+=" · 已装配" if bool(row.get("active",true)) else (" · 身法生效" if bool(row.get("movement_active",false)) else " · 暂未生效")
		else:sub+=" · 通习"
		_txt(h,sub,Vector2(x+5,yy+31),10,a,JADE if bool(row.get("active",false)) or bool(row.get("movement_active",false)) else FADED)
		_rule(h,Vector2(x+5,yy+37),Vector2(x+200,yy+37),a*.65)
	if selected.is_empty():return
	var quote:Dictionary=h.get_meta("ink_heart_quote",{})
	if not quote.is_empty() and str(quote.get("id",quote.get("new_id","")))==str(selected.id):
		_draw_heart_confirmation(h,x,y,a,quote);return
	_technique_art(h,str(selected.id),Rect2(x+228,y+117,31,32),a)
	_txt(h,str(selected.name),Vector2(x+269,y+135),20,a,INK,true)
	_txt(h,"第%d/%d重"%[int(selected.get("level",0)),int(selected.get("max_level",1))],Vector2(x+528,y+133),10,a,FADED)
	var tags:String=" · ".join(selected.get("tags",[]))
	var required:String=str(selected.get("required_weapon",""))
	var compatibility:String=("需剑" if required in ["sword","weapon_sword"] else "需扇") if not required.is_empty() else "兵器不限"
	if not bool(selected.get("compatible",true)):compatibility+=" · 扇招停用，身法生效" if bool(selected.get("movement_active",false)) else " · 不匹配，选择保留"
	_txt(h,_ellipsis(tags+" · "+compatibility,373,10),Vector2(x+229,y+153),10,a,RED if not bool(selected.get("compatible",true)) else FADED)
	var cost:float=float(selected.get("qi_cost",0))
	_txt(h,"被动生效 · 不耗战斗真气 · 无冷却" if cost<=0 else "主动耗 %d 战斗真气 · 基础冷却 %.0f秒"%[int(cost),float(selected.get("cooldown",0))],Vector2(x+229,y+171),11,a,JADE)
	_wrap(h,str(selected.get("effect","")),Vector2(x+229,y+189),373,11,a,INK,1)
	var gate:int=clampi(int(selected.get("next_rank_realm",selected.get("unlock_realm",0))),0,h.state.MAX_REALM)
	var reason:String=str(selected.get("locked_reason",""))
	var prerequisite:String=str(selected.get("prerequisite_text",""))
	var gate_text:String="下重 · "+str(h.state.REALM_NAMES[gate])+(" · "+prerequisite if not prerequisite.is_empty() else "")
	if not reason.is_empty():gate_text="下重 · "+str(h.state.REALM_NAMES[gate])+" · "+reason
	_wrap(h,gate_text,Vector2(x+229,y+208),373,10,a,FADED,1)
	_txt(h,_manual_training_text(h,selected),Vector2(x+229,y+227),10,a,JADE if bool(selected.get("training",false)) else FADED)
	if bool(selected.get("training",false)):_meter(h,Rect2(x+229,y+233,373,0),float(selected.get("training_progress",0)),a)

const CRAFTS_PER_PAGE := 4

static func _craft_selected(h)->Dictionary:
	var rows:Array=h.state.crafting_rows()
	var id:String=str(h.get_meta("craft_recipe","refine_stone"))
	for row in rows:
		if str(row.id)==id:return _craft_quote(h,row)
	return rows[0] if not rows.is_empty() else {}

static func _craft_quote(h,row:Dictionary)->Dictionary:
	if not row.has("alternatives"):return row
	var material:String=str(h.get_meta("craft_material_"+str(row.id),""))
	if not material in row.alternatives:
		# Pin the preview to one mundane ingredient. Running out never silently
		# chooses another stack, and rare jade is used only after an explicit cycle.
		material=str(row.get("selected_material",row.alternatives[0]))
		if material=="spirit_jade":material=str(row.alternatives[0])
		h.set_meta("craft_material_"+str(row.id),material)
	return h.state.crafting_quote(str(row.id),material)

static func _craft_page(h,rows:Array)->int:
	var selected:String=str(h.get_meta("craft_recipe","refine_stone"))
	for i in range(rows.size()):
		if str(rows[i].id)==selected:
			h.set_meta("craft_page",i/CRAFTS_PER_PAGE)
			return i/CRAFTS_PER_PAGE
	h.set_meta("craft_page",0)
	if not rows.is_empty():h.set_meta("craft_recipe",str(rows[0].id))
	return 0

static func inspect_craft(h,id:String):
	var rows:Array=h.state.crafting_rows()
	for i in range(rows.size()):
		if str(rows[i].id)!=id:continue
		h.set_meta("craft_recipe",id);h.set_meta("craft_page",i/CRAFTS_PER_PAGE)
		h.set_meta("craft_receipt","")
		_craft_quote(h,rows[i])
		h._refresh_drawer()
		return

static func _turn_craft_page(h,direction:int):
	var rows:Array=h.state.crafting_rows()
	if rows.is_empty():return
	var page:int=clampi(_craft_page(h,rows)+direction,0,(rows.size()-1)/CRAFTS_PER_PAGE)
	inspect_craft(h,str(rows[page*CRAFTS_PER_PAGE].id))

static func _cycle_craft_material(h,id:String):
	var row:Dictionary=h.state.crafting_quote(id)
	var alternatives:Array=row.get("alternatives",[])
	if alternatives.is_empty():return
	var current:String=str(_craft_quote(h,row).get("selected_material",""))
	h.set_meta("craft_material_"+id,str(alternatives[(alternatives.find(current)+1)%alternatives.size()]))
	h.set_meta("craft_receipt","");h._refresh_drawer()

static func _craft_status(row:Dictionary)->String:
	if not bool(row.get("unlocked",true)):return str(row.get("unlock_text","尚未解锁"))
	match str(row.get("reason","")):
		"inventory_full":return "行囊装备已满"
		"material_full":return "成物材料已满"
	return "材料齐备" if bool(row.get("can_craft",false)) else "待收集材料"

static func _craft_comparison(row:Dictionary)->String:
	var comparison:Dictionary=row.get("comparison",{})
	if comparison.is_empty():return "用于衣冠页灵材淬炼，原装备必定提升一级。"
	return "较身上：攻 %+d · 御 %+d · 闪避 %+.1f点 · 吐纳 %+.1f%%"%[int(comparison.get("attack_delta",0)),int(comparison.get("defense_delta",0)),float(comparison.get("evasion_delta",0))*100,float(comparison.get("qi_delta",0))*100]

static func _craft_hint(row:Dictionary)->String:
	var result:String=str(row.get("description",""))+"\n"+_craft_status(row)+"\n消耗："+_cost_text(row.get("costs",[]),true)
	result+="\n成物："+str(row.get("output_name",""))+" ×%d"%int(row.get("output_count",1))
	var comparison:Dictionary=row.get("comparison",{})
	if not comparison.is_empty():
		result+="\n"+str(SLOT_NAMES.get(str(comparison.get("slot","")),"身上"))+"："+str(comparison.get("equipped_name","未穿戴"))+" → "+str(row.get("output_name",""))
	result+="\n"+_craft_comparison(row)
	return result+"\n制成收入行囊，装备需亲手穿戴。" if not comparison.is_empty() else result

static func _perform_craft(h,id:String,material:String):
	if _guard_live_loadout(h):return
	# Use a fresh quote, but keep precisely the ingredient the player saw.
	var quote:Dictionary=h.state.crafting_quote(id,material)
	if not bool(quote.get("can_craft",false)):
		h._notice(_craft_status(quote)+"，未消耗任何材料。");h._refresh_drawer();return
	var result:Dictionary=h.state.craft_recipe(id,material)
	if not bool(result.get("ok",false)):
		h._notice("材料或空间不足，未消耗任何材料。");h._refresh_drawer();return
	h.set_meta("craft_receipt","已入囊 · "+str(quote.get("output_name",""))+" ×%d"%int(quote.get("output_count",1))+" · 耗 "+_cost_text(quote.get("costs",[])))
	if result.get("item") is Dictionary and not result.item.is_empty():
		h.selected_item=int(result.item.id);h.selected_slot=str(result.item.slot);h.inventory_page=maxi(0,(h.state.inventory.size()-1)/3)
	h.set_meta("enhancement_method","materials")
	h._save_loadout();h._notice("百工成物 · "+str(quote.get("output_name",""))+" · 已入行囊","loot");h._refresh_drawer()

static func _build_bag(h,x:float,y:float):
	var view:String=str(h.get_meta("bag_view","materials"))
	var choices:Array=["materials","craft","supplies"]
	for i in range(3):
		var choice:String=choices[i]
		_hit(h,"bag_view_"+choice,["山材","百工","药囊"][i],Rect2(x+i*74,y+60,68,25),func():h.set_meta("bag_view",choice);h._refresh_drawer(),["材料数量、出处与用途","合成灵材，制作真实装备","草露与丹药库存"][i])
	if view=="craft":
		var rows:Array=h.state.crafting_rows()
		var page:int=_craft_page(h,rows)
		for i in range(CRAFTS_PER_PAGE):
			var index:int=page*CRAFTS_PER_PAGE+i
			if index>=rows.size():break
			var row:Dictionary=_craft_quote(h,rows[index])
			var id:String=str(row.id)
			_hit(h,"craft_recipe_"+id,str(row.name),Rect2(x,y+95+i*34,207,32),func():inspect_craft(h,id),_craft_hint(row))
		h._qbutton(h.drawer,"craft_prev","‹",Rect2(x,y+238,31,27),func():_turn_craft_page(h,-1),"前一页配方").disabled=page<=0
		h._qbutton(h.drawer,"craft_next","›",Rect2(x+176,y+238,31,27),func():_turn_craft_page(h,1),"后一页配方").disabled=(page+1)*CRAFTS_PER_PAGE>=rows.size()
		var row:Dictionary=_craft_selected(h)
		if row.has("alternatives"):
			h._qbutton(h.drawer,"craft_material_next","换用材料 ↻",Rect2(x+493,y+138,111,25),func():_cycle_craft_material(h,str(row.id)),"只消耗当前列明的材料；耗尽不会改用别种。灵髓玉珍稀，须主动切换才使用。")
		var label:String="尚待解锁" if not bool(row.get("unlocked",true)) else ("合成" if str(row.get("id","")).begins_with("refine") else "制作入囊")
		var craft:Button=h._qbutton(h.drawer,"craft_selected",label,Rect2(x+232,y+238,162,27),func():_perform_craft(h,str(row.get("id","")),str(row.get("selected_material",""))),_craft_hint(row),true)
		craft.disabled=_live_loadout_locked(h) or not bool(row.get("can_craft",false))
		if _live_loadout_locked(h):craft.tooltip_text=LIVE_LOADOUT_HINT
		h._qbutton(h.drawer,"craft_to_equipment","穿戴 / 淬炼 ↗",Rect2(x+412,y+238,192,27),func():h.wardrobe_tab="equipment";h.set_meta("enhancement_method","materials");h._refresh_drawer(),"到衣冠页查看已制成装备；淬炼耗淬灵石，保留原物与强化等级。")
	elif view=="materials":
		var rows:Array=h.state.material_rows()
		var page:int=clampi(int(h.get_meta("material_page",0)),0,maxi(0,(rows.size()-1)/6))
		h.set_meta("material_page",page)
		for i in range(6):
			var index:int=page*6+i
			if index>=rows.size():break
			var row:Dictionary=rows[index]
			_hit(h,"material_"+str(row.id),str(row.name),Rect2(x+(i%2)*306,y+97+(i/2)*43,296,41),func():h._notice(str(row.name)+" · "+str(row.get("source",""))+" · "+str(row.description)),str(row.get("source",""))+"\n"+str(row.description))
		h._qbutton(h.drawer,"materials_prev","‹",Rect2(x,y+238,32,27),func():h.set_meta("material_page",maxi(0,page-1));h._refresh_drawer()).disabled=page==0
		h._qbutton(h.drawer,"materials_next","›",Rect2(x+133,y+238,32,27),func():h.set_meta("material_page",page+1);h._refresh_drawer()).disabled=(page+1)*6>=rows.size()
		h._qbutton(h.drawer,"materials_to_craft","百工 · 合成与制作 ↗",Rect2(x+307,y+238,297,27),func():h.set_meta("bag_view","craft");h._refresh_drawer(),"原材料合成淬灵石，也能制作衣冠兵器。",true)
	else:
		h._qbutton(h.drawer,"bag_alchemy","翻阅丹方  ↗",Rect2(x+273,y+234,150,29),func():h._toggle_drawer("alchemy"),"查看三种丹药与剩余增益")
		h._qbutton(h.drawer,"bag_help","山居志  ↗",Rect2(x+441,y+234,163,29),func():h.set_meta("ink_journal_tab","journal");h._toggle_drawer("practice"),"查看修行指引、委托与收集")

static func _material_icon(h,row:Dictionary,p:Vector2,a:float):
	var color:Color=Color(str(row.get("color","91a48c")))
	var icon:String=str(row.get("icon","crystal"))
	if icon=="leaf":
		h.draw_line(p+Vector2(-7,10),p+Vector2(7,-9),Color(color.darkened(.23),a),1.5,true)
		h.draw_colored_polygon(PackedVector2Array([p+Vector2(-3,4),p+Vector2(-11,-2),p+Vector2(-10,-9),p+Vector2(-1,-4)]),Color(color,a))
		h.draw_colored_polygon(PackedVector2Array([p+Vector2(1,-1),p+Vector2(4,-12),p+Vector2(12,-13),p+Vector2(10,-4)]),Color(color.lightened(.12),a))
	elif icon=="feather":
		h.draw_colored_polygon(PackedVector2Array([p+Vector2(-7,8),p+Vector2(-9,-1),p+Vector2(-3,-10),p+Vector2(7,-14),p+Vector2(9,-4),p+Vector2(3,5)]),Color(color,a))
		h.draw_line(p+Vector2(-7,12),p+Vector2(7,-12),Color(color.darkened(.30),a),1.2,true)
		for i in range(3):h.draw_line(p+Vector2(-5+i*3,5-i*5),p+Vector2(3+i*2,3-i*5),Color(color.darkened(.18),a*.7),.8,true)
	elif icon=="thread":
		for i in range(3):
			var points=PackedVector2Array()
			for j in range(15):points.append(p+Vector2(-11+j*1.55,sin(j*.56+i*.5)*4+i*4-6))
			h.draw_polyline(points,Color(color,a),1.2,true)
	elif icon=="cinder":
		h.draw_colored_polygon(PackedVector2Array([p+Vector2(-8,7),p+Vector2(-9,-2),p+Vector2(-2,-7),p+Vector2(2,-15),p+Vector2(8,-1),p+Vector2(7,8),p+Vector2(0,12)]),Color(color,a))
		h.draw_colored_polygon(PackedVector2Array([p+Vector2(-3,8),p+Vector2(0,-5),p+Vector2(4,8)]),Color(color.lightened(.35),a))
	else:
		var shape=PackedVector2Array([p+Vector2(-10,4),p+Vector2(-5,-9),p+Vector2(5,-12),p+Vector2(12,0),p+Vector2(5,10),p+Vector2(-6,10)]) if icon=="ore" else PackedVector2Array([p+Vector2(0,-14),p+Vector2(10,-3),p+Vector2(5,10),p+Vector2(-6,12),p+Vector2(-10,-2)])
		h.draw_colored_polygon(shape,Color(color,a))
		h.draw_line(p+Vector2(-2,-9),p+Vector2(1,7),Color(color.lightened(.38),a),1.4,true)
		h.draw_line(p+Vector2(1,7),p+Vector2(7,-1),Color(color.darkened(.22),a),.9,true)

static func _draw_bag(h,x:float,y:float,a:float):
	var view:String=str(h.get_meta("bag_view","materials"))
	for i in range(3):
		var active:bool=view==["materials","craft","supplies"][i]
		_center(h,["山 材","百 工","药 囊"][i],Rect2(x+i*74,y+60,68,25),12,a,RED if active else FADED,true)
		if active:h.draw_line(Vector2(x+i*74+10,y+86),Vector2(x+i*74+58,y+86),Color(RED,a*.7),1.4,true)
	if view=="supplies":_draw_supplies(h,x,y,a);return
	if view=="materials":
		var rows:Array=h.state.material_rows()
		var page:int=int(h.get_meta("material_page",0))
		for i in range(6):
			var index:int=page*6+i
			if index>=rows.size():break
			var row:Dictionary=rows[index]
			var xx:float=x+(i%2)*306
			var yy:float=y+97+(i/2)*43
			var owned:bool=int(row.get("count",0))>0
			_material_icon(h,row,Vector2(xx+17,yy+20),a*(1.0 if owned else .34))
			_txt(h,str(row.name),Vector2(xx+39,yy+17),13,a,INK if owned else FADED,true)
			_txt(h,_ellipsis(str(row.get("description","")),234,9),Vector2(xx+39,yy+32),9,a,FADED)
			_txt(h,"×%d"%int(row.get("count",0)),Vector2(xx+248,yy+18),13,a,JADE if owned else FADED)
			_rule(h,Vector2(xx+3,yy+41),Vector2(xx+295,yy+41),a*.6)
		_center(h,"%d / %d"%[page+1,maxi(1,ceili(rows.size()/6.0))],Rect2(x+35,y+240,96,20),11,a,FADED)
		return
	var rows:Array=h.state.crafting_rows()
	var selected:Dictionary=_craft_selected(h)
	var page:int=_craft_page(h,rows)
	_rule(h,Vector2(x+218,y+96),Vector2(x+218,y+265),a)
	for i in range(CRAFTS_PER_PAGE):
		var index:int=page*CRAFTS_PER_PAGE+i
		if index>=rows.size():break
		var row:Dictionary=_craft_quote(h,rows[index])
		var yy:float=y+95+i*34
		if str(row.id)==str(selected.get("id","")):h.draw_line(Vector2(x-3,yy+4),Vector2(x-3,yy+28),Color(RED,a*.8),2,true)
		_txt(h,_ellipsis(str(row.name),195,13),Vector2(x+5,yy+16),13,a,INK if bool(row.get("unlocked",true)) else FADED,true)
		_txt(h,_ellipsis(_craft_status(row),195,9),Vector2(x+5,yy+29),9,a,JADE if bool(row.get("can_craft",false)) else FADED)
	_center(h,"百工 %d / %d"%[page+1,maxi(1,ceili(rows.size()/float(CRAFTS_PER_PAGE)))],Rect2(x+33,y+242,140,18),10,a,FADED)
	if selected.is_empty():return
	_txt(h,_ellipsis(str(selected.name),369,19),Vector2(x+233,y+113),19,a,INK,true)
	var summary:String=str(selected.get("description","")) if bool(selected.get("unlocked",true)) else str(selected.get("unlock_text","尚未解锁"))
	_txt(h,_ellipsis(summary,369,10),Vector2(x+233,y+131),10,a,FADED if bool(selected.get("unlocked",true)) else RED)
	var costs:Array=selected.get("costs",[])
	for i in range(mini(2,costs.size())):
		var cost:Dictionary=costs[i]
		_txt(h,("所需 · " if i==0 else "         ")+_cost_text([cost],true),Vector2(x+233,y+150+i*16),10,a,JADE if int(cost.get("owned",0))>=int(cost.get("count",0)) else FADED)
	if selected.has("alternatives"):
		var rare:bool=str(selected.get("selected_material",""))=="spirit_jade"
		_txt(h,"珍稀灵玉 · 亲选才耗用" if rare else "本次仅用此材 · 耗尽不换料",Vector2(x+233,y+166),10,a,RED if rare else FADED)
	_txt(h,_ellipsis("成物 · "+str(selected.get("output_name",""))+" ×%d"%int(selected.get("output_count",1)),369,12),Vector2(x+233,y+185),12,a,INK,true)
	var comparison:Dictionary=selected.get("comparison",{})
	if not comparison.is_empty():
		var equipped:String=str(SLOT_NAMES.get(str(comparison.get("slot","")),"身上"))+" · "+str(comparison.get("equipped_name","未穿戴"))+" → "+str(selected.get("output_name",""))
		_txt(h,_ellipsis(equipped,369,10),Vector2(x+233,y+201),10,a,FADED)
		_txt(h,_ellipsis(_craft_comparison(selected),369,10),Vector2(x+233,y+217),10,a,JADE)
	else:
		_txt(h,_ellipsis(_craft_comparison(selected),369,10),Vector2(x+233,y+201),10,a,FADED)
		_txt(h,"制成入囊 · 可在衣冠页亲手淬炼",Vector2(x+233,y+217),10,a,FADED)
	var receipt:String=str(h.get_meta("craft_receipt",""))
	if receipt.is_empty():receipt="制成不自动穿戴；可与身上装备比较后再选。" if not comparison.is_empty() else ""
	_txt(h,_ellipsis(receipt,369,9),Vector2(x+233,y+232),9,a,JADE if not str(h.get_meta("craft_receipt","")).is_empty() else FADED)

static func _draw_supplies(h, x:float, y:float, a:float):
	for i in range(3):
		var xx:float=x+i*203
		if i==0: _herb(h,Vector2(xx+89,y+121),.58,a)
		elif i==1: _drop(h,Vector2(xx+99,y+109),27,a)
		else:
			h.draw_circle(Vector2(xx+99,y+116),21,Color(JADE,a*.78))
			h.draw_arc(Vector2(xx+97,y+114),16,3.3,5.9,24,Color("d6ddc0",a*.6),1.5,true)
		_center(h,["灵 草","灵 露","聚 气 丹"][i],Rect2(xx+7,y+156,185,25),17,a,INK,true)
		_center(h,str([h.state.herbs,h.state.dew,h.state.pills][i]),Rect2(xx+7,y+185,185,24),21,a,INK,true)
		if i<2: _rule(h,Vector2(xx+198,y+76),Vector2(xx+198,y+210),a)
	_txt(h,"回春丹 %d · 澄心丹 %d"%[int(h.state.pill_stocks.get("spring",0)),int(h.state.pill_stocks.get("clarity",0))],Vector2(x+15,y+251),11,a,FADED,true)

static func _recipe_selected(h) -> Dictionary:
	var rows:Array=h.state.recipe_rows()
	var id:String=str(h.get_meta("ink_recipe_id",h.state.recipe))
	for row in rows:
		if str(row.id)==id: return row
	return rows[0] if not rows.is_empty() else {}

static func build_alchemy(h, x:float, y:float, _r:Rect2):
	var rows:Array=h.state.recipe_rows()
	for i in range(rows.size()):
		var row:Dictionary=rows[i]
		var id:String=str(row.id)
		_hit(h,"recipe_"+id,str(row.name),Rect2(x,y+72+i*48,201,47),func():
			h.set_meta("ink_recipe_id",id)
			if h.state.select_recipe(id): h._save_loadout()
			h._refresh_drawer(),str(row.description))
	var row:Dictionary=_recipe_selected(h)
	var enough:bool=bool(row.get("can_brew",false))
	var unlocked:bool=bool(row.get("unlocked",false))
	var brew:Button=h._qbutton(h.drawer,"start_brew",("温火炼丹" if enough else "循香采药") if unlocked else "尚未得方",Rect2(x+232,y+237,175,29),func():
		h.state.select_recipe(str(row.id));h.state.set_activity("brew" if enough else "gather")
		h._notice("温火已起 · "+str(row.name) if enough else "先把灵草与灵露带回来。")
		h._save_loadout();h._build_nav();h._refresh_drawer(),"炼制当前丹方；材料不足时先去采药",true)
	brew.disabled=not unlocked
	var use:Button=h._qbutton(h.drawer,"use_pill","服用一枚 · %d"%int(row.get("count",0)),Rect2(x+427,y+237,177,29),func():
		if h.state.use_pill(str(row.id)):
			h._notice(str(row.name)+"入息，药力已生。","loot");h.breakthrough_glow=.35;h._save_loadout();h._refresh_drawer(),str(row.description))
	use.disabled=int(row.get("count",0))<=0
	for buff in h.state.buff_rows():
		if str(buff.id)==str(row.id) and float(buff.seconds)>=3600.0-.000001:
			use.disabled=true;use.text="药力已足";use.tooltip_text="药力最多积存一小时，稍候再服。"

static func draw_alchemy(h, x:float, y:float, a:float):
	_book_header(h,"丹 方","草木入炉  ·  一息青烟",x,y,605,a)
	_rule(h,Vector2(x+213,y+66),Vector2(x+213,y+265),a)
	var rows:Array=h.state.recipe_rows()
	var selected:Dictionary=_recipe_selected(h)
	for i in range(rows.size()):
		var row:Dictionary=rows[i]
		var yy:float=y+72+i*48
		if row.id==selected.get("id",""):
			h.draw_line(Vector2(x-2,yy+6),Vector2(x-2,yy+38),Color(RED,a*.8),2,true)
		_txt(h,str(row.name),Vector2(x+8,yy+20),17,a,INK if bool(row.unlocked) else FADED,true)
		_txt(h,"藏丹 %d 枚"%int(row.count) if bool(row.unlocked) else h.state.REALM_NAMES[int(row.get("unlock_realm",0))]+"解锁",Vector2(x+8,yy+38),10,a,FADED)
		if bool(row.selected): _seal(h,"方",Vector2(x+164,yy+10),a,23)
		_rule(h,Vector2(x+7,yy+47),Vector2(x+197,yy+47),a*.6)
	var buffs:Array=h.state.buff_rows()
	for i in range(mini(buffs.size(),2)):
		var buff:Dictionary=buffs[i]
		_txt(h,str(buff.name)+" · "+_duration(float(buff.seconds)),Vector2(x+8,y+240+i*17),10,a,JADE)
	if buffs.is_empty(): _txt(h,"丹香入息，静待其时。",Vector2(x+8,y+252),11,a,FADED,true)
	_herb(h,Vector2(x+270,y+96),.38,a*.7)
	_txt(h,str(selected.get("name","丹方")),Vector2(x+317,y+91),25,a,INK,true)
	_wrap(h,str(selected.get("description","")),Vector2(x+234,y+130),363,11,a,FADED,2)
	_txt(h,"药 引",Vector2(x+234,y+177),12,a,INK,true)
	_txt(h,"灵草 %d / %d · 灵露 %d / %d"%[h.state.herbs,int(selected.get("herbs",0)),h.state.dew,int(selected.get("dew",0))],Vector2(x+291,y+177),11,a,JADE if bool(selected.get("can_brew",false)) else RED)
	var brewing:bool=h.state.activity=="brew" and str(h.state.recipe)==str(selected.get("id",""))
	var progress:float=float(h.state.activity_progress) if brewing else 0.0
	var seconds:float=float(selected.get("seconds",20))
	_txt(h,"温火慢煨 · "+_duration(seconds*(1.0-progress)) if brewing and bool(selected.get("can_brew",false)) else "每炉一丹 · 温养 "+_duration(seconds),Vector2(x+234,y+205),10,a,FADED)
	_meter(h,Rect2(x+234,y+219,369,0),progress,a)

static func _herb(h, origin:Vector2, scale:float, a:float):
	# Several translucent strokes give the leaves paper-showing ink edges.
	var stem = PackedVector2Array()
	for i in range(19):
		var t:float = i/18.0
		stem.append(origin+Vector2(-18+38*t+sin(t*PI)*4,46-102*t)*scale)
	h.draw_polyline(stem,Color(INK,a*.55),1.5*scale,true)
	var bases:Array = [Vector2(-12,30),Vector2(-4,10),Vector2(3,-8),Vector2(11,-29),Vector2(18,-47)]
	for i in range(bases.size()):
		var p:Vector2 = bases[i]
		var flip:float = -1.0 if i%2==0 else 1.0
		var length:float = 36.0-i*3.0
		var leaf = PackedVector2Array()
		leaf.append(origin+p*scale)
		for j in range(13):
			var t:float = j/12.0
			var width:float = sin(t*PI)*10.0
			leaf.append(origin+(p+Vector2(flip*(length*t),-26*t-width))*scale)
		for j in range(12,-1,-1):
			var t:float = j/12.0
			var width:float = sin(t*PI)*5.0
			leaf.append(origin+(p+Vector2(flip*(length*t),-26*t+width))*scale)
		h.draw_colored_polygon(leaf,Color(JADE.darkened(i*.035),a*(.56+i*.045)))
		h.draw_line(origin+p*scale,origin+(p+Vector2(flip*length,-26))*scale,Color(INK,a*.28),.8*scale,true)
	for i in range(3):
		h.draw_line(origin+Vector2(-18,45)*scale,origin+Vector2(-29+i*10,57+i*3)*scale,Color(INK,a*.32),.7*scale,true)

static func _drop(h, center:Vector2, radius:float, a:float):
	var drop = PackedVector2Array()
	for i in range(48):
		var angle:float = i*TAU/48.0
		var yy:float = -cos(angle)
		var width:float = .55+.35*((yy+1)*.5)
		drop.append(center+Vector2(sin(angle)*radius*width,yy*radius))
	h.draw_colored_polygon(drop,Color("7d9d92",a*.53))
	h.draw_arc(center+Vector2(-radius*.1,radius*.13),radius*.55,.3,2.3,20,Color("e7ecd4",a*.66),1.3,true)
