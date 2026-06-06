# Far Horizon — DEVLOG

Session-by-session build history. Newest entries at the top.

---

## 2026-06-06 — Fix: Helm console rendered off-screen

Playtest caught the Helm panels invisible. Cause: `HelmConsole` (a plain Control
under another plain Control) stayed size (0,0) — `set_anchors_preset(FULL_RECT)`
doesn't lay out a child of a non-Container parent — so its corner-anchored panels
landed off-screen (e.g. Course Order at y=−300). Fixed by setting explicit
full-rect anchors/offsets in `_ready`. Verified with a screenshot harness
(`tools/screenshot.gd`, a non-headless dev utility): all three panels now sit at
their corners with the map behind. The console is persistent (always on, no
toggle). 74/74 still green.

---

## 2026-06-06 — Session 9: Polish + feel pass — α0.1 complete (step 9)

Milestone wrap. Clarity/camera polish, a usable save/load, done-criteria confirmed.

- **Camera (scale-tuning debt):** `CameraFit` (src/core, tested) defines zoom
  min/max bounds; `SystemView` frames the whole system at boot (computed zoom,
  not a blind constant) and the mouse wheel zooms within bounds. Resolves the
  camera half of the scale debt; body spacing + tick/burn numbers remain
  feel-tuning (clearly-marked constants, none touch logic).
- **Nav Plot clarity:** `CourseLine` draws a dashed ship→target line + a
  destination marker while a course is laid in/executing (helm.md), tracking the
  interpolated ship marker.
- **Save/load in-game:** `sim_save` (F5) / `sim_load` (F9) actions + a
  `SaveController` with a toast — makes the (already-tested) save/load spine
  usable. Load emits `game_state_loaded`; the console, fuel, clock, and flight
  resync off it.
- **Fix:** the debug overlay + boot line mislabelled the debug key as F1; it's
  bound to **F3**. Corrected.

**α0.1 done-criteria — confirmed:**
1. **Plot + burn** — Helm Nav Plot: click a body → ETA + RM preview → burn
   selector → Lay In / Engage. ✓
2. **Fly on the clock** — FlightController over discrete ticks, interpolated
   render; pause / 1× / 2× / 4× in the shell, clock runs while the console is up. ✓
3. **Fuel matters** — RM spent per burn, refuel by docking at the station, live
   gauge. ✓
4. **Save / load** — position, fuel, tick, system round-trip via SaveManager,
   schema-versioned; F5/F9 in-game. ✓
5. **It feels good** — legible named states, ETA, abort (Belay) always available,
   course line; static bodies = no moving-target clunk. (Numeric feel left for
   in-engine tuning.) ✓
6. **Green tests** — clock, ETA/fuel, save round-trip, + flight/console/voice:
   **74/74 GUT green** headless. ✓

**Status:** α0.1 "The Ship Flies" is complete. Next is α0.2 scoping (agree scope,
write the milestone spec, then build) — see CLAUDE.md.

---

## 2026-06-06 — Session 8: The Helm console (step 8)

The α0.1 spine is now played through a real captain's terminal.

- **Minimal terminal theme** (ADR 0006): `Palette` (colourblind-safe Okabe–Ito
  status colours) + `TerminalTheme` (panel/button styleboxes, default font for
  now — Orbitron/Share Tech Mono are a later drop-in), applied once at the shell
  root so all Controls inherit it.
- **Config-driven component library** (ADR 0007): `TPanel`, `TButton`,
  `TReadout`, `TGauge`, `TLight`, `TList`. They read via binding callables and
  write only by invoking intents — never mutate state. `TLight` carries colour
  **and** glyph **and** label (never colour alone, ADR 0012).
- **Helm console** (`src/ui/consoles/helm_console.gd`, ADR 0013) assembled from
  those components over the Nav Plot map:
  - **Nav Plot:** click a body to select it as target (map emits
    `nav_target_selected`, owns its highlight ring); retired the temporary
    click-to-fly.
  - **Course Order:** selected target, burn selector (Economy/Standard/Hard),
    live ETA + RM-cost preview (with a ⚠ non-colour cue when unaffordable), and
    the order buttons — Lay In / Engage / Belay / All Stop / Establish Orbit /
    Dock.
  - **Flight Status:** flight-state light (state name + glyph + colour),
    distance + ETA to the active target, reaction-mass gauge.
  - **Order Log:** acknowledgments + rejections, newest first.
