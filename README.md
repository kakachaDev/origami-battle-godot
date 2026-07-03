# Origami Battle

> **Unfinished / on hold.** Prototype-stage match-3, kept public as a code sample rather than a playable release.

A mobile-first (1080×1920) match-3 battler built in Godot 4.6, played against a bot opponent.

## Systems

- **Board & matching** — match-3/match-4 detection, gem swapping, cascades (`GameBoard`, `BoardState`, `GemCell`, `GemData`)
- **Skills** — active skills with rank/count progression, driven by `SkillData` resources and reusable `ActiveSkillBase` prefabs
- **Passives & modifiers** — stacking passive effects (`PassiveStack`, `ModifierData`) that alter gem behaviour and scoring
- **Bot opponent** — `BotPlayer` / `BotData` drive a non-player side for solo play
- **Feedback** — cascading `GemEffect` visuals, animated score popups, hint system for stalled boards (`BoardAnimator`, `ScoreLine`)

## Tech

Godot 4.6, GL Compatibility renderer, touch-first input (mouse fallback), web export via `build_web.sh`.

## Running

Open the project in Godot 4.6+ and run the main scene, or build for web with `./build_web.sh`.
