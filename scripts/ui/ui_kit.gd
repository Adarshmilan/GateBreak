# ui_kit.gd -> shared helpers for the menu pages
extends RefCounted

const UI := "res://assets/UI/"

# ONE size for every button in the game. Change it here and all buttons follow.
const BTN_SIZE := Vector2(260, 80)
const BTN_FONT := 26

static var _style_cache := {}


static func add_background(parent: Control, dim: float) -> void:
	var bg := TextureRect.new()
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	bg.texture = load(UI + "mainbackground.jpg")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	if dim > 0.0:
		var shade := ColorRect.new()
		shade.color = Color(0, 0, 0, dim)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(shade)


static func _btn_style(file: String) -> StyleBoxTexture:
	if not _style_cache.has(file):
		var tex: Texture2D = load(UI + file)
		var s := StyleBoxTexture.new()
		s.texture = tex
		s.region_rect = Rect2(tex.get_image().get_used_rect())   # only the visible pixels
		s.content_margin_left = 16
		s.content_margin_right = 16
		s.content_margin_top = 6
		s.content_margin_bottom = 6
		_style_cache[file] = s
	return _style_cache[file]


static func skin_button(b: Button) -> void:
	b.add_theme_stylebox_override("normal", _btn_style("btn_normal.png"))
	b.add_theme_stylebox_override("hover", _btn_style("btn_normal.png"))
	b.add_theme_stylebox_override("pressed", _btn_style("btn_pressed.png"))
	b.add_theme_stylebox_override("disabled", _btn_style("btn_disable.png"))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())


# every button: same skin, same size (BTN_SIZE). Only the position and text change.
static func make_button(parent: Node, text: String, pos: Vector2, font_size: int = BTN_FONT) -> Button:
	var b := Button.new()
	b.text = text
	b.add_theme_font_size_override("font_size", font_size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.5))
	skin_button(b)                       # skin first, then size
	b.position = pos
	b.size = BTN_SIZE
	parent.add_child(b)
	return b


static func make_label(parent: Node, text: String, rect: Rect2, font_size: int) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", font_size)
	l.add_theme_color_override("font_color", Color.WHITE)
	l.add_theme_color_override("font_outline_color", Color(0.05, 0.07, 0.1))
	l.add_theme_constant_override("outline_size", 6)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.position = rect.position
	l.size = rect.size
	parent.add_child(l)
	return l
