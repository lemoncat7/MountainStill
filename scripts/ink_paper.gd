extends Control
## A hand-painted paper surface. The static painter is also safe to use from a
## parent's _draw() before its typography, without covering text with a child.
## kind: "book" (bound leaf), "scroll" (unrolled sheet), or "leaf".

const PAPER_TEXTURE: Texture2D = preload("res://assets/ui/ink/rice-paper.png")
const BRUSH_TEXTURE: Texture2D = preload("res://assets/ui/ink/soot-brush.png")
const PAPER_SOURCE = Rect2(28, 28, 1480, 968)
const BRUSH_SOURCE = Rect2(32, 114, 2114, 500)
const PAPER_INK = Color("403e34")
const SEAL = Color("a44737")

@export var kind: String = "book":
	set(value):
		kind = value
		queue_redraw()
@export_range(0.0, 1.0) var reveal: float = 1.0:
	set(value):
		reveal = clampf(value, 0.0, 1.0)
		queue_redraw()

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR

func _draw() -> void:
	paint(self, Rect2(Vector2.ZERO, size), 1.0, kind, reveal)

static func paint(canvas: CanvasItem, rect: Rect2, alpha: float = 1.0,
		paper_kind: String = "book", amount: float = 1.0) -> void:
	var a: float = clampf(alpha, 0.0, 1.0)
	var progress: float = clampf(amount, 0.0, 1.0)
	if a <= 0.0 or progress <= 0.0 or not rect.has_area():
		return
	var edge: float = rect.position.x + rect.size.x * progress
	# The shadow inherits the paper's fibrous silhouette. There is no panel box.
	_image(canvas, PAPER_TEXTURE, Rect2(rect.position + Vector2(1, 5), rect.size),
		PAPER_SOURCE, Color(0.19, 0.17, 0.13, 0.17 * a), edge)
	if paper_kind == "book":
		# A small stack of individual leaves, rather than a generic raised card.
		_image(canvas, PAPER_TEXTURE, Rect2(rect.position + Vector2(2, 3), rect.size - Vector2(4, 0)),
			PAPER_SOURCE, Color(0.77, 0.73, 0.64, 0.96 * a), edge)
		_image(canvas, PAPER_TEXTURE, Rect2(rect.position + Vector2(1, 1.5), rect.size - Vector2(2, 0)),
			PAPER_SOURCE, Color(0.91, 0.88, 0.80, a), edge)
	_image(canvas, PAPER_TEXTURE, rect, PAPER_SOURCE, Color(1, 1, 1, a), edge)
	if paper_kind == "book":
		# The binding stays in the margin; it never divides a caller's layout.
		_vertical_brush(canvas, Rect2(rect.position + Vector2(8, 8), Vector2(3, rect.size.y - 16)),
			Color(0.31, 0.29, 0.24, 0.15 * a), edge)
		for portion in [0.20, 0.42, 0.64, 0.86]:
			brush(canvas, Rect2(rect.position + Vector2(5, rect.size.y * portion), Vector2(7, 1.4)),
				Color(0.29, 0.28, 0.23, 0.35 * a), edge)
	elif paper_kind == "scroll":
		# Slim, textured scroll ends retain the watercolor character of the page.
		_vertical_brush(canvas, Rect2(rect.position + Vector2(1, 4), Vector2(5, rect.size.y - 8)),
			Color(0.43, 0.34, 0.22, 0.35 * a), edge)
		_vertical_brush(canvas, Rect2(Vector2(rect.end.x - 6, rect.position.y + 4), Vector2(5, rect.size.y - 8)),
			Color(0.43, 0.34, 0.22, 0.30 * a), edge)
	if progress < 0.995:
		# A damp, narrow paper edge follows the unfurl, without moving the text.
		_vertical_brush(canvas, Rect2(Vector2(edge - 2, rect.position.y + 5), Vector2(2, rect.size.y - 10)),
			Color(0.44, 0.40, 0.31, 0.13 * a), edge)

## Shared material brush. Modulation uses a real pigment texture, never an oval.
static func brush(canvas: CanvasItem, rect: Rect2, tint: Color,
		clip_right: float = INF) -> void:
	_image(canvas, BRUSH_TEXTURE, rect, BRUSH_SOURCE, tint, clip_right)

