# arena.gd -> res://scripts/core/arena.gd
# The playfield: layout numbers, slot maths, and all drawing of the ground, gate and tower slots.
# Nothing here has state, so nobody needs to create an Arena (just call Arena.something()).
class_name Arena
extends RefCounted

const SCREEN_W := 540.0
const SCREEN_H := 960.0
const LANE_X := [90.0, 270.0, 450.0]
const SPAWN_Y := 60.0
const GATE_Y := 540.0
const GRID_Y := 650.0
const GRID_STEP := 100.0
const SLOT_COUNT := 9
const SLOT_W := 58.0
const SLOT_H := 50.0
const SLOT_HIT := 46.0          # how close (px) a click must be to a slot centre to count


# screen position of slot i (0..8), 3 per row
@warning_ignore("integer_division")
static func slot_pos(i: int) -> Vector2:
	var y := GRID_Y + (i / 3) * GRID_STEP
	return Vector2(Persp.screen_x(LANE_X[i % 3], y), y)


# which slot is under screen point p? -1 if none
static func slot_at(p: Vector2) -> int:
	for i in SLOT_COUNT:
		var c := slot_pos(i)
		if absf(p.x - c.x) <= SLOT_HIT and absf(p.y - c.y) <= SLOT_HIT:
			return i
	return -1


# left (x) and right (y) edge of the road at screen height y
static func road_edges(y: float) -> Vector2:
	return Vector2(Persp.screen_x(0.0, y), Persp.screen_x(SCREEN_W, y))


# Call from a node's _draw():  Arena.draw(self, gate_hp, gate_max)
static func draw(ci: CanvasItem, gate_hp: int, gate_max: int) -> void:
	ci.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color("1b1f2a"))

	# one ground plane, from the far top all the way to the bottom of the screen
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(Persp.screen_x(0.0, 0.0), 0.0), Vector2(Persp.screen_x(SCREEN_W, 0.0), 0.0),
		Vector2(Persp.screen_x(SCREEN_W, SCREEN_H), SCREEN_H), Vector2(Persp.screen_x(0.0, SCREEN_H), SCREEN_H),
	]), Color("242a38"))

	# gate: a wall across the road
	var g0 := road_edges(GATE_Y)
	var g1 := road_edges(GATE_Y + 24.0)
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(g0.x, GATE_Y), Vector2(g0.y, GATE_Y),
		Vector2(g1.y, GATE_Y + 24.0), Vector2(g1.x, GATE_Y + 24.0),
	]), Color("8b5a2b"))

	# gate health bar, same width as the road at that height
	var hb := road_edges(GATE_Y + 28.0)
	var hw := hb.y - hb.x
	ci.draw_rect(Rect2(hb.x, GATE_Y + 28.0, hw, 10), Color("401010"))
	ci.draw_rect(Rect2(hb.x, GATE_Y + 28.0, hw * float(gate_hp) / gate_max, 10), Color("e04040"))

	# tower slots lying on the same ground
	for i in SLOT_COUNT:
		var q := Persp.ground_quad(slot_pos(i), SLOT_W, SLOT_H)
		ci.draw_colored_polygon(q, Color("303850"))
		var o := q.duplicate()
		o.append(q[0])
		ci.draw_polyline(o, Color("46506e"), 2.0)
