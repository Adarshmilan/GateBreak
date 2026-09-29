# projectile.gd -> no scene needed (created via Projectile.new())
class_name Projectile
extends Node2D

const SPEED := 700.0

var target: Zombie
var damage := 5.0

func _process(delta: float) -> void:
	if not is_instance_valid(target) or target.dead:
		queue_free()
		return
	var to := target.global_position - global_position
	var step := SPEED * delta
	if to.length() <= step + target.radius * 0.5:
		target.take_damage(damage)
		queue_free()
	else:
		global_position += to.normalized() * step

func _draw() -> void:
	draw_circle(Vector2.ZERO, 6.0, Color("ffe070"))
