# arena.gd -> res://scripts/core/arena.gd
# The playfield: layout numbers, slot maths, and all drawing of the ground, gate and tower slots.
# Nothing here has state, so nobody needs to create an Arena (just call Arena.something()).
class_name Arena
extends RefCounted
const GATE_Y := 500.0
const ROAD_FULL := preload("res://assets/road.png")     # above 90%
const ROAD_90   := preload("res://assets/gate30.png")   # 90% and below
const ROAD_50   := preload("res://assets/gate50.png")   # 50% and below
const ROAD_30   := preload("res://assets/gate90.png")   # 30% and below
const SCREEN_W := 540.0
const SCREEN_H := 960.0
const LANE_X := [90.0, 270.0, 450.0]
const SPAWN_Y := 60.0
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

# picks the road image that matches how damaged the gate is
static func road_texture(gate_hp: int, gate_max: int) -> Texture2D:
	var pct := float(gate_hp) / gate_max * 100.0
	if pct <= 30.0:
		return ROAD_30
	if pct <= 50.0:
		return ROAD_50
	if pct <= 90.0:
		return ROAD_90
	return ROAD_FULL


# Call from a node's _draw():  Arena.draw(self, gate_hp, gae_max)
static func draw(ci: CanvasItem, gate_hp: int, gate_max: int) -> void:
	ci.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color("1b1f2a"))

	# one ground plane, from the far top all the way to the bottom of the screen
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(Persp.screen_x(0.0, 0.0), 0.0), Vector2(Persp.screen_x(SCREEN_W, 0.0), 0.0),
		Vector2(Persp.screen_x(SCREEN_W, SCREEN_H), SCREEN_H), Vector2(Persp.screen_x(0.0, SCREEN_H), SCREEN_H),
	]), Color("242a38"))
	
	# road art: scaled to the screen width, shifted up so its gate wall lands on GATE_Y
	ci.draw_texture_rect(ROAD_FULL, Rect2(0.0, GATE_Y - 525.0, 540.0, 959.5), false)

	# gate health bar, centred on the wall
		# gate health bar, centred on the wall (rounded, same shape as the wave bar)
	var bar_w := 240.0
	var bar_h := 12.0
	var bar_x := (SCREEN_W - bar_w) / 2.0
	var bar_y := GATE_Y + 95.0
	_round_bar(ci, Rect2(bar_x, bar_y, bar_w, bar_h), Color(0.25, 0.06, 0.06))   # empty track
	var fill_w := bar_w * float(gate_hp) / gate_max
	if fill_w > 0.0:
		_round_bar(ci, Rect2(bar_x, bar_y, fill_w, bar_h), Color(0.88, 0.25, 0.25))   # health

# draws a pill-shaped bar (ends are fully rounded)
static func _round_bar(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) / 2.0))
	ci.draw_style_box(s, rect)

	# tower slots lying on the same ground
	for i in SLOT_COUNT:
		var q := Persp.ground_quad(slot_pos(i), SLOT_W, SLOT_H)
		ci.draw_colored_polygon(q, Color("303850"))
		var o := q.duplicate()
		o.append(q[0])
		ci.draw_polyline(o, Color("46506e"), 2.0)
