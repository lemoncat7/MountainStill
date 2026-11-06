extends RefCounted
## Explicit full-active-slot choice on the existing manual page. Drafts are
## presentation-only; opening, cancelling or invalidating one never saves.
const KEY := "active_replacement"

static func clear(h):
	h.remove_meta(KEY)

static func _available(h) -> bool:
	return h.drawer_name == "wardrobe" and h.wardrobe_tab == "technique" and h.practice_session == null and not h.closing and not h.get_meta("update_transaction", false) and not h.get_tree().paused and not h.InkPages._live_loadout_locked(h)

static func is_open(h, id: String) -> bool:
	var draft: Dictionary = h.get_meta(KEY, {})
	return not draft.is_empty() and str(draft.get("id", "")) == id

static func _eligible(h, id: String) -> bool:
	return h.state._manual_eligible(id) and "active" in h.state.Content.TECHNIQUES[id].slots and not h.state.equipped_actives.has(id) and h.state.equipped_actives.size() == h.state.active_capacity()

static func reconcile(h):
	var draft: Dictionary = h.get_meta(KEY, {})
	if draft.is_empty(): return
	if not _available(h) or str(h.InkPages._technique_selected(h).get("id", "")) != str(draft.get("id", "")) or h.state.equipped_actives != draft.get("expected", []) or not _eligible(h, str(draft.get("id", ""))):
		clear(h)

static func open(h, id: String):
	if not _available(h) or str(h.InkPages._technique_selected(h).get("id", "")) != id: return
	if not _eligible(h, id): return
	var serial: int = int(h.get_meta("active_replacement_serial", 0)) + 1
	h.set_meta("active_replacement_serial", serial)
	h.set_meta("ink_heart_quote", {})
	h.set_meta(KEY, {"id": id, "expected": h.state.equipped_actives.duplicate(), "serial": serial})
	h._refresh_drawer()

static func _current(h, draft: Dictionary) -> bool:
	return _available(h) and not draft.is_empty() and h.get_meta(KEY, {}) == draft and str(h.InkPages._technique_selected(h).get("id", "")) == str(draft.get("id", ""))

static func commit(h, draft: Dictionary, previous_id: String):
	if not _current(h, draft): return
	var id := str(draft.get("id", ""))
	var result: Dictionary = h.state.replace_active_technique(id, previous_id, draft.get("expected", []))
	clear(h)
	if bool(result.get("ok", false)):
		h.InkPages._manual_outcome(h, result, "主动已替换 · " + h.InkPages._manual_name(h, previous_id) + " → " + h.InkPages._manual_name(h, id))
	else:
		h._notice("搭配或功法状态已改变，请重新选择；原主动栏未改动。")
		h._refresh_drawer()

static func build(h, x: float, y: float):
	var draft: Dictionary = h.get_meta(KEY, {}).duplicate(true)
	var ids: Array = draft.get("expected", [])
	var id := str(draft.get("id", ""))
	for i in range(ids.size()):
		var previous_id := str(ids[i])
		var hint := "主动第%d格：%s → %s\n只替换此格，保留另一主动、武式和已学重数；不耗材料。\n%s" % [i + 1, h.InkPages._manual_name(h, previous_id), h.InkPages._manual_name(h, id), h.InkPages._manual_hint(h, h.state.technique_descriptor(id))]
		h._qbutton(h.drawer, "replace_active_%d" % i, "替下 · " + h.InkPages._manual_name(h, previous_id), Rect2(x + 227, y + 166 + i * 34, 378, 28), func():commit(h, draft, previous_id), hint, true)
	h._qbutton(h.drawer, "cancel_active_replacement", "暂不替换", Rect2(x + 227, y + 240, 132, 28), func():
		if not _current(h, draft): return
		clear(h); h._refresh_drawer(), "保留全部原搭配；不耗资源、不保存。")

static func draw(h, x: float, y: float, a: float):
	var draft: Dictionary = h.get_meta(KEY, {})
	h.InkPages._txt(h, "将装入 · " + h.InkPages._manual_name(h, str(draft.get("id", ""))), Vector2(x + 229, y + 135), 17, a, h.InkPages.JADE)
	h.InkPages._txt(h, "选择替下哪一法；保留其余栏位与重数。", Vector2(x + 229, y + 155), 12, a)
	h.InkPages._txt(h, "不耗材料 · 不自动开战", Vector2(x + 373, y + 258), 12, a, h.InkPages.FADED)
