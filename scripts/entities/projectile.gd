# projectile.gd -> no scene needed (created via Projectile.new())
class_name Projectile
extends Node2D

const SPEED := 700.0      # game units per second (same on every screen size)

var target: Zombie
var damage := 5.0

# The bullet and its target are both children of the game node, so `position` is in game
# units for both. (global_position is in screen pixels and changes with the phone's resolution.)
func _process(delta: float) -> void:
	scale = Vector2.ONE * Persp.scale_at(position.y)
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var to := target.position - position
	rotation = to.angle()   # point the bullet at the zombie
	var step := SPEED * delta
	if to.length() <= step + target.radius * target.scale.x * 0.5:
		target.take_damage(damage)
		queue_free()
	else:
		position += to.normalized() * step

func _draw() -> void:
	# bullet pointing right (+x); the rotation above turns it toward the target
	var body := PackedVector2Array([
		Vector2(-10, -3), Vector2(3, -3), Vector2(10, 0),
		Vector2(3, 3), Vector2(-10, 3),
	])
	draw_colored_polygon(body, Color("ffe070"))
	draw_rect(Rect2(-10, -3, 4, 6), Color("d09a30"))   # darker back end
