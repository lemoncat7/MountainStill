extends SceneTree
## Native raster proof of the same contact painter the live host calls.
## Run under a native display or Xvfb, with --output=/absolute/path.
const Impact = preload("res://scripts/combat_impact.gd")
const Examples = preload("res://tests/test_combat_impact.gd")

class Sheet extends Node2D:
	func _draw() -> void:
		draw_rect(Rect2(0, 0, 1200, 710), Color("f0ebdd"))
		draw_string(ThemeDB.fallback_font, Vector2(26, 35), "CONTACT MATERIALS | real painter, 2x contact scale", HORIZONTAL_ALIGNMENT_LEFT, -1, 24, Color("384e46"))
		draw_string(ThemeDB.fallback_font, Vector2(26, 61), "No camera shake or screen flashes. Each row: contact / 35 ms / 90 ms / 160 ms.", HORIZONTAL_ALIGNMENT_LEFT, -1, 15, Color("667262"))
		var selected := [0, 1, 6, 18, 7, 8, 13, 14, 15, 17]
		var all_examples := Examples.examples()
		for row in range(selected.size()):
			var item: Dictionary = all_examples[selected[row]]
			var profile := Impact.describe(item.event)
			var column := row / 5
			var line := row % 5
			var origin := Vector2(28 + column * 592, 117 + line * 115)
			draw_string(ThemeDB.fallback_font, origin, str(item.name).replace("-", " ") + "  / " + str(profile.kind), HORIZONTAL_ALIGNMENT_LEFT, -1, 17, Color("40584b"))
			draw_string(ThemeDB.fallback_font, origin + Vector2(0, 20), "%s + %s | hold %.0f ms" % [profile.strike_material, profile.material, float(profile.hitstop) * 1000.0], HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color("7f856f"))
			for frame in range(4):
				var point := origin + Vector2(76 + frame * 126, 65)
				draw_line(point + Vector2(-48, 0), point + Vector2(48, 0), Color("d7d8c8"), 1.0)
				var record := {"profile": profile, "age": [0.0, 0.035, 0.09, 0.16][frame], "position": point, "scale": 2.0}
				if str(profile.family) == "moss_slam":
					record.ground = point + Vector2(0, 25)
				Impact.draw(self, record)


func _initialize() -> void:
	root.size = Vector2i(1200, 710)
	root.add_child(Sheet.new())
	_finish.call_deferred()


func _finish() -> void:
	await process_frame
	await process_frame
	await RenderingServer.frame_post_draw
	var directory := "/tmp/mountain-impact-proof"
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--output="):
			directory = arg.trim_prefix("--output=")
	DirAccess.make_dir_recursive_absolute(directory)
	var result := root.get_texture().get_image().save_png(directory.path_join("contact-materials.png"))
	print("IMPACT_VISUAL_PROOF: ", result, " ", directory)
	quit()
