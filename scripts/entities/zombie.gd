# zombie.gd -> res://scripts/entities/zombie.gd (no scene needed, created via Zombie.new())
# The look comes from ZombieFrames: pre-rendered images when available (fast), otherwise a
# live 3D render of the model (slow fallback). Camera / model settings live in zombie_frames.gd.
class_name Zombie
extends Node2D

signal died(zombie)
signal reached_gate        # fires on EVERY hit on the gate (once per ATTACK_INTERVAL)

const ATTACK_INTERVAL := 1.0

# model = which folder to use (2 -> zombie_2.glb, 3 -> zombie_3.glb)
# tint = colour multiplied over the model. Kind 5 is the Boss.
const KINDS := [
	{"name": "Walker", "model": 2, "hp": 1.0,  "speed": 1.0,  "radius": 20.0, "tint": Color(1.0, 1.0, 1.0),  "gate_damage": 1, "reward": 1.0},
	{"name": "Brute",  "model": 3, "hp": 1.7,  "speed": 0.95, "radius": 23.0, "tint": Color(0.85, 1.0, 0.85), "gate_damage": 1, "reward": 1.5},
	{"name": "Tank",   "model": 2, "hp": 3.2,  "speed": 0.85, "radius": 28.0, "tint": Color(1.0, 0.65, 0.35), "gate_damage": 2, "reward": 3.0},
	{"name": "Giant",  "model": 3, "hp": 5.5,  "speed": 0.75, "radius": 33.0, "tint": Color(0.7, 0.6, 1.0),  "gate_damage": 3, "reward": 4.5},
	{"name": "Boss",   "model": 3, "hp": 12.0, "speed": 0.6,  "radius": 40.0, "tint": Color(1.0, 0.35, 0.35), "gate_damage": 5, "reward": 8.0},
]

# ---- size on screen (tune these) ----
# size dial per MODEL (raise one if it looks small next to the other)
const SIZE_MULT := {2: 1.0, 3: 1.0}
const HEIGHT_PER_RADIUS := 3.4     # on-screen height = radius x this
const FEET_DROP := 0.9
const FALL_TIME := 0.45
const LIE_TIME := 1.0

var flash_frames := 0
var kind := 1
var max_hp := 12.0
var hp := 12.0
var speed := 45.0
var radius := 20.0
var gate_y := 540.0
var gate_damage := 1
var reward_mult := 1.0
var tint := Color.WHITE
var model_id := 2
var is_boss := false
var dead := false
var attacking := false
var attack_timer := 0.0
var lane_x := 270.0

var _sprite: Sprite2D
var _sprite_y := 0.0
var _top_y := -60.0
var _animated := false             # false = the model has no walk animation: waddle instead
var _t := randf() * 10.0

# pre-rendered look (fast path)
var _frames := {}
var _clip: Array = []              # images of the loop being played
var _clip_len := 1.0               # seconds the loop lasts
var _clip_t := 0.0
var _anim_speed := 1.0

# live 3D look (fallback)
var _viewport: SubViewport
var _fall: Node3D
var _anim: AnimationPlayer
var _attack := ""


func setup(new_kind: int, base_hp: float, base_speed: float) -> void:
	kind = clampi(new_kind, 1, KINDS.size())
	var k: Dictionary = KINDS[kind - 1]
	max_hp = base_hp * k["hp"]
	speed = base_speed * k["speed"]
	radius = k["radius"]
	tint = k["tint"]
	model_id = k["model"]
	gate_damage = k["gate_damage"]
	reward_mult = k["reward"]
	is_boss = kind == KINDS.size()


func _ready() -> void:
	hp = max_hp
	add_to_group("zombies")
	_anim_speed = clampf(speed / 45.0, 0.6, 1.6)
	_frames = ZombieFrames.get_frames(model_id)
	if not _frames.is_empty():
		_build_baked()
	else:
		_build_live()
	_update_scale()


# finds the blood layer; creates one if the game doesn't have it yet
func _blood() -> BloodLayer:
	var b := get_tree().get_first_node_in_group("blood") as BloodLayer
	if b == null:
		b = BloodLayer.new()
		get_parent().add_child(b)
		get_parent().move_child(b, 0)   # drawn behind towers and zombies
	return b


# the sprite that shows the zombie, sized and placed so the feet sit on our position
func _make_sprite(tex: Texture2D, fitted_h: float) -> void:
	var elev := deg_to_rad(ZombieFrames.CAM_ELEVATION)
	var ppu := radius * HEIGHT_PER_RADIUS * float(SIZE_MULT.get(model_id, 1.0)) / ZombieFrames.MODEL_H
	_sprite = Sprite2D.new()
	_sprite.texture = tex
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE * (ZombieFrames.CAMERA_SIZE * ppu / ZombieFrames.VIEW_PX)
	_sprite.self_modulate = tint
	_sprite_y = radius * FEET_DROP - ppu * ZombieFrames.CAM_TARGET_Y * cos(elev)
	_sprite.position = Vector2(0.0, _sprite_y)
	_top_y = radius * FEET_DROP - fitted_h * ppu * cos(elev)
	add_child(_sprite)


func _build_baked() -> void:
	_animated = _frames["animated"]
	_play_clip("walk")
	_clip_t = randf() * _clip_len                 # zombies don't step in sync
	_make_sprite(_clip[0], _frames["fitted_h"])
	_show_clip_frame()


func _play_clip(key: String) -> void:
	_clip = _frames[key]
	_clip_len = _frames[key + "_len"]
	_clip_t = 0.0


func _show_clip_frame() -> void:
	var n := _clip.size()
	var i := int(_clip_t / _clip_len * n) % n
	if _sprite.texture != _clip[i]:
		_sprite.texture = _clip[i]


func _build_live() -> void:
	var rig := ZombieFrames.build_rig(model_id, self)
	if rig.is_empty():
		return   # model missing: coloured circle fallback in _draw()
	_viewport = rig["viewport"]
	_fall = rig["fall"]
	_make_sprite(_viewport.get_texture(), rig["fitted_h"])
	_anim = rig["anim"]
	_attack = rig["attack"]
	var walk: String = rig["walk"]
	_animated = walk != ""
	if _animated:
		_anim.speed_scale = _anim_speed
		_anim.play(walk)
		_anim.seek(randf() * _anim.get_animation(walk).length)   # zombies don't step in sync


# ------------------------------------------------------------------ gameplay
func _process(delta: float) -> void:
	if dead:
		return
	if flash_frames > 0:
		flash_frames -= 1
		if flash_frames == 0:
			if _sprite != null:
				_sprite.modulate = Color.WHITE
			queue_redraw()

	if _animated and not _frames.is_empty():
		_clip_t = fmod(_clip_t + delta * _anim_speed, _clip_len)
		_show_clip_frame()

	if attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer += ATTACK_INTERVAL
			reached_gate.emit()
		return

	position.y += speed * delta
	_update_scale()

	# no walk animation in the model: waddle and bob
	if _sprite != null and not _animated:
		_t += delta * speed * 0.22
		_sprite.rotation = sin(_t) * 0.07
		_sprite.position.y = _sprite_y - absf(sin(_t)) * 4.0

	if position.y >= gate_y:
		position.y = gate_y
		_update_scale()
		attacking = true
		attack_timer = ATTACK_INTERVAL
		if _sprite != null:
			_sprite.rotation = 0.0
			_sprite.position.y = _sprite_y
		if not _frames.is_empty():
			if not _frames["attack"].is_empty():
				_play_clip("attack")
		elif _anim != null and _attack != "":
			_anim.play(_attack)


