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
