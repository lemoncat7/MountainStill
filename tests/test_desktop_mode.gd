extends SceneTree
const Desktop = preload("res://scripts/desktop_mode.gd")
var checks := 0
var failures := 0

func check(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		failures += 1
		printerr("FAIL: " + label)

func polygon_for(rects: Array = [], safe: Rect2 = Rect2(1130, 8, 45, 32), dimensions: Vector2 = Vector2(1200, 320), transform_value: Transform2D = Transform2D.IDENTITY) -> PackedVector2Array:
	return Desktop._build_passthrough_polygon(dimensions, transform_value, safe, rects)

func valid_polygon(polygon: PackedVector2Array, dimensions: Vector2) -> bool:
	if polygon.size() < 4 or Geometry2D.triangulate_polygon(polygon).is_empty():
		return false
	for i in range(polygon.size()):
		var a := polygon[i]
		var b := polygon[(i + 1) % polygon.size()]
		if a == b or not a.is_finite() or a.x < 0 or a.y < 0 or a.x > dimensions.x or a.y > dimensions.y:
			return false
		for j in range(i + 1, polygon.size()):
			if j == i + 1 or (i == 0 and j == polygon.size() - 1):
				continue
			if a == polygon[j] or Geometry2D.segment_intersects_segment(a, b, polygon[j], polygon[(j + 1) % polygon.size()]) != null:
				return false
	return true

func test_geometry() -> void:
	var dimensions := Vector2(1200, 320)
	var plain := polygon_for()
	check(valid_polygon(plain, dimensions) and plain.size() == 4, "Old single-argument API yields a valid top band")
	check(Geometry2D.is_point_in_polygon(Vector2(10, 49), plain), "Narrow recovery seal still preserves the full-width 50px safety band")
	check(not Geometry2D.is_point_in_polygon(Vector2(600, 100), plain), "Empty scene below the band can pass clicks through")
	var hotspots := [Rect2(110, 170, 95, 80), Rect2(465, 140, 110, 150), Rect2(830, 160, 105, 100), Rect2(650, 235, 65, 45)]
	var comb := polygon_for(hotspots)
	check(valid_polygon(comb, dimensions), "Four scene hotspots create one simple triangulatable comb")
	for rect: Rect2 in hotspots:
		check(Geometry2D.is_point_in_polygon(rect.get_center(), comb), "Hotspot remains native-clickable at " + str(rect.position))
		check(Geometry2D.is_point_in_polygon(Vector2(rect.get_center().x, 70), comb), "Safe stem connects hotspot to recovery band")
	check(not Geometry2D.is_point_in_polygon(Vector2(350, 170), comb), "A clear gap between scene stems still passes through")
	check(not Geometry2D.is_point_in_polygon(Vector2(160, 300), comb), "Area below a shallow hotspot is not unnecessarily captured")
	var overlap := polygon_for([Rect2(100, 80, 100, 50), Rect2(190, 200, 70, 90), Rect2(250, 100, 30, 50)])
	check(valid_polygon(overlap, dimensions), "Overlapping chains merge into a valid polygon")
	check(Geometry2D.is_point_in_polygon(Vector2(110, 280), overlap) and Geometry2D.is_point_in_polygon(Vector2(270, 280), overlap), "Overlapping X spans conservatively inherit the greatest depth")
	var touching := polygon_for([Rect2(0, 80, 100, 80), Rect2(100, 100, 100, 150), Rect2(1180, 300, 100, 100)])
	check(valid_polygon(touching, dimensions), "Touching and edge-clipped stems have no duplicate or crossing edges")
	check(Geometry2D.is_point_in_polygon(Vector2(30, 240), touching), "Touching stems merge conservatively")
	check(Geometry2D.is_point_in_polygon(Vector2(1199, 319), touching), "Partly offscreen hotspot remains clickable to the window edge")
	check(polygon_for([Rect2(1500, 400, 20, 20)]) == plain, "Fully offscreen hotspot does not capture empty space")
	check(polygon_for([Rect2(20, 10, 20, 10)]) == plain, "Hotspot already within recovery band adds no degenerate stem")
	check(polygon_for([Rect2(100, 100, -20, -20)]) == polygon_for([Rect2(80, 80, 20, 20)]), "Reversed hotspot rectangles are normalized safely")
	check(polygon_for([], Rect2()).is_empty(), "Missing recovery measurement disables polygon passthrough")
	check(polygon_for([], Rect2(1400, 0, 10, 20)).is_empty(), "Offscreen recovery seal disables passthrough")
	check(polygon_for([Rect2(NAN, 0, 10, 10)]).is_empty(), "Non-finite hotspot fails closed")
	check(polygon_for(["invalid"]).is_empty(), "Malformed hotspot input fails closed")
	check(polygon_for([], Rect2(0, 0, INF, 20)).is_empty(), "Non-finite recovery measurement fails closed")
	check(polygon_for([], Rect2(0, 0, 20, 20), Vector2.ZERO).is_empty(), "Zero native window fails closed")
	check(polygon_for([], Rect2(0, 0, 20, 20), dimensions, Transform2D(Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)).is_empty(), "Singular viewport transform fails closed")
	var scaled := polygon_for([Rect2(100.2, 40.2, 20.2, 50.2)], Rect2(550, 0, 40, 20), dimensions, Transform2D(Vector2(2, 0), Vector2(0, 2), Vector2.ZERO))
	check(valid_polygon(scaled, dimensions), "Scaled fractional input creates a valid native polygon")
	check(Geometry2D.is_point_in_polygon(Vector2(201, 180), scaled), "DPI conversion and outward rounding preserve hotspot edges")
	check(not Geometry2D.is_point_in_polygon(Vector2(245, 180), scaled), "Scaled hotspot does not consume distant blank space")
	check(valid_polygon(polygon_for([], Rect2(1, 1, 10, 10), Vector2(30, 30)), Vector2(30, 30)), "Tiny native windows retain their entire recovery area safely")
	# Deterministic, bounded geometry stress: arbitrary order, overlaps and clips.
	var rng := RandomNumberGenerator.new()
	rng.seed = 8591
	for sample in range(100):
		var rects: Array = []
		for i in range(8):
			rects.append(Rect2(rng.randf_range(-70, 1250), rng.randf_range(-40, 300), rng.randf_range(1, 200), rng.randf_range(1, 180)))
		var polygon := polygon_for(rects)
		check(valid_polygon(polygon, dimensions), "Random comb has no crossings or degeneracy: %d" % sample)
		var preserves_all := true
		for rect: Rect2 in rects:
			var clipped := rect.intersection(Rect2(Vector2.ZERO, dimensions))
			if clipped.has_area() and not Geometry2D.is_point_in_polygon(clipped.get_center(), polygon):
				preserves_all = false
		check(preserves_all, "Random comb preserves all visible hotspots: %d" % sample)
		check(Geometry2D.is_point_in_polygon(Vector2(1, 25), polygon) and Geometry2D.is_point_in_polygon(Vector2(1199, 25), polygon), "Random comb preserves full-width recovery: %d" % sample)

func _initialize() -> void:
	test_geometry()
	var helper = Desktop.new()
	check(not helper.desired_passthrough and not helper.passthrough_enabled, "Click-through is off by default")
	helper.attach(root)
	helper.update_passthrough(Rect2(0, 0, 1200, 72))
	var hotspots := [Rect2(100, 150, 100, 100)]
	helper.update_passthrough(Rect2(1120, 8, 55, 34), hotspots)
	hotspots.clear()
	check(helper._interactive_rects.size() == 1, "Caller mutations cannot erase measured hotspot protection")
	helper.set_strip(true)
	helper.set_width(900)
	helper.set_top(true)
	helper.set_transparent(true)
	helper.set_passthrough(true)
	helper.safe_restore()
	check(not helper.strip_enabled and not helper.top_enabled and not helper.transparent_enabled and not helper.passthrough_enabled, "Restore clears all active desktop flags")
	check(not helper.desired_top and not helper.desired_transparent and not helper.desired_passthrough, "Restore also clears queued preferences")
	check(not root.mouse_passthrough and root.mouse_passthrough_polygon.is_empty(), "Restore enables input over the whole window")
	helper.dispose()
	check(not root.size_changed.is_connected(helper._on_size_changed) and not root.tree_exiting.is_connected(helper.dispose), "Dispose disconnects helper-owned window signals")
	check(helper._safe_rect == Rect2() and helper._interactive_rects.is_empty(), "Dispose discards stale recovery and hotspot measurements")
	helper.attach(root)
	helper.dispose()
	print("Desktop helper: %d checks, %d failures; geometry, API, headless guards, and safe recovery" % [checks, failures])
	quit(1 if failures else 0)
