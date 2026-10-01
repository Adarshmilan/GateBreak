# game.gd -> attach to root Node2D of game.tscn
extends Node2D

const LANE_X := [90.0, 270.0, 450.0]
const SPAWN_Y := 60.0
const GATE_Y := 540.0
const GRID_Y := 650.0
const GRID_STEP := 100.0


var lvl := 1                   # level being played (from GameData.level)
var assist_stacks := 0         # losses in a row -> easier zombies + more gold
var assist := 0.0
var gold := 0
var wave := 0                  # 1..3 (current wave number)
var elapsed := 0.0             # seconds since the round started
var schedule: Array = []       # every zombie of this level, with its spawn time
var spawn_i := 0
var kills := 0
var towers_bought := 0
var gate_max := 10
var gate_hp := 10
var over := false

var slots: Array = []          # 9 entries: Tower or null
var dragging: Tower = null
var drag_from := -1

const SLOT_W := 58.0
const SLOT_H := 50.0

var gold_label: Label
var wave_label: Label
var level_label: Label
var time_label: Label
var gate_label: Label
var buy_btn: Button
var banner: Label
var over_panel: Control
var over_label: Label
var primary_btn: Button

func _ready() -> void:
	slots.resize(9)
	lvl = GameData.level
	assist_stacks = GameData.fail_streak
	assist = LevelConfig.assist_amount(assist_stacks)
	gold = LevelConfig.start_gold(lvl, assist_stacks)
	gate_max = LevelConfig.gate_hp(lvl) + GameData.gate_bonus()
	gate_hp = gate_max
	_build_schedule()
	_build_ui()
	_update_ui()
	_start_wave(1)

# ---------------------------------------------------------------- helpers
func slot_pos(i: int) -> Vector2:
	var y := GRID_Y + (i / 3) * GRID_STEP
	return Vector2(Persp.screen_x(LANE_X[i % 3], y), y)

func tower_cost() -> int:
	return LevelConfig.tower_cost(lvl, towers_bought)

func _slot_at(p: Vector2) -> int:
	for i in 9:
		if absf(p.x - slot_pos(i).x) <= 46.0 and absf(p.y - slot_pos(i).y) <= 46.0:
			return i
	return -1

func _road_edges(y: float) -> Vector2:
	return Vector2(Persp.screen_x(0.0, y), Persp.screen_x(540.0, y))

func _draw() -> void:
	draw_rect(Rect2(0, 0, 540, 960), Color("1b1f2a"))

	# one ground plane, from the far top all the way to the bottom of the screen
	draw_colored_polygon(PackedVector2Array([
		Vector2(Persp.screen_x(0.0, 0.0), 0.0), Vector2(Persp.screen_x(540.0, 0.0), 0.0),
		Vector2(Persp.screen_x(540.0, 960.0), 960.0), Vector2(Persp.screen_x(0.0, 960.0), 960.0),
	]), Color("242a38"))

	# gate: a wall across the road
	var g0 := _road_edges(GATE_Y)
	var g1 := _road_edges(GATE_Y + 24.0)
	draw_colored_polygon(PackedVector2Array([
		Vector2(g0.x, GATE_Y), Vector2(g0.y, GATE_Y),
		Vector2(g1.y, GATE_Y + 24.0), Vector2(g1.x, GATE_Y + 24.0),
	]), Color("8b5a2b"))

	# gate health bar, same width as the road at that height
	var hb := _road_edges(GATE_Y + 28.0)
	var hw := hb.y - hb.x
	draw_rect(Rect2(hb.x, GATE_Y + 28.0, hw, 10), Color("401010"))
	draw_rect(Rect2(hb.x, GATE_Y + 28.0, hw * float(gate_hp) / gate_max, 10), Color("e04040"))

	# tower slots lying on the same ground
	for i in 9:
		var q := Persp.ground_quad(slot_pos(i), SLOT_W, SLOT_H)
		draw_colored_polygon(q, Color("303850"))
		var o := q.duplicate()
		o.append(q[0])
		draw_polyline(o, Color("46506e"), 2.0)
