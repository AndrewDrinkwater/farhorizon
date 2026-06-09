# ADR 0031 — Console shell + console bar

**Status:** accepted · **Date:** 2026-06-09
**Builds on:** ADR 0006 (diegetic terminal), ADR 0013 (UI as captain's consoles),
ADR 0007 (config-driven components).

## Context
ADR 0013 said the UI is organised as *consoles*, but only the Helm exists and the
shell hosts it directly. To grow the game (and to unburden the Helm), we realise
the shell: multiple consoles with a switcher, and a stub second console to prove
it. This is also the frame that lets future domains (Comms, Survey, Crew, Cargo)
slot in without reworking the shell each time.

## Decision
A **`ConsoleShell`** owns a set of consoles and shows **one at a time**, inside
the persistent terminal chrome (clock + time controls stay put; the sim keeps
running, ADR 0006).

- **Console bar (tabs).** A persistent bar of console tabs along one edge lists
  the available consoles and the active one; click or hotkey to switch. Diegetic,
  always shows where you are. Switching is pure UI (no state mutation); the shell
  emits `console_changed(id)` and `ConfigManager` remembers the last console.
- **Each console is a self-contained scene** (like `helm_console`), registered
  with the shell by id, shown/hidden on switch.
- **A console may own a background "stage."** The **Helm** owns the nav-view stage
  (orrery / tactical scope / surface / focus inset, ADR 0016/0017/0030); the shell
  shows that stage only while Helm is active and hides it for other consoles. The
  `T` toggle and land/take-off surface-swap stay *within* the Helm's stage (moved
  out of the shell root into the Helm console's ownership). Consoles without a
  stage render a plain themed panel.
- **Second console: `Ship / Engineering` (stub).** A placeholder console — title +
  a few real readouts (hull id, reaction mass, sensor range) and clearly-marked
  "TBD" sections — enough to prove two consoles and the switcher. No new systems.

## Consequences
- New `ConsoleShell` + a console-bar component; `helm_console` becomes one
  registered console; the nav-view stage moves under the Helm console's ownership.
- New stub `ship_console`; `console_changed` signal; a `toggle_console_next`/
  per-console hotkeys input action; `ConfigManager` last-console setting.
- New strings: console names (`CONSOLE_HELM`, `CONSOLE_SHIP`) + the Ship stub
  labels (`tr()`, ADR 0010).
- Forward-compatible: Comms / Survey / Crew / Cargo consoles register the same way.

## Alternatives rejected
- **Keep one console, no shell** — blocks every future domain and leaves the Helm
  overloaded.
- **All consoles always visible (split-screen)** — clutters the terminal and
  fights the "operate one console" feel; the bar + single active console is the
  captain's-terminal model.
