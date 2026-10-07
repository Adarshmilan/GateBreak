# upgrades.gd -> upgrades page (root Control of upgrades.tscn)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

const UPGRADES := {
	"damage": "Tower Damage +10%",
	"gate": "Gate Health +2",
	"gold": "Gold Earned +10%",
}

var coins_label: Label
var buttons := {}


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.add_background(self, 0.65)     # darker so the buttons are easy to read

	UIKit.make_label(self, "UPGRADES", Rect2(20, 90, 500, 80), 56)
	coins_label = UIKit.make_label(self, "", Rect2(20, 180, 500, 40), 28)

	var y := 280.0
	for key in UPGRADES.keys():
		var b := UIKit.make_button(self, "", Vector2((540.0 - UIKit.BTN_SIZE.x) / 2.0, y), 18)
		b.pressed.connect(_on_upgrade.bind(key))
		buttons[key] = b
		y += 110.0

	var back := UIKit.make_button(self, "BACK", Vector2((540.0 - UIKit.BTN_SIZE.x) / 2.0, 700))
	back.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/menu.tscn"))
	_refresh()


func _on_upgrade(key: String) -> void:
	GameData.buy_upgrade(key)
	_refresh()


func _refresh() -> void:
	coins_label.text = "Coins: %d" % GameData.coins
	for key in buttons.keys():
		var lvl: int = GameData.upgrades[key]
		var b: Button = buttons[key]
		if lvl >= GameData.MAX_UPGRADE:
			b.text = "%s\nMAX" % UPGRADES[key]
			b.disabled = true
		else:
			b.text = "%s\nLv %d - %d coins" % [UPGRADES[key], lvl, GameData.upgrade_cost(key)]
			b.disabled = GameData.coins < GameData.upgrade_cost(key)
