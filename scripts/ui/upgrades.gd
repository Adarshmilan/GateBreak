# upgrades.gd -> upgrades page (root Control of upgrades.tscn)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

# the page is laid out in this design space, then scaled and centred to fit any screen
const DESIGN := Vector2(540.0, 960.0)

var UPGRADES := {
	"damage": "Tower Damage +10%",
	"gate": "Gate Health +%d" % GameData.GATE_HP_PER_UPGRADE,
	"gold": "Gold Earned +10%",
}

var holder: Control
var coins_label: Label
var buttons := {}


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.add_background(self, 0.65)     # darker so the buttons are easy to read

	holder = Control.new()
	holder.size = DESIGN
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(holder)

	var x := (DESIGN.x - UIKit.BTN_SIZE.x) / 2.0
	UIKit.make_label(holder, "UPGRADES", Rect2(20, 90, 500, 80), 56)
	coins_label = UIKit.make_label(holder, "", Rect2(20, 180, 500, 40), 28)

	var y := 280.0
	for key in UPGRADES.keys():
		var b := UIKit.make_button(holder, "", Vector2(x, y), 18)
		b.pressed.connect(_on_upgrade.bind(key))
		buttons[key] = b
		y += 110.0

	var back := UIKit.make_button(holder, "BACK", Vector2(x, 700))
	back.pressed.connect(_go_back)
	_refresh()

	_fit()
	get_viewport().size_changed.connect(_fit)
	Audio.play_music(Audio.MUSIC_MENU)


func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0 or vs.y <= 0:
		return
	var s := minf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	holder.scale = Vector2(s, s)
	holder.position = (vs - DESIGN * s) / 2.0


func _go_back() -> void:
	get_tree().change_scene_to_file("res://scenes/menu.tscn")


# Android back button returns to the menu
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_GO_BACK_REQUEST:
		_go_back()


func _on_upgrade(key: String) -> void:
	if GameData.buy_upgrade(key):
		Haptics.tap()
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
