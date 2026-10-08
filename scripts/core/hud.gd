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
const DEFEAT_SCALE := 0.87     # 1.0 = full image size; lower = smaller
const DEFEAT_Y := 220.0        # top of the image on screen

var defeat_art: Control
var defeat_wave_label: Label
var defeat_coin_label: Label
var defeat_kill_label: Label
const VICTORY_SCALE := 1.0     # 1.0 = full image size
const VICTORY_Y := 170.0       # top of the image on screen
# our button, in image pixels; it covers the green button drawn in the picture
const VICTORY_BTN := Rect2(178, 322, 256, 58)

var victory_art: Control
var victory_kill_label: Label
var victory_coin_label: Label
var victory_level_label: Label
var secondary_btn: Button

const PAUSE_SCALE := 1.2     # 1.0 = full image size
const PAUSE_Y := 290.0        # top of the image on screen

var pause_panel: Control
var pause_btn: Button




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
	
	_build_defeat_art()
	
	_build_victory_art()

	primary_btn = _make_button(over_panel, "RETRY", Vector2(120, 520), Vector2(300, 80))
	secondary_btn = _make_button(over_panel, "UPGRADES", Vector2(120, 630), Vector2(300, 80))
	_skin_button(primary_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	_skin_button(secondary_btn, BTN_NORMAL, BTN_PRESSED, BTN_DISABLE)
	
	primary_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	secondary_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/upgrades.tscn"))
	
	_build_pause_menu()


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

func _build_victory_art() -> void:
	victory_art = Control.new()
	victory_art.visible = false
	victory_art.size = Vector2(612, 408)                  # the image's own size
	victory_art.scale = Vector2(VICTORY_SCALE, VICTORY_SCALE)
	victory_art.position = Vector2((540.0 - 612.0 * VICTORY_SCALE) / 2.0, VICTORY_Y)
	over_panel.add_child(victory_art)

	var pic := TextureRect.new()
	pic.texture = load(UI + "victory.png")
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	victory_art.add_child(pic)

	# slot boxes in IMAGE pixels: Rect2(x, y, width, height)
	victory_kill_label = _victory_stat(Rect2(121, 290, 100, 25))    # zombie killed
	victory_coin_label = _victory_stat(Rect2(258, 290, 98, 25))     # coin earned
	victory_level_label = _victory_stat(Rect2(395, 290, 98, 25))    # level


func _victory_stat(rect: Rect2) -> Label:
	var l := _bar_label(victory_art, rect, 20, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.1))
	l.add_theme_constant_override("outline_size", 5)
	return l


func show_victory(kills: int, coins: int, level: int) -> void:
	show_result("", "NEXT LEVEL")
	over_label.visible = false
	victory_art.visible = true
	victory_kill_label.text = str(kills)
	victory_coin_label.text = str(coins)
	victory_level_label.text = str(level)
	# first button sits right over the button drawn in the image
	primary_btn.position = victory_art.position + VICTORY_BTN.position * VICTORY_SCALE
	primary_btn.size = VICTORY_BTN.size * VICTORY_SCALE
	# second button just below the art
	secondary_btn.position = Vector2(120, victory_art.position.y + 405.0 * VICTORY_SCALE)
	secondary_btn.size = Vector2(300, 70)



func _build_defeat_art() -> void:
	defeat_art = Control.new()
	defeat_art.visible = false
	defeat_art.size = Vector2(866, 288)                 # the image's own size
	defeat_art.scale = Vector2(DEFEAT_SCALE, DEFEAT_SCALE)
	defeat_art.position = Vector2((540.0 - 866.0 * DEFEAT_SCALE) / 2.0, DEFEAT_Y)   # centered
	over_panel.add_child(defeat_art)

	var pic := TextureRect.new()
	pic.texture = load(UI + "defeated.png")
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	defeat_art.add_child(pic)

	# slot boxes in IMAGE pixels: Rect2(x, y, width, height)
	defeat_wave_label = _defeat_stat(Rect2(245, 205, 83, 35))    # shield slot
	defeat_coin_label = _defeat_stat(Rect2(410, 205, 82, 35))    # coin slot
	defeat_kill_label = _defeat_stat(Rect2(577, 205, 88, 35))    # chest slot


