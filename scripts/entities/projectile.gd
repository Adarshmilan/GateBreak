# projectile.gd -> no scene needed (created via Projectile.new())
class_name Projectile
extends Node2D

const SPEED := 700.0

var target: Zombie
var damage := 5.0

func _process(delta: float) -> void:
	scale = Vector2.ONE * Persp.scale_at(global_position.y)
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var to := target.global_position - global_position
	rotation = to.angle()   # point the bullet at the zombie
	var step := SPEED * delta
	if to.length() <= step + target.radius * 0.5:
		target.take_damage(damage)
		queue_free()
	else:
		global_position += to.normalized() * step

func _draw() -> void:
	# bullet pointing right (+x); the rotation above turns it toward the target
	var body := PackedVector2Array([
		Vector2(-10, -3), Vector2(3, -3), Vector2(10, 0),
		Vector2(3, 3), Vector2(-10, 3),
	])
	draw_colored_polygon(body, Color("ffe070"))
	draw_rect(Rect2(-10, -3, 4, 6), Color("d09a30"))   # darker back end
