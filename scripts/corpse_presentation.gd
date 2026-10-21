extends RefCounted
## A finite, data-driven presentation of defeated bodies. Bodies have no combat
## hitbox and remain opaque until the owning search receipt has been collected.
const Beast = preload("res://scripts/beast_presentation.gd")
const Authored = preload("res://scripts/monster_pose_renderer.gd")
const PROFILES := {
	"bamboo_pass": {"pose": "authored_crouch", "rotation": -0.82},
	"creek_bridge": {"pose": "idle", "rotation": -0.88},
	"cloud_slope": {"pose": "authored_peck", "rotation": -0.78},
	"ember_ruins": {"pose": "idle", "rotation": -0.70},
	"moon_marsh": {"pose": "idle", "rotation": -0.72},
	"summit_gate": {"pose": "idle", "rotation": -0.90},
}
const FALLEN_PATH := "res://assets/cultivation/beasts/fallen-body-landmarks.json"
static var _compiled: Dictionary = {}
static var _fallen_metadata: Dictionary = {}
static var _fallen_loaded: bool = false

static func _fallen(key: String) -> Dictionary:
	if not _fallen_loaded:
		_fallen_loaded = true
		var file := FileAccess.open(FALLEN_PATH, FileAccess.READ)
		if file:
			var value: Variant = JSON.parse_string(file.get_as_text())
			if value is Dictionary: _fallen_metadata = value.get("poses", {})
	return _fallen_metadata.get(key, {})

static func _body(textures: Dictionary, route: String, boss: bool, size: float, fallen: bool = false) -> Dictionary:
	var cache_key := route + str(boss) + ":" + str(size) + str(fallen)
	if _compiled.has(cache_key):
		return _compiled[cache_key]
	var profile: Dictionary = PROFILES.get(route, {"pose": "idle", "rotation": -0.75})
	var prefix := route + ("_boss" if boss else "")
	var key := prefix + ("_authored_fallen_v7" if fallen else "_" + str(profile.pose))
	var fallen_data := _fallen(key) if fallen else {}
	if fallen and fallen_data.is_empty():
		_compiled[cache_key] = {}
		return {}
	var texture: Texture2D = load("res://assets/cultivation/beasts/" + str(fallen_data.filename)) if fallen else textures.get(key)
	if texture == null:
		key = prefix + "_idle"
		texture = textures.get(key)
	if texture == null:
		return {}
	var authored := "_authored_" in key
	var metadata: Dictionary = fallen_data if fallen else (Authored.landmarks(key) if authored else Beast.landmarks(key))
	var anchor: Array = metadata.get("ground_anchor", [128,232])
	var registration: Array = metadata.get("registration_offset", [0,0])
	var calibration := float(metadata.get("reference_head_diameter",1.0)) / maxf(1.0,float(metadata.get("head_diameter",1.0)))
	if fallen and metadata.has("body_registration"):
		var landmark: Dictionary = metadata.body_registration
		calibration = float(landmark.reference_diameter) / maxf(1.0,float(landmark.diameter))
	var scale_value := size / 256.0 * calibration
	var rect := Rect2((-Vector2(float(anchor[0]),float(anchor[1])) + Vector2(float(registration[0]),float(registration[1]))) * scale_value, texture.get_size() * scale_value)
	var bounds: Array = metadata.get("alpha_bbox", [0,0,256,256])
	var visible := Rect2(rect.position + Vector2(float(bounds[0]),float(bounds[1])) * scale_value, Vector2(float(bounds[2])-float(bounds[0]),float(bounds[3])-float(bounds[1])) * scale_value)
	var data := {"texture": texture, "rect": rect, "visible": visible, "rotation": 0.0 if fallen else float(profile.rotation), "fallen": fallen}
	_compiled[cache_key] = data
	return data

static func draw(canvas: CanvasItem, textures: Dictionary, route: String, boss: bool, feet: Vector2, size: float, collapse: float, fade: float = 0.0) -> bool:
	var fallen_body := _body(textures, route, boss, size, true)
	var use_fallen := not fallen_body.is_empty() and collapse >= .36
	var body := fallen_body if use_fallen else _body(textures, route, boss, size)
	if body.is_empty():
		return false
	# One painted silhouette at a time: buckle, then low resting keypose.
	# Fallen anatomy is authored, never a standing sprite flattened/turned over.
	var t := smoothstep(0.0, 1.0, clampf(collapse,0.0,1.0))
	var settle := sin(clampf(collapse,0.0,1.0)*PI) * 2.3
	var angle := float(body.rotation) * t
	if use_fallen:
		t = 1.0
		angle = -.055 * (1.0-smoothstep(.36,1.0,collapse))
	var rect: Rect2 = body.rect
	var visible: Rect2 = body.visible
	var pivot := visible.get_center()
	var local := visible.position - pivot
	var bottom := -INF
	for corner in [local,local+Vector2(visible.size.x,0),local+visible.size,local+Vector2(0,visible.size.y)]:
		bottom = maxf(bottom,Vector2(corner).rotated(angle).y)
	var origin := feet + pivot.lerp(Vector2(0,-bottom+1),t) + Vector2(0,settle)
	var alpha := 1.0-smoothstep(0.0,1.0,clampf(fade,0.0,1.0))
	# The shadow and source body settle together; no whole-canvas squash.
	canvas.draw_set_transform(feet+Vector2(0,2),0,Vector2(1,.16))
	canvas.draw_circle(Vector2.ZERO,size*.28,Color(.24,.28,.20,.18*alpha))
	canvas.draw_set_transform(origin,angle,Vector2.ONE)
	canvas.draw_texture_rect(body.texture,Rect2(rect.position-pivot,rect.size),false,Color(.85,.87,.81,alpha))
	canvas.draw_set_transform(Vector2.ZERO,0,Vector2.ONE)
	return true
