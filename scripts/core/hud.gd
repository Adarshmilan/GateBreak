# hud.gd -> res://scripts/ui/hud.gd
# Everything the player reads or taps during a round: labels, BUY button, banner, result panel.
# It only shows what game.gd tells it to show; it never changes game state itself.
class_name Hud
extends CanvasLayer

signal buy_pressed
const UI := "res://assets/UI/"
const BAR_RECT := Rect2(8, 8, 524, 64)   # x, y, width, height of the whole bar
var wave_bar: ProgressBar
const BTN_NORMAL := UI + "btn_normal.png"
const BTN_PRESSED := UI + "btn_pressed.png"
const BTN_DISABLE := UI + "btn_disable.png"
var gold_label: Label	
var gate_label: Label
var level_label: Label
var wave_label: Label
var time_label: Label
var banner: Label
var buy_btn: Button
var over_panel: Control
var over_label: Label
var primary_btn: Button
const BUY_RECT := Rect2(120, 880, 300, 64)   # x, y, width, height




func _ready() -> void:
	# the game pauses itself when the round ends; the result buttons must keep working then
	process_mode = Node.PROCESS_MODE_ALWAYS
	_build_top_bar()

	banner = _make_label(self, Vector2(0, 250), 56)
	banner.size = Vector2(540, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0

	buy_btn = Button.new()
	buy_btn.add_theme_font_size_override("font_size", 26)
	_skin_button(buy_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	buy_btn.position = BUY_RECT.position
	buy_btn.size = BUY_RECT.size
	buy_btn.pressed.connect(func(): buy_pressed.emit())
	add_child(buy_btn)
	_skin_button(buy_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)

	over_panel = Control.new()
	over_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.visible = false
	add_child(over_panel)
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.8)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	over_panel.add_child(dim)
	over_label = _make_label(over_panel, Vector2(0, 260), 40)
	over_label.size = Vector2(540, 200)
	over_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

	primary_btn = _make_button(over_panel, "RETRY", Vector2(120, 520), Vector2(300, 80))
	var menu_btn := _make_button(over_panel, "UPGRADES", Vector2(120, 630), Vector2(300, 80))
	_skin_button(primary_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	_skin_button(menu_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	
	primary_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))


func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l

func _build_top_bar() -> void:
	var bar := _make_image(self, UI + "top_bar.png", BAR_RECT.position, BAR_RECT.size)
	bar.self_modulate.a = 0.4

	# all positions below are INSIDE the bar (0,0 = top-left corner of the bar)

	# heart + HP
	_make_image(bar, UI + "icon_heart.png", Vector2(14, 18), Vector2(28, 28))
	gate_label = _bar_label(bar, Rect2(46, 14, 52, 36), 26, HORIZONTAL_ALIGNMENT_LEFT)

	# coin + gold
	_make_image(bar, UI + "icon_coin.png", Vector2(114, 18), Vector2(28, 28))
	gold_label = _bar_label(bar, Rect2(146, 14, 62, 36), 26, HORIZONTAL_ALIGNMENT_LEFT)

	# wave text + progress bar
	wave_label = _bar_label(bar, Rect2(222, 4, 178, 32), 24, HORIZONTAL_ALIGNMENT_CENTER)
	# wave progress bar: x, y, width, height (inside the top bar)
	var wave_bar_rect := Rect2(222, 42, 178, 10)

	wave_bar = ProgressBar.new()
	wave_bar.show_percentage = false            # must come BEFORE size
	wave_bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	wave_bar.min_value = 0.0
	wave_bar.max_value = 1.0

	var radius := int(wave_bar_rect.size.y / 2.0)   # keeps the ends round at any height
	var bg := StyleBoxFlat.new()
	bg.bg_color = Color(0.05, 0.08, 0.12)
	bg.set_corner_radius_all(radius)
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.2, 0.7, 1.0)
	fill.set_corner_radius_all(radius)
	wave_bar.add_theme_stylebox_override("background", bg)
	wave_bar.add_theme_stylebox_override("fill", fill)

	wave_bar.position = wave_bar_rect.position
	wave_bar.size = wave_bar_rect.size          # now height can be small
	bar.add_child(wave_bar)

	# level + time (stacked on the right)
	level_label = _bar_label(bar, Rect2(412, 6, 102, 28), 20, HORIZONTAL_ALIGNMENT_CENTER)
	time_label = _bar_label(bar, Rect2(412, 32, 102, 28), 22, HORIZONTAL_ALIGNMENT_CENTER)


# a label with a fixed box, text centered up/down
func _bar_label(parent: Node, rect: Rect2, font_size: int, h_align: HorizontalAlignment) -> Label:
	var l := _make_label(parent, rect.position, font_size)
	l.size = rect.size
	l.horizontal_alignment = h_align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _make_button(parent: Node, text: String, pos: Vector2, btn_size := Vector2(300, 80)) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", 32)
	_skin_button(b, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	b.position = pos
	b.size = btn_size
	parent.add_child(b)
	return b
	
func _make_image(parent: Node, path: String, pos: Vector2, img_size: Vector2) -> TextureRect:
	var t := TextureRect.new()
	t.expand_mode = TextureRect.EXPAND_IGNORE_SIZE   # must come BEFORE texture and size
	t.stretch_mode = TextureRect.STRETCH_SCALE
	t.mouse_filter = Control.MOUSE_FILTER_IGNORE
	t.texture = load(path)
	t.position = pos
	t.size = img_size
	parent.add_child(t)
	return t


# panel image + a label centered on it
func _make_panel(path: String, pos: Vector2, panel_size: Vector2, font_size: int) -> Label:
	var img := _make_image(self, path, pos, panel_size)
	var l := _make_label(img, Vector2.ZERO, font_size)
	l.size = panel_size
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	return l


func _skin_button(b: Button, normal: String, pressed: String, disabled: String) -> void:
	var make := func(path: String) -> StyleBoxTexture:
		var s := StyleBoxTexture.new()
		s.texture = load(path)
		s.content_margin_left = 24     # space between the left edge and the text
		s.content_margin_right = 24    # right edge
		s.content_margin_top = 8
		s.content_margin_bottom = 8
		return s
	b.add_theme_stylebox_override("normal", make.call(normal))
	b.add_theme_stylebox_override("hover", make.call(normal))
	b.add_theme_stylebox_override("pressed", make.call(pressed))
	b.add_theme_stylebox_override("disabled", make.call(disabled))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


@warning_ignore("integer_division")
func refresh(gold: int, gate_hp: int, lvl: int, wave: int, secs_left: int, cost: int) -> void:
	gold_label.text = str(gold)
	gate_label.text = str(gate_hp)
	level_label.text = "LEVEL %d" % lvl
	wave_label.text = "Wave %d / %d" % [wave, LevelConfig.WAVES]
	time_label.text = "%d:%02d" % [secs_left / 60, secs_left % 60]
	wave_bar.value = clampf(1.0 - float(secs_left) / LevelConfig.ROUND_TIME, 0.0, 1.0)
	buy_btn.text = "BUY TOWER (%dg)" % cost
	buy_btn.disabled = gold < cost


func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 1.5)


func show_result(text: String, primary_text: String) -> void:
	over_label.text = text
	primary_btn.text = primary_text
	over_panel.visible = true
