# zombie_frames.gd -> AUTOLOAD named "ZombieFrames"
# Every zombie of the same model looks the same from our fixed camera; only its tint, size and
# animation timing differ. So instead of every zombie running its own live 3D render each frame
# (very heavy on phones), each model is rendered ONCE at startup into flat images:
#   walk loop, attack loop, and falling over (backwards and forwards).
# Zombies then flip through those images like a cartoon (see zombie.gd).
# If baking is impossible (headless) or not finished yet, zombies fall back to a live 3D render,
# built by build_rig() below, so the look is identical either way.
extends Node

signal baked                         # all models are ready

const ENABLED := true                # false = every zombie renders live 3D (old, slow behaviour)
const MODELS := [2, 3]               # model ids to pre-render (zombie_2.glb, zombie_3.glb)

# ---- 3D look (shared by baked frames and the live fallback) ----
const MODEL_PATH := "res://assets/zombies/zombie_%d/zombie_%d.glb"
const MODEL_YAW := {2: 0.0, 3: 0.0}  # turn each MODEL so its face points at the camera (try 90, 180, -90)
const VIEW_PX := 192
const CAMERA_SIZE := 4.0             # raise if a zombie is cut off at the edges
const MODEL_H := 2.0
const MODEL_W := 2.8
const CAM_ELEVATION := 30.0
const CAM_TARGET_Y := 1.0
const TOON_SHADER := preload("res://shaders/gun_toon.gdshader")
const OUTLINE_SHADER := preload("res://shaders/gun_outline.gdshader")
const WALK_WORDS := ["walk", "run", "move", "shamble", "crawl"]       # priority order
const ATTACK_WORDS := ["attack", "punch", "bite", "swing", "hit"]

# ---- baking ----
const LOOP_FRAMES := 16              # images per walk / attack loop
const FALL_FRAMES := 8               # images per fall direction
const BATCH := 16                    # rigs rendered at the same time while baking

var _scenes := {}
var _frames := {}                    # model id -> Dictionary (see _bake_model)
var _logged := {}
var done := false


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	if ENABLED and DisplayServer.get_name() != "headless":
		_bake_all.call_deferred()
	else:
		done = true


# baked images for a model, or {} if not available (then render live)
func get_frames(model_id: int) -> Dictionary:
	return _frames.get(model_id, {})


func get_scene(m: int) -> PackedScene:
	if not _scenes.has(m):
		var path := MODEL_PATH % [m, m]
		_scenes[m] = load(path) if ResourceLoader.exists(path) else null
	return _scenes[m]


# Builds the 3D setup for one zombie model inside `parent`:
# SubViewport -> camera, light, fall pivot -> holder (yaw) -> fitted model with toon materials.
# Returns {} if the model is missing, else:
# {viewport, fall, anim (AnimationPlayer or null), walk, attack (animation names, "" = none), fitted_h}
func build_rig(model_id: int, parent: Node, msaa := Viewport.MSAA_2X) -> Dictionary:
	var scene := get_scene(model_id)
	if scene == null:
		return {}

	var vp := SubViewport.new()
	vp.size = Vector2i(VIEW_PX, VIEW_PX)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = msaa
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	parent.add_child(vp)

	var elev := deg_to_rad(CAM_ELEVATION)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = CAMERA_SIZE
	vp.add_child(cam)
	var dist := 6.0
	cam.look_at_from_position(
		Vector3(0.0, CAM_TARGET_Y + dist * tan(elev), dist), Vector3(0.0, CAM_TARGET_Y, 0.0))

	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-50, 0, 0)
	light.light_energy = 1.2
	vp.add_child(light)

	var env := Environment.new()
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color.WHITE
	env.ambient_light_energy = 0.55
	cam.environment = env

	var fall := Node3D.new()
	vp.add_child(fall)
	var holder := Node3D.new()
	fall.add_child(holder)
	holder.rotation_degrees.y = float(MODEL_YAW.get(model_id, 0.0))
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

	var rig := {"viewport": vp, "fall": fall, "anim": null, "walk": "", "attack": "", "fitted_h": fitted_h}
	var players := model.find_children("*", "AnimationPlayer", true, false)
	if players.is_empty():
		_log_once(model_id, "no animations (using waddle)")
		return rig
	var anim: AnimationPlayer = players[0]
	var names: Array = []
	for n in anim.get_animation_list():
		if String(n).to_lower() != "reset":
			names.append(String(n))
	_log_once(model_id, "animations: " + str(names))

	var attack := _pick(names, ATTACK_WORDS)
	var walk := _pick(names, WALK_WORDS)
	if walk == "":
		for n in names:
			var low := String(n).to_lower()
			if n != attack and not low.contains("death") and not low.contains("die"):
				walk = n
				break
	if walk != "":
		anim.get_animation(walk).loop_mode = Animation.LOOP_LINEAR
	if attack != "":
		anim.get_animation(attack).loop_mode = Animation.LOOP_LINEAR
	rig["anim"] = anim
	rig["walk"] = walk
	rig["attack"] = attack
	return rig