## A tiny imperfect cinnabar seal used for selection. The deliberately small
## mark has no baked-in text and remains separate from keyboard focus.
static func seal(canvas: CanvasItem, center: Vector2, extent: float = 7.0,
		alpha: float = 1.0) -> void:
	var half: float = extent * 0.5
	var points = PackedVector2Array([
		center + Vector2(-half, -half + 0.6), center + Vector2(half - 0.7, -half),
		center + Vector2(half, half - 0.3), center + Vector2(-half + 0.4, half)])
	canvas.draw_colored_polygon(points, Color(SEAL, alpha))
	canvas.draw_line(center + Vector2(-half * 0.25, -half * 0.55),
		center + Vector2(-half * 0.25, half * 0.46), Color(0.97, 0.92, 0.80, alpha * 0.72), 0.8, true)
	canvas.draw_line(center + Vector2(half * 0.25, -half * 0.20),
		center + Vector2(half * 0.25, half * 0.50), Color(0.97, 0.92, 0.80, alpha * 0.62), 0.8, true)

static func _image(canvas: CanvasItem, texture: Texture2D, dest: Rect2,
		source: Rect2, tint: Color, clip_right: float) -> void:
	if dest.size.x <= 0.0 or dest.size.y <= 0.0 or dest.position.x >= clip_right:
		return
	var proportion: float = clampf((clip_right - dest.position.x) / dest.size.x, 0.0, 1.0)
	var clipped_dest = Rect2(dest.position, Vector2(dest.size.x * proportion, dest.size.y))
	var clipped_source = Rect2(source.position, Vector2(source.size.x * proportion, source.size.y))
	canvas.draw_texture_rect_region(texture, clipped_dest, clipped_source, tint)

static func _vertical_brush(canvas: CanvasItem, rect: Rect2, tint: Color,
		clip_right: float) -> void:
	if rect.size.x <= 0.0 or rect.size.y <= 0.0 or rect.position.x >= clip_right:
		return
	var fraction: float = clampf((clip_right - rect.position.x) / rect.size.x, 0.0, 1.0)
	var right: float = rect.position.x + rect.size.x * fraction
	var points = PackedVector2Array([rect.position, Vector2(right, rect.position.y),
		Vector2(right, rect.end.y), Vector2(rect.position.x, rect.end.y)])
	var ts: Vector2 = BRUSH_TEXTURE.get_size()
	var u0: float = BRUSH_SOURCE.position.x / ts.x
	var u1: float = BRUSH_SOURCE.end.x / ts.x
	var v0: float = BRUSH_SOURCE.position.y / ts.y
	var v1: float = lerpf(BRUSH_SOURCE.position.y, BRUSH_SOURCE.end.y, fraction) / ts.y
	var uvs = PackedVector2Array([Vector2(u0, v0), Vector2(u0, v1), Vector2(u1, v1), Vector2(u1, v0)])
	canvas.draw_polygon(points, PackedColorArray([tint]), uvs, BRUSH_TEXTURE)

## Native TooltipPanel / Window panel bridge for callers that use Theme.
static func paper_style(margin_x: float = 12.0, margin_y: float = 8.0) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = PAPER_TEXTURE
	style.region_rect = PAPER_SOURCE
	style.texture_margin_left = 10.0
	style.texture_margin_right = 10.0
	style.texture_margin_top = 10.0
	style.texture_margin_bottom = 10.0
	style.content_margin_left = margin_x
	style.content_margin_right = margin_x
	style.content_margin_top = margin_y
	style.content_margin_bottom = margin_y
	return style

## Optional material bridge for stock dialog buttons. Native font colors
## remain the caller's responsibility (cream over an active soot brush).
static func brush_style(alpha: float = 0.92) -> StyleBoxTexture:
	var style = StyleBoxTexture.new()
	style.texture = BRUSH_TEXTURE
	style.region_rect = BRUSH_SOURCE
	style.modulate_color = Color(0.84, 0.83, 0.75, alpha)
	style.content_margin_left = 12.0
	style.content_margin_right = 12.0
	style.content_margin_top = 7.0
	style.content_margin_bottom = 7.0
	return style
