# α0.1 — "The Ship Flies"

**Status:** planned (pre-code) · **Goal:** the vertical spine of Far Horizon,
feeling good.

This milestone proves the core loop's foundation end to end: a captain plots
a course, watches the ship fly there on the clock, manages reaction mass, and
can save and resume the run. Everything else in the game builds on these
systems, so they get built properly here.

---

## Definition of done

α0.1 is complete when **all** of these are true:

1. **Plot + burn.** The player clicks a body on the NAV terminal, sees a course
   preview (ETA + reaction-mass cost), chooses a burn intensity
   (Economy / Standard / Hard), and engages.
2. **Fly on the clock.** The ship visibly flies to the target through the
   flight state machine, advancing on discrete SimClock ticks with smooth
   interpolated motion. The clock can be paused / run at 1× / 2× / 4×, and
   keeps running while menus are open.
3. **Fuel matters.** Burns spend reaction mass; the choice of burn intensity
   changes how much. The player can refuel (at the station body). Fuel is
   shown live on the HUD.
4. **Save / load.** The run (ship position, fuel, clock tick, loaded system)
   serializes and restores correctly via SaveManager, schema-versioned.
5. **It feels good.** Flight reads clearly — legible states, ETA, abort always
   available — with none of the POC's moving-target or unclear-state clunk.
6. **Green tests.** GUT tests pass for the `core` logic: clock ticks, ETA/fuel
   math, save round-trip.

---

## In scope

- **SimClock** (discrete ticks, speed control) + **EventBus** + **GameState** +
  **SaveManager** + **TypeRegistry** — the five-autoload foundation.
- **One hardcoded star system** with a few static bodies (a star, 2–3 planets,
  one station) authored as `.tres`.
- **Spatially-real flight:** ship node, camera follow, `FlightController` state
  machine, course preview, burn intensity, abort.
- **Reaction-mass fuel:** consumption on burn, refuel at station, live readout.
- **The Helm console** (first console — see `docs/consoles/helm.md`): Nav Plot
  system map + live flight status, built from the first config-driven components
  (panel, readout, gauge, button, light, list), inside the persistent terminal
  shell. The α0.1 spine is played through Helm.
- **The order lifecycle** (ADR 0014): issue → acknowledge (ship voice) → execute
  → belay, with the active order saved in `ShipState`.
- **Minimal theme:** fonts + colourblind-safe palette + the handful of base
  components (state carries an icon/label, not colour alone — ADR 0012).
- **Save/load** round-trip.
- **Cross-cutting scaffolding:** `tr()` string table, `ConfigManager` settings,
  named input actions, debug overlay, `GAME_VERSION` (ADRs 0010–0012, CONVENTIONS).

## Out of scope (deferred to later phases)

- Crew, away missions, probes
- Warp fuel, multi-system, galaxy map
- Scanning, aspects, planet classification
- Procedural planet shaders / Planet Studio
- The editor plugins (System Builder, Ship Yard, FHDM) — data hand-authored as
  `.tres` for now
- Full screen set (SHIP/CREW/CARGO/etc.) beyond what the spine needs — a stub
  is fine; one complete extra screen is a stretch goal, not required

---

## Suggested build order

Each step ends in something runnable and, where it's `core` logic, tested.

1. **Project scaffold.** Godot project, folder structure, git + GitHub remote,
   GUT installed, the six empty autoloads registered (incl. `ConfigManager`).
   Set up: the string table + `tr()` wiring (ADR 0010), named input actions
   (ADR 0011), and the `GAME_VERSION` constant (CONVENTIONS).
2. **SimClock + EventBus.** Discrete ticks, speed control, `sim_tick` signal,
   window-focus auto-pause. A tiny on-screen tick/clock readout to see it run.
   Stand up the debug overlay early (ADR 0012). *(GUT: tick math.)*
3. **GameState + SaveManager.** Minimal state tree (clock + a stub ship),
   save/load round-trip. *(GUT: round-trip.)*
4. **World + static bodies.** Load the hardcoded system `.tres`, place body
   nodes, camera. Ship node at a start position.
5. **Flight core.** ETA/fuel math in `src/core`. *(GUT: ETA + fuel.)*
6. **FlightController.** State machine driving the ship along a course on
   ticks, interpolated rendering, abort.
7. **Fuel.** Reaction-mass consumption by burn intensity; refuel at station.
8. **Helm console + order lifecycle.** Terminal shell + minimal theme + base
   components; the Helm console: Nav Plot with click-to-target, course preview,
   burn selector, order buttons (Lay In / Engage / Belay / All Stop / Orbit /
   Dock), flight status readouts, order log. Wire the issue→acknowledge→execute
   lifecycle with ship-voice acknowledgments. Time controls in the shell.
9. **Polish + feel pass.** Tune tick rate, burn costs, camera, clarity. Confirm
   all done-criteria. Update DEVLOG.

---

## Tuning knobs (placeholders, expect to change by feel)

- Seconds-per-tick at 1× speed
- In-game-hours per tick (currently 1)
- Reaction-mass cost per burn intensity, and ETA multipliers
- System scale (world units between bodies) and camera zoom range

None of these touch game logic — they're data/constants, tuned late in the
build order.
