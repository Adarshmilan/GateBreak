extends Node

const DIE := [
	"res://assets/audio/call1.ogg",
	"res://assets/audio/call2.ogg",
	"res://assets/audio/call3.ogg",
	"res://assets/audio/call4.ogg",
	"res://assets/audio/call5.ogg",
	"res://assets/audio/call6.ogg",
	"res://assets/audio/call7.ogg",
]
const SHOOT := [
	"res://assets/audio/gun.ogg",
	"res://assets/audio/gun1.ogg",
	"res://assets/audio/gun3.ogg",
]
const BOSS_DIE := [
	"res://assets/audio/bosscall.ogg",
]
const CLICK := "res://assets/audio/click.ogg"
const MUSIC_MENU := "res://assets/audio/lading.ogg"
const MUSIC_GAME := "res://assets/audio/mainbackground.ogg"
const VICTORY := "res://assets/audio/victory.ogg"
const DEFEAT := "res://assets/audio/defeated.ogg"
const MERGE := "res://assets/audio/merge.ogg"
const VOICES := 8                             # sounds that can overlap

var _music := AudioStreamPlayer.new()
var _sfx: Array[AudioStreamPlayer] = []
var _cache := {}
var _current_music := ""

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS   # keeps working while paused
	_music.volume_db = -8.0
	# the music files are imported without looping, so restart them when they end
	_music.finished.connect(func():
		if _current_music != "":
			_music.play())
	add_child(_music)
	for i in VOICES:
		var p := AudioStreamPlayer.new()
		add_child(p)
		_sfx.append(p)

func _load(path: String) -> AudioStream:
	if not _cache.has(path):
		_cache[path] = load(path)
	return _cache[path]

func play_music(path: String) -> void:
	if path == _current_music and _music.playing:
		return                                # already playing, don't restart
	_current_music = path
	_music.stream = _load(path)
	_music.play()

# Plays a sound on a free voice. When every voice is busy, normal sounds are skipped,
# but important ones (important = true) take over the voice that has played the longest.
func play_sfx(path: String, vol_db := 0.0, pitch_var := 0.0, important := false) -> AudioStreamPlayer:
	var player: AudioStreamPlayer = null
	for p in _sfx:
		if not p.playing:
			player = p
			break
	if player == null:
		if not important:
			return null                       # all busy: skip this sound
		player = _sfx[0]
		for p in _sfx:
			if p.get_playback_position() > player.get_playback_position():
				player = p
	player.stream = _load(path)
	player.volume_db = vol_db
	player.pitch_scale = 1.0 + randf_range(-pitch_var, pitch_var)
	player.play()
	return player

func zombie_die() -> void:
	play_sfx(DIE.pick_random(), 0.0, 0.08)    # random clip + slight pitch change

func shoot() -> void:
	play_sfx(SHOOT.pick_random(), -10.0, 0.06)

func boss_die() -> void:
	play_sfx(BOSS_DIE.pick_random(), 2.0, 0.0, true)     # louder, no pitch change

func click() -> void:
	play_sfx(CLICK, 0.0, 0.0, true)

func stop_music() -> void:
	_current_music = ""
	_music.stop()

func victory() -> void:
	stop_music()
	play_sfx(VICTORY, 0.0, 0.0, true)

func defeat() -> void:
	stop_music()
	play_sfx(DEFEAT, 0.0, 0.0, true)

func merge(level: int = 1) -> void:
	var p := play_sfx(MERGE, 0.0, 0.0, true)
	if p != null:
		p.pitch_scale = 1.0 + (level - 1) * 0.06   # a little higher with each level
