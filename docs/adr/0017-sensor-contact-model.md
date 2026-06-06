# ADR 0017 — Sensor & contact model

**Status:** accepted · **Date:** 2026-06-06
**Builds on:** ADR 0016 (orrery Nav Plot), ADR 0004 (sim_tick), ADR 0003
(EventBus), ADR 0012 (accessibility), ADR 0002 (authored data by id).

## Context
Not everything in a system is known on arrival. Massive bodies announce
themselves by gravity; small things don't. We want sensor range to matter — and
to fold it into the orrery without distorting the chart (sensor range is a
real-space circle around the *ship*; the orrery is a non-linear chart centred on
the *star*, so that circle warps).

## Decision
**Two classes of contact:**

- **Charted (gravimetric)** — stars, planets, gas giants, stations. Positions
  known on arrival; **always shown** on the orrery. (These are today's
  `SystemData` bodies.)
- **Transient (non-gravimetric)** — ships, derelicts, anomalies, signals,
  probes, debris. Detected **only within sensor range**; they wink in and out.

**Detection is decided in real space, in pure `core`, on `sim_tick`.**
`Sensors.contacts_in_range(ship_pos, radius, entities)` returns what's currently
in range. It never touches display scale — which is exactly why the orrery's
non-linearity is a non-issue: the chart *reflects* detection, it never *computes*
it. Detection tiers reuse the survey model: `UNDETECTED → BLIP (in range,
unidentified) → IDENTIFIED (scanned)`, forward-compatible with the design's
contact→identified→surveyed→explored ladder.

**Representation (chosen: contacts-only on the orrery):**
- Charted bodies always on their rings.
- Transient contacts appear as distinct **shape** icons (a blip/diamond glyph —
  shape, not colour alone, per ADR 0012) that wink in/out as coverage changes.
- The sensor radius itself is **not drawn on the orrery** (it would warp). Reach
  is *felt* through contacts appearing, and *seen* literally on the tactical
  scope.
- A **true-scale tactical scope** (ship-centred) is built alongside the orrery:
  there the sensor range is a clean circle with contacts inside it. Strategic
  orrery + tactical scope = chart plotter + radar.

**Sensor radius** is a ship stat — a base value now; later widened by a crew
officer's skill at a console or a refit (ties sensors into the Grow pillar).

**Data & state:** transient entities are authored as `ContactData` `.tres`
(by id, via TypeRegistry) per system for now (procgen later). Their runtime
detection state (detected set + tier per contact) lives in `GameState` and is
saved (ADR 0008). `EventBus` gains `contact_detected(id)`,
`contact_lost(id)`, `contact_promoted(id, tier)`.

See `docs/navigation.md` for the detection function contract and test outline.

## Why
Sensor range becomes a **decision**, not a stat: you move not only to reach
bodies but to *sweep coverage* over empty space and flush out signals,
derelicts, and anomalies the gravimetrics can't see — and better sensors widen
the sweep. Real-space detection keeps the simulation honest and sidesteps the
chart-distortion trap entirely.

## Consequences
- New pure `core` `Sensors` module + tests; runs off `sim_tick`.
- `EventBus` gains the three contact signals.
- New authored `ContactData` type; `SystemData` carries transient entities.
- `GameState` tracks detected contacts + tiers (serialized).
- New tactical-scope view hosted on the Helm console (built with the orrery).

## Alternatives rejected
- **Draw the warped sensor bubble on the orrery** — honest and can look great,
  but busier and more to build; cut for now (could return as an optional glow).
- **Treat all entities identically** — loses the gravimetric/sensor distinction
  that makes scanning and sweeping meaningful.
