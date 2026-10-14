# tower.gd -> res://scripts/entities/tower.gd (no scene needed, created via Tower.new())
class_name Tower
extends Node2D

const GUN_SCENES := [
	preload("res://assets/guns/level_1/level_1.glb"),
	preload("res://assets/guns/level_2/level_2.glb"),
	preload("res://assets/guns/level_3/level_3.glb"),
	preload("res://assets/guns/level_4/level_4.glb"),
	preload("res://assets/guns/level_5/level_5.glb"),
	preload("res://assets/guns/level_6/level_6.glb"),
	preload("res://assets/guns/level_7/level_7.glb"),
	preload("res://assets/guns/level_8/level_8.glb"),
]
const TOON_SHADER := preload("res://shaders/gun_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/gun_outline.gdshader")

# ---- PER-LEVEL TUNING (index 0 = level 1 ... index 7 = level 8) ----
# CLIP: height of the cut. Everything below it is removed (base / floor plate).
const CLIP := [0.35, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35, 0.35]
const BASE_COLORS := [
	Color("6c9a5c"), Color("4a9fd8"), Color("8e6bd8"), Color("d86bb0"),
	Color("e0a030"), Color("e06030"), Color("d83a3a"), Color("40d8c8"),
]

# Extra turn in degrees, ONLY if the automatic barrel detection is wrong for a level.
# Turn on CALIBRATE, hover a tower and press Q / E; paste the printed list here.
static var aim_offset: Array = [0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0]
const CALIBRATE := false

# ---- gameplay (same as before) ----
const BASE_DAMAGE := 6.0
const DAMAGE_GROWTH := 2.4
const FIRE_RATE := 1.2
const TARGET_POOL := 15

# ---- look ----
const VIEW_PX := 384               # sharper render (go back to 320 if a phone lags)
const FOOTPRINT := 1.4             # gun length relative to the slot width (bigger = bigger gun)
const SIZE_LEVEL_1 := 0.85         # grows with level
const SIZE_LEVEL_8 := 1.05
const MODEL_FIT := 2.0             # internal model size (don't change)
const MAX_HEIGHT := 1.6            # tallest a gun may be
const CAMERA_SIZE := 3.6
const CAMERA_POS := Vector3(0.0, 4.0, 4.0)
const CAMERA_TARGET_Y := 0.6
const TURN_SPEED := 12.0
const OUTLINE_WIDTH := 0.022       # thinner outline looks cleaner

# ---- shooting effects ----
const RECOIL_PX := 7.0
const MERGE_QUIET := 0.6           # seconds a tower stays silent after a spawn / merge

static var _barrel_cache := {}     # level index -> [yaw, length, height]

var level := 1:
	set(v):
		level = v
		if is_node_ready():
			_load_model()
var cooldown := 0.0
var target: Zombie = null
var held := false                  # true while the player drags this tower (tower_grid.gd sets it)

var _busy := 0.0                   # no firing while this is above 0
var _viewport: SubViewport
var _holder: Node3D
var _model: Node3D
var _sprite: Sprite2D
var _flash: Polygon2D
var _flash_time := 0.0
var _aim_angle := 0.0
var _aim_dir := Vector2.UP         # screen direction to the target
var _aim_world := Vector2(0, -1)   # ground direction to the target (x, z)
var _recoil := 0.0
var _ppu := 100.0                  # screen pixels per model unit
var _barrel_yaw := 0.0
var _muzzle_len := 1.0
var _muzzle_h := 0.5


func damage() -> float:
	return BASE_DAMAGE * pow(DAMAGE_GROWTH, level - 1) * GameData.damage_mult()


func _ready() -> void:
	cooldown = randf() * (1.0 / FIRE_RATE)   # random start so towers don't fire together
	_build_viewport()
	_build_flash()
	_load_model()


func _elevation() -> float:
	return atan2(CAMERA_POS.y - CAMERA_TARGET_Y, CAMERA_POS.z)


