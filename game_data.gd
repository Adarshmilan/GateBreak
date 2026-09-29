# game_data.gd  -> add as AUTOLOAD named "GameData"
extends Node

const SAVE_PATH := "user://save.json"
const MAX_UPGRADE := 10

var coins := 0
var best_wave := 0
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

func gate_hp() -> int:
	return 10 + 2 * upgrades["gate"]

func gold_mult() -> float:
	return 1.0 + 0.10 * upgrades["gold"]

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"coins": coins, "best_wave": best_wave, "upgrades": upgrades}))

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	var data = JSON.parse_string(f.get_as_text())
	if typeof(data) != TYPE_DICTIONARY:
		return
	coins = int(data.get("coins", 0))
	best_wave = int(data.get("best_wave", 0))
	var u: Dictionary = data.get("upgrades", {})
	for k in upgrades.keys():
		upgrades[k] = int(u.get(k, 0))
