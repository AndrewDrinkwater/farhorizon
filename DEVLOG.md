# Far Horizon — DEVLOG

Session-by-session build history. Newest entries at the top.

---

## 2026-06-06 — Session 2: Gate + SimClock tick loop (α0.1 build-order step 2)

First real compile/run of the scaffold, then the discrete clock.

**Gate (step 1 verification).** Ran the project headless in Godot 4.6.2 (mono).
The scaffold compiled and the smoke test passed **4/4** untouched — no scaffold
fixes needed. Only wrinkle was the run command itself: on PowerShell the GUT
`-gconfig=...` arg must be quoted (`"-gconfig=.gutconfig.json"`) or Godot sees
`Unknown arguments`.

**SimClock (step 2).**
- **Pure tick math in `src/core`** (ADR 0004): `ClockMath` accumulates
  speed-scaled real time and returns whole ticks (sub-tick remainder preserved
  across frames; speed 0 freezes with no lost progress). `SimCalendar` derives
  day/hour from the tick count. Both node-free and GUT-tested.
- **`SimClock` node** is now a thin shell: drives `ClockMath` in `_process`,
  emits `EventBus.sim_tick(tick)`. Speed `0/1/2/4×` via `set_speed` /
  `speed_up` / `speed_down` / `toggle_pause`, wired to the `sim_pause`,
  `sim_speed_up`, `sim_speed_down` actions. Boots at `default_sim_speed`.
- **Window-focus auto-pause** (CONVENTIONS.md, the one allowed auto-pause):
  pauses on `NOTIFICATION_APPLICATION_FOCUS_OUT`, restores the prior speed on
  focus-in, gated by `ConfigManager.pause_on_focus_loss`. A manual pause is left
  untouched (separate flag), so focus regain doesn't un-pause the player.
- **On-screen clock readout** (`src/ui/shell/clock_readout.gd`) — derived
  calendar + speed, all via `tr()` keys (new `CLOCK_FORMAT/SPEED/PAUSED`).
  **Debug overlay** (`src/ui/components/debug_overlay.gd`, ADR 0012) toggled by
  `toggle_debug` (F1): tick / speed / sec-per-tick / FPS, read-only, debug text
  exempt from localisation. Both hosted by the interim `main` shell.
- **Localisation wired up**: registered `strings.en.translation` in
  `project.godot` `[internationalization]` so `tr()` works without the manual
  editor step (SETUP.md updated; that step is now automated).

**Tests:** `test_clock_math` (9), `test_sim_calendar` (4), `test_sim_clock` (7),
plus the smoke suite (4) — **24/24 green** headless. Main scene boots clean.

**Next:** build-order step 3 — `GameState` + `SaveManager` minimal state tree
(clock + stub ship) with a save/load round-trip (GUT: round-trip).

---

## 2026-06-06 — Session 1: Project scaffold (α0.1 build-order step 1)

First code. Stood up the Godot project skeleton against the plan — no gameplay
yet, just the foundation everything hangs off.

- **Godot 4.6** (latest stable, Forward+), GDScript, 1920×1080. `project.godot`
  with the six autoloads registered, named input actions (`sim_pause`,
  `sim_speed_up/down`, `toggle_debug`), and the GUT plugin enabled.
- **Six autoloads** created: `EventBus` (all signals declared, incl. order +
  clock), `GameState`/`SimClock`/`SaveManager`/`TypeRegistry` as typed stubs
  with public surfaces + TODOs pointing at their build-order step, and
  `ConfigManager` implemented (settings in `user://settings.cfg`, separate from
  saves).
- **`GameVersion`** constants (`GAME_VERSION` 0.1.0, `SAVE_SCHEMA_VERSION` 1).
- **Localisation** string table `localization/strings.csv` (Helm/flight keys);
  `tr()` ready. One manual editor step to register the locale (SETUP.md).
- **GUT 9.6.0** vendored into `addons/gut`; `tests/unit/test_smoke.gd` asserts
  the autoloads load and defaults hold; `.gutconfig.json` added.
- Repo hygiene: `.gitignore` (`.godot/`, `*.translation`, etc.), `.gitattributes`
  (LF), `icon.svg`, `README.md`, `SETUP.md`, full `src/` tree with `.gitkeep`.
- Runnable placeholder scene (`src/ui/shell/main.tscn`) so the project boots.

Couldn't run a live compile (no Godot in this environment); verified structure,
GUT's `GutTest`/headless runner, and plugin manifest by hand. **First open in
Godot 4.6 is the real check** — see SETUP.md.

