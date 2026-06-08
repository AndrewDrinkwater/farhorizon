# ADR 0020 — Generalized nav targets + the scan action

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0014 (orders), ADR 0015 (travel pipeline), ADR 0017
(sensors/contacts), ADR 0016 (orrery).

## Context
α0.1/α0.2 could only plot a course to a **charted body** (`current_order`
carried a `target_id` resolved to a `BodyData`; arrival settled onto the body's
holding ring). But the captain also wants to (a) navigate to a **sensor
contact** (an anomaly/derelict/signal) and **scan** it, and (b) set a course to
an **arbitrary point** in empty space. Neither fits "a body id."

## Decision

**One course, three destination kinds.** A course destination is a *point*,
optionally tagged with the entity it came from:

- The course order gains a frozen **`dest: Vector2`** (the real destination),
  alongside the existing `target_id`. `target_id` is a body id, a contact id, or
  `""` for a free point.
- `FlightController` resolves the destination at lay-in: a body or detected
  contact → its position; a free point → the point the UI supplies. Execution
  uses the live body position for body courses (bodies may move later) and the
  frozen `dest` otherwise.

**Arrival depends on the kind (drift, not a new state):**
- **Body** → unchanged: settle onto the holding ring, `HOLDING`.
- **Contact or free point** → **drift**: stop on the point, drop the course, and
  go `IDLE` in `DEEP_SPACE` (exactly like All Stop). No "hold at a point" state —
  deliberately kept minimal; station-keeping can come later if wanted.

**Scan is an explicit order (ADR 0014 lifecycle).** `{type: "scan",
contact_id}`. Legal only when the contact is within `sensor_range` and currently
a `BLIP` (detected, not yet identified). It promotes the contact to
`IDENTIFIED` (`GameState.contacts`, saved) and emits `contact_promoted`. This is
the player-driven `BLIP → IDENTIFIED` step the α0.2 spec deferred. Detection
stays automatic (passive, on `sim_tick`); **identification is a deliberate act**.

**Selection plumbing.** Bodies and contacts are still selected by id
(`nav_target_selected`). A free point needs no id, so a new signal
**`nav_point_selected(point: Vector2)`** carries it. Both nav views pick the
nearest body/detected-contact under the cursor; an empty click drops a waypoint
(orrery via `OrreryProjection.unproject`, the inverse log map; tactical scope by
true-scale inverse — see ADR 0016). `Travel.available` gains `scan` and a
`has_nav_selection` flag (so a free point enables `lay_in` though its id is `""`).

**Identification is visible.** A `BLIP` renders as a hollow diamond labelled
"Unknown contact"; scanning fills the diamond and reveals the authored name — so
the scan order has a legible payoff (shape + label, not colour — ADR 0012).

## Why
Keeps a single course pipeline (one order type, one execution loop) instead of
forking per destination; the point-with-optional-id model absorbs all three
cases. Scan-as-order keeps the "orders are deliberate" pillar and advances the
contact ladder (contact → identified → …) without a passive auto-reveal.

## Consequences
- `ShipState.current_order` carries `dest` (a `Vector2` in the already-saved
  order dict — no schema bump). Old saves without `dest` fall back to the body
  position / ship position, so load stays forgiving (ADR 0008).
- New pure `OrreryProjection.unproject` (GUT-tested, round-trips `project`).
- New `EventBus.nav_point_selected`; `Travel.available` grows `scan` +
  `has_nav_selection` (back-compatible: defaults to `nav_target_id != ""`).
- New strings (waypoint, unknown-contact, scan, scan-complete, out-of-range,
  already-identified), all `tr()` keys.

## Alternatives rejected
- **A separate "waypoint" order type** — duplicates the whole engage/fly/fuel
  loop; the point-with-optional-id course subsumes it.
- **Auto-identify on arrival / in close range** — removes player agency; scan is
  meant to be a deliberate order.
- **A new "hold at a point" location state** — more state to save/animate for
  little gain in this slice; drift-on-arrival is enough (revisit later).
