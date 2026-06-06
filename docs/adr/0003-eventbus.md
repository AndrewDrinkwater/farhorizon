# ADR 0003 — EventBus for system communication

**Status:** accepted · **Date:** 2026-06-06

## Context
Tight coupling between systems was a source of POC tangle. The clock, flight,
and UI all need to react to each other's events without becoming a dependency
knot.

## Decision
A central autoload, **`EventBus`**, declares every cross-system signal and
contains no logic. Systems `emit` and `connect` to its signals; they do not
hold direct references to each other.

Example signals (illustrative, not final):
- `sim_tick(tick: int)`
- `course_plotted(target_id: String, burn: int)` — intent from UI
- `flight_state_changed(state: int)`
- `fuel_changed(pool: int, value: float)`
- `game_state_loaded()`

## Why
- **Decoupling.** The UI emits `course_plotted`; the FlightController listens.
  Neither imports the other.
- **One tick, many listeners.** Every future ticking system subscribes to the
  single `sim_tick` instead of owning its own timer — directly fixing the
  POC's competing-timers clunk.

In Godot terms: signals are the engine's built-in observer pattern. Centralizing
the global ones in one autoload makes the system's "wiring diagram" readable in
a single file.

## Consequences
- Need discipline to keep EventBus signals coarse/global; tight intra-screen
  interactions still use local signals (the "mix" was not chosen — EventBus is
  the default, local signals only within a single scene's internals).
- A grep of `EventBus.` shows every cross-system interaction — good for
  onboarding and debugging.
