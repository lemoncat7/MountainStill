extends SceneTree
const Art = preload("res://scripts/scene_art_layout.gd")
var checks := 0
var failures := 0
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)
func _initialize() -> void:
	for key in Art.CROPS:
		var source := Art.source_rect(key)
		var image: Image = Art.texture(key).get_image()
		check(image != null and Vector2(image.get_size()).x >= source.end.x and Vector2(image.get_size()).y >= source.end.y, key + " documented source crop exists")
		check(image.has_mipmaps() or image.detect_alpha() != Image.ALPHA_NONE, key + " original has alpha, no opacity mask needed")
		for scale in [0.75, 1.0, 1.5, 2.0]:
			var scene := Rect2(Vector2(13, 70), Vector2(1040,280) * scale)
			for distance in [0.0, 520.0, 940.0, 1040.0]:
				var dest := Art.destination_rect(key, scene, distance)
				check(is_equal_approx(dest.size.x/source.size.x,dest.size.y/source.size.y), key + " source pixels scale uniformly")
				check(is_equal_approx(dest.position.y+dest.size.y*Art.GROUND_FRACTION,scene.position.y+scene.size.y*Art.GROUND_FRACTION), key + " ground remains aligned")
				check(is_equal_approx(dest.position.x,scene.position.x-distance*scale), key + " scrolling keeps canonical world distance")
	check(not Art.destination_rect("unknown",Rect2(0,0,1040,280)).has_area(), "unknown artwork fails safely")
	print("Scene original-art layout: %d checks, %d failures (geometry/resource, not native graphics)" % [checks, failures])
	quit(1 if failures else 0)
