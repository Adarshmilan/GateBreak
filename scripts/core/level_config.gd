# level_config.gd  (NEW FILE)  ->  res://scripts/core/level_config.gd
# Every number that controls level difficulty lives HERE. Change a constant, the whole game follows.
# Nothing is capped by level: every function takes the level number L (1, 2, 3, ... forever).
class_name LevelConfig
extends RefCounted

# ============================================================ ROUND STRUCTURE
const ROUND_TIME := 90.0                    # seconds per level
const WAVES := 3                            # wave 3 is the FINAL wave
const WAVE_SHARE := [0.25, 0.30, 0.45]      # share of the level's zombies in each wave (final = biggest)
const SPAWN_WINDOW := 0.70                  # spawn during the first 70% of each wave, last 30% = breathing room

# ============================================================ HORDE FEEL (the one knob for "many weak zombies")
# Zombie count x HORDE_FACTOR, zombie HP and gold-per-kill / HORDE_FACTOR  ->  same total difficulty, more kills.
# Set to 1.0 for the old few-tough-zombies feel, 4.0 for a huge swarm.
const HORDE_FACTOR := 2.5
const GATE_HP_MULT := 3.0                   # more zombies = more leaks, so the gate is tougher to match

# ============================================================ HOW MANY ZOMBIES  (grows slowly, sub-linear)
const BASE_COUNT := 14
const COUNT_GROWTH := 1.7
const COUNT_EXP := 0.75                     # < 1 so count never explodes at high levels

# ============================================================ HOW TOUGH  (polynomial, not exponential)
const BASE_HP := 260.0
const HP_GROWTH := 0.04
const HP_EXP := 0.60
const FINAL_WAVE_HP_MULT := 1.25            # final wave zombies are 25% tougher
const FINAL_WAVE_SPEED_MULT := 1.04

# ============================================================ HOW FAST
const BASE_SPEED := 45.0
const SPEED_GROWTH := 0.25                  # +0.25 px/s per level ...
const SPEED_CAP := 65.0                     # ... but never faster than this (keeps it dodge-able / playable)

# ============================================================ KINDS  (index 0..3 = Walker, Brute, Tank, Giant)
const KIND_UNLOCK_LEVEL := [1, 3, 6, 10]
const KIND_WEIGHTS := [60.0, 25.0, 12.0, 5.0]
const KIND_LEVEL_DRIFT := 0.03              # heavier kinds get +3% weight per level per tier
const FINAL_WAVE_HEAVY_BONUS := 1.0         # final wave: Tank/Giant weights x2
const BOSS_FROM_LEVEL := 5                  # final wave ends with a Boss from this level on
const BOSS_EVERY_N_LEVELS := 15             # +1 extra boss every N levels (L20 = 2 bosses ...)

# ============================================================ PLAYER ECONOMY  (grows with level)
const START_GOLD_BASE := 80
const START_GOLD_PER_LEVEL := 22.0
const START_GOLD_EXP := 1.10
const KILL_REWARD_BASE := 4.0
const KILL_REWARD_PER_LEVEL := 1.2
const WAVE_BONUS_FRACTION := 0.6            # gold gift at wave 2 and 3 = 60% of start gold
const TOWER_COST_BASE := 20
const TOWER_COST_STEP := 0.5                # each tower bought this level makes the next cost +0.5
const TOWER_COST_PER_LEVEL := 0.0           # raise (e.g. 0.3) if gold feels too plentiful at high levels

# ============================================================ GATE
const GATE_BASE_HP := 10
const GATE_HP_EVERY_N_LEVELS := 5           # +1 gate HP every 5 levels
const GATE_HEAL_BETWEEN_WAVES := 0.20       # heal 20% of max gate HP when wave 2 / 3 starts

# ============================================================ EASE / ASSIST (after losing, next try is kinder)
const ASSIST_PER_LOSS := 0.08               # each loss in a row = 8% weaker zombies + 12% more start gold ...
const ASSIST_GOLD_PER_LOSS := 0.12
const ASSIST_MAX_STACKS := 6                # ... up to 6 stacks (48% weaker zombies). A win resets it to 0.

# ============================================================ MAX MERGE LEVEL (tower.gd COLORS just clamps)
const MAX_TOWER_LEVEL := 12

# ============================================================ REWARDS (permanent coins)
const WIN_COINS_BASE := 20
const WIN_COINS_PER_LEVEL := 6
const KILL_COINS_DIVISOR := 10              # +1 coin per 10 kills (more kills now, so higher divisor)
const LOSE_COIN_FRACTION := 0.5             # a lost round still pays 50% of the win payout (scaled by waves reached)


# ---------------------------------------------------------------- functions of the level
static func wave_length() -> float:
	return ROUND_TIME / WAVES

static func zombie_count(level: int) -> int:
	return int(round((BASE_COUNT + COUNT_GROWTH * pow(level - 1, COUNT_EXP)) * HORDE_FACTOR))

static func wave_count(level: int, wave_index: int) -> int:
	return maxi(1, int(round(zombie_count(level) * WAVE_SHARE[wave_index])))

static func zombie_hp(level: int, assist: float = 0.0) -> float:
	return BASE_HP * pow(1.0 + HP_GROWTH * (level - 1), HP_EXP) * (1.0 - assist) / HORDE_FACTOR

static func zombie_speed(level: int) -> float:
	return minf(BASE_SPEED + SPEED_GROWTH * (level - 1), SPEED_CAP)

static func boss_count(level: int) -> int:
	if level < BOSS_FROM_LEVEL:
		return 0
	return 1 + (level - BOSS_FROM_LEVEL) / BOSS_EVERY_N_LEVELS

static func start_gold(level: int, assist_stacks: int = 0) -> int:
	var g := START_GOLD_BASE + START_GOLD_PER_LEVEL * pow(level - 1, START_GOLD_EXP)
	return int(g * (1.0 + ASSIST_GOLD_PER_LOSS * assist_stacks))

static func wave_bonus_gold(level: int) -> int:
	return int(start_gold(level) * WAVE_BONUS_FRACTION)

static func kill_reward(level: int) -> float:
	return (KILL_REWARD_BASE + KILL_REWARD_PER_LEVEL * (level - 1)) / HORDE_FACTOR

static func tower_cost(level: int, bought: int) -> int:
	return int(TOWER_COST_BASE + TOWER_COST_PER_LEVEL * (level - 1) + TOWER_COST_STEP * bought)

static func gate_hp(level: int) -> int:
	return int((GATE_BASE_HP + (level - 1) / GATE_HP_EVERY_N_LEVELS) * GATE_HP_MULT)

static func assist_amount(stacks: int) -> float:
	return ASSIST_PER_LOSS * mini(stacks, ASSIST_MAX_STACKS)

static func win_coins(level: int, kills: int) -> int:
	return WIN_COINS_BASE + WIN_COINS_PER_LEVEL * level + kills / KILL_COINS_DIVISOR

# Pick a zombie kind (1..4) for this level; final wave leans heavy.
static func pick_kind(level: int, is_final_wave: bool) -> int:
	var weights: Array = []
	var total := 0.0
	for k in 4:
		var w := 0.0
		if level >= KIND_UNLOCK_LEVEL[k]:
			w = KIND_WEIGHTS[k] * (1.0 + KIND_LEVEL_DRIFT * (level - 1) * k)
			if is_final_wave and k >= 2:
				w *= 1.0 + FINAL_WAVE_HEAVY_BONUS
		weights.append(w)
		total += w
	var roll := randf() * total
	for k in 4:
		roll -= weights[k]
		if weights[k] > 0.0 and roll <= 0.0:
			return k + 1
	return 1
