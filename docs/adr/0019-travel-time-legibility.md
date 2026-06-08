# ADR 0019 — Travel-time legibility on the nav views

**Status:** accepted · **Date:** 2026-06-06
**Builds on:** ADR 0016 (orrery Nav Plot), ADR 0017 (sensors / tactical scope),
ADR 0015 (travel pipeline), ADR 0004 (discrete clock).

## Context
The orrery (ADR 0016) log-compresses radius for legibility, which deliberately
strips travel-time information out of the geometry: equal screen distance no
longer means equal time, so the captain gets no sense of how long a leg takes
just by looking. On a schematic chart, magnitude must be **labelled, not read**
(every transit map works this way). Since "time is a resource" is a core pillar,
time deserves to be the chart's primary annotation.

## Decision
Make travel time explicit on both nav views, **burn-aware** (everything
recomputes when the Helm burn selector changes — Economy / Standard / Hard).

**Orrery (labels, not geometry):**
- **Per-body ETA badges** — each charted body shows its time-to-reach at the
  selected burn, e.g. `Rubicon · 2h 9m`, using `FlightMath.eta_ticks(dist, burn)`
  formatted through the calendar helper (`tr()` + duration format, ADR 0010).
- **Time-pip course line** — the plotted course line is graduated with a pip per
  fixed time unit and tagged with its ETA, so leg length reads as *duration*.

**Tactical scope (true scale, ship-centred — ADR 0017):**
- **Isochrone rings** at fixed durations for the selected burn (e.g. 15m / 30m /
  1h / 2h), drawn as clean concentric circles alongside the sensor circle. The
  captain reads "how long to anything" by which ring it falls in — the scope is
  the reach/planning instrument.

**Why isochrones live on the scope, not the orrery:** a ship-centred time-circle
projected onto the star-centred orrery would *warp* exactly like the sensor
bubble (ADR 0017). On the true-scale, ship-centred scope it stays a circle. So
the orrery gets time *labels*; the scope gets time *rings*.

**New pure helper** (`FlightMath`, the inverse of `eta_ticks`):

```gdscript
# Distance (wu) reachable in `ticks` at a burn — places isochrone rings.
static func reach_wu(burn: int, ticks: int) -> float:
    return speed_wu_per_tick(burn) * float(ticks)
```

## Why
Restores the lost sense of time without abandoning the orrery: the map stays
legible, time is one glance away on both views, and the burn choice visibly
changes ETA and reach — turning burn intensity into a felt decision.

## Consequences
- `FlightMath.reach_wu` added (pure, GUT-tested); ETA badges reuse `eta_ticks`.
- Orrery draws badges + a graduated course line; the scope draws isochrone rings.
- A burn-selection change must notify the views to recompute (reuse the Helm's
  burn signal on `EventBus`, or add one).
- All time text via `tr()` + the duration format; rings/badges carry a
  label, not colour alone (ADR 0012).

## Alternatives rejected
- **Time-based orrery projection** (compress by ETA instead of distance) — the
  layout would re-flow whenever the ship moves or the burn changes, an unstable
  map you can't build a mental model of. Keep the layout stable (distance),
  annotate the variable (time).
- **No annotation, rely on the Course Order panel's ETA** — the status quo that
  prompted this; gives no at-a-glance, whole-system sense of time.
