<<<<<<< HEAD
# ZOMHEX

A portrait mobile tower-defense / merge game made with **Godot 4.7** (GDScript, Mobile renderer, Jolt physics).

Zombies march down the road toward your gate. Buy guns, drop them on the 9 plates, and drag one gun onto
another of the same level to merge it into a stronger one. Survive 3 waves (the last one ends with a boss
from level 5 on) to clear the level and earn coins for permanent upgrades.

## Running

1. Install [Godot 4.7](https://godotengine.org/download).
2. Open `project.godot` in the editor and press **F5** (main scene: `scenes/menu.tscn`).

Android export settings live in `export_presets.cfg` (uses the Gradle build in `android/`).

## Controls

| Action | Input |
| --- | --- |
| Buy a gun | **BUY TOWER** button |
| Move / swap / merge | Drag a gun onto another plate |
| Pause | **II** button, Esc, or the Android back button |

## Project layout

```
scenes/            menu.tscn, game.tscn, upgrades.tscn (thin; everything is built in code)
scripts/core/      game.gd (round logic), wave_director.gd, tower_grid.gd, hud.gd,
                   level_config.gd (ALL difficulty numbers), arena.gd, prespective.gd (Persp),
                   screen_fit.gd, blood_layer.gd, gate_front.gd, game_data.gd (save + upgrades)
scripts/entities/  tower.gd, zombie.gd, projectile.gd (3D models rendered into 2D via SubViewports)
scripts/ui/        menu.gd, upgrades.gd, ui_kit.gd
audio.gd, Haptics.gd   autoloads: sound/music and phone vibration
shaders/           toon + outline shaders for guns and zombies
```

The playfield is designed at **540 x 960** and scaled to fit any phone (`ScreenFit`).

## Tuning

- Difficulty, economy, waves, bosses: `scripts/core/level_config.gd`
- Gun damage / fire rate / look: constants at the top of `scripts/entities/tower.gd`
- Zombie kinds (HP, speed, size, tint, reward): `KINDS` in `scripts/entities/zombie.gd`
- Upgrade prices and effects: `scripts/core/game_data.gd`

Progress is saved to `user://save.json`.
=======
# 🧟 GateBreak

A mobile **merge tower-defense** game made with **Godot 4**. Hordes of zombies march down the road toward your gate – buy turrets, drag matching guns together to merge them into stronger ones, and survive three waves to clear the level.

## 🎮 Gameplay

- **Buy towers** with gold – each new turret lands in a free slot on a 3×3 grid.
- **Drag & merge** – drop a tower on another of the same level to upgrade it (8 gun levels, each with its own 3D model). Drop it on a different tower to swap them.
- **Defend the gate** – every zombie that reaches the gate costs health. Lose all of it and the level is over.
- **Three waves per level** (90 s total). The final wave is the biggest and toughest, and from level 5 it ends with a **Boss**.
- **Zombie types** unlock as you progress: Walker (L1) → Brute (L2) → Tank (L4) → Giant (L7).
- **Endless levels** – difficulty scales smoothly with no cap; a small assist kicks in if you lose several times in a row.
- **Permanent upgrades** bought with coins between levels:
  - Tower Damage +10%
  - Gate Health +2
  - Gold Earned +10%
- Progress is saved to `user://save.json`.
- Sound effects, background music, haptic feedback and a blood-splatter layer.

## 🛠️ Tech stack

- **Godot 4.7** (Forward+ renderer), **GDScript**
- 3D gun models (`.glb`) rendered into the 2D game with custom **toon** and **outline** shaders
- Fixed 540×960 portrait layout scaled to any phone screen
- Android export preset

## 📁 Project structure

```
scenes/
├── menu.tscn            # main menu
├── game.tscn            # gameplay
└── upgrades.tscn        # upgrade shop
scripts/
├── core/
│   ├── game.gd          # glues everything: gold, gate HP, win/lose
│   ├── level_config.gd  # every difficulty number in one place
│   ├── wave_director.gd # builds the spawn schedule for 3 waves
│   ├── tower_grid.gd    # 9 slots: place, drag, merge, swap
│   ├── game_data.gd     # autoload: coins, level, upgrades, save/load
│   ├── hud.gd, arena.gd, gate_front.gd, blood_layer.gd, screen_fit.gd, prespective.gd
├── entities/            # tower.gd, zombie.gd, projectile.gd
└── ui/                  # menu.gd, upgrades.gd, ui_kit.gd
shaders/                 # gun_toon.gdshader, gun_outline.gdshader
assets/                  # guns (level_1..7), zombies, UI, audio, road and gate art
audio.gd, Haptics.gd     # sound and vibration helpers
```

## ⚙️ Tuning the difficulty

All balance numbers live in `scripts/core/level_config.gd` – round length, wave share, zombie count/HP/speed growth, boss frequency and the economy. Change a constant and the whole game follows. For example, `HORDE_FACTOR` switches between "few tough zombies" (1.0) and "huge swarm" (4.0).

## 🚀 Run it

1. Install [Godot 4.7+](https://godotengine.org/download).
2. Clone the repo and open `project.godot` in Godot:
   ```bash
   git clone https://github.com/Adarshmilan/GateBreak.git
   ```
3. Press **F5** to play.

### Build for Android
Install the Android export templates in Godot, then **Project → Export → Android**.
>>>>>>> 3bd34396b9f7c894592b59568903acb86f52203d
