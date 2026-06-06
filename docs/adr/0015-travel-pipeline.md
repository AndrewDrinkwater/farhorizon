# ADR 0015 — Travel pipeline: location, course, and context-derived orders

**Status:** accepted · **Date:** 2026-06-06
**Builds on:** ADR 0005 (spatial flight, static bodies), ADR 0014 (order lifecycle)

## Context
The first flight pass (ADR 0005) had a single flight state machine that
conflated *where the ship is*, *what it's planning*, and *whether it's moving*.
The Helm showed every order at all times, so the player could press orders that
made no sense in context (Engage with no course, Dock in open space). We want
available orders to be a function of the ship's situation.

## Decision
Model travel as three separate things on `ShipState`, and derive the legal
orders from them:

1. **Location** — where the ship *is* when not under way. `Travel.Location`:
   - `DEEP_SPACE` — drifting in open space (no body).
   - `HOLDING` — in a body's holding area / orbit (`location_body_id`).
   - `DOCKED` — docked at a station (`location_body_id`, a `can_dock` body).
2. **Course (target state)** — the laid-in plan, `ShipState.current_order`
   `{target_id, burn, engaged}`. A course is *laid in* (composed + committed) and
   then *engaged* (executed). `engaged == true` means the ship is **under way**.
3. **Motion** — the transit phase while under way (`FlightCore.State`:
   `Engaging → Accelerating → Cruising → Decelerating → Arriving`), and `Idle`
   when not.

**Nav target ≠ location.** Selecting a body on the Nav Plot is a compose-time
*selection* (UI state). It only becomes the ship's target by **laying in a
course**.

**Order availability is derived** by a pure function `Travel.available(context)`
(GUT-tested), the single source of truth the Helm uses to enable/disable buttons
and the FlightController validates against:

| Order | Available when |
|-------|----------------|
| **Lay In Course** | a nav target is selected, it isn't where we already are, and we're not under way |
| **Engage** | a course is laid in, not under way, and not docked |
| **Belay** | under way (abort; keeps the course laid in) |
| **All Stop** | under way (halt; drops the course) |
| **Dock** | holding at a `can_dock` body, not under way |
| **Undock** | docked |

**Transitions.** Engage departs (location → `DEEP_SPACE`). Arrival auto-enters
`HOLDING` at the target and clears the course (no manual "establish orbit").
Belay stops in `DEEP_SPACE` keeping the course; All Stop stops and drops it.
Dock → `DOCKED` (refuels at a `can_refuel` body); Undock → `HOLDING`.

**Persistence.** `location` + `location_body_id` join `current_order` in
`ShipState` so a save restores the full situation (ADR 0008); motion is
recomputed from the course on load (the transient ack beat isn't saved).

## Why
Separating location / course / motion makes "what can I do now?" a pure
derivation instead of scattered conditionals, kills nonsensical orders, and
gives a legible status ("Holding: Anchorage", "Cruising → Rubicon"). It extends
ADR 0005's machine rather than replacing it — the transit phases are unchanged.

## Consequences
- `ShipState` gains `location` + `location_body_id` (serialized).
- `FlightCore.State` drops `COURSE_SET`/`IN_ORBIT` (now course/location concepts)
  and is motion-only.
- The Helm derives its button enablement and status from `Travel.available` +
  location; orders `establish_orbit`/`break_orbit` are retired, `undock` added.
- EventBus gains `ship_context_changed` so the UI re-derives on any situation
  change.

## Alternatives rejected
- **One flat state machine** (the ADR 0005 shape) — conflates the three axes and
  can't cleanly answer "what's legal now?".
- **Auto-undock on engage** — hides a deliberate step; docking should be left
  explicitly.
