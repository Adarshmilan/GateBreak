# screen_fit.gd -> res://scripts/core/screen_fit.gd
# Works out how to fit the 540x960 game onto any phone screen.
class_name ScreenFit
extends RefCounted

const W := 540.0
const H := 960.0


static func view_size(n: Node) -> Vector2:
	return n.get_viewport().get_visible_rect().size


# pixels at the top / bottom covered by a notch or the gesture bar (in view units)
static func inset_top(n: Node) -> float:
	return _inset(n, true)

static func inset_bottom(n: Node) -> float:
	return _inset(n, false)

static func _inset(n: Node, top: bool) -> float:
	if not OS.has_feature("mobile"):
		return 0.0
	var win_h := float(DisplayServer.window_get_size().y)
	var safe := DisplayServer.get_display_safe_area()
	if win_h <= 0.0 or safe.size.y <= 0:
		return 0.0
	var k := view_size(n).y / win_h
	if top:
		return maxf(0.0, float(safe.position.y) * k)
	return maxf(0.0, (win_h - float(safe.position.y + safe.size.y)) * k)


# scale and position for the game so it fits and sits at the bottom, centred sideways
static func fit(n: Node) -> float:
	var vs := view_size(n)
	var avail_h := vs.y - inset_bottom(n)
	return minf(vs.x / W, avail_h / H)

static func origin(n: Node) -> Vector2:
	var vs := view_size(n)
	var f := fit(n)
	return Vector2((vs.x - W * f) / 2.0, vs.y - inset_bottom(n) - H * f)