- **Order lifecycle** (ADR 0014): the console *composes* and *issues*;
  `FlightController` validates → the post *acknowledges* (ship voice) → *executes*
  over ticks → *belay* aborts. Added `CrewVoice.speaker_for(post)` — the seam the
  crew system plugs into (α0.1: always the ship's computer). Added
  `establish_orbit` / `break_orbit` orders. Acks/rejections flow to the Order Log.
- **Shell** (ADR 0006): `main` now assembles the persistent shell — Nav Plot map
  + `TimeControls` (clock + pause/1×/2×/4×, in the shell not the console) + the
  Helm console on a themed, mouse-transparent UI layer so empty-space clicks
  reach the map. Retired the standalone clock/fuel HUD labels (folded into the
  time bar + flight status).

**Tests:** `test_crew_voice` (2) + `test_helm_console` (5: builds clean,
select→lay-in issues the right order, no-target no-op, burn carries into the
order, ack logs). Whole suite **70/70 green** headless; full shell boots clean.

**Next:** build-order step 9 — polish + feel pass (tick rate, burn costs, camera
zoom range + fit-to-system, clarity), confirm all α0.1 done-criteria, and the
scale-tuning debt. Save/load round-trip (criterion 4) is already in from step 3.

---

## 2026-06-06 — Session 7: Fuel — reaction mass bites (step 7)

Burns now cost reaction mass, the burn choice matters, and you can refuel.

- **Consumption per tick:** `FlightController` spends RM for the distance
  actually covered each tick (`FlightMath.rm_cost`), so the total over a course
  equals the preview cost exactly. Emits `EventBus.fuel_changed`.
- **Fuel bites at engage:** engaging now validates the tank can complete the
  course (cost ≤ reaction mass) and rejects with `ORDER_REJECT_INSUFFICIENT_RM`
  otherwise — the real time-vs-fuel decision (ADR 0005). Pick a cheaper burn or
  refuel.
- **Refuel at station:** a `dock` order refills to capacity when the ship is at a
  `can_refuel` body, else rejects (`ORDER_REJECT_NOT_AT_STATION`). Added
  `ShipState.max_reaction_mass` (tank capacity, saved; additive — no schema bump,
  forgiving load covers it). The full Dock/Undock + crew voice are step 8; the
  temporary click now docks when you click the station you're parked at.
- **Live HUD:** `FuelReadout` shows current / max RM (tr() keys), updating on
  `fuel_changed` / load. `Fuel.Pool` enum added (Reaction Mass now; Warp
  reserved). Debug overlay already shows RM.

**Tests:** `test_fuel` (5: spend matches the cost model, harder burn drinks more,
engage refused without fuel, dock refuels, dock refused in open space) + the ship
round-trip now covers `max_reaction_mass`. Whole suite **63/63 green** headless;
scene boots clean.

**Next:** build-order step 8 — the Helm console: terminal shell + minimal theme +
config-driven components, Nav Plot with click-to-target, course preview, burn
selector, order buttons, flight status, order log, and the full
issue→acknowledge→execute lifecycle with ship-voice acks. (Retires the temporary
click-to-fly.)

---

## 2026-06-06 — Session 6: FlightController — the ship flies (step 6)

The vertical spine moves: plot → engage → fly on the clock → orbit, with abort.

- **`FlightCore`** (`src/core/flight_core.gd`, pure, GUT-tested) — owns the
  `State` enum (Idle → CourseSet → Engaging → Accelerating → Cruising →
  Decelerating → Arriving → InOrbit, matching the FLIGHT_STATE_* strings) plus
  `step_position` (clamped, never overshoots), `executing_state` (phase from
  course progress), `has_arrived`, `state_key`. α0.1 movement is straight-line at
  constant burn speed; the ramp phases are presentation, swappable later.
- **`FlightController`** (`src/flight/`, plain system node — not an autoload) is
  the system side of the order lifecycle (ADR 0014): validates orders off
  `EventBus` (`set_course` / `engage` / `all_stop`, `order_belayed` = abort),
  executes one `FlightCore.step` per `sim_tick`, writes `GameState.ship`
  (position/heading), and emits `flight_state_changed`. Holds no system refs
  (ADR 0003); reads GameState + TypeRegistry only. The course lives in
  `ShipState.current_order` (target_id, burn, engaged, origin) so a mid-flight
  save resumes — `game_state_loaded` recomputes the phase from geometry (the
  transient Engaging beat isn't persisted). Abort returns to CourseSet (ADR 0005).
- **Interpolated rendering (ADR 0004):** `ShipView` lerps between the last tick's
  rendered position and the live authoritative position using
  `SimClock.get_tick_fraction()` — smooth motion over the coarse tick; logic
  never reads the interpolated value.
- **Runnable now:** a TEMPORARY click-to-fly in `SystemView` (click a body →
  plot + engage a Standard course) so flight is visible before the Helm Nav Plot;
  replaced by the proper compose→preview→confirm flow in step 8. Debug overlay
  now shows flight state, ship position, and reaction mass. Order-reject reasons
  added as tr() keys.

**Tests:** `test_flight_core` (6) + `test_flight_controller` (6: lay-in/ack,
reject unknown target, engage→fly→orbit, belay→hold, all-stop→idle, load-resume).
Whole suite **58/58 green** headless; scene boots clean.

**Next:** build-order step 7 — reaction-mass consumption per burn on each tick,
refuel at the station, live fuel on the HUD (GUT: fuel).

---

## 2026-06-06 — Session 5: Flight ETA/fuel math (step 5)

The time-vs-fuel model, as pure tested logic before any flight node exists.

- **`FlightMath`** (`src/core/flight_math.gd`, node-free, GUT-tested) — the
  canonical owner of the **`Burn` enum** (Economy / Standard / Hard, used by
  Helm + FlightController later) plus: `distance`, `eta_ticks` (ceil — a partial
  tick still costs a tick), `rm_cost` (reaction mass, linear in distance), and a
  `preview()` that bundles distance + ETA + RM + affordability for the Helm
  course plot.
- **Model (α0.1, deliberately simple, ADR 0005):** straight-line course at a
  fixed per-burn cruise speed; RM spent per world-unit. Higher burn = faster but
  dearer per wu — the real lever. Speeds (60/120/240 wu/tick) and RM rates
  (0.020/0.035/0.060 per wu) are **tuning constants** (CONVENTIONS.md), expected
  to shift at the step-9 feel pass and likely to move onto per-hull authored data
  later. (See the scale/tuning notes — distances are in wu, scale-agnostic.)

**Tests:** `test_flight_math` (9) asserts the tradeoff holds (higher burn →
fewer ticks, more RM), ceil rounding, linear fuel scaling, zero-distance
free/instant, preview bundling + insufficient-fuel flag — all independent of the
exact numbers. Whole suite **46/46 green** headless.

**Next:** build-order step 6 — `FlightController` state machine driving the ship
along a course on SimClock ticks (interpolated rendering), with abort.

---

## 2026-06-06 — Session 4: World + static bodies (step 4)

The system is on screen: a star, planets, a station, and the ship.

- **Authored data types** (`src/data`, immutable `.tres`, ADR 0002/0005):
  `BodyData` (id, name_key, kind STAR/PLANET/STATION, position in wu, radius,
  tint, can_dock/can_refuel) and `SystemData` (id, name_key, bodies, ship_start).
- **The hardcoded "Sol" system** — `resources/systems/sol.tres`: star + 3 planets
  + 1 dockable station. Authored via a regenerable tool (`tools/build_sol_system.gd`,
  run headless) rather than hand-edited, so the typed sub-resource array stays
  valid; the `.tres` is the committed artifact.
- **TypeRegistry** now scans `resources/systems/` on ready and resolves
  `get_system(id)` / `has_system` / `system_ids` (read-only cache, by id).
- **World nodes** (`src/world`, presentation-only — read state, never mutate):
  `BodyView` (kind drives the shape — star = ringed disc, station = diamond,
  planet = disc — so type reads without colour, ADR 0012; tr() name label),
  `ShipView` (heading-pointed triangle tracking `GameState.ship`), `SystemView`
  (builds bodies + ship + a ship-following `Camera2D`, `ignore_rotation` so the
  view stays upright). `PIXELS_PER_WU` is the single wu→screen scale.
- **Shell wiring:** `main` bootstraps the start system into GameState (system_id
  + ship start), builds the `SystemView`, and moves the HUD (title + clock
  readout) into a `CanvasLayer` so it stays screen-fixed under the world camera.
- **Strings:** system + body display names added (all via tr(), ADR 0010).

**Tests:** `test_type_registry` (4) guards the authored content loads and stays
well-formed (star/3 planets/station, dock+refuel, name keys present). Whole
suite **37/37 green** headless; scene boots clean with system 'sol'.

**Next:** build-order step 5 — pure ETA/fuel math in `src/core` (GUT-tested),
the foundation for the course preview and FlightController.

---

## 2026-06-06 — Session 3: GameState tree + SaveManager round-trip (step 3)

The state tree and a real, versioned save/load.

- **Typed state objects** in `src/core/state` (pure, node-free, GUT-tested):
  `ClockState` (tick, speed), `ShipState` (hull_id, position, heading,
  reaction_mass, current_order — the step-3 stub), `SystemState` (system_id).
  Each implements `to_dict()` + a forgiving static `from_dict()`; authored
  content is referenced by id, never embedded (ADR 0002).
- **`GameState`** now owns the tree (`clock`/`ship`/`system`) with `new_game()`,
  `to_dict()`, and a forgiving `from_dict()` that falls back to defaults for
  missing branches (ADR 0008). It's the single source of truth.
- **`SimClock` reads/advances `GameState.clock` directly** rather than keeping a
  divergent copy — the live tick/speed *is* the saved value, so the save is just
  a serialized tree (resolves the ADR 0002 / "transient mirror" tension cleanly).
  On `game_state_loaded` it drops sub-tick progress and refreshes listeners.
- **`SaveManager`** writes a version-stamped payload (`game_version`,
  `schema_version`, `state`) via `var_to_str` (round-trips `Vector2` cleanly,
  human-readable) to `user://save_0.sav`. Load is forgiving, emits
  `EventBus.game_state_loaded`, and has a `_migrate()` hook for future schema
  bumps. The clock readout also refreshes on load.

**Tests:** added `test_state_objects` (4) and `test_save_manager` (5: full
round-trip incl. Vector2 + active order, version stamps, load-emits-signal,
no-save no-op, partial/forgiving load). Whole suite **33/33 green** headless;
main scene boots clean.

**Note:** `SAVE_PATH` moved from the scaffold's `.tres` to `.sav` (it's a
serialized dict, not a Resource). No saves existed, so no migration needed.

**Next:** build-order step 4 — load a hardcoded star system `.tres` (star,
planets, station) via TypeRegistry, place body nodes + camera, ship at a start
position.

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
