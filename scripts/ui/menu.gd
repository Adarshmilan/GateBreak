# menu.gd -> landing page (root Control of menu.tscn, the Main Scene)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

# Rect2(x, y, width, height) on the 540x960 screen (right of the zombie face)
const INFO_RECT := Rect2(290, 520, 240, 64)
const PLAY_RECT := Rect2(300, 550, 220, 76)
const UPGRADE_RECT := Rect2(300, 637, 220, 76)

var info_label: Label


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.add_background(self, 0.0)

	info_label = UIKit.make_label(self, "", INFO_RECT, 20)

	var play_btn := UIKit.make_button(self, "PLAY", PLAY_RECT, 32)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

	var up_btn := UIKit.make_button(self, "UPGRADES", UPGRADE_RECT, 26)
	up_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/upgrades.tscn"))

	info_label.text = "Level %d   Best %d\nCoins: %d" % [GameData.level, GameData.best_level, GameData.coins]
