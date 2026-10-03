# zombie.gd -> res://scripts/entities/zombie.gd (no scene needed, created via Zombie.new())
class_name Zombie
extends Node2D


signal died(zombie)
signal reached_gate        # now fires on EVERY hit on the gate (once per ATTACK_INTERVAL), not once

const ATTACK_INTERVAL := 1.0   # seconds between hits while the zombie stands at the gate

# The ladder: each kind is bigger and tougher than the one before it.
# hp / speed are multipliers on the wave-scaled base values.
const KINDS := [
	{"name": "Walker", "hp": 1.0,  "speed": 1.0,  "radius": 18.0, "color": Color("5c9a4a"), "gate_damage": 1, "reward": 1.0},
	{"name": "Brute",  "hp": 1.8,  "speed": 0.95, "radius": 22.0, "color": Color("b8a83a"), "gate_damage": 1, "reward": 1.5},
	{"name": "Tank",   "hp": 3.5,  "speed": 0.85, "radius": 27.0, "color": Color("d98a2b"), "gate_damage": 2, "reward": 2.5},
	{"name": "Giant",  "hp": 7.0,  "speed": 0.75, "radius": 32.0, "color": Color("8e4fd0"), "gate_damage": 3, "reward": 4.0},
	{"name": "Boss",   "hp": 14.0, "speed": 0.6,  "radius": 38.0, "color": Color("c03030"), "gate_damage": 5, "reward": 8.0},
]

var flash_frames := 0
var kind := 1
var max_hp := 12.0
var hp := 12.0
var speed := 45.0
var radius := 20.0
var gate_y := 540.0
var gate_damage := 1
var reward_mult := 1.0
var body_color := Color("5c9a4a")
var is_boss := false
var dead := false
var attacking := false   # true once it has reached the gate and stopped to hit it
var attack_timer := 0.0
var lane_x := 270.0     # the zombie's x at full size (set by game.gd)
# Call this BEFORE add_child(): it applies the kind's stats to the base values.
func setup(new_kind: int, base_hp: float, base_speed: float) -> void:
	kind = clampi(new_kind, 1, KINDS.size())
	var k: Dictionary = KINDS[kind - 1]
	max_hp = base_hp * k["hp"]
	speed = base_speed * k["speed"]
	radius = k["radius"]
	body_color = k["color"]
	gate_damage = k["gate_damage"]
	reward_mult = k["reward"]
	is_boss = kind == KINDS.size()

func _ready() -> void:
	hp = max_hp
	_update_scale()
	add_to_group("zombies")

func _process(delta: float) -> void:
	if dead:
		return
	if flash_frames > 0:
		flash_frames -= 1
		if flash_frames == 0:
			queue_redraw()   # go back to normal color

	if attacking:
		# stand at the gate and hit it every ATTACK_INTERVAL seconds until killed
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer += ATTACK_INTERVAL
			reached_gate.emit()
		return

	position.y += speed * delta
	_update_scale()
	if position.y >= gate_y:
		position.y = gate_y
		_update_scale()
		attacking = true
		attack_timer = ATTACK_INTERVAL   # first hit lands 1 second after arriving (set 0.0 for an instant hit)

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
		if not attacking:
			position.y -= 1.5  # small push back = impact feel (not while it is hitting the gate)
		flash_frames = 2       # bright for a frame or two
		queue_redraw()

func _update_scale() -> void:
	# same camera as the ground; scale is exactly 1.0 when it reaches the gate
	scale = Vector2.ONE * (Persp.scale_at(position.y) / Persp.scale_at(gate_y))
	position.x = Persp.screen_x(lane_x, position.y)

func _draw() -> void:
	var col := body_color.lightened(0.6) if flash_frames > 0 else body_color
	draw_circle(Vector2.ZERO, radius, col)
	draw_circle(Vector2(-radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
	draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
	var w := radius * 2.0
	draw_rect(Rect2(-radius, -radius - 10, w, 5), Color("401010"))
	draw_rect(Rect2(-radius, -radius - 10, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color("e04040"))
