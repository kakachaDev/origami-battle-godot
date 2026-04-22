# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Origami Battle** — a 1v1 turn-based match-3 puzzle battle game built in Godot 4.6 (GL Compatibility, mobile-first portrait 1080x1920).

## Running the Project

- **Run:** `godot --path . Assets/Scenes/game.tscn`
- **Web build:** `bash build_web.sh` → outputs to `build/web/`
- **Export targets:** Web (HTML5), Windows (D3D12), Android/Mobile (GL Compatibility)

## Directory Structure

```
Assets/
├── Fonts/                        — game fonts (Chicoree Em Bold, Shonen)
├── Prefabs/                      — reusable scenes (.tscn)
│   ├── ActiveSkillBase.tscn
│   ├── PassiveStack.tscn
│   ├── ScoreLine.tscn
│   └── GemCell.tscn
├── Resources/
│   ├── Gems/                     — GemData .tres (Red, Blue, Green, Pink, Banana, Applebomb)
│   ├── PassiveStacks/            — PassiveStackData .tres (Red, Green, Blue, Pink, Banana, Applebomb)
│   ├── Modifiers/                — ModifierData .tres (BombLeftRight, BombUpDown)
│   └── Skills/                   — SkillData .tres (Cube, Lube, Hand, Baloon, Botle, Flower, Hammer40k, Sphere)
├── Scenes/
│   └── game.tscn                 — main scene
├── Scripts/                      — all GDScript files
└── Sprites/                      — textures grouped by UI section
```

## Architecture

### Main Scene: `Assets/Scenes/game.tscn`

```
Game (root Control)
├── GameManager (Node)            — business logic only
├── GameUI (Node)                 — UI layer only
├── GameField (TextureRect)
│   └── Gems (Panel)              — GameBoard script, 7×7 grid of GemCell nodes
├── TopMenu (Control)             — player/enemy badges, Rules/About/Exit buttons
└── HotBar (Control)              — all battle UI
    ├── L_*/R_*                   — left = player, right = enemy (naming convention)
    ├── L_Turns / R_Turns         — moves remaining this turn
    ├── L_Score / R_Score         — total scores
    ├── L_AddScore / R_AddScore   — "+N" score gain popups (TextureRect > Count Label)
    ├── Turn                      — round label ("Round N" or "Round N/M")
    ├── ScoreLine                 — instance of ScoreLine.tscn
    ├── L_PassiveStack / R_PassiveStack — instances of PassiveStack.tscn
    └── L_ActiveSkillSlots / R_ActiveSkillSlots — 2 slots each
        └── Slot1, Slot2 → ActiveSkillBase (instance of ActiveSkillBase.tscn)
```

### Game Logic Scripts

#### `GameManager` (`Scripts/GameManager.gd`)
Pure business logic — no references to visual nodes. Emits signals when state changes.
- **State:** `current_round`, `current_player` (LEFT=0 / RIGHT=1), `l/r_moves_left`, `l/r_score`, `l/r_passive_gem_type` (0–4), `l/r_passive_charge`
- **Constants:** `MOVES_PER_TURN = 2`, `PASSIVE_CHARGE_MAX = 5`
- **Signals:** `score_updated(l, r)`, `player_scored(player, amount)`, `turns_updated(l_moves, r_moves, player, round)`, `passive_types_assigned(l_gem_type, r_gem_type)`, `passive_charge_updated(player, charge)`
- **Method:** `charge_passive_one(player)` — called by GameUI when a flying gem icon lands
- Connects to `GameBoard.move_completed`; initial signals deferred via `call_deferred("_emit_initial_state")`

#### `GameUI` (`Scripts/GameUI.gd`)
Visual layer — owns all UI updates and animations. No game logic.
- `@export var passive_stack_resources: Array[PassiveStackData]` — set in scene, indexed by gem type (0=Red … 4=Banana)
- Connects to all `GameManager` signals and `GameBoard.gems_about_to_destroy`
- On `gems_about_to_destroy`: spawns flying gem icons for matching gems (cubic Bezier arc, 0.7s)
- Flying icon lands → calls `_manager.charge_passive_one(player)` → GameManager emits `passive_charge_updated` → updates PassiveStack visual via `set_count_animated`

