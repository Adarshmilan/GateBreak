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

var level := 1
var cooldown := 0.0
var target: Zombie = null      # current locked target, kept until it dies

func damage() -> float:
	return BASE_DAMAGE * pow(DAMAGE_GROWTH, level - 1) * GameData.damage_mult()

func _process(delta: float) -> void:
	cooldown -= delta
	if cooldown > 0.0:
		return

	# only pick a new target if we have none, or the old one died / reached the gate
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
	# closest to the gate first (largest y)
	zombies.sort_custom(func(a, b): return a.position.y > b.position.y)
	var pool_size := mini(TARGET_POOL, zombies.size())
	return zombies[randi() % pool_size]

func pop() -> void:
	scale = Vector2(1.3, 1.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)

func _draw() -> void:
	var col: Color = COLORS[clampi(level - 1, 0, COLORS.size() - 1)]

	var shape := PackedVector2Array([
		Vector2(-32, -40),  # top left
		Vector2(32, -40),   # top right
		Vector2(40, 40),    # bottom right
		Vector2(-40, 40),   # bottom left
	])
	draw_colored_polygon(shape, col)

	# white outline (first point repeated to close the shape)
	var outline := shape.duplicate()
	outline.append(shape[0])
	draw_polyline(outline, Color.WHITE, 3.0)

	draw_string(ThemeDB.fallback_font, Vector2(-40, 12), str(level),
		HORIZONTAL_ALIGNMENT_CENTER, 80, 36, Color.WHITE)
