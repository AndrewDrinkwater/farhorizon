# ADR 0011 — Settings persistence and named input actions

**Status:** accepted · **Date:** 2026-06-06

## Context
Player settings (resolution, volume, language, default sim speed, keybinds) are
not part of a saved *game* — mixing them into save files makes both messier.
And reading raw keycodes scatters input handling and blocks remapping later.

## Decision
- **`ConfigManager` autoload** owns player settings, persisted to
  `user://settings.cfg` (Godot `ConfigFile`), **separate from save games**.
  Settings: window/resolution, volume buses, language, default sim speed,
  keybind overrides, accessibility toggles (see ADR 0012).
- **Named input actions** are defined in Project Settings (Input Map) from the
  start — e.g. `ui_plot_course`, `sim_pause`, `sim_speed_up`, `toggle_debug`.
  Nothing reads raw keycodes; everything reads actions.
- Remap UI can come later; the action layer means it won't require touching
  gameplay code.

This makes `ConfigManager` the sixth (and final core) autoload alongside
EventBus, GameState, SimClock, SaveManager, TypeRegistry. It holds *settings*,
not *run state* — so GameState remains the only autoload holding the saved run.

## Why
Separating settings from saves keeps each format clean and lets settings
persist across different save games. Named actions are the standard Godot way to
keep input remappable and centralised.

## Consequences
- One more autoload, but cleanly scoped (settings only).
- Input handling reads actions; adding a key is a Project Settings + config
  change, not a code hunt.

## Alternatives rejected
- **Settings inside the save file** — couples unrelated data, breaks
  cross-save settings.
- **Raw keycode handling** — blocks remapping, scatters input logic.