# ---------------------------------------------------------------- UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)

	gold_label = _make_label(layer, Vector2(16, 8), 28)
	gate_label = _make_label(layer, Vector2(400, 8), 28)
	level_label = _make_label(layer, Vector2(16, 44), 24)
	wave_label = _make_label(layer, Vector2(190, 44), 24)
	time_label = _make_label(layer, Vector2(400, 44), 24)

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

	primary_btn = Button.new()
	primary_btn.text = "RETRY"
	primary_btn.position = Vector2(120, 520)
	primary_btn.size = Vector2(300, 80)
	primary_btn.add_theme_font_size_override("font_size", 32)
	primary_btn.pressed.connect(func(): get_tree().reload_current_scene())
	over_panel.add_child(primary_btn)

	var menu := Button.new()
	menu.text = "UPGRADES"
	menu.position = Vector2(120, 630)
	menu.size = Vector2(300, 80)
	menu.add_theme_font_size_override("font_size", 32)
	menu.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	over_panel.add_child(menu)

func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _update_ui() -> void:
	gold_label.text = "G: %d" % gold
	gate_label.text = "HP %d" % gate_hp
	level_label.text = "Level %d" % lvl
	wave_label.text = "Wave %d/%d" % [wave, LevelConfig.WAVES]
	var left := maxi(0, int(ceil(LevelConfig.ROUND_TIME - elapsed)))
	time_label.text = "%d:%02d" % [left / 60, left % 60]
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
	elif other.level == t.level and t.level < LevelConfig.MAX_TOWER_LEVEL:
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

# ---------------------------------------------------------------- level / waves
# Build the whole level up front: 3 waves, each with its own zombie count, spread over its time window.
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
	if over:
		return
	elapsed += delta
	var w := mini(int(elapsed / LevelConfig.wave_length()) + 1, LevelConfig.WAVES)
	if w != wave:
		_start_wave(w)
	while spawn_i < schedule.size() and schedule[spawn_i]["t"] <= elapsed:
		_spawn_zombie(schedule[spawn_i])
		spawn_i += 1
	if spawn_i >= schedule.size() and get_tree().get_nodes_in_group("zombies").is_empty():
		_win()
	_update_ui()

func _start_wave(w: int) -> void:
	wave = w
	if w > 1:
		# reward + a little repair between waves
		gold += LevelConfig.wave_bonus_gold(lvl)
		gate_hp = mini(gate_max, gate_hp + int(ceil(gate_max * LevelConfig.GATE_HEAL_BETWEEN_WAVES)))
	_show_banner("FINAL WAVE!" if w == LevelConfig.WAVES else "WAVE %d" % w)
	_update_ui()

func _spawn_zombie(entry: Dictionary) -> void:
	var z := Zombie.new()
	z.setup(entry["kind"], entry["hp"], entry["speed"])
	var margin := z.radius / Persp.scale_at(GATE_Y) + 4.0
	var lane_x := randf_range(margin, 540.0 - margin)
	z.lane_x = lane_x
	z.position = Vector2(Persp.screen_x(lane_x, SPAWN_Y), SPAWN_Y)
	z.gate_y = GATE_Y
	z.died.connect(_on_zombie_died)
	z.reached_gate.connect(_on_gate_hit.bind(z))
	add_child(z)

# x of a lane boundary (0 to 3) at a given y

func _on_zombie_died(z: Zombie) -> void:
	kills += 1
	var reward: float = LevelConfig.kill_reward(lvl) * z.reward_mult
	gold += int(round(reward * GameData.gold_mult()))
	_update_ui()

func _on_gate_hit(z: Zombie) -> void:
	gate_hp -= z.gate_damage
	gate_hp = maxi(gate_hp, 0)
	_update_ui()
	if gate_hp <= 0:
		_game_over()

func _win() -> void:
	over = true
	var earned := LevelConfig.win_coins(lvl, kills)
	GameData.complete_level(earned)
	over_label.text = "LEVEL %d CLEARED!\n\nZombies killed: %d\nCoins earned: %d" % [lvl, kills, earned]
	primary_btn.text = "NEXT LEVEL"
	over_panel.visible = true

func _game_over() -> void:
	over = true
	var share := float(wave) / LevelConfig.WAVES
	var earned := int(LevelConfig.win_coins(lvl, kills) * LevelConfig.LOSE_COIN_FRACTION * share)
	GameData.fail_level(earned)
	over_label.text = "THE GATE HAS FALLEN\n\nLevel %d  -  reached wave %d/%d\nZombies killed: %d\nCoins earned: %d\n\nNext try gets a little help." % [lvl, wave, LevelConfig.WAVES, kills, earned]
	primary_btn.text = "RETRY"
	over_panel.visible = true
