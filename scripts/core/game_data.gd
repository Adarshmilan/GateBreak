# game_data.gd -> AUTOLOAD named "GameData": coins, level progress and upgrades, saved to disk
extends Node

const SAVE_PATH := "user://save.json"
const MAX_UPGRADE := 10
const GATE_HP_PER_UPGRADE := 6     # gate HP added per "gate" upgrade level (the upgrades page shows this)

var coins := 0
var level := 1            # the level the PLAY button starts (next to play)
var best_level := 0       # highest level completed
var fail_streak := 0      # losses in a row on the current level -> drives the assist in LevelConfig
var upgrades := {"damage": 0, "gate": 0, "gold": 0}

func _ready() -> void:
	load_game()

func upgrade_cost(key: String) -> int:
	return 50 * (upgrades[key] + 1)

func buy_upgrade(key: String) -> bool:
	if upgrades[key] >= MAX_UPGRADE or coins < upgrade_cost(key):
		return false
	coins -= upgrade_cost(key)
	upgrades[key] += 1
	save_game()
	return true

func damage_mult() -> float:
	return 1.0 + 0.10 * upgrades["damage"]

func gate_bonus() -> int:
	return GATE_HP_PER_UPGRADE * upgrades["gate"]

func gold_mult() -> float:
	return 1.0 + 0.10 * upgrades["gold"]

# ---- level progression
func complete_level(earned_coins: int) -> void:
	coins += earned_coins
	best_level = maxi(best_level, level)
	level += 1
	fail_streak = 0
	save_game()

func fail_level(earned_coins: int) -> void:
	coins += earned_coins
	fail_streak += 1
	save_game()

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({
			"coins": coins, "level": level, "best_level": best_level,
			"fail_streak": fail_streak, "upgrades": upgrades,
		}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		push_warning("save file is damaged, starting fresh")
		return
	coins = maxi(0, int(data.get("coins", 0)))
	level = maxi(1, int(data.get("level", 1)))
	best_level = maxi(0, int(data.get("best_level", 0)))
	fail_streak = maxi(0, int(data.get("fail_streak", 0)))
	var u = data.get("upgrades", {})
	if typeof(u) == TYPE_DICTIONARY:
		for k in upgrades.keys():
			upgrades[k] = clampi(int(u.get(k, 0)), 0, MAX_UPGRADE)
