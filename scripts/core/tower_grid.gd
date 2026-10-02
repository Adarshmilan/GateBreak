# tower_grid.gd -> res://scripts/core/tower_grid.gd
# Owns the 9 tower slots: placing new towers, dragging them around, merging and swapping.
# It knows nothing about gold or levels; game.gd decides if a purchase is allowed.
class_name TowerGrid
extends Node

var world: Node2D                 # towers (and their bullets) live in this node
var slots: Array = []             # 9 entries: Tower or null
var dragging: Tower = null
var drag_from := -1
var active := true                # false = ignore all input (round is over)


func setup(world_node: Node2D) -> void:
	world = world_node
	slots.resize(Arena.SLOT_COUNT)


func has_space() -> bool:
	return slots.has(null)


# put a new level-1 tower in a random empty slot (call has_space() first)
func add_tower() -> void:
	var empty: Array = []
	for i in slots.size():
		if slots[i] == null:
			empty.append(i)
	if empty.is_empty():
		return
	var pick: int = empty.pick_random()
	var t := Tower.new()
	t.position = Arena.slot_pos(pick)
	world.add_child(t)
	t.pop()
	slots[pick] = t


# round is over: put a half-dragged tower back and stop listening
func lock() -> void:
	active = false
	if dragging != null:
		dragging.z_index = 0
		dragging.position = Arena.slot_pos(drag_from)
		dragging = null


# Pressing is "unhandled" so buttons get the click first ...
func _unhandled_input(event: InputEvent) -> void:
	if not active:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		var i := Arena.slot_at(world.get_global_mouse_position())
		if i >= 0 and slots[i] != null:
			dragging = slots[i]
			drag_from = i
			dragging.z_index = 10


# ... but moving and releasing use _input, so a drag can never get stuck
# (e.g. if you let go while the mouse is over the BUY button).
func _input(event: InputEvent) -> void:
	if not active or dragging == null:
		return
	if event is InputEventMouseMotion:
		dragging.position = world.get_global_mouse_position()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and not event.pressed:
		_drop()


func _drop() -> void:
	var t := dragging
	dragging = null
	t.z_index = 0
	var j := Arena.slot_at(world.get_global_mouse_position())
	if j < 0 or j == drag_from:
		t.position = Arena.slot_pos(drag_from)
		return
	var other: Tower = slots[j]
	if other == null:                                   # move to an empty slot
		slots[drag_from] = null
		slots[j] = t
		t.position = Arena.slot_pos(j)
	elif other.level == t.level and t.level < LevelConfig.MAX_TOWER_LEVEL:   # merge
		slots[drag_from] = null
		t.queue_free()
		other.level += 1
		other.pop()
		other.queue_redraw()
	else:                                               # swap
		slots[drag_from] = other
		slots[j] = t
		other.position = Arena.slot_pos(drag_from)
		t.position = Arena.slot_pos(j)
