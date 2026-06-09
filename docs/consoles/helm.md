# Console — Helm

**Role:** flight control and navigation, from the captain's chair.
**Status:** α0.1 console (the first one built).

The captain does not fly the ship. At Helm, the captain **issues orders** —
set a course, all stop, establish orbit, dock — and the ship (a helm officer,
or the ship's computer if the post is unmanned) **acknowledges and carries
them out** over the mission clock. The console is an order surface and a status
display, never a flight stick.

This is the diegetic face of the architecture's core rule: the UI emits
intents, systems execute. Here, an *intent* is an *order*.

---

## What the captain can order (α0.1)

| Order | Effect |
|-------|--------|
| **Set Course** (+ burn intensity) | Target a body, choose `Economy / Standard / Hard` burn, preview ETA + reaction-mass cost, lay in the course. |
| **Engage / Belay** | Execute the laid-in course; or cancel/abort an order in progress (returns to drifting / course-set). |
| **All Stop** | Halt and hold position. |
| **Establish / Break Orbit** | Enter or leave orbit at the destination. |
| **Dock** | Dock at a station (enables refuelling). |

Reaction mass makes the burn choice bite (ADR 0005). Warp/jump orders are out
of scope until multi-system.

---

## Order lifecycle (acknowledged, then executes)

One active order at a time at Helm.

```
Captain composes order  →  ISSUE
        │  (UI emits order_issued on EventBus)
        ▼
FlightController validates
        │  invalid → rejected ("Unable — insufficient reaction mass")
        ▼
ACKNOWLEDGE  (brief beat; the helm replies)
        │  emits order_acknowledged(voice, line)
        ▼
EXECUTE  (flight state machine runs over ticks)
        │  Engaging → Accelerating → Cruising → Decelerating → Arriving → InOrbit
        ▼
COMPLETE / or BELAYED mid-flight (Abort → CourseSet)
```

- The acknowledgment is a short beat that sells the chain of command; it maps
  onto the flight machine's `Engaging` state — no new state needed.
- The **active order is stored in `ShipState`** so a mid-flight save resumes
  correctly (the transient ack beat is not saved; on load the ship resumes the
  executing state).
- **Belay** is always available while an order executes.

## Who answers — voice by crew slot

The acknowledgment's voice is **resolved from the Helm post**:

- **Manned** (a helm officer assigned to the post) → that officer answers, by
  name: *"Helm, aye — course laid in for the inner moon."*
- **Unmanned** (no crew, as in α0.1) → the ship's computer answers, impersonal:
  *"Course laid in. Engaging."*

A small resolver maps `post → assigned officer or null`; null falls back to the
ship voice. The same resolver serves every future console, so the crew system
later "lights up" voices everywhere without console changes.

---

## Layout (assembled from config-driven components)

A persistent console; the mission clock keeps running while it's open.

| Region | Built from | Shows |
|--------|-----------|-------|
| **Nav Plot** (main) | map node + overlays | System map: star, static bodies, ship marker, current course line + destination, sensor range. Click a body to target it. |
| **Course Order** | `TPanel` + `TButton` + burn selector + `TReadout` | Selected target, burn intensity, ETA + reaction-mass preview, **Lay In Course**; plus All Stop, Establish Orbit / Dock, Belay. |
| **Flight Status** | `TReadout` + `TGauge` + `TLight` | Flight state (named, not colour-only — ADR 0012), ETA / arrival time, distance, reaction mass — plus a **transient acknowledgment line** (the ship's "Course laid in", fades after a few seconds; ADR 0025). |
| **Target Information** | `TPanel` + `TReadout`s | Details of the current selection, burn-aware (ADR 0025): a body's type/parent/distance/ETA/RM/reachability/dock+refuel/has-moons; a contact's tier (Blip/Identified)/kind/scan availability; a waypoint's bearing/ETA. Replaces the old Order Log. |

Time controls (pause / 1× / 2× / 4×) live in the persistent terminal shell, not
inside Helm — they're the captain's *watch* speed, not a flight order.

All labels are `tr()` keys (ADR 0010); all state shown with a non-colour
channel (ADR 0012).

---

## Signals (illustrative)

- UI → EventBus: `order_issued(order)`, `order_belayed()`, `course_previewed(target_id, burn)`
- EventBus → UI: `order_acknowledged(voice, line)`, `order_rejected(reason)`,
  `flight_state_changed(state)`, `fuel_changed(...)`
- Helm reads ship/flight/fuel from `GameState` (binding); it never mutates.

---

## α0.1 definition of done (Helm slice)

Helm is the console through which the α0.1 spine is played. Done when the
captain can: target a body on the Nav Plot, choose a burn, see ETA + fuel,
**lay in and engage** a course, watch the ship execute it on the clock, **belay**
mid-flight, **all stop**, **establish orbit / dock**, refuel at a station, and
have every order acknowledged in the ship voice — with the run saving and
restoring mid-order. See `docs/ALPHA-0.1-SPEC.md`.
