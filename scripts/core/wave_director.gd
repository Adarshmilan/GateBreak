# wave_director.gd -> res://scripts/core/wave_director.gd
# Builds the whole level up front (3 waves, each with its own zombie count spread over its
# time window), then spawns zombies on schedule and reports what happens via signals.
class_name WaveDirector
extends Node

signal wave_started(wave: int)
signal zombie_died(zombie: Zombie)
signal zombie_reached_gate(zombie: Zombie)
signal cleared                             # everything spawned and everything dead

var world: Node2D                          # zombies are added here
var lvl := 1
var assist := 0.0
var wave := 0                              # 1..3 (current wave number)
var elapsed := 0.0                         # seconds since the round started
var schedule: Array = []                   # every zombie of this level, with its spawn time
var spawn_i := 0
var running := false


func setup(world_node: Node2D, level: int, assist_amount: float) -> void:
	world = world_node
	lvl = level
	assist = assist_amount
	_build_schedule()


func start() -> void:
	running = true
	_set_wave(1)


func stop() -> void:
	running = false


func _build_schedule() -> void:
	schedule.clear()
	var wl := LevelConfig.wave_length()
	var base_hp := LevelConfig.zombie_hp(lvl, assist)
	var base_speed := LevelConfig.zombie_speed(lvl)
	for w in LevelConfig.WAVES:
		var is_final := (w == LevelConfig.WAVES - 1)
		var c := LevelConfig.wave_count(lvl, w)
		var bosses := LevelConfig.boss_count(lvl) if is_final else 0
		for i in c:
			var kind := 5 if i >= c - bosses else LevelConfig.pick_kind(lvl, is_final)
			schedule.append({
				"t": w * wl + (i + 0.5) / c * wl * LevelConfig.SPAWN_WINDOW,
				"kind": kind,
				"hp": base_hp * (LevelConfig.FINAL_WAVE_HP_MULT if is_final else 1.0),
				"speed": base_speed * (LevelConfig.FINAL_WAVE_SPEED_MULT if is_final else 1.0),
			})
	schedule.sort_custom(func(a, b): return a["t"] < b["t"])


func _process(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	var w := mini(int(elapsed / LevelConfig.wave_length()) + 1, LevelConfig.WAVES)
	if w != wave:
		_set_wave(w)
	while spawn_i < schedule.size() and schedule[spawn_i]["t"] <= elapsed:
		_spawn_zombie(schedule[spawn_i])
		spawn_i += 1
	if spawn_i >= schedule.size() and get_tree().get_nodes_in_group("zombies").is_empty():
		running = false
		cleared.emit()


func _set_wave(w: int) -> void:
	wave = w
	wave_started.emit(w)


func _spawn_zombie(entry: Dictionary) -> void:
	var z := Zombie.new()
	z.setup(entry["kind"], entry["hp"], entry["speed"])
	var margin := z.radius / Persp.scale_at(Arena.GATE_Y) + 4.0
	var lane_x := randf_range(margin, Arena.SCREEN_W - margin)
	z.lane_x = lane_x
	z.position = Vector2(Persp.screen_x(lane_x, Arena.SPAWN_Y), Arena.SPAWN_Y)
	z.gate_y = Arena.GATE_Y
	z.died.connect(func(zz): zombie_died.emit(zz))
	z.reached_gate.connect(func(): zombie_reached_gate.emit(z))
	world.add_child(z)
