# zombie.gd -> no scene needed (created via Zombie.new())
class_name Zombie
extends Node2D

signal died(zombie)
signal reached_gate

var max_hp := 12.0
var hp := 12.0
var speed := 45.0
var radius := 20.0
var gate_y := 540.0
var is_boss := false
var dead := false

func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")

func _process(delta: float) -> void:
	position.y += speed * delta
	if position.y >= gate_y and not dead:
		dead = true
		remove_from_group("zombies")
		reached_gate.emit()
		queue_free()

func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	if hp <= 0.0:
		dead = true
		remove_from_group("zombies")
		died.emit(self)
		queue_free()
	else:
		queue_redraw()

func _draw() -> void:
	var body := Color("c03030") if is_boss else Color("5c9a4a")
	draw_circle(Vector2.ZERO, radius, body)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
	draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
	var w := radius * 2.0
	draw_rect(Rect2(-radius, -radius - 10, w, 5), Color("401010"))
	draw_rect(Rect2(-radius, -radius - 10, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color("e04040"))
