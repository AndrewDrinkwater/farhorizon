# ADR 0026 — Zones: authored spatial regions

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0002 (authored data by id), ADR 0003 (EventBus), ADR 0004
(sim_tick), ADR 0017 (sensors — the pattern to mirror), ADR 0018 (body-relative
anchoring), ADR 0012 (accessibility).

## Context
Systems need authored **regions** — gas clouds, radiation bands, asteroid
fields, stellar no-go zones, station coverage, refuel/scoop bands, and on-arrival
mission/event triggers. These look like many features but are one primitive: a
shape in the system plus some effect(s) that apply while the ship is inside (or
on entry). Designing them as one general primitive avoids a separate system per
hazard type.

## Decision
A **`ZoneData`** authored resource (`.tres`, by id), held in
`SystemData.zones: Array[ZoneData]` alongside bodies and contacts.

**Geometry** (`shape`):
- `CIRCLE` — `radius` about a centre (disc).
- `BAND` — `inner_radius`..`outer_radius` annulus (a planet's radiation *band*).
- `POLYGON` — `points` (a hand-drawn gas cloud). Visual design comes later; the
  shape model supports it now.
- **Anchoring:** `anchor_body_id` ("" = free). Anchored zones position relative
  to the body — a station's sensor range, a planet's radiation band (ADR 0018
  pattern). Free zones use absolute `center` / `points`.

**Effects — a generic tag bag** (`effects: Dictionary`), not a fixed enum. A zone
carries a display `category` (HAZARD / FIELD / NOGO / FACILITY / TRIGGER — the
non-colour channel, ADR 0012) plus recognised effect keys that consuming systems
read. Examples (authored now, honoured as each system lands):
`sensor_mult` (Sensors), `rm_drain` / `refuel` (fuel), `blocks_course`
(none/`hazard`/`nogo`, ADR 0027), `trigger_event` + `once` (events). New effects
need no new zone type.

**Membership detection — pure `core` + a controller** (mirrors Sensors, ADR 0017):
- `src/core/zones.gd`: `Zones.contains(shape_params, point) -> bool` per shape
  (circle: `d ≤ r`; band: `inner ≤ d ≤ outer`; polygon:
  `Geometry2D.is_point_in_polygon`). Pure, GUT-tested.
- A `ZoneController` (`src/flight/`) ticks on `EventBus.sim_tick`, resolves
  anchored centres from the loaded system, computes the ship's current zone set,
  diffs vs last tick → `EventBus.zone_entered(id)` / `zone_exited(id)`.

**Wired this slice: the trigger hook only.** A zone with a `trigger_event` fires
`EventBus.zone_trigger_fired(zone_id, event_id)` on entry (once if `once`), for
the future event/mission system to consume — hook now, engine later (the
design-for-defer pattern). All other effects are **authored-but-inert** until
their consuming system exists (Sensors reads `sensor_mult` next; fuel reads
`refuel`; ADR 0027 reads `blocks_course`).

**Rendering.** Zones draw on the nav views beneath bodies/contacts, shape = the
region. On the true-scale tactical scope they're true shapes; on the orrery they
**warp** (project polygon vertices / circle-boundary samples through
`OrreryProjection`, like the sensor field) — acceptable, outlined/labelled, with
category as a non-colour channel.

**Persistence.** Zone definitions are authored (immutable). Runtime: fired
one-shot triggers are saved in `GameState` (so they don't re-fire); current
membership is recomputed on load (ADR 0008). Reset on system change (ADR 0024).

## Consequences
- New `ZoneData` type; `SystemData.zones`; `src/core/zones.gd` + tests;
  `ZoneController`.
- New `EventBus` signals: `zone_entered`, `zone_exited`, `zone_trigger_fired`.
- `GameState` gains a fired-trigger set (saved); cleared on system change.
- Authored example zones added to Calder Reach / Sol (see `docs/zones.md`).
- Sets up ADR 0027 (course obstacle avoidance reads `blocks_course`).

## Alternatives rejected
- **A fixed zone-type enum with per-type fields** — every new effect needs a
  code change; the tag bag keeps zones data-driven.
- **A separate system per hazard kind** — duplicates geometry + membership; one
  primitive serves all.
