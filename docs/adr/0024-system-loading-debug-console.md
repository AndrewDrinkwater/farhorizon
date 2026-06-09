# ADR 0024 — Runtime system loading + debug command console

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0002 (GameState/TypeRegistry), ADR 0003 (EventBus), ADR 0016
(orrery), ADR 0017 (sensors), ADR 0011 (input), ADR 0012 (debug overlay).

## Context
There's one authored system (`sol`) and it loads once at boot
(`Main._bootstrap_system` + `build`). To keep iterating on navigation we need
(a) more than one system and the ability to **switch at runtime**, and (b) dev
shortcuts (refuel, teleport) to test fast. Switching systems is also the seed of
warp / multi-system (β0.6), so the load path is designed cleanly now rather than
as a throwaway.

## Decision

### 1. Runtime system loading — a real capability
- **Signals:** `EventBus.system_change_requested(system_id)` (intent) and
  `EventBus.system_changed(system_id)` (done).
- **Handler** (the Main shell, or a small dedicated node) performs the load:
  validate the id via `TypeRegistry`; swap `GameState.system.system_id`; reset the
  ship to the new system's `ship_start`, clear `current_order`, set `location =
  DEEP_SPACE`; **reset transient contact discovery** state in `GameState`; rebuild
  the nav views (orrery / tactical / focus inset) for the new system; emit
  `system_changed`. Sensors re-detect from the new position on the next tick.
- **Views gain a rebuild path** — today they `build(system)` once; add a
  clear-and-rebuild on `system_changed`.
- **Forward-compatible:** warp / multi-system later reuses this exact load path
  (gated by fuel + a jump action). The debug console just calls it ungated.
  `system_changed` is the canonical "loaded system changed — re-init" signal
  every nav system listens to.

### 2. Debug command console — a dev tool
- A text-input overlay toggled by a new `toggle_console` action (backtick),
  **separate** from the F3 debug *overlay* (which is read-only readouts). Themed,
  screen-fixed, sim keeps running.
- **v1 commands:** `help`; `systems` (list ids); `system <id>` (→
  `system_change_requested`); `refuel` (fill RM to max, emit `fuel_changed`);
  `tp <body_id>` or `tp <x> <y>` (teleport: set position, `DEEP_SPACE`, clear
  course, emit `ship_context_changed`).
- **Privileged surface.** The console may call a small `DebugActions` helper that
  mutates `GameState` and emits the *existing* change signals. This is the
  sanctioned exception to "UI emits intents, never mutates" (ADR 0007) — it's a
  debug tool, not gameplay UI. Keeping debug actions in `DebugActions` (not as
  signals on the bus) avoids polluting `EventBus` with dev-only intents.
- **Release gating:** available in debug builds; gate out of release later
  (TODO — a `ConfigManager`/build flag).

## Consequences
- New `EventBus` signals: `system_change_requested`, `system_changed` (real —
  reused by warp later).
- Nav views + sensors re-init on `system_changed`; add a rebuild path.
- `GameState` gains a reset for contact discovery on system change.
- New `toggle_console` input action; new `DebugConsole` UI + `DebugActions` helper.
- A second authored system is needed to exercise switching (see
  `docs/navigation.md` → Calder Reach).

## Alternatives rejected
- **Reload the whole scene to switch systems** — heavy, and not warp-compatible
  (warp must swap systems without dropping the run).
- **Debug commands as gameplay intents on `EventBus`** — pollutes the bus with
  dev-only signals; keep them in `DebugActions`.