func _build_viewport() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(VIEW_PX, VIEW_PX)
	_viewport.transparent_bg = true
	_viewport.own_world_3d = true
	_viewport.msaa_3d = Viewport.MSAA_4X
	_viewport.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA
	_viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(_viewport)

	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAMERA_SIZE
	_viewport.add_child(cam)
	cam.look_at_from_position(CAMERA_POS, Vector3(0, CAMERA_TARGET_Y, 0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, -30, 0)
	light.light_energy = 1.1
	_viewport.add_child(light)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.5
	cam.environment = env

	_holder = Node3D.new()
	_viewport.add_child(_holder)

	# puts the world origin (the cut line) exactly on the tower's slot centre
	var origin_below_centre := CAMERA_TARGET_Y * cos(_elevation())
	_sprite = Sprite2D.new()
	_sprite.texture = _viewport.get_texture()
	_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	_sprite.offset = Vector2(0, -origin_below_centre / CAMERA_SIZE * VIEW_PX)
	add_child(_sprite)


func _build_flash() -> void:
	_flash = Polygon2D.new()
	var pts := PackedVector2Array()
	for i in 16:
		var r := 24.0 if i % 2 == 0 else 8.0
		var a := TAU * i / 16.0
		pts.append(Vector2(cos(a), sin(a)) * r)
	_flash.polygon = pts
	_flash.color = Color(1.0, 1.0, 0.9)
	_flash.z_index = 5
	_flash.visible = false
	add_child(_flash)


func _load_model() -> void:
	if _model != null:
		_model.queue_free()
	var idx := clampi(level - 1, 0, GUN_SCENES.size() - 1)
	var scene: PackedScene = GUN_SCENES[idx]
	_model = scene.instantiate()
	_holder.add_child(_model)
	_holder.rotation.y = 0.0

	# fit: longest side = MODEL_FIT, but never taller than MAX_HEIGHT
	var box := _model_aabb(_model)
	var longest := maxf(box.size.x, maxf(box.size.y, box.size.z))
	var clip := float(CLIP[idx])
	if longest > 0.001 and box.size.y > 0.001:
		var k := minf(MODEL_FIT / longest, (MAX_HEIGHT + clip) / box.size.y)
		_model.scale = Vector3.ONE * k
		var base_center := Vector3(box.get_center().x, box.position.y, box.get_center().z)
		_model.position = -base_center * k

	_holder.position.y = -clip
	_apply_toon(_model)

	# find where the barrel points (cached per level)
	if not _barrel_cache.has(idx):
		_barrel_cache[idx] = _detect_barrel(clip)
	var info: Array = _barrel_cache[idx]
	_barrel_yaw = info[0]
	_muzzle_len = info[1]
	_muzzle_h = info[2]


# The barrel tip = the part of the model (above the cut) farthest from the centre.
# Returns [yaw the barrel currently points at, tip distance, tip height] in model units.
func _detect_barrel(clip: float) -> Array:
	var to_model := _model.global_transform.affine_inverse()
	var pts := PackedVector3Array()
	var far := 0.0
	for n in _model.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		if mi.mesh == null:
			continue
		var xf: Transform3D = to_model * mi.global_transform
		for s in mi.mesh.get_surface_count():
			var arr := mi.mesh.surface_get_arrays(s)
			var verts = arr[Mesh.ARRAY_VERTEX]
			if verts == null:
				continue
			for v in verts:
				var p: Vector3 = _model.transform * (xf * v)   # into the holder's space
				if p.y < clip:
					continue
				pts.append(p)
				far = maxf(far, Vector2(p.x, p.z).length())
	if far < 0.001 or pts.is_empty():
		return [0.0, 0.8, 0.5]
	var sum := Vector3.ZERO
	var count := 0
	for p in pts:
		if Vector2(p.x, p.z).length() >= far * 0.85:
			sum += p
			count += 1
	var c := sum / float(count)
	return [atan2(-c.x, -c.z), Vector2(c.x, c.z).length(), maxf(c.y - clip, 0.1)]


func _apply_toon(root: Node) -> void:
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		for s in mi.mesh.get_surface_count():
			var orig := mi.get_active_material(s)
			var mat := ShaderMaterial.new()
			mat.shader = TOON_SHADER
			if orig is BaseMaterial3D:
				var bm := orig as BaseMaterial3D
				if bm.albedo_texture != null:
					mat.set_shader_parameter("albedo_tex", bm.albedo_texture)
				mat.set_shader_parameter("tint", bm.albedo_color)
			var line := ShaderMaterial.new()
			line.shader = OUTLINE_SHADER
			line.set_shader_parameter("width", OUTLINE_WIDTH)
			mat.next_pass = line
			mi.set_surface_override_material(s, mat)


func _model_aabb(root: Node3D) -> AABB:
	var result := AABB()
	var first := true
	var to_root := root.global_transform.affine_inverse()
	for n in root.find_children("*", "MeshInstance3D", true, false):
		var mi := n as MeshInstance3D
		var b: AABB = to_root * mi.global_transform * mi.get_aabb()
		if first:
			result = b
			first = false
		else:
			result = result.merge(b)
	return result


# calibrator: hover a tower, press Q / E, copy the printed list into aim_offset above
func _unhandled_key_input(event: InputEvent) -> void:
	if not CALIBRATE:
		return
	var e := event as InputEventKey
	if e == null or not e.pressed or e.echo:
		return
	var step := 0.0
	if e.keycode == KEY_E:
		step = 15.0
	elif e.keycode == KEY_Q:
		step = -15.0
	else:
		return
	var mine := Arena.slot_at(global_position)
	if mine < 0 or mine != Arena.slot_at(get_global_mouse_position()):
		return
	var i := clampi(level - 1, 0, 7)
	aim_offset[i] = wrapf(float(aim_offset[i]) + step, -180.0, 180.0)
	print("level ", level, " offset ", aim_offset[i], "   ALL: ", aim_offset)


func _process(delta: float) -> void:
	queue_redraw()

	# size: follows perspective, grows slightly per level
	var t := float(level - 1) / float(LevelConfig.MAX_TOWER_LEVEL - 1)
	var factor := lerpf(SIZE_LEVEL_1, SIZE_LEVEL_8, t)
	var s := Persp.scale_at(position.y)
	var slot_px := Arena.SLOT_W * 2.0 * s
	_ppu = slot_px * FOOTPRINT * factor / MODEL_FIT
	_sprite.scale = Vector2.ONE * (CAMERA_SIZE * _ppu / VIEW_PX)

	# recoil kick
	_recoil = move_toward(_recoil, 0.0, delta * 60.0)
	_sprite.position = -_aim_dir * _recoil * s

	if _flash_time > 0.0:
		_flash_time -= delta
		if _flash_time <= 0.0:
			_flash.visible = false

	if not is_instance_valid(target) or target.dead:
		target = _pick_target()

	# only the head turns. The camera looks down, so the ground is squashed vertically;
	# we undo the squash, then subtract the barrel's own direction in the model.
	if target != null:
		var d := target.global_position - global_position
		if d.length() > 1.0:
			_aim_dir = d.normalized()
			var squash := sin(_elevation())
			_aim_world = Vector2(d.x, d.y / squash).normalized()
			var off := deg_to_rad(float(aim_offset[clampi(level - 1, 0, 7)]))
			var want := atan2(-_aim_world.x, -_aim_world.y) - _barrel_yaw + off
			_aim_angle = lerp_angle(_aim_angle, want, clampf(TURN_SPEED * delta, 0.0, 1.0))
			_holder.rotation.y = _aim_angle

	if _busy > 0.0:
		_busy -= delta
	cooldown -= delta
	if cooldown > 0.0 or target == null or held or _busy > 0.0:
		return

	var muzzle := _muzzle_pos()
	var p := Projectile.new()
	p.target = target
	p.damage = damage()
	p.global_position = to_global(muzzle)
	get_parent().add_child(p)
	cooldown = (1.0 / FIRE_RATE) * randf_range(0.8, 1.25)   # slightly different rhythm each shot

	_recoil = RECOIL_PX
	_flash.position = muzzle
	_flash.rotation = randf() * TAU
	_flash.scale = Vector2.ONE * s * randf_range(0.8, 1.3)
	_flash.visible = true
	_flash_time = 0.07


# the barrel tip on screen: forward along the aim, up by the barrel height
func _muzzle_pos() -> Vector2:
	var squash := sin(_elevation())
	var ground := Vector2(_aim_world.x, _aim_world.y * squash) * _muzzle_len * _ppu
	return ground + Vector2(0, -_muzzle_h * cos(_elevation()) * _ppu)


func _pick_target() -> Zombie:
	var zombies: Array = get_tree().get_nodes_in_group("zombies")
	if zombies.is_empty():
		return null
	zombies.sort_custom(func(a, b): return a.position.y > b.position.y)
	var pool_size := mini(TARGET_POOL, zombies.size())
	return zombies[randi() % pool_size]


# plays on spawn AND on every merge: the evolve effect (the gun stays quiet meanwhile)
func pop() -> void:
	_busy = MERGE_QUIET
	scale = Vector2(0.5, 0.5)
	var tw := create_tween()
	tw.tween_property(self, "scale", Vector2.ONE, 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	if _sprite != null:
		_sprite.modulate = Color(3, 3, 3)
		create_tween().tween_property(_sprite, "modulate", Color.WHITE, 0.35)
	_burst()


func _burst() -> void:
	var p := CPUParticles2D.new()
	p.one_shot = true
	p.amount = 22
	p.lifetime = 0.6
	p.explosiveness = 1.0
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 170.0
	p.scale_amount_min = 3.0
	p.scale_amount_max = 6.0
	p.color = Color(1.0, 0.95, 0.5)
	p.z_index = 6
	p.position = Vector2(0, -20)
	add_child(p)
	p.emitting = true
	get_tree().create_timer(1.0).timeout.connect(p.queue_free)


# the fixed cartoon base: fills the grid slot and never rotates
# round dark-metal platform with a glowing ring in the level colour (fixed, never rotates)
# hexagon metal base with a glowing ring in the level colour (fixed, never rotates)
func _draw() -> void:
	var col: Color = BASE_COLORS[clampi(level - 1, 0, BASE_COLORS.size() - 1)]
	var rx := Arena.plate_w_at(position.y) * 0.40
	var ry := Arena.plate_h_at(position.y) * 0.36
	draw_colored_polygon(_hex(rx * 1.1, ry * 1.1), Color(col.r, col.g, col.b, 0.22))   # glow
	draw_colored_polygon(_hex(rx, ry), Color("0f141c"))                                # dark rim
	draw_colored_polygon(_hex(rx * 0.92, ry * 0.92), Color("2b3445"))                  # steel plate
	draw_colored_polygon(_hex(rx * 0.62, ry * 0.62), col.darkened(0.5))                # inner hexagon
	var ring := _hex(rx * 0.8, ry * 0.8)
	ring.append(ring[0])
	draw_polyline(ring, col.lightened(0.15), 3.0)
	for p in _hex(rx * 0.92, ry * 0.92):                                               # six corner bolts
		draw_circle(p, 2.5, col.lightened(0.3))


func _hex(rx: float, ry: float) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in 6:
		var a := TAU * i / 6.0
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts
