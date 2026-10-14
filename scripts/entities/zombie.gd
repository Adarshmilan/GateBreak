# zombie.gd -> res://scripts/entities/zombie.gd (no scene needed, created via Zombie.new())
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

# ---- model look (tune these) ----
const MODEL_PATH := "res://assets/zombies/zombie_%d/zombie_%d.glb"
# turn each MODEL so its face points at the camera (try 90, 180, -90)
const MODEL_YAW := {2: 0.0, 3: 0.0}
# size dial per MODEL (raise one if it looks small next to the other)
const SIZE_MULT := {2: 1.0, 3: 1.0}
const HEIGHT_PER_RADIUS := 3.4     # on-screen height = radius x this
const FEET_DROP := 0.9
const VIEW_PX := 192
const CAMERA_SIZE := 4.0           # raise if a zombie is cut off at the edges
const MODEL_H := 2.0
const MODEL_W := 2.8
const CAM_ELEVATION := 30.0
const CAM_TARGET_Y := 1.0
const FALL_TIME := 0.45
const LIE_TIME := 1.0
const TOON_SHADER := preload("res://shaders/gun_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/gun_outline.gdshader")

static var _scenes := {}

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

var _viewport: SubViewport
var _fall: Node3D
var _sprite: Sprite2D
var _sprite_y := 0.0
var _top_y := -60.0
var _anim: AnimationPlayer
var _walk := ""
var _attack := ""
var _t := randf() * 10.0


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
	_build_model()
	_update_scale()


static func _get_scene(m: int) -> PackedScene:
	if not _scenes.has(m):
		var path := MODEL_PATH % [m, m]
		_scenes[m] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[m]


# finds the blood layer; creates one if the game doesn't have it yet
func _blood() -> BloodLayer:
	var b := get_tree().get_first_node_in_group("blood") as BloodLayer
	if b == null:
		b = BloodLayer.new()
		get_parent().add_child(b)
		get_parent().move_child(b, 0)   # drawn behind towers and zombies
	return b


func _build_model() -> void:
	var scene := _get_scene(model_id)
	if scene == null:
		return   # model missing: coloured circle fallback in _draw()

	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_PX, VIEW_PX)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_2X
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var elev := deg_to_rad(CAM_ELEVATION)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAMERA_SIZE
	_viewport.add_child(cam)
	var dist := 6.0
	cam.look_at_from_position(
		Vector3(0.0, CAM_TARGET_Y + dist * tan(elev), dist), Vector3(0.0, CAM_TARGET_Y, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 0, 0)
	light.light_energy = 1.2
	_viewport.add_child(light)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	cam.environment = env

	_fall = Node3D.new()
	_viewport.add_child(_fall)
	var holder := Node3D.new()
	_fall.add_child(holder)
	holder.rotation_degrees.y = float(MODEL_YAW[model_id])
	var model: Node3D = scene.instantiate()
	holder.add_child(model)

	var box := _model_aabb(model)
	var fitted_h := MODEL_H
	if box.size.y > 0.001:
		var wide := maxf(box.size.x, box.size.z)
		var k := MODEL_H / box.size.y
		if wide > 0.001:
			k = minf(k, MODEL_W / wide)
		model.scale = Vector3.ONE * k
		model.position = -Vector3(box.get_center().x, box.position.y, box.get_center().z) * k
		fitted_h = box.size.y * k

	_apply_toon(model)

	var ppu := radius * HEIGHT_PER_RADIUS * float(SIZE_MULT[model_id]) / MODEL_H
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.scale = Vector2.ONE * (CAMERA_SIZE * ppu / VIEW_PX)
	_sprite.self_modulate = tint
	_sprite_y = radius * FEET_DROP - ppu * CAM_TARGET_Y * cos(elev)
	_sprite.position = Vector2(0.0, _sprite_y)
	_top_y = radius * FEET_DROP - fitted_h * ppu * cos(elev)
	add_child(_sprite)

	_setup_animations(model)


func _apply_toon(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var orig := mi.get_active_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = TOON_SHADER
			mat.set_shader_parameter("clip_y", -100.0)
			mat.set_shader_parameter("smooth_lod", 0.7)
			mat.set_shader_parameter("saturation", 1.5)
			if orig is BaseMaterial3D:
				var bm := orig as BaseMaterial3D
				if bm.albedo_texture != null:
					mat.set_shader_parameter("albedo_tex", bm.albedo_texture)
				mat.set_shader_parameter("tint", bm.albedo_color)
			var line := ShaderMaterial.new()
			line.shader = OUTLINE_SHADER
			line.set_shader_parameter("width", 0.03)
			line.set_shader_parameter("clip_y", -100.0)
			mat.next_pass = line
			mi.set_surface_override_material(s, mat)


func _setup_animations(model: Node) -> void:
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		print("zombie model ", model_id, ": no animations (using waddle)")
		return
	_anim = players[0]
	var names: Array = []
	for n in _anim.get_animation_list():
		if String(n).to_lower() != "reset":
			names.append(String(n))
	print("zombie model ", model_id, " animations: ", names)

	_attack = _pick(names, ["attack", "punch", "bite", "swing", "hit"])
	_walk = _pick(names, ["walk", "run", "move", "shamble", "crawl"])
	if _walk == "":
		for n in names:
			var low := String(n).to_lower()
			if n != _attack and not low.contains("death") and not low.contains("die"):
				_walk = n
				break
	if _walk != "":
		_anim.get_animation(_walk).loop_mode = Animation.LOOP_LINEAR
		_anim.speed_scale = clampf(speed / 45.0, 0.6, 1.6)
		_anim.seek(randf() * _anim.get_animation(_walk).length)   # zombies don't step in sync
		_anim.play(_walk)
	if _attack != "":
		_anim.get_animation(_attack).loop_mode = Animation.LOOP_LINEAR


func _pick(names: Array, words: Array) -> String:
	for n in names:
		var low := String(n).to_lower()
		for w in words:
			if low.contains(w):
				return n
	return ""


func _model_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var to_root := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var b: AABB = to_root * mi.global_transform * mi.get_aabb()
		if first:
			result = b
			first = false
		else:
			result = result.merge(b)
	return result


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

	if attacking:
		attack_timer -= delta
		if attack_timer <= 0.0:
			attack_timer += ATTACK_INTERVAL
			reached_gate.emit()
		return

	position.y += speed * delta
	_update_scale()

	# no walk animation in the model: waddle and bob
	if _sprite != null and _walk == "":
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
		if _anim != null and _attack != "":
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
		else:
			Audio.zombie_die()
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

	var tw := create_tween()
	if _fall != null:
		var dir := -1.0 if randf() < 0.7 else 1.0     # mostly falls backwards
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