func take_damage(amount: float) -> void:
	if dead:
		return
	hp -= amount
	var blood := _blood()
	if hp <= 0.0:
		dead = true
		remove_from_group("zombies")
		died.emit(self)
		if is_boss:
			Audio.boss_die()
			Haptics.boss_die()
		else:
			Audio.zombie_die()
			Haptics.zombie_die()
		_die(blood)
	else:
		if not attacking:
			position.y -= 1.5
		flash_frames = 2
		if _sprite != null:
			_sprite.modulate = Color(1.8, 1.8, 1.8)
		if randf() < 0.3:
			blood.splash(position, radius * scale.x, false)
		queue_redraw()


func _die(blood: BloodLayer) -> void:
	var s := scale.x
	blood.splash(position, radius * s, true)
	blood.add_pool(position + Vector2(0, radius * FEET_DROP * s), radius * 1.7 * s)
	queue_redraw()   # removes the health bar

	if _anim != null:
		_anim.pause()
	if _sprite != null:
		_sprite.rotation = 0.0
		_sprite.position.y = _sprite_y
		_sprite.modulate = Color.WHITE

	var backwards := randf() < 0.7                 # mostly falls backwards
	var tw := create_tween()
	if not _frames.is_empty():
		_clip = _frames["fall_back" if backwards else "fall_fwd"]
		tw.tween_method(func(u: float): _sprite.texture = _clip[mini(int(u * _clip.size()), _clip.size() - 1)],
			0.0, 1.0, FALL_TIME)
	elif _fall != null:
		var dir := -1.0 if backwards else 1.0
		tw.tween_property(_fall, "rotation_degrees:x", 90.0 * dir, FALL_TIME) \
			.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
		tw.parallel().tween_property(_fall, "rotation_degrees:z", randf_range(-20.0, 20.0), FALL_TIME)
		tw.tween_callback(func():
			if _viewport != null:
				_viewport.render_target_update_mode = SubViewport.UPDATE_ONCE)
	elif _sprite != null:
		tw.tween_property(_sprite, "scale:y", _sprite.scale.y * 0.15, FALL_TIME)
	tw.tween_interval(LIE_TIME)
	tw.tween_property(self, "modulate:a", 0.0, 0.5)
	tw.tween_callback(queue_free)


func _update_scale() -> void:
	scale = Vector2.ONE * (Persp.scale_at(position.y) / Persp.scale_at(gate_y))
	position.x = Persp.screen_x(lane_x, position.y)


func _draw() -> void:
	if _sprite == null:
		var col := tint.lightened(0.6) if flash_frames > 0 else Color("5c9a4a") * tint
		draw_circle(Vector2.ZERO, radius, col)
		draw_circle(Vector2(-radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
		draw_circle(Vector2(radius * 0.35, -radius * 0.2), radius * 0.15, Color.BLACK)
		if not dead:
			_draw_bar(-radius - 10.0)
		return

	# neon-green glow + dark shadow under the feet
	var glow := PackedVector2Array()
	var shadow := PackedVector2Array()
	for i in 20:
		var a := TAU * i / 20.0
		var c := Vector2(0.0, radius * FEET_DROP)
		glow.append(c + Vector2(cos(a) * radius * 1.35, sin(a) * radius * 0.5))
		shadow.append(c + Vector2(cos(a) * radius * 1.0, sin(a) * radius * 0.32))
	var fade := 1.0 if not dead else 0.5
	draw_colored_polygon(glow, Color(0.35, 1.0, 0.3, 0.16 * fade))
	draw_colored_polygon(shadow, Color(0.0, 0.0, 0.0, 0.45 * fade))
	if not dead:
		_draw_bar(_top_y - 8.0)


func _draw_bar(y: float) -> void:
	var w := radius * 2.0
	draw_rect(Rect2(-radius - 2, y - 2, w + 4, 9), Color("120a0a"))      # dark outline
	draw_rect(Rect2(-radius, y, w, 5), Color("401010"))
	draw_rect(Rect2(-radius, y, w * clampf(hp / max_hp, 0.0, 1.0), 5), Color("ff4a4a"))
