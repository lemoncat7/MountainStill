extends SceneTree
const Pages = preload("res://scripts/practice_pages.gd")
const Content = preload("res://scripts/cultivation_content.gd")
const Registry = preload("res://scripts/attack_module_registry.gd")
const Ink = preload("res://scripts/ink_pages.gd")
var failures := 0
var checks := 0
func check(ok: bool, label: String):
	checks += 1
	if not ok: failures += 1; printerr("FAIL: " + label)
func _initialize():
	for stage in Content.STAGES.values():
		for original in stage.get("monsters", []):
			var row: Dictionary = original.duplicate(true)
			row.unlocked = true
			var before := row.duplicate(true)
			var notes: Array[String] = Pages.notes(row)
			check(notes.size() == 2, "two actual mechanism notes")
			check(row == before, "read-only canonical row")
			var module = Registry.default_registry().bind(str(row.attack_module_id), {"enemy": row})
			var action: Dictionary = module.select_action({"enemy": row, "action_index": 0, "roll": 0.5})
			check(str(action.label) in notes[0], "actual module opening label")
			check(("%.2f" % float(action.windup)) in notes[0], "actual module opening duration")
			check(Ink._wrapped_lines(notes[0], 600, 14, 10).size() <= 2, "opening fits two lines")
			check(Ink._wrapped_lines(notes[1], 600, 14, 10).size() <= 1, "mechanic fits one line")
			notes[0] = "mutated"
			check(Pages.notes(row)[0] != "mutated", "cached strings not aliased")
			row.unlocked = false
			check(not str(row.name) in "".join(Pages.notes(row)), "locked enemy identity concealed")
	check("首次" in Pages.comparison_text({}, {}), "no previous report explained")
	var previous := {"elapsed": 20.0, "damage_taken": 30, "outcome": "victory"}
	var before := previous.duplicate(true)
	var faster := Pages.comparison_text({"elapsed": 18.0, "damage_taken": 20}, previous)
	check("更快2.0秒" in faster and "少受10伤害" in faster, "faster and lower damage readable")
	check("（胜）" in faster, "previous outcome explicit to avoid faster defeat implying better")
	var slower := Pages.comparison_text({"elapsed": 23.0, "damage_taken": 35}, previous)
	check("更慢3.0秒" in slower and "多受5伤害" in slower, "slower and higher damage readable")
	check("耗时相同" in Pages.comparison_text(previous, previous) and "承伤相同" in Pages.comparison_text(previous, previous), "identical report neutral")
	check(previous == before, "comparison leaves previous report untouched")
	check(Ink._wrapped_lines(slower, 600, 14, 10).size() == 1, "comparison fits one body line")
	print("Practice pages: %d checks, %d failures" % [checks, failures])
	quit(1 if failures else 0)
