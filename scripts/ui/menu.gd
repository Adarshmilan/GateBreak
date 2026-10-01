	# menu.gd -> attach to root Control node of menu.tscn (set as Main Scene)
extends Control

const UPGRADES := {
	"damage": "Tower Damage (+10%)",
	"gate": "Gate Health (+2)",
	"gold": "Gold Earned (+10%)",
}

var coins_label: Label
var play_btn: Button
var buttons := {}

func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	var bg := ColorRect.new()
	bg.color = Color("1b1f2a")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 40
	box.offset_right = -40
	box.offset_top = 80
	box.add_theme_constant_override("separation", 20)
	add_child(box)

	var title := Label.new()
	title.text = "LAST GATE"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 64)
	box.add_child(title)

	coins_label = Label.new()
	coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	coins_label.add_theme_font_size_override("font_size", 28)
	box.add_child(coins_label)

	for key in UPGRADES.keys():
		var b := Button.new()
		b.custom_minimum_size = Vector2(0, 80)
		b.add_theme_font_size_override("font_size", 24)
		b.pressed.connect(_on_upgrade.bind(key))
		box.add_child(b)
		buttons[key] = b

	play_btn = Button.new()
	play_btn.custom_minimum_size = Vector2(0, 100)
	play_btn.add_theme_font_size_override("font_size", 40)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))
	box.add_child(play_btn)
	_refresh()

func _on_upgrade(key: String) -> void:
	GameData.buy_upgrade(key)
	_refresh()

func _refresh() -> void:
	coins_label.text = "Coins: %d   |   Best Level: %d" % [GameData.coins, GameData.best_level]
	play_btn.text = "PLAY LEVEL %d" % GameData.level
	for key in buttons.keys():
		var lvl: int = GameData.upgrades[key]
		var b: Button = buttons[key]
		if lvl >= GameData.MAX_UPGRADE:
			b.text = "%s  [MAX]" % UPGRADES[key]
			b.disabled = true
		else:
			b.text = "%s  Lv %d  -  %d coins" % [UPGRADES[key], lvl, GameData.upgrade_cost(key)]
			b.disabled = GameData.coins < GameData.upgrade_cost(key)
