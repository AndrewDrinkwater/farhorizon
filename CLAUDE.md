# CLAUDE.md — Far Horizon

Orientation for Claude Code working in this repo. Read this first, then
`ARCHITECTURE.md` and `docs/ALPHA-0.1-SPEC.md`.

## What this is
A 2D top-down space exploration game in **Godot 4.6** (Forward+, GDScript).
Captain's-terminal command game: you issue **orders**, the ship executes them on
a mission clock. Being rebuilt deliberately from scratch; α0.1 = "The Ship Flies".

## Where the decisions live (read before changing architecture)
- `ARCHITECTURE.md` — the system design (autoloads, EventBus, clock, flight, UI).
- `docs/ALPHA-0.3-SPEC.md` — current milestone + **build order** (you work this).
  `docs/ALPHA-0.1-SPEC.md` / `docs/ALPHA-0.2-SPEC.md` are completed milestones.
- `docs/CONVENTIONS.md` — canonical units, versioning, style.
- `docs/consoles/helm.md` — the first console (flight + navigation).
- `docs/navigation.md` — the orrery + sensor navigation model with the pure
  `core` function contracts and test outlines (planned for α0.2).
- `docs/adr/0001..0023` — one decision per file. **If you change a decision,
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
- The translation is registered in `project.godot` (`[internationalization]`),
  so `tr()` works out of the box. If you edit `strings.csv` outside the editor,
  run `godot --headless --import` to regenerate the compiled `.translation`.
- Input actions (`sim_pause`, `sim_speed_up/down`, `toggle_debug` = F3,
  `sim_save` = F5, `sim_load` = F9) are in `project.godot`.

## Current state & next task
- **Done:** **α0.1 "The Ship Flies" — complete** (build-order steps 1–9). The
  spine works end to end: plot a course on the Helm Nav Plot (preview ETA +
  reaction mass, pick a burn), engage and fly it on the discrete clock with
  interpolated motion, spend/refuel reaction mass, save/load the run (F5/F9), all
  through the captain's-terminal Helm console with the order lifecycle + ship
  voice. **74 GUT tests green.** See `DEVLOG.md` for the per-session history and
  the step-9 done-criteria confirmation.
- **Tuning left (by feel, not blocking):** system spacing + the tick/burn
  numeric constants are sensible baselines, not play-tuned (they're clearly
  marked; none touch logic).
- **α0.2 "Navigation II" — mostly built** (`docs/ALPHA-0.2-SPEC.md`; ADRs
  0016/0017/0018/0019 accepted). Done: orrery Nav Plot (`OrreryView`, screen-space
  log projection — real AU distances unchanged), moons (`BodyData.parent_id` +
  parent-relative `project_child`), sensor/contact model (`Sensors`,
  `SensorController` on sim_tick, `ContactsState` saved, contacts wink in/out), the
  true-scale tactical scope (`TacticalView`, **T** to toggle), and travel-time
  legibility (ADR 0019: `FlightMath.reach_wu`, burn-aware per-body ETA badges +
  time-pip course line on the orrery, isochrone rings on the scope, via
  `EventBus.nav_burn_changed`). Pure core (`OrreryProjection`, `Sensors`,
  `FlightMath`) GUT-tested. **106 tests green.**
- **α0.2 feel pass still open** (build step 10 — orrery log band / sensor radius /
  glyphs / time-pip interval / isochrone steps — tune in-engine by F5); the
  focus-a-body moon sub-view stays deferred (moons are directly targetable).
- **α0.3 "Navigation III: Targets & the Scan" — in progress** (`docs/ALPHA-0.3-SPEC.md`;
  **ADR 0020/0021/0022** accepted). Done: generalized course (`current_order.dest`
  — body/contact/free-point; drift-on-arrival for non-bodies), empty-space
  waypoints (`nav_point_selected`, `OrreryProjection.unproject`, crosshair marker),
  the **scan** action (BLIP → IDENTIFIED, in-range gated, Helm Scan button,
  unknown-vs-named rendering), the **orrery scale toggle** (`OrreryParams.mode`
  LOG/LINEAR, Helm `Schematic | True scale` control), **moon orbit rings**, and the
  **focus inset** (`MoonInsetView` PiP, "has-moons" affordance, Helm Focus button +
  re-click, `nav_focus_requested`/`closed`); plus a **feel pass** (ADR 0023): orrery
  **pan & zoom** (wheel + right/middle-drag), near-star course pulled inward, lay-in
  label declutter, between-pip legend, scale control as a toggle switch above the
  Course Order box. **129 tests green; boots clean.**
- **Next:** more α0.3 feel tuning if needed in-engine (glyphs, scan range cue,
  inset size, zoom limits); then scope the next slice (station-keeping hold, survey
  rung, or a second console) — write the spec before building.

## Workflow expectations
- Keep `DEVLOG.md` updated; add an ADR for any architectural fork.
- Tests green before calling a `core` system done.
- Commit in logical steps with clear messages.
