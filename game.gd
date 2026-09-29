# game.gd -> attach to root Node2D of game.tscn
extends Node2D

const LANE_X := [90.0, 270.0, 450.0]
const SPAWN_Y := 60.0
const GATE_Y := 540.0
const GRID_Y := 650.0
const GRID_STEP := 100.0
const MAX_LEVEL := 8
const START_GOLD := 60

var gold := START_GOLD
var wave := 0
var kills := 0
var towers_bought := 0
var gate_max := 10
var gate_hp := 10
var over := false

var slots: Array = []          # 9 entries: Tower or null
var dragging: Tower = null
var drag_from := -1

var to_spawn := 0
var spawn_timer := 0.0
var spawn_interval := 1.0
var break_timer := 1.5

var gold_label: Label
var wave_label: Label
var gate_label: Label
var buy_btn: Button
var banner: Label
var over_panel: Control
var over_label: Label

func _ready() -> void:
	slots.resize(9)
	gate_max = GameData.gate_hp()
	gate_hp = gate_max
	_build_ui()
	_update_ui()

# ---------------------------------------------------------------- helpers
func slot_pos(i: int) -> Vector2:
	return Vector2(LANE_X[i % 3], GRID_Y + (i / 3) * GRID_STEP)

func tower_cost() -> int:
	return 20 + 4 * towers_bought

func _slot_at(p: Vector2) -> int:
	for i in 9:
		if absf(p.x - slot_pos(i).x) <= 46.0 and absf(p.y - slot_pos(i).y) <= 46.0:
			return i
	return -1

# ---------------------------------------------------------------- drawing
func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("1b1f2a"))
	for i in 3:
		var c := Color("242a38") if i % 2 == 0 else Color("2b3244")
		draw_rect(Rect2(i * 180, 0, 180, GATE_Y), c)
	draw_rect(Rect2(0, GATE_Y, 540, 24), Color("8b5a2b"))
	draw_rect(Rect2(0, GATE_Y + 28, 540, 10), Color("401010"))
	draw_rect(Rect2(0, GATE_Y + 28, 540.0 * float(gate_hp) / gate_max, 10), Color("e04040"))
	for i in 9:
		draw_rect(Rect2(slot_pos(i) - Vector2(46, 46), Vector2(92, 92)), Color("303850"))

# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	gold_label = _make_label(layer, Vector2(16, 8), 30)
	wave_label = _make_label(layer, Vector2(200, 8), 30)
	gate_label = _make_label(layer, Vector2(380, 8), 30)

	banner = _make_label(layer, Vector2(0, 250), 56)
	banner.size = Vector2(540, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0

	buy_btn = Button.new()
	buy_btn.position = Vector2(150, 900)
	buy_btn.size = Vector2(240, 50)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(_on_buy)
	layer.add_child(buy_btn)

	over_panel = Control.new()
	over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.visible = false
	layer.add_child(over_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(dim)
	over_label = _make_label(over_panel, Vector2(0, 260), 40)
	over_label.size = Vector2(540, 200)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	var retry := Button.new()
	retry.text = "RETRY"
	retry.position = Vector2(120, 520)
	retry.size = Vector2(300, 80)
	retry.add_theme_font_size_override("font_size", 32)
	retry.pressed.connect(func(): get_tree().reload_current_scene())
	over_panel.add_child(retry)

	var menu := Button.new()
	menu.text = "UPGRADES"
	menu.position = Vector2(120, 630)
	menu.size = Vector2(300, 80)
	menu.add_theme_font_size_override("font_size", 32)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://menu.tscn"))
	over_panel.add_child(menu)

func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _update_ui() -> void:
	gold_label.text = "G: %d" % gold
	wave_label.text = "Wave %d" % wave
	gate_label.text = "HP %d" % gate_hp
	buy_btn.text = "BUY TOWER (%dg)" % tower_cost()
	buy_btn.disabled = gold < tower_cost()
	queue_redraw()

func _show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 1.5)

# ---------------------------------------------------------------- buying
func _on_buy() -> void:
	if over or gold < tower_cost():
		return
	var empty: Array = []
	for i in 9:
		if slots[i] == null:
			empty.append(i)
	if empty.is_empty():
		_show_banner("NO SPACE!")
		return
	gold -= tower_cost()
	towers_bought += 1
	var i: int = empty.pick_random()
	var t := Tower.new()
	t.position = slot_pos(i)
	add_child(t)
	t.pop()
	slots[i] = t
	_update_ui()

# ---------------------------------------------------------------- drag & merge
func _input(event: InputEvent) -> void:
	if over:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			var i := _slot_at(get_global_mouse_position())
			if i >= 0 and slots[i] != null:
				dragging = slots[i]
				drag_from = i
				dragging.z_index = 10
		else:
			_drop()
	elif event is InputEventMouseMotion and dragging:
		dragging.position = get_global_mouse_position()

func _drop() -> void:
	if dragging == null:
		return
	var t := dragging
	dragging = null
	t.z_index = 0
	var j := _slot_at(get_global_mouse_position())
	if j < 0 or j == drag_from:
		t.position = slot_pos(drag_from)
		return
	var other: Tower = slots[j]
	if other == null:
		slots[drag_from] = null
		slots[j] = t
		t.position = slot_pos(j)
	elif other.level == t.level and t.level < MAX_LEVEL:
		slots[drag_from] = null
		t.queue_free()
		other.level += 1
		other.pop()
		other.queue_redraw()
	else:  # swap
		slots[drag_from] = other
		slots[j] = t
		other.position = slot_pos(drag_from)
		t.position = slot_pos(j)

# ---------------------------------------------------------------- waves
func _process(delta: float) -> void:
	if over:
		return
	if to_spawn > 0:
		spawn_timer -= delta
		if spawn_timer <= 0.0:
			_spawn_zombie()
			to_spawn -= 1
			spawn_timer = spawn_interval
	elif get_tree().get_nodes_in_group("zombies").is_empty():
		break_timer -= delta
		if break_timer <= 0.0:
			_start_wave()

func _start_wave() -> void:
	wave += 1
	to_spawn = 4 + wave * 2
	spawn_interval = maxf(0.35, 1.0 - wave * 0.03)
	spawn_timer = 0.0
	break_timer = 2.5
	_show_banner("WAVE %d" % wave)
	_update_ui()

func _spawn_zombie() -> void:
	var z := Zombie.new()
	var boss := (wave % 5 == 0 and to_spawn == 1)
	z.max_hp = 12.0 * pow(1.18, wave - 1)
	z.speed = minf(45.0 + wave * 2.0, 110.0)
	if boss:
		z.max_hp *= 8.0
		z.speed *= 0.6
		z.radius = 34.0
		z.is_boss = true
	z.gate_y = GATE_Y
	z.position = Vector2(LANE_X[randi() % 3], SPAWN_Y)
	z.died.connect(_on_zombie_died)
	z.reached_gate.connect(_on_gate_hit.bind(z))
	add_child(z)

func _on_zombie_died(z: Zombie) -> void:
	kills += 1
	var reward := 4.0 + wave * 0.5
	if z.is_boss:
		reward *= 5.0
	gold += int(round(reward * GameData.gold_mult()))
	_update_ui()

func _on_gate_hit(z: Zombie) -> void:
	gate_hp -= 5 if z.is_boss else 1
	gate_hp = maxi(gate_hp, 0)
	_update_ui()
	if gate_hp <= 0:
		_game_over()

func _game_over() -> void:
	over = true
	var earned := wave * 8 + kills / 4
	GameData.coins += earned
	GameData.best_wave = maxi(GameData.best_wave, wave)
	GameData.save_game()
	over_label.text = "THE GATE HAS FALLEN\n\nWave reached: %d\nZombies killed: %d\nCoins earned: %d" % [wave, kills, earned]
	over_panel.visible = true
