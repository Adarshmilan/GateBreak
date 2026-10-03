# game.gd -> res://scripts/core/game.gd (attach to the root Node2D of game.tscn)
# The "assembler": creates the parts, connects them, and owns the round's money, gate and result.
#   Arena         (arena.gd)         layout + drawing of the field
#   TowerGrid     (tower_grid.gd)    slots, drag, merge
#   WaveDirector  (wave_director.gd)  schedule + spawning
#   Hud           (ui/hud.gd)        labels, buttons, banner, result panel
extends Node2D


var lvl := 1                   # level being played (from GameData.level)
var assist := 0.0              # how much easier zombies are after losses in a row
var gold := 0
var gold_frac := 0.0           # fractional gold from small kill rewards
var kills := 0
var towers_bought := 0
var gate_max := 10
var gate_hp := 10
var over := false

var hud: Hud
var grid: TowerGrid
var director: WaveDirector


func _ready() -> void:
	get_tree().paused = false      # a new round must never start frozen
	lvl = GameData.level
	var assist_stacks := GameData.fail_streak
	assist = LevelConfig.assist_amount(assist_stacks)
	gold = LevelConfig.start_gold(lvl, assist_stacks)
	gate_max = LevelConfig.gate_hp(lvl) + int(GameData.gate_bonus() * LevelConfig.GATE_HP_MULT)
	gate_hp = gate_max

	hud = Hud.new()
	add_child(hud)
	hud.buy_pressed.connect(_on_buy)

	grid = TowerGrid.new()
	add_child(grid)
	grid.setup(self)

	director = WaveDirector.new()
	add_child(director)
	director.setup(self, lvl, assist)
	director.wave_started.connect(_on_wave_started)
	director.zombie_died.connect(_on_zombie_died)
	director.zombie_reached_gate.connect(_on_gate_hit)
	director.cleared.connect(_win)

	director.start()
	_update_ui()


func _draw() -> void:
	Arena.draw(self, gate_hp, gate_max)


func _process(_delta: float) -> void:
	_update_ui()


func tower_cost() -> int:
	return LevelConfig.tower_cost(lvl, towers_bought)


func _update_ui() -> void:
	var left := maxi(0, int(ceil(LevelConfig.ROUND_TIME - director.elapsed)))
	hud.refresh(gold, gate_hp, lvl, director.wave, left, tower_cost())
	queue_redraw()


# ---------------------------------------------------------------- buying
func _on_buy() -> void:
	if over or gold < tower_cost():
		return
	if not grid.has_space():
		hud.show_banner("NO SPACE!")
		return
	gold -= tower_cost()
	towers_bought += 1
	grid.add_tower()
	_update_ui()


# ---------------------------------------------------------------- events from the director
func _on_wave_started(w: int) -> void:
	if over:
		return
	if w > 1:
		# reward + a little repair between waves
		gold += LevelConfig.wave_bonus_gold(lvl)
		gate_hp = mini(gate_max, gate_hp + int(ceil(gate_max * LevelConfig.GATE_HEAL_BETWEEN_WAVES)))
	hud.show_banner("FINAL WAVE!" if w == LevelConfig.WAVES else "WAVE %d" % w)
	_update_ui()


func _on_zombie_died(z: Zombie) -> void:
	if over:
		return
	kills += 1
	var reward: float = LevelConfig.kill_reward(lvl) * z.reward_mult
	gold_frac += reward * GameData.gold_mult()
	var gain := int(gold_frac)
	gold_frac -= gain
	gold += gain
	_update_ui()


func _on_gate_hit(z: Zombie) -> void:
	if over:
		return
	gate_hp = maxi(gate_hp - z.gate_damage, 0)
	_update_ui()
	if gate_hp <= 0:
		_game_over()


# ---------------------------------------------------------------- end of round
# Both endings go through here: freeze everything first, THEN show the result.
func _end_round() -> void:
	over = true
	director.stop()
	grid.lock()


func _win() -> void:
	if over:
		return
	_end_round()
	var earned := LevelConfig.win_coins(lvl, kills)
	GameData.complete_level(earned)
	hud.show_result("LEVEL %d CLEARED!\n\nZombies killed: %d\nCoins earned: %d" % [lvl, kills, earned], "NEXT LEVEL")
	get_tree().paused = true


func _game_over() -> void:
	if over:
		return
	_end_round()
	var share := float(director.wave) / LevelConfig.WAVES
	var earned := int(LevelConfig.win_coins(lvl, kills) * LevelConfig.LOSE_COIN_FRACTION * share)
	GameData.fail_level(earned)
	hud.show_result("THE GATE HAS FALLEN\n\nLevel %d  -  reached wave %d/%d\nZombies killed: %d\nCoins earned: %d\n\nNext try gets a little help." % [lvl, director.wave, LevelConfig.WAVES, kills, earned], "RETRY")
	get_tree().paused = true