### Board Scripts

#### `GameBoard` (`Scripts/GameBoard.gd`)
Manages the 7×7 gem grid: drag-swap input, match detection, destruction, gravity, cascades, animations.
- `@export var gem_resources: Array[GemData]` — indexed by gem type int (0=Red … 4=Banana)
- **Signals:**
  - `move_completed(gems_by_type: Dictionary)` — fires after all cascades; keys = gem type int, values = count destroyed
  - `gems_about_to_destroy(gem_infos: Array)` — fires at start of each destruction wave; each element `{gem_type: int, world_pos: Vector2}`
- Uses `BoardState` for grid state and `BoardAnimator` for all animations

#### `BoardState` (`Scripts/BoardState.gd`)
Pure data model for the 7×7 grid. Gem types stored as integers: 0=Red, 1=Blue, 2=Green, 3=Pink, 4=Banana. `-1` = empty.

#### `BoardAnimator` (`Scripts/BoardAnimator.gd`)
Handles all board animations: swap (0.25s), return, destroy (0.16s scale-to-zero), fall (900px/s with per-column stagger).

### Prefab Scripts

All prefabs are `@tool` — they update visually in the editor when inspector values change.

#### `PassiveStack` (`Scripts/PassiveStack.gd`)
Horizontal row of charge slots centered in parent.
- `@export var stack_data: PassiveStackData` — sets icon textures for all slots
- `@export var max_count` (1–10), `current_count` (0–max), `icon_size`, `max_spacing`, `reverse`
- Each slot is a `Control` with two children: `Bg` (disabled sprite, always visible) and `Fg` (active sprite, scale-animated)
- **`set_count_animated(new_count)`** — animates slot transitions: appear = scale 0→1.2→1, disappear = scale 1→0; kills conflicting tweens via `_slot_tweens` dictionary

#### `ActiveSkillBase` (`Scripts/ActiveSkillBase.gd`)
`TextureButton` with skill icon, rank stars (1–3), and use counter.
- `@export var skill_data: SkillData`, `rank` (1–3), `count` — when `count == 0` button is disabled and greyed out

#### `ScoreLine` (`Scripts/ScoreLine.gd`)
Progress bar showing score balance. Range `-100` to `100`, center = 0.
- Set `value` to `l_score - r_score`; animates smoothly via `lerpf` in `_process`

### Resource Types

#### `GemData` (`Scripts/GemData.gd`)
`gem_name`, `sprite_base`, `sprite_modified`, `is_multicolor` (true for Applebomb wildcard).

#### `PassiveStackData` (`Scripts/PassiveStackData.gd`)
`sprite_disabled` (grey/inactive) and `sprite_active` (coloured) texture pair.

#### `SkillData` (`Scripts/SkillData.gd`)
`skill_name`, `description`, `icon`.

### Turn System

- Each round: left player takes 2 moves, then right player takes 2 moves
- Both players' remaining moves are always visible simultaneously
- Score = total gems destroyed per move
- `ScoreLine.value = l_score - r_score` (clamped to ±100)
- Passive stacks charge when gems matching the player's passive type are destroyed; at 5 charges it fires and resets (overflow carries over)

### Naming Conventions

- `L_` prefix = left/player side; `R_` prefix = right/enemy side
- Gem type integers: 0=Red, 1=Blue, 2=Green, 3=Pink, 4=Banana (matches `passive_stack_resources` array order)
- Sprites grouped by UI section under `Assets/Sprites/`
- Skill icon files: `Assets/Sprites/Skills/SkillIcons/{Name}.png`
- Mini gem sprites: `Assets/Sprites/Gems/Mini/{Color}_mini_0.png` (disabled) / `_1.png` (active)
