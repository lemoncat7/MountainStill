extends RefCounted
## Original alpha artwork, uniformly scaled from its documented source crop.
## This deliberately replaces the old anisotropically resized runtime strips.
## Crops are from campaign-panorama-metadata.json, bamboo-panorama-metadata.json
## and sanctuary-diorama-provenance.json. Static preloads retain export dependencies.
const TEXTURES = {
	"bamboo_pass": preload("res://assets/cultivation/routes/sources/bamboo_panorama-source.png"),
	"creek_bridge": preload("res://assets/cultivation/routes/sources/creek_bridge_panorama-source.png"),
	"cloud_slope": preload("res://assets/cultivation/routes/sources/cloud_slope_panorama-source.png"),
	"ember_ruins": preload("res://assets/cultivation/routes/sources/ember_ruins_panorama-source.png"),
	"moon_marsh": preload("res://assets/cultivation/routes/sources/moon_marsh_panorama-source.png"),
	"summit_gate": preload("res://assets/cultivation/routes/sources/summit_gate_panorama-source.png"),
	"courtyard": preload("res://assets/cultivation/sources/sanctuary-diorama-source.png"),
}
const CROPS = {
	"bamboo_pass": Vector2(2176,723),
	"creek_bridge": Vector2(2172,724),
	"cloud_slope": Vector2(2172,724),
	"ember_ruins": Vector2(2172,685),
	"moon_marsh": Vector2(2172,710),
	"summit_gate": Vector2(2172,724),
	"courtyard": Vector2(2068,744),
}
const GROUND_FRACTION := 246.0 / 280.0

static func texture(key: String) -> Texture2D:
	return TEXTURES.get(key)

static func source_rect(key: String) -> Rect2:
	return Rect2(Vector2.ZERO, CROPS.get(key, Vector2.ZERO))

static func destination_rect(key: String, scene_rect: Rect2, horizontal_offset: float = 0.0) -> Rect2:
	var crop := source_rect(key)
	if not crop.has_area():
		return Rect2()
	var logical_width := 1040.0 if key == "courtyard" else 2080.0
	var width := scene_rect.size.x * logical_width / 1040.0
	var height := width * crop.size.y / crop.size.x
	# 246 is the existing authored gameplay foot row. Transform that same row
	# back into source coordinates, then pin it to the world floor. This preserves
	# x/camera progress and combat footing, not every incidental garden anchor.
	var ground_y := scene_rect.position.y + scene_rect.size.y * GROUND_FRACTION
	return Rect2(Vector2(scene_rect.position.x - horizontal_offset * scene_rect.size.x / 1040.0,
		ground_y - height * GROUND_FRACTION), Vector2(width, height))
