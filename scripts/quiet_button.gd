extends Button
## Text laid on paper; focus and touch arrive as pigment, not a raised panel.
## The original selected/accent/hint API is retained. "ink_hit", blank text,
## or metadata ink_region turns this into a transparent artwork hit region.

const InkPaper = preload("res://scripts/ink_paper.gd")
const SERIF: Font = preload("res://assets/fonts/NotoSerifCJK-Regular.ttc")
const CREAM = Color("fff8e7")
const CINNABAR = Color("994536")

var ink: Color = Color("3b3b32")
var selected: bool = false:
	set(value):
		selected = value
		queue_redraw()
var accent: bool = false:
	set(value):
		accent = value
		queue_redraw()
var hint: String = "":
	set(value):
		hint = value
		tooltip_text = value
var variant: String = "text":
	set(value):
		variant = value
		queue_redraw()
var wash: float = 0.0
var press_wash: float = 0.0

func _ready() -> void:
	flat = true
	mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	for state_name in ["normal", "hover", "pressed", "focus", "disabled", "hover_pressed"]:
		add_theme_stylebox_override(state_name, StyleBoxEmpty.new())
	for color_name in ["font_color", "font_hover_color", "font_pressed_color", "font_focus_color", "font_disabled_color", "font_hover_pressed_color", "font_outline_color"]:
		add_theme_color_override(color_name, Color.TRANSPARENT)
	add_theme_font_override("font", SERIF)
	tooltip_text = hint
	set_process(true)

func _process(delta: float) -> void:
	var target: float = 1.0 if not disabled and (is_hovered() or has_focus()) else 0.0
	var pressed_target: float = 1.0 if not disabled and is_pressed() else 0.0
	var before: Vector2 = Vector2(wash, press_wash)
	wash = move_toward(wash, target, delta * (6.5 if target > wash else 4.5))
	press_wash = move_toward(press_wash, pressed_target, delta * 15.0)
	if before != Vector2(wash, press_wash):
		queue_redraw()

func _draw() -> void:
	var hit_region: bool = variant == "ink_hit" or text.is_empty() or bool(get_meta("ink_region", false))
	var area = Rect2(Vector2(3, 2), size - Vector2(6, 4))
	if not area.has_area():
		return
	if hit_region:
		# Host artwork, item text and selected seals must remain unobscured.
		if wash + press_wash > 0.0:
			InkPaper.brush(self, area, Color(0.62, 0.61, 0.52, wash * 0.07 + press_wash * 0.06))
		if has_focus() and not disabled:
			_draw_focus(0.58)
		return
	var font_size: int = get_theme_font_size("font_size")
	var font: Font = get_theme_font("font")
	var text_color: Color = ink
	if accent:
		# An ink-loaded brush is the sole strong action surface.
		var body_alpha: float = 0.89 + wash * 0.07 + press_wash * 0.04
		if disabled:
			body_alpha = 0.14
		InkPaper.brush(self, area, Color(0.84, 0.83, 0.75, body_alpha))
		if wash > 0.0 and not disabled:
			InkPaper.brush(self, area.grow(1.3), Color(0.24, 0.24, 0.21, wash * 0.08))
		text_color = Color("71695c") if disabled else CREAM
	else:
		var amount: float = wash * 0.075 + press_wash * 0.075 + (0.025 if selected else 0.0)
		if amount > 0.0:
			InkPaper.brush(self, area, Color(0.66, 0.64, 0.55, amount))
		if selected:
			text_color = CINNABAR
		if disabled:
			text_color = Color("8a8070")
	# Preserve the original centered label API, with no positional hover jump.
	# Reduce only when necessary; compact recovery/window controls stay legible.
	var available: float = maxf(size.x - 12.0, 4.0)
	var text_width: float = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	while text_width > available and font_size > 10:
		font_size -= 1
		text_width = font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	var baseline: float = (size.y - font.get_height(font_size)) * 0.5 + font.get_ascent(font_size)
	var start: float = (size.x - text_width) * 0.5
	draw_string(font, Vector2(start, baseline), text, HORIZONTAL_ALIGNMENT_LEFT,
		available, font_size, text_color)
	if selected and not accent and not disabled:
		# The marker sits in unused whitespace when possible; tiny controls use
		# a discreet red brush under the label instead of covering its glyphs.
		if start >= 14.0:
			InkPaper.seal(self, Vector2(start - 8.5, size.y * 0.5), 5.6, 0.88)
		else:
			InkPaper.brush(self, Rect2(Vector2(size.x * 0.33, size.y - 3), Vector2(size.x * 0.34, 1.7)),
				Color(0.71, 0.28, 0.20, 0.75))
	if has_focus() and not disabled:
		_draw_focus(0.80 if accent else 0.62)

func _draw_focus(alpha: float) -> void:
	# Distinct keyboard focus remains visible without a rectangular outline.
	var color = Color(CREAM, alpha) if accent else Color(CINNABAR, alpha)
	InkPaper.brush(self, Rect2(Vector2(size.x * 0.28, size.y - 4.2), Vector2(size.x * 0.44, 1.9)), color)
