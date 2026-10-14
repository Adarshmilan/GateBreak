# menu.gd -> landing page (root Control of menu.tscn, the Main Scene)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

# button positions on the 540x960 screen (right of the zombie face)
const PLAY_POS := Vector2(272, 545)
const UPGRADE_POS := Vector2(272, 635)
const STATS_SCALE := 0.15
const STATS_Y := 190.0
const STATS_IMG_SIZE := Vector2(1944, 809)
const STATS_TOP := 237.0
const LEVEL_SLOT := Rect2(441, 290, 468, 148)
const COIN_SLOT := Rect2(1288, 290, 486, 149)

const DESIGN := Vector2(540.0, 960.0)

var level_label: Label
var coin_label: Label
var holder: Control


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# dark fill for any spare space around the menu
	var fill := ColorRect.new()
	fill.color = Color("0d0f18")
	fill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fill.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(fill)

	# everything below is built INSIDE this 540x960 holder, which is scaled and centred
	holder = Control.new()
	holder.name = "FitHolder"
	holder.size = DESIGN
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(holder)

	UIKit.add_background(holder, 0.0)

	var play_btn := UIKit.make_button(holder, "PLAY", PLAY_POS)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

	var up_btn := UIKit.make_button(holder, "UPGRADES", UPGRADE_POS)
	up_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/upgrades.tscn"))

	_build_stats()

	_fit()
	get_viewport().size_changed.connect(_fit)
	Audio.play_music(Audio.MUSIC_MENU)


# scales and centres the holder for whatever screen this phone has
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	var f := minf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	holder.scale = Vector2(f, f)
	holder.position = (vs - DESIGN * f) / 2.0


func _build_stats() -> void:
	var origin := Vector2((DESIGN.x - STATS_IMG_SIZE.x * STATS_SCALE) / 2.0, STATS_Y - STATS_TOP * STATS_SCALE)

	var pic := TextureRect.new()
	pic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	pic.stretch_mode = TextureRect.STRETCH_SCALE
	pic.texture = load("res://assets/UI/level_coin_hud.png")
	pic.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	pic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	pic.position = origin
	pic.size = STATS_IMG_SIZE * STATS_SCALE
	holder.add_child(pic)

	level_label = UIKit.make_label(holder, str(GameData.level), _slot_on_screen(LEVEL_SLOT, origin), 26)
	coin_label = UIKit.make_label(holder, str(GameData.coins), _slot_on_screen(COIN_SLOT, origin), 26)


func _slot_on_screen(slot: Rect2, origin: Vector2) -> Rect2:
	return Rect2(origin + slot.position * STATS_SCALE, slot.size * STATS_SCALE)
