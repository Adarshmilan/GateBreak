# perspective.gd -> res://scripts/core/perspective.gd (one shared "camera" for the whole playfield)
class_name Persp
extends RefCounted

const CENTER_X := 270.0
const HORIZON_Y := -550.0   # the vanishing point (above the screen). Closer to 0 = stronger 3D
const REF_Y := 960.0        # screen y where things are drawn at scale 1.0

# how big things look at a given screen height
static func scale_at(y: float) -> float:
	return (y - HORIZON_Y) / (REF_Y - HORIZON_Y)

# flat "world" x -> screen x at height y (everything squeezes toward the center going up)
static func screen_x(world_x: float, y: float) -> float:
	return CENTER_X + (world_x - CENTER_X) * scale_at(y)

# a box lying on the ground, centered at a screen position; returns 4 screen-space corners.
# Its sides point at the vanishing point, same as the road edges.
static func ground_quad(center: Vector2, half_w: float, half_h: float) -> PackedVector2Array:
	var s := scale_at(center.y)
	var dx := (center.x - CENTER_X) / s
	var hh := half_h * s
	var y_top := center.y - hh
	var y_bot := center.y + hh
	var s_top := scale_at(y_top)
	var s_bot := scale_at(y_bot)
	var cx_top := CENTER_X + dx * s_top
	var cx_bot := CENTER_X + dx * s_bot
	return PackedVector2Array([
		Vector2(cx_top - half_w * s_top, y_top), Vector2(cx_top + half_w * s_top, y_top),
		Vector2(cx_bot + half_w * s_bot, y_bot), Vector2(cx_bot - half_w * s_bot, y_bot),
	])
