# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project

**Origami Battle** — a 1v1 turn-based match-3 puzzle battle game built in Godot 4.6 (GL Compatibility, mobile-first portrait 1080x1920).

## Running the Project

There are no build scripts. Use the standard Godot workflow:

- **Open:** Launch Godot 4.6 and open the project at this directory
- **Run:** Press `F5` in the editor, or `godot --path . Assets/Scenes/game.tscn` from the CLI
- **Export targets:** Windows (D3D12), Android/Mobile (GL Compatibility)

## Directory Structure

```
Assets/
├── Fonts/                        — game fonts (Chicoree Em Bold, Shonen)
├── Prefabs/                      — reusable scenes (.tscn)
│   ├── ActiveSkillBase.tscn
│   ├── PassiveStack.tscn
│   └── ScoreLine.tscn
├── Resources/
│   ├── PassiveStacks/            — PassiveStackData .tres (Red, Green, Blue, Pink, Banana, Applebomb)
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
├── GameField (TextureRect)
│   └── Gems (VBoxContainer) — 7×7 grid
│       └── GemsLine1–7 → GemCell1–7 → Gem + GemModificator
├── TopMenu (Control) — player/enemy badges, Rules/About/Exit buttons
└── HotBar (Control) — all battle UI
    ├── L_*/R_* — left = player, right = enemy (naming convention throughout)
    ├── L_Turns / R_Turns — turn counters
    ├── L_Score / R_Score — scores; L_AddScore / R_AddScore — score gain popups
    ├── ScoreLine — instance of ScoreLine.tscn
    ├── L_PassiveStack / R_PassiveStack — instances of PassiveStack.tscn
    └── L_ActiveSkillSlots / R_ActiveSkillSlots — 2 slots each
        └── Slot1, Slot2 → ActiveSkillBase (instance of ActiveSkillBase.tscn)
```

### Prefabs & Scripts

All prefabs are `@tool` — they update visually in the editor when inspector values change.

#### `ActiveSkillBase` (`Scripts/ActiveSkillBase.gd`)
`TextureButton` with skill icon, rank stars (1–3), and use counter.
- `@export var skill_data: SkillData` — drag a `.tres` from `Resources/Skills/`; icon updates immediately
- `@export_range(1,3) var rank` — controls how many of 3 stars are visible
- `@export var count` — updates the counter label; when `count == 0` the button is disabled and `modulate = #7b7b7b`

#### `ScoreLine` (`Scripts/ScoreLine.gd`)
Progress bar showing score balance between two players. Range is `min_value=-100` to `max_value=100`, center (value=0) = 50% fill.
- `Foreground` (ColorRect) width driven by `anchor_right = (value - min) / (max - min)`
- `Point` sprite switches to `point_sprite_negative` when `value < 0`
- Animates smoothly via `lerpf` in `_process`; `smooth_speed = 0` snaps instantly

#### `PassiveStack` (`Scripts/PassiveStack.gd`)
Horizontal row of icon slots, centered inside its parent, with configurable spacing.
- `@export var stack_data: PassiveStackData` — drag a `.tres` from `Resources/PassiveStacks/`
- `@export var max_count` (1–10) — total slots; children named `Slot1`..`SlotN` are created dynamically
- `@export var current_count` (0–max) — active slots; `reverse=false` fills from right, `reverse=true` from left
- `@export var icon_size` and `max_spacing` — layout; spacing auto-reduces (to negative/overlap) when icons don't fit
- Responds to `NOTIFICATION_RESIZED` — recalculates layout on parent resize

### Resource Types

#### `SkillData` (`Scripts/SkillData.gd`)
Stores `skill_name: String`, `description: String`, `icon: Texture2D`.
One `.tres` per skill in `Assets/Resources/Skills/`.

#### `PassiveStackData` (`Scripts/PassiveStackData.gd`)
Stores a disabled/active texture pair: `sprite_disabled` (_0 sprite) and `sprite_active` (_1 sprite).
One `.tres` per gem type in `Assets/Resources/PassiveStacks/`.

### Gem Grid

7×7 grid as VBoxContainer rows. Each cell: **Gem** (base sprite) + **GemModificator** (bomb/special overlay).
Types: Red, Blue, Green, Pink, Banana, Applebomb, Bomb_LeftRight, Bomb_UpDown.
Mini animated variants in `Assets/Sprites/Gems/Mini/` follow the `{Color}_mini_0.png` / `{Color}_mini_1.png` naming (0 = disabled, 1 = active).

### Naming Conventions

- `L_` prefix = left/player side; `R_` prefix = right/enemy side
- `GemsLine{1–7}` rows, `GemCell{1–7}` columns
- Sprites grouped by UI section under `Assets/Sprites/`
- Skill icon files: `Assets/Sprites/Skills/SkillIcons/{Name}.png`
