# Far Horizon

A 2D top-down space exploration game built in **Godot 4.6** (Forward+,
GDScript). A *frontier procedural* about the voyage — slow ships, real
distances, decisions that play out on the mission clock. You command a survey
ship from the captain's terminal: issue orders, and the crew (or the ship)
carries them out over time.

> **Status:** α0.1 in progress — "The Ship Flies". This repo is being rebuilt
> from scratch, slowly and deliberately. See `DEVLOG.md` for the build history.

## Documentation

- **`ARCHITECTURE.md`** — how the game is built (autoloads, EventBus, the
  discrete clock, flight, the console UI).
- **`docs/ALPHA-0.1-SPEC.md`** — the current milestone and its build order.
- **`docs/CONVENTIONS.md`** — canonical units, versioning, conventions.
- **`docs/consoles/helm.md`** — the first console (flight + navigation).
- **`docs/adr/`** — the decision records (one per major fork).
- **`SETUP.md`** — first-time setup steps.

## Layout

```
src/autoload/   EventBus, GameState, SimClock, SaveManager, TypeRegistry, ConfigManager
src/core/       pure, testable logic (no node deps)
src/flight/     flight state machine + ship
src/world/      star system + bodies + camera
src/data/       authored Resource type definitions
src/ui/         theme, components, shell, consoles
resources/      authored .tres content (systems, ships)
localization/   tr() string table
tests/          GUT unit tests
addons/gut/     GUT 9.6.0 (vendored)
```

## Running

Open the project in Godot 4.6 and press Play. Tests run from the **GUT** panel
(bottom dock) or headless — see `SETUP.md`.
