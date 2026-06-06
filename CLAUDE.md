# CLAUDE.md — Far Horizon

Orientation for Claude Code working in this repo. Read this first, then
`ARCHITECTURE.md` and `docs/ALPHA-0.1-SPEC.md`.

## What this is
A 2D top-down space exploration game in **Godot 4.6** (Forward+, GDScript).
Captain's-terminal command game: you issue **orders**, the ship executes them on
a mission clock. Being rebuilt deliberately from scratch; α0.1 = "The Ship Flies".

## Where the decisions live (read before changing architecture)
- `ARCHITECTURE.md` — the system design (autoloads, EventBus, clock, flight, UI).
- `docs/ALPHA-0.1-SPEC.md` — current milestone + **build order** (you work this).
- `docs/CONVENTIONS.md` — canonical units, versioning, style.
- `docs/consoles/helm.md` — the first console (flight + navigation).
- `docs/adr/0001..0014` — one decision per file. **If you change a decision,
  add/supersede an ADR.**
- `DEVLOG.md` — append a short entry per work session (newest on top).

## Non-negotiable conventions (from the ADRs)
- **Strictly typed GDScript**, Godot official style (tabs, snake_case, PascalCase
  classes, `class_name` on shared types).
- **Six autoloads only** (`src/autoload/`): `EventBus`, `GameState`, `SimClock`,
  `SaveManager`, `TypeRegistry`, `ConfigManager`. `GameState` is the *only* one
  holding saved run state. Don't add autoloads without an ADR.
- **All cross-system comms go through `EventBus`** (ADR 0003). No system holds a
  ref to another. Intra-scene chatter uses local signals.
- **Discrete clock** (ADR 0004): one tick = one in-game hour; everything ticks off
  `EventBus.sim_tick`. Never drive sim logic from raw `delta`. Rendering may
  interpolate; logic reads the tick.
- **UI emits intents/orders, never mutates state** (ADR 0007/0014). The order
  lifecycle is compose → issue → acknowledge → execute → belay.
- **Pure logic in `src/core/`** (no node deps) so it's GUT-testable; nodes are
  thin shells over it.
- **Player text → `tr()` keys** in `localization/strings.csv` (ADR 0010). No
  hardcoded display strings.
- **Authored content is `.tres`, referenced by id** via `TypeRegistry`; never
  mutate a Resource at runtime, never embed one in state.
- **Accessibility:** colourblind-safe + never colour alone — state also carries
  an icon/label/shape (ADR 0012).

## Layout
```
src/autoload/  the six singletons
src/core/      pure testable logic (game_version.gd here)
src/flight/    flight state machine + ship      (empty — step 5/6)
src/world/     star system, bodies, camera      (empty — step 4)
src/data/      authored Resource type defs       (empty — step 4/5)
src/ui/        theme/, components/, shell/, consoles/
resources/     authored .tres (systems/, ships/)
tests/unit/    GUT tests
addons/gut/    GUT 9.6.0 (vendored, do not edit)
localization/  strings.csv
```

## Running & testing
- Open in **Godot 4.6**, press F5 — the scaffold scene prints a boot line.
- **GUT** (unit tests) — in-editor via the GUT bottom dock, or headless:
  ```
  godot --headless -s addons/gut/gut_cmdln.gd -gconfig=.gutconfig.json
  ```
  Tests live in `tests/`, config in `.gutconfig.json`. Test scripts
  `extends GutTest`.
- **GUT is set up but has never actually been run** (the scaffold was built
  without a Godot binary available). **First task: open the project, confirm it
  compiles, and run the smoke test (`tests/unit/test_smoke.gd`) green.** Fix any
  scaffold issues you find before building new features.

## One-time editor setup (see SETUP.md)
- Enable the **Gut** plugin if not auto-enabled (it's listed in `project.godot`).
- Register the imported translation: Project Settings → Localization → add
  `localization/strings.en.translation` (generated on first CSV import).
- Sanity-check the input actions in `project.godot` (`sim_pause`, `sim_speed_up`,
  `sim_speed_down`, `toggle_debug`) resolve to keys after first open.

## Current state & next task
- **Done:** α0.1 build-order **step 1** (scaffold) — see `DEVLOG.md` top entries.
  Autoloads are typed skeletons with TODOs naming their step; `ConfigManager` is
  the only fully-implemented one.
- **Next:** build-order **step 2** — implement `SimClock` (tick accumulation,
  speed multipliers, window-focus auto-pause) emitting `EventBus.sim_tick`, plus
  a tiny on-screen clock readout and the toggleable debug overlay (ADR 0012).
  Add GUT tests for the tick math. Then continue down the build order in
  `docs/ALPHA-0.1-SPEC.md`.

## Workflow expectations
- Keep `DEVLOG.md` updated; add an ADR for any architectural fork.
- Tests green before calling a `core` system done.
- Commit in logical steps with clear messages.
