extends Node

var enabled := true            # hook this to a settings toggle later
var _last_light := 0           # cooldown so mass zombie deaths don't buzz nonstop

# A pattern is [buzz_ms, pause_ms, buzz_ms, ...] plus an amplitude (0.0 - 1.0)
func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS

func _play(pattern: Array, amp: float) -> void:
	if not enabled:
		return
	for i in pattern.size():
		if i % 2 == 0:
			Input.vibrate_handheld(pattern[i], amp)
		await get_tree().create_timer(pattern[i] / 1000.0).timeout

func tap() -> void:            # UI click / merge: very light
	_play([20], 0.3)

func zombie_die() -> void:     # light, rate limited
	var now := Time.get_ticks_msec()
	if now - _last_light < 120:
		return
	_last_light = now
	_play([30], 0.4)

func boss_die() -> void:       # heavy triple thud
	_play([120, 60, 120, 60, 200], 1.0)

func merge() -> void:          # quick double tap
	_play([25, 40, 40], 0.6)

func victory() -> void:        # rising: short, medium, long
	_play([60, 80, 100, 80, 250], 0.8)

func defeat() -> void:         # one long heavy buzz
	_play([700], 1.0)
