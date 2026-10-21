class_name ReadabilityLayout
extends RefCounted
## Native window pixels and logical UI units are deliberately separate. Keep
## book layouts intact while scaling their type, controls and art together.
const MIN_LOGICAL := Vector2(960, 320)

static func effective_scale(native_size: Vector2i, requested: float, display_scale: float = 1.0) -> float:
	if not is_finite(requested): requested = 1.5
	if not is_finite(display_scale): display_scale = 1.0
	var wanted := clampf(requested, 1.0, 1.75) * clampf(display_scale, 1.0, 3.0)
	return maxf(0.1, minf(wanted, minf(native_size.x / MIN_LOGICAL.x, native_size.y / MIN_LOGICAL.y)))

static func landscape_rect(logical_size: Vector2) -> Rect2:
	# Stable authored world units. Smaller viewports crop the edges; wider
	# windows reveal more panorama/quiet margins, never stretch scene or actors.
	return Rect2((logical_size.x-1040.0)/2.0,logical_size.y-280.0,1040.0,280.0)
