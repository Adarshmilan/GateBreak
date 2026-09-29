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

var level := 1
var cooldown := 0.0

func damage() -> float:
	return BASE_DAMAGE * pow(DAMAGE_GROWTH, level - 1) * GameData.damage_mult()

func _process(delta: float) -> void:
	cooldown -= delta
	if cooldown > 0.0:
		return
	var target := _find_target()
	if target == null:
		return
	var p := Projectile.new()
	p.target = target
	p.damage = damage()
	p.global_position = global_position
	get_parent().add_child(p)
	cooldown = 1.0 / FIRE_RATE

func _find_target() -> Zombie:
	var best: Zombie = null
	for z in get_tree().get_nodes_in_group("zombies"):
		if best == null or z.position.y > best.position.y:
			best = z
	return best

func pop() -> void:
	scale = Vector2(1.3, 1.3)
	create_tween().tween_property(self, "scale", Vector2.ONE, 0.2)

func _draw() -> void:
	var col: Color = COLORS[clampi(level - 1, 0, COLORS.size() - 1)]
	draw_rect(Rect2(-40, -40, 80, 80), col)
	draw_rect(Rect2(-40, -40, 80, 80), Color.WHITE, false, 3.0)
	draw_string(ThemeDB.fallback_font, Vector2(-40, 12), str(level),
		HORIZONTAL_ALIGNMENT_CENTER, 80, 36, Color.WHITE)
