# arena.gd -> res://scripts/core/arena.gd
# The playfield: layout numbers, slot maths, and all drawing of the ground and gate bar.
# Nothing here has state, so nobody needs to create an Arena (just call Arena.something()).
class_name Arena
extends RefCounted

const GATE_Y := 500.0
const ZOMBIE_STOP_Y := 462.0     # where the zombies' FEET stop (the gate wall). Lower number = they stop higher up
const ROAD_FULL := preload("res://assets/road.jpg")     # above 90%
const ROAD_90   := preload("res://assets/gate30.png")   # 90% and below
const ROAD_50   := preload("res://assets/gate50.png")   # 50% and below
const ROAD_30   := preload("res://assets/gate90.png")   # 30% and below
const SCREEN_W := 540.0
const SCREEN_H := 960.0
const LANE_X := [90.0, 270.0, 450.0]
const SPAWN_Y := 60.0
const SLOT_COUNT := 9


# kept so other scripts that mention them still work
const GRID_Y := 650.0
const GRID_STEP := 100.0
const SLOT_W := 58.0
const SLOT_H := 50.0


# ---- SLOTS: centres of the 9 plates in the background art (screen pixels) ----
# One entry per ROW (top, middle, bottom). Plates widen and spread out toward the bottom.
const ROW_Y   := [599.0, 714.0, 845.0]
const COL_X   := [[127.0, 270.0, 410.0], [110.0, 270.0, 430.0], [95.0, 270.0, 445.0]]
const PLATE_W := [135.0, 150.0, 165.0]
const PLATE_H := [100.0, 110.0, 130.0]
const HIT_SHARE := 0.45          # click area = this share of the plate size
const DEBUG_SLOTS := false     # draws a thin outline on every plate: use it to calibrate, then set false

const GATE_BAR_Y := 528.0        # gate health bar, between the gate wall and the plates



@warning_ignore("integer_division")
static func slot_pos(i: int) -> Vector2:
	var r: int = i / 3
	var c: int = i % 3
	var x: float = COL_X[r][c]
	var y: float = ROW_Y[r]
	return Vector2(x, y)


# which slot is under screen point p? -1 if none
@warning_ignore("integer_division")
static func slot_at(p: Vector2) -> int:
	for i in SLOT_COUNT:
		var c: Vector2 = slot_pos(i)
		var r: int = i / 3
		var pw: float = PLATE_W[r]
		var ph: float = PLATE_H[r]
		if absf(p.x - c.x) <= pw * HIT_SHARE and absf(p.y - c.y) <= ph * HIT_SHARE:
			return i
	return -1


# plate size at any screen height (smooth between the rows); towers use this for their base
static func plate_w_at(y: float) -> float:
	return _row_lerp(PLATE_W, y)

static func plate_h_at(y: float) -> float:
	return _row_lerp(PLATE_H, y)

static func _row_lerp(values: Array, y: float) -> float:
	if y <= float(ROW_Y[0]):
		return float(values[0])
	for r in 2:
		var y0: float = ROW_Y[r]
		var y1: float = ROW_Y[r + 1]
		if y <= y1:
			var t: float = (y - y0) / (y1 - y0)
			return lerpf(float(values[r]), float(values[r + 1]), t)
	return float(values[2])


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


# Call from a node's _draw():  Arena.draw(self, gate_hp, gate_max)
@warning_ignore("integer_division")
static func draw(ci: CanvasItem, gate_hp: int, gate_max: int) -> void:
	ci.draw_rect(Rect2(0, 0, SCREEN_W, SCREEN_H), Color("1b1f2a"))

	# tall road art: covers the entire screen from the bottom plates up through the cosmic vortex
	ci.draw_texture_rect(road_texture(gate_hp, gate_max), Rect2(0.0, -245.0, SCREEN_W, 1205.0), false)

	# gate health bar (rounded, same shape as the wave bar)
	var bar_w := 240.0
	var bar_h := 12.0
	var bar_x := (SCREEN_W - bar_w) / 2.0
	_round_bar(ci, Rect2(bar_x, GATE_BAR_Y, bar_w, bar_h), Color(0.25, 0.06, 0.06))   # empty track
	var fill_w := bar_w * float(gate_hp) / gate_max
	if fill_w > 0.0:
		_round_bar(ci, Rect2(bar_x, GATE_BAR_Y, fill_w, bar_h), Color(0.88, 0.25, 0.25))   # health

	# calibration outlines: the plate rectangles the game thinks it has
	if DEBUG_SLOTS:
		for i in SLOT_COUNT:
			var c: Vector2 = slot_pos(i)
			var r: int = i / 3
			var pw: float = PLATE_W[r]
			var ph: float = PLATE_H[r]
			ci.draw_rect(Rect2(c.x - pw * 0.5, c.y - ph * 0.5, pw, ph),
				Color(0.2, 1.0, 1.0, 0.8), false, 1.5)


# draws a pill-shaped bar (ends are fully rounded)
static func _round_bar(ci: CanvasItem, rect: Rect2, color: Color) -> void:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(int(minf(rect.size.x, rect.size.y) / 2.0))
	ci.draw_style_box(s, rect)