**Next:** build-order step 2 — implement SimClock ticks + EventBus, window-focus
auto-pause, and the debug overlay.

---

## 2026-06-06 — Session 0c: Consoles + the Helm console

Defined the first console and, with it, the UI's organizing model.

- **Consoles, not screens.** The UI is a set of captain's **consoles** (bridge
  posts); **Helm** is the first (flight + navigation). Supersedes the flat
  screen list. Each console is a post a crew officer can man later. (ADR 0013)
- **Orders, not actions.** The captain *issues orders*; the ship executes. Order
  lifecycle: compose → issue → **acknowledge** (a beat) → execute → belay. One
  active order per console. The active order is stored in `ShipState` so
  mid-order saves resume. This is the diegetic form of "UI emits intents". (ADR 0014)
- **Voice by crew slot.** Acknowledgments are voiced by whoever holds the post —
  a named officer if manned, the ship's computer if not (α0.1). One resolver
  serves every console; the crew system later lights up named voices everywhere.
- **Helm α0.1 orders:** Set Course (+ burn), Engage / Belay, All Stop,
  Establish / Break Orbit, Dock. Spec: `docs/consoles/helm.md`.

The α0.1 spine is now played *through* the Helm console.

**Next:** review, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0b: Cross-cutting concerns + data model

Reviewed what else to plan early. Added project-wide disciplines as ADRs and a
conventions doc, and produced a data-model diagram of entities + runtime flow.

**Added (decided cheap-now, expensive-later):**
- **Localisation-ready** — all player text via `tr()` keys + string table; one
  formatting helper. English only for now. (ADR 0010)
- **Settings + input actions** — `ConfigManager` (sixth autoload), settings in
  `user://settings.cfg` separate from saves; named input actions, no raw
  keycodes. (ADR 0011)
- **Accessibility + debug overlay** — colourblind-safe palette, never colour
  alone, toggleable live debug overlay. (ADR 0012)
- **CONVENTIONS.md** — canonical units (tick = hour, world units, fuel),
  `GAME_VERSION` + save `SCHEMA_VERSION`, window-focus auto-pause.

**Deferred (reserved):** single seeded `Rng` service for all randomness —
arrives with procgen, not α0.1.

**Data model:** confirmed the flow — UI reads GameState + emits intents; all
cross-system traffic via EventBus; authored `.tres` immutable, referenced by id;
SaveManager serializes the one GameState tree. (Diagram produced for review.)

**Next:** review the updated docs, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0: Planning the rebuild

Greenfield restart of Far Horizon — "slower and properly." Old POC treated as
discarded (rebuild from the design vision, not the old code). No game code this
session; the output is the architecture plan and the α0.1 milestone spec, for
review before any code is written.

**Why the restart:** the POC worked but was clunky. The named clunk was in
three places — **time/tick handling**, **UI flow**, and **flight feel** — so
each got a deliberate design here.

**Decisions locked (see `docs/adr/`):**
- Godot latest stable 4.x, GDScript strictly typed, Forward+, 1080p 16:9. (0001)
- Single owned **GameState** tree as the only stateful autoload. (0002)
- Central **EventBus** for all cross-system signals. (0003)
- **Discrete SimClock** — one authoritative tick, interpolated rendering;
  speed 0/1/2/4×; never auto-pauses for UI. Fixes the time clunk. (0004)
- **Spatial flight, static bodies, burn-intensity** lever. Static bodies kill
  the moving-target problem; a named flight state machine stays extensible.
  Fixes the flight clunk. (0005)
- **Diegetic terminal UI** — persistent live main view, full-screen menu
  layouts over it, stylistic (no bezel). Fixes the UI-flow clunk. (0006)
- **Config-driven UI components** fed data + layout. (0007)
- **Save schema from the start**, versioned + forgiving. (0008)
- **GUT testing from the start** on pure `core` logic. (0009)

**Five autoloads, no more:** EventBus, GameState, SimClock, SaveManager,
TypeRegistry.

**α0.1 "The Ship Flies" — done =** plot a course with burn choice, fly it on
the clock, spend/refuel reaction mass, save/load the run, and it feels good.
Build order and scope in `docs/ALPHA-0.1-SPEC.md`.

**Flagged for a later design-doc revision:** flight/travel section, the UI
model, and ship progression/tiers — the rebuild supersedes parts of the
original doc in these areas.

**Open / assumed:** GitHub remote to be created at project init; exact Godot
patch version to pin at scaffold time.

**Next session:** review these docs, sign off or adjust, then scaffold the
project.
