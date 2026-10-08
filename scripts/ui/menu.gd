# menu.gd -> landing page (root Control of menu.tscn, the Main Scene)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

# button positions on the 540x960 screen (right of the zombie face)
const PLAY_POS := Vector2(272, 545)       # top-left of the PLAY button (size = UIKit.BTN_SIZE)
const UPGRADE_POS := Vector2(272, 635)
const STATS_SCALE := 0.15                     # size of the level/coin bar
const STATS_Y := 190.0                        # screen y of the bar's top edge (just under the logo)
const STATS_IMG_SIZE := Vector2(1944, 809)    # the image's own size
const STATS_TOP := 237.0                      # empty space above the bar inside the image
const LEVEL_SLOT := Rect2(441, 290, 468, 148) # slot boxes in IMAGE pixels
const COIN_SLOT := Rect2(1288, 290, 486, 149)

var level_label: Label
var coin_label: Label


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)
	UIKit.add_background(self, 0.0)


	var play_btn := UIKit.make_button(self, "PLAY", PLAY_POS)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

	var up_btn := UIKit.make_button(self, "UPGRADES", UPGRADE_POS)
	up_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/upgrades.tscn"))
	_build_stats()
	
	
func _build_stats() -> void:
	# top-left corner of the whole image on screen (centered horizontally)
	var origin := Vector2((540.0 - STATS_IMG_SIZE.x * STATS_SCALE) / 2.0, STATS_Y - STATS_TOP * STATS_SCALE)

	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE    # must come before size
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture = load("res://assets/UI/level_coin_hud.png")
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = origin
	pic.size = STATS_IMG_SIZE * STATS_SCALE
	add_child(pic)

	level_label = UIKit.make_label(self, str(GameData.level), _slot_on_screen(LEVEL_SLOT, origin), 26)
	coin_label = UIKit.make_label(self, str(GameData.coins), _slot_on_screen(COIN_SLOT, origin), 26)


# converts a slot box from image pixels to screen pixels
func _slot_on_screen(slot: Rect2, origin: Vector2) -> Rect2:
	return Rect2(origin + slot.position * STATS_SCALE, slot.size * STATS_SCALE)
