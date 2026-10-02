# hud.gd -> res://scripts/ui/hud.gd
# Everything the player reads or taps during a round: labels, BUY button, banner, result panel.
# It only shows what game.gd tells it to show; it never changes game state itself.
class_name Hud
extends CanvasLayer

signal buy_pressed

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


func _ready() -> void:
	# the game pauses itself when the round ends; the result buttons must keep working then
	process_mode = Node.PROCESS_MODE_ALWAYS

	gold_label = _make_label(self, Vector2(16, 8), 28)
	gate_label = _make_label(self, Vector2(400, 8), 28)
	level_label = _make_label(self, Vector2(16, 44), 24)
	wave_label = _make_label(self, Vector2(190, 44), 24)
	time_label = _make_label(self, Vector2(400, 44), 24)

	banner = _make_label(self, Vector2(0, 250), 56)
	banner.size = Vector2(540, 80)
	banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	banner.modulate.a = 0.0

	buy_btn = Button.new()
	buy_btn.position = Vector2(150, 900)
	buy_btn.size = Vector2(240, 50)
	buy_btn.add_theme_font_size_override("font_size", 26)
	buy_btn.pressed.connect(func(): buy_pressed.emit())
	add_child(buy_btn)

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

	primary_btn = _make_button(over_panel, "RETRY", Vector2(120, 520))
	primary_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().reload_current_scene())
	var menu_btn := _make_button(over_panel, "UPGRADES", Vector2(120, 630))
	menu_btn.pressed.connect(func():
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/menu.tscn"))


func _make_label(parent: Node, pos: Vector2, font_size: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", font_size)
	parent.add_child(l)
	return l


func _make_button(parent: Node, text: String, pos: Vector2) -> Button:
	var b := Button.new()
	b.text = text
	b.position = pos
	b.size = Vector2(300, 80)
	b.add_theme_font_size_override("font_size", 32)
	parent.add_child(b)
	return b


@warning_ignore("integer_division")
func refresh(gold: int, gate_hp: int, lvl: int, wave: int, secs_left: int, cost: int) -> void:
	gold_label.text = "G: %d" % gold
	gate_label.text = "HP %d" % gate_hp
	level_label.text = "Level %d" % lvl
	wave_label.text = "Wave %d/%d" % [wave, LevelConfig.WAVES]
	time_label.text = "%d:%02d" % [secs_left / 60, secs_left % 60]
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