func _defeat_stat(rect: Rect2) -> Label:
	var l := _bar_label(defeat_art, rect, 28, HORIZONTAL_ALIGNMENT_CENTER)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	return l


func show_banner(text: String) -> void:
	banner.text = text
	banner.modulate.a = 1.0
	create_tween().tween_property(banner, "modulate:a", 0.0, 1.5)


func show_result(text: String, primary_text: String) -> void:
	pause_btn.visible = false
	over_label.text = text
	over_label.visible = true
	defeat_art.visible = false
	victory_art.visible = false
	primary_btn.text = primary_text
	over_panel.visible = true


func show_defeat(wave: int, waves: int, kills: int, coins: int) -> void:
	show_result("", "RETRY")
	over_label.visible = false
	defeat_art.visible = true
	defeat_wave_label.text = "%d/%d" % [wave, waves]
	defeat_coin_label.text = str(coins)
	defeat_kill_label.text = str(kills)



func _build_pause_menu() -> void:
	# small pause button on the HUD (below the top bar, right side)
	pause_btn = Button.new()
	pause_btn.text = "II"
	pause_btn.add_theme_font_size_override("font_size", 24)
	pause_btn.position = Vector2(472, 80)
	pause_btn.size = Vector2(60, 44)
	pause_btn.pressed.connect(open_pause)
	add_child(pause_btn)

	# the pause screen: dark dim + the panel image
	pause_panel = Control.new()
	pause_panel.visible = false
	pause_panel.size = Vector2(540, 960)
	add_child(pause_panel)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.size = Vector2(540, 960)
	pause_panel.add_child(dim)

	var art := Control.new()
	art.size = Vector2(1050, 700)                          # the image's own size
	art.scale = Vector2(PAUSE_SCALE, PAUSE_SCALE)
	art.position = Vector2((540.0 - 612.0 * PAUSE_SCALE) / 2.0, PAUSE_Y)
	pause_panel.add_child(art)

	var pic := TextureRect.new()
	pic.texture = load(UI + "pause_menu.png")
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	art.add_child(pic)

	# invisible buttons placed over the 3 buttons in the picture (image pixels)
	_hotspot(art, Rect2(197, 130, 218, 50), close_pause)   # green: resume
	_hotspot(art, Rect2(197, 195, 218, 50), _restart)      # blue: restart
	_hotspot(art, Rect2(197, 259, 218, 50), _go_home)      # blue: home


# a see-through button; it only darkens a little while pressed
func _hotspot(parent: Node, rect: Rect2, action: Callable) -> void:
	var b := Button.new()
	b.flat = true
	b.focus_mode = Control.FOCUS_NONE
	for s in ["normal", "hover", "focus", "disabled"]:
		b.add_theme_stylebox_override(s, StyleBoxEmpty.new())
	var press := StyleBoxFlat.new()
	press.bg_color = Color(0, 0, 0, 0.25)
	press.set_corner_radius_all(24)
	b.add_theme_stylebox_override("pressed", press)
	b.position = rect.position
	b.size = rect.size
	b.pressed.connect(action)
	parent.add_child(b)


func open_pause() -> void:
	if over_panel.visible or pause_panel.visible:
		return                       # not after the round has ended
	pause_panel.visible = true
	get_tree().paused = true


func close_pause() -> void:
	pause_panel.visible = false
	get_tree().paused = false


func _restart() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()


func _go_home() -> void:
	get_tree().paused = false
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# phone back button / Esc also opens and closes the pause menu
func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not over_panel.visible:
		if pause_panel.visible:
			close_pause()
		else:
			open_pause()