# ------------------------------------------------------------------ baking
func _bake_all() -> void:
	for m in MODELS:
		if get_scene(m) == null:
			continue
		var data := await _bake_model(m)
		if data.is_empty():
			push_warning("ZombieFrames: could not pre-render zombies, using live 3D instead")
			break
		_frames[m] = data
	done = true
	baked.emit()


# Renders one model's frames. Returns {} on failure, else:
# {walk: [Texture2D], walk_len, attack: [Texture2D] (may be empty), attack_len,
#  fall_back: [Texture2D], fall_fwd: [Texture2D], fitted_h, animated: bool}
func _bake_model(m: int) -> Dictionary:
	var probe := build_rig(m, self)
	var anim: AnimationPlayer = probe["anim"]
	var walk: String = probe["walk"]
	var attack: String = probe["attack"]
	var data := {
		"fitted_h": probe["fitted_h"], "animated": walk != "",
		"walk_len": anim.get_animation(walk).length if walk != "" else 1.0,
		"attack_len": anim.get_animation(attack).length if attack != "" else 1.0,
	}
	probe["viewport"].queue_free()

	# every image to render: [key, animation name, time, fall angle in degrees]
	var jobs: Array = []
	var walk_n := LOOP_FRAMES if walk != "" else 1
	for i in walk_n:
		jobs.append(["walk", walk, data["walk_len"] * i / walk_n, 0.0])
	if attack != "":
		for i in LOOP_FRAMES:
			jobs.append(["attack", attack, data["attack_len"] * i / LOOP_FRAMES, 0.0])
	for dir in [-1.0, 1.0]:                                   # -1 = falls backwards
		for i in FALL_FRAMES:
			var u := float(i + 1) / FALL_FRAMES
			jobs.append(["fall_back" if dir < 0.0 else "fall_fwd", walk, 0.0, 90.0 * dir * u * u])   # ease-in

	for key in ["walk", "attack", "fall_back", "fall_fwd"]:
		data[key] = []
	var start := 0
	while start < jobs.size():
		var batch: Array = jobs.slice(start, start + BATCH)
		var rigs: Array = []
		for job in batch:
			var rig := build_rig(m, self)
			if rig["anim"] != null and job[1] != "":
				var ap: AnimationPlayer = rig["anim"]
				ap.play(job[1])
				ap.seek(job[2], true)
				ap.pause()
			rig["fall"].rotation_degrees.x = job[3]
			rigs.append(rig)
		# give the skeletons a frame to pose, and the viewports a frame to draw
		await RenderingServer.frame_post_draw
		await RenderingServer.frame_post_draw
		var ok := true
		for j in rigs.size():
			var img: Image = rigs[j]["viewport"].get_texture().get_image()
			if img == null or img.is_empty() or img.get_used_rect().size == Vector2i.ZERO:
				ok = false
			else:
				data[batch[j][0]].append(ImageTexture.create_from_image(img))
			rigs[j]["viewport"].queue_free()
		if not ok:
			return {}
		start += BATCH
	return data


# ------------------------------------------------------------------ helpers
func _log_once(model_id: int, msg: String) -> void:
	if OS.is_debug_build() and not _logged.has(model_id):
		_logged[model_id] = true
		print("zombie model ", model_id, " ", msg)


# first animation matching the EARLIEST word in the list (words are in priority order,
# so "walk" wins over "crawl" and "attack" wins over "hit")
func _pick(names: Array, words: Array) -> String:
	for w in words:
		for n in names:
			if String(n).to_lower().contains(w):
				return n
	return ""


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
