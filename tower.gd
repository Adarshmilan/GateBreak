# tower.gd -> no scene needed (created via Tower.new())
class_name Tower
extends Node2D

const COLORS := [
	Color("6c9a5c"), Color("4a9fd8"), Color("8e6bd8"), Color("d86bb0"),
	Color("e0a030"), Color("e06030"), Color("d83a3a"), Color("f0e060"),
]
const BASE_DAMAGE := 6.0
const DAMAGE_GROWTH := 2.4     # >2 so merging is always worth it
const FIRE_RATE := 1.2         # shots per second
const FIRERATE_GROWTH := 1.5   # not used yet (fire rate per level comes later)
const TARGET_POOL := 15        # each tower picks randomly among the 15 front-most zombies
const BOX_W := 50.0            # tower footprint on the ground
const BOX_H := 42.0

var level := 1
var cooldown := 0.0
var target: Zombie = null

func damage() -> float:
	return BASE_DAMAGE * pow(DAMAGE_GROWTH, level - 1) * GameData.damage_mult()

func _process(delta: float) -> void:
	queue_redraw()   # shape depends on position (also while dragging)
	cooldown -= delta
	if cooldown > 0.0:
		return

	if not is_instance_valid(target) or target.dead:
		target = _pick_target()
	if target == null:
		return

	var p := Projectile.new()
	p.target = target
	p.damage = damage()
	p.global_position = global_position
	get_parent().add_child(p)
	cooldown = 1.0 / FIRE_RATE

func _pick_target() -> Zombie:
	var zombies: Array = get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty():
		return null
	zombies.sort_custom(func(a, b): return a.position.y > b.position.y)
	var pool_size := mini(TARGET_POOL, zombies.size())
	return zombies[randi() % pool_size]

func pop() -> void:
	scale = Vector2(1.3, 1.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)

func _draw() -> void:
	var col: Color = COLORS[clampi(level - 1, 0, COLORS.size() - 1)]

	# same ground-plane shape as the slots, converted to local coordinates
	var shape := PackedVector2Array()
	for pt in Persp.ground_quad(position, BOX_W, BOX_H):
		shape.append(pt - position)
	draw_colored_polygon(shape, col)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color.WHITE, 3.0)

	var s := Persp.scale_at(position.y)
	draw_string(ThemeDB.fallback_font, Vector2(-40.0 * s, 12.0 * s), str(level),
		HORIZONTAL_ALIGNMENT_CENTER, 80.0 * s, int(36.0 * s), Color.WHITE)
