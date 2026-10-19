# menu.gd -> landing page (root Control of menu.tscn, the Main Scene)
extends Control

const UIKit := preload("res://scripts/ui/ui_kit.gd")

# Native resolution of the tall master background (assets/UI/mainbackground.jpg)
const DESIGN := Vector2(459.0, 1024.0)

# Button layout inside the 459x1024 coordinate system (right of zombie head)
const PLAY_POS := Vector2(230, 580)
const UPGRADE_POS := Vector2(230, 660)
const MENU_BTN_SIZE := Vector2(205, 66)

# Level & Coin bar placement (between ZOMHEX logo and the portal)
const STATS_SCALE := 0.135
const STATS_Y := 218.0
const STATS_IMG_SIZE := Vector2(1944, 809)
const STATS_TOP := 237.0
const LEVEL_SLOT := Rect2(441, 290, 468, 148)
const COIN_SLOT := Rect2(1288, 290, 486, 149)

var level_label: Label
var coin_label: Label
var holder: Control
var bg: TextureRect


func _ready() -> void:
	get_tree().paused = false
	set_anchors_preset(Control.PRESET_FULL_RECT)

	# Full-screen background covering 100% of any phone display (no black bars)
	bg = TextureRect.new()
	bg.name = "Background"
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load("res://assets/UI/mainbackground.jpg")
	bg.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)

	# UI holder: holds buttons & stats in 459x1024 space, perfectly synced with the art
	holder = Control.new()
	holder.name = "FitHolder"
	holder.size = DESIGN
	holder.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(holder)

	var play_btn := UIKit.make_button(holder, "PLAY", PLAY_POS, 22, MENU_BTN_SIZE)
	play_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/game.tscn"))

	var up_btn := UIKit.make_button(holder, "UPGRADES", UPGRADE_POS, 20, MENU_BTN_SIZE)
	up_btn.pressed.connect(func(): get_tree().change_scene_to_file("res://scenes/upgrades.tscn"))

	_build_stats()

	_fit()
	_fit.call_deferred()
	get_tree().process_frame.connect(_fit, CONNECT_ONE_SHOT)
	get_viewport().size_changed.connect(_fit)
	Audio.play_music(Audio.MUSIC_MENU)


# Synchronizes the UI holder exactly with the background image on ANY phone aspect ratio
func _fit() -> void:
	var vs := get_viewport().get_visible_rect().size
	if vs.x <= 0 or vs.y <= 0:
		return
	bg.size = vs
	bg.position = Vector2.ZERO
	# Exact scale used by STRETCH_KEEP_ASPECT_COVERED
	var s := maxf(vs.x / DESIGN.x, vs.y / DESIGN.y)
	holder.scale = Vector2(s, s)
	holder.position = (vs - DESIGN * s) / 2.0


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

	level_label = UIKit.make_label(holder, str(GameData.level), _slot_on_screen(LEVEL_SLOT, origin), 22)
	coin_label = UIKit.make_label(holder, str(GameData.coins), _slot_on_screen(COIN_SLOT, origin), 22)


func _slot_on_screen(slot: Rect2, origin: Vector2) -> Rect2:
	return Rect2(origin + slot.position * STATS_SCALE, slot.size * STATS_SCALE)

