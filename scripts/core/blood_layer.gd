# blood_layer.gd -> res://scripts/core/blood_layer.gd
# Draws blood pools on the ground and spawns blood splashes. Old pools fade out,
# and when there are too many, the oldest ones fade out faster.
class_name BloodLayer
extends Node2D

const MAX_POOLS := 40
const POOL_LIFE := 10.0          # seconds a pool lasts
const BLOOD := Color(0.8, 0.04, 0.06)

var pools: Array = []


func _ready() -> void:
	add_to_group("blood")


func add_pool(pos: Vector2, r: float) -> void:
	var pts := PackedVector2Array()
	var n := 14
	for i in n:
		var a := TAU * i / n
		var rr := r * randf_range(0.7, 1.15)
		pts.append(Vector2(cos(a) * rr, sin(a) * rr * 0.45))   # flat, like lying on the ground
	pools.append({
		"pos": pos, "pts": pts, "age": 0.0,
		"life": POOL_LIFE * randf_range(0.85, 1.15),
	})
	queue_redraw()


# a burst of blood drops; big = true when a zombie dies
func splash(pos: Vector2, size: float, big: bool) -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 18 if big else 6
	p.lifetime = 0.55
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2(0, 420)
	p.initial_velocity_min = 50.0 * (1.5 if big else 1.0)
	p.initial_velocity_max = 150.0 * (1.5 if big else 1.0)
	p.scale_amount_min = 2.0
	p.scale_amount_max = 4.5 if big else 3.0
	p.color = BLOOD
	p.position = pos + Vector2(0, -size * 0.8)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)
	if big:
		for i in 2:   # a few small drops around the main pool
			add_pool(pos + Vector2(randf_range(-1.0, 1.0), randf_range(-0.3, 0.3)) * size * 1.4, size * randf_range(0.3, 0.5))


func _process(delta: float) -> void:
	if pools.is_empty():
		return
	var extra := pools.size() - MAX_POOLS
	for i in pools.size():
		var speed := 1.0 + (3.0 if i < extra else 0.0)   # oldest pools vanish faster when crowded
		pools[i]["age"] += delta * speed
	for i in range(pools.size() - 1, -1, -1):
		if pools[i]["age"] >= pools[i]["life"]:
			pools.remove_at(i)
	queue_redraw()


func _draw() -> void:
	for p in pools:
		var a := clampf(1.0 - float(p["age"]) / float(p["life"]), 0.0, 1.0)
		a = a * a * 0.9
		draw_set_transform(p["pos"], 0.0, Vector2.ONE)
		draw_colored_polygon(p["pts"], Color(BLOOD.r, BLOOD.g, BLOOD.b, a))
		draw_set_transform(p["pos"], 0.0, Vector2(0.6, 0.6))
		draw_colored_polygon(p["pts"], Color(0.45, 0.02, 0.03, a))   # darker centre
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
