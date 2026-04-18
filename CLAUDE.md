# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Origami Battle** — a 1v1 turn-based match-3 puzzle battle game built in Godot 4.6 (GL Compatibility, mobile-first portrait 1080x1920).

## Running the Project

There are no build scripts. Use the standard Godot workflow:

- **Open:** Launch Godot 4.6 and open the project at this directory
- **Run:** Press `F5` in the editor, or `godot --path . Assets/Scenes/game.tscn` from the CLI
- **Export targets:** Windows (D3D12), Android/Mobile (GL Compatibility)

## Architecture

The project currently has a complete UI scene with no GDScript logic yet — all gameplay systems still need to be implemented.

### Main Scene: `Assets/Scenes/game.tscn`

Single-scene architecture with ~366 nodes and three top-level sections:

```
Game (root Control)
├── GameField (TextureRect)
│   └── Gems (VBoxContainer) — 7×7 grid
│       └── GemsLine1–7 → GemCell1–7 → Gem + GemModificator
├── TopMenu (Control) — player/enemy badges, Rules/About/Exit buttons
└── HotBar (Control) — all battle UI
    ├── L_*/R_* — left = player, right = enemy (naming convention throughout)
    ├── L_Turns / R_Turns — turn counters
    ├── L_Score / R_Score — scores; L_AddScore / R_AddScore — score gain popups
    ├── ScoreLine — animated win-condition progress bar
    ├── L_PassiveStack / R_PassiveStack — 7 passive effect slots each
    └── L_ActiveSkillSlots / R_ActiveSkillSlots — 2 skill slots each
        └── ActiveSkillBase → Icon, Rank (stars ×3), Count
```

### Gem Grid

The 7×7 grid is constructed as VBoxContainer rows. Each cell has:
- **Gem** (TextureRect) — the base colored gem sprite
- **GemModificator** (TextureRect) — overlay for bomb/special variants

Gem types: Red, Blue, Green, Pink, Banana, Applebomb, plus Bomb_LeftRight and Bomb_UpDown directional variants. Animated mini versions exist in `Assets/Sprites/Gems/Mini/`.

### Skills System

8 skill types available (Cube, Lube, Hand, Balloon, Bottle, Flower, Hammer, Sphere). Each active skill slot displays icon, rank (1–3 stars), and a quantity counter.

### Naming Conventions

- `L_` prefix = left/player side; `R_` prefix = right/enemy side
- `GemsLine{1–7}` rows, `GemCell{1–7}` columns within each row
- Sprites are grouped by UI section under `Assets/Sprites/`
