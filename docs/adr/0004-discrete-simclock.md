# ADR 0004 — Discrete SimClock: authoritative tick, interpolated view

**Status:** accepted · **Date:** 2026-06-06

## Context
Time/tick handling was the #1 clunk in the POC — multiple competing timers,
hard to reason about, awkward to save mid-flow. Time is also a core design
pillar ("time is a resource"), so the clock must be rock-solid.

## Decision
- **One autoload, `SimClock`,** is the sole driver of simulation time.
- **Discrete ticks.** One tick = one in-game hour (placeholder unit, tunable).
- `SimClock` accumulates real `delta`, and on each step emits
  `EventBus.sim_tick(tick)`. **Nothing else owns a sim-affecting timer.**
- **Speed multiplier:** `0× paused`, `1×`, `2×`, `4×` — speed = ticks per real
  second. Pause stops emission; the world freezes cleanly.
- **Sim never auto-pauses for UI.** The player may choose to pause.
- **Authoritative tick, interpolated view:** logic reads the discrete tick;
  the ship sprite's *rendered* position interpolates between the last and next
  tick for smooth motion. Logic never reads the interpolated value.

## Why
Discrete ticks are deterministic, trivially serializable (save a single
integer), and reproducible. A single signal means every future system
(missions, probes, supply consumption) hangs off one clock instead of its own
fragile timer. Interpolation keeps spatially-real flight looking smooth
despite a coarse logical tick.

## Consequences
- All time-based logic must be expressed in ticks, not raw `delta`.
- Tunable feel: changing seconds-per-tick or the tick unit doesn't touch
  game logic.
- Easy to unit-test (GUT) since the clock is pure integer math.

## Alternatives rejected
- **Continuous real-time** — smoother by default but harder to make
  deterministic and to save mid-tick.
- **Hybrid clock** — unnecessary once we separate authoritative tick from
  interpolated rendering; that gives smooth visuals without a hybrid clock.
