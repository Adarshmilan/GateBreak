# gate_front.gd -> res://scripts/core/gate_front.gd
# Redraws the gate strip of the background ON TOP of the zombies,
# so zombies standing at the gate look like they are behind it.
class_name GateFront
extends Node2D

const STRIP_TOP := 432.0       # screen y where the gate (spikes) starts
const STRIP_BOTTOM := 498.0    # screen y where the gate wall ends
const DEBUG := false           # true = shows a cyan frame around the strip, for calibrating


func _ready() -> void:
	z_index = 4                # above zombies, towers and blood; below the muzzle flash


func _draw() -> void:
	var tex: Texture2D = Arena.ROAD_FULL
	var dest_y := Arena.ROAD_DEST_Y
	var dest_h := Arena.ROAD_DEST_H
	var tw := float(tex.get_width())
	var th := float(tex.get_height())
	var sy0 := (STRIP_TOP - dest_y) / dest_h * th
	var sy1 := (STRIP_BOTTOM - dest_y) / dest_h * th
	draw_texture_rect_region(tex,
		Rect2(0.0, STRIP_TOP, Arena.SCREEN_W, STRIP_BOTTOM - STRIP_TOP),
		Rect2(0.0, sy0, tw, sy1 - sy0))
	if DEBUG:
		draw_rect(Rect2(0.0, STRIP_TOP, Arena.SCREEN_W, STRIP_BOTTOM - STRIP_TOP),
			Color(0.2, 1.0, 1.0), false, 2.0)
