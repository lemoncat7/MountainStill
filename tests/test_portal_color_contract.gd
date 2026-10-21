extends SceneTree
## CPU/source regression, not a GPU screenshot test. Godot 4 fragment COLOR
## already contains texture * vertex/node modulation; do not multiply twice.
var checks := 0
var failures := 0

func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok:
		failures += 1
		printerr("FAIL: " + label)

func shade(fragment_color: Color, dissolve: float, noise: float) -> Color:
	var visible := 1.0 if noise >= dissolve else 0.0
	var edge := (1.0 - smoothstep(dissolve, dissolve + 0.13, noise)) * (1.0 if dissolve >= 0.01 else 0.0)
	var color := fragment_color.lerp(Color(0.91, 0.83, 0.49, fragment_color.a), edge * 0.85)
	color.a = fragment_color.a * visible
	return color

func _initialize() -> void:
	var shader: Shader = load("res://scripts/portal_dissolve.gdshader")
	check(shader != null, "portal shader loads")
	var code := shader.code
	check(code.contains("vec4 tex = COLOR;"), "fragment starts with Godot's already-textured color")
	check(not code.contains("texture(TEXTURE"), "portal cannot double-sample and square equipment RGB/alpha")
	check(code.contains("COLOR = vec4(tex.rgb,tex.a*visible);"), "only dissolve visibility changes source alpha")
	# Source contract above binds this numeric reference to the intentionally
	# small shader. GPU/driver rendering remains a separate visual acceptance.
	for color in [Color(0.4, 0.2, 0.1, 1.0), Color(0.7, 0.6, 0.4, 0.5), Color(0.1, 0.15, 0.2, 0.0)]:
		for noise in [0.0, 0.05, 0.5, 0.999]:
			check(shade(color, 0.0, noise).is_equal_approx(color), "zero dissolve preserves exact original RGB and alpha")
			check(is_zero_approx(shade(color, 1.0, noise).a), "full dissolve hides every pixel")
	var edge := shade(Color(0.4, 0.2, 0.1, 0.5), 0.5, 0.51)
	check(edge.r > 0.4 and edge.g > 0.2 and edge.b > 0.1 and is_equal_approx(edge.a, 0.5), "surviving edge retains warm shimmer without dimming or squaring alpha")
	check(is_zero_approx(shade(Color.WHITE, 0.5, 0.49).a), "grain behind moving dissolve threshold disappears")
	print("Portal color source/CPU contract: %d checks, %d failures (not GPU validation)" % [checks, failures])
	quit(1 if failures else 0)
