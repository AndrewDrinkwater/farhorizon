# ADR 0030 — Surface locations + planetary navigation

**Status:** accepted · **Date:** 2026-06-09
**Builds on:** ADR 0029 (landable bodies / LANDED), ADR 0015 (travel pipeline),
ADR 0016 (the orrery, as the space-side analog), ADR 0008 (save).

## Context
A landable body isn't a single point — you touch down somewhere, and a body can
hold named sites that become bases / POIs later. Once on the surface the ship
moves between those sites, taking a planetary flight time. This is a second,
local navigation context layered under the system.

## Decision

### Surface locations (`SurfaceLocationData`, authored `.tres`, by id)
On `BodyData.surface_locations: Array[SurfaceLocationData]`:
- `id`, `name_key`.
- `kind`: `WILD` / `SITE` / `BASE` / `POI` (display + future gameplay; all are
  landable points now). Bases/POIs gain behaviour later (the design's
  wreck/digsite missions, forward operating bases).
- `surface_position: Vector2` — coordinates on the body's local **surface map**
  (surface units, `su`). Drives planetary flight time.

### The generic touchdown ("Open Landing")
Any `landable` body always offers a generic **Open Landing** — touch down on open
ground without a known site (its surface position defaults to the body's
`wild_touchdown`, or map centre). It's the `WILD` kind, implicit, always
available; named sites are additional, specific destinations. (Rename freely;
"Open Landing" / "Wilderness" are candidates.)

### Surface navigation (planetary flight time)
When `LANDED`, the active nav context is the body's surface. The ship has a
`surface_site_id`. **Move** between sites is a timed transit on the discrete
clock: `surface_ticks = round(distance_su / surface_speed_su_per_tick)` —
distance between the two sites' `surface_position`s, at a ship surface-speed stat
(modifiable later, ADR 0029 pattern). Pure `core` `SurfaceMath.surface_ticks` +
distance, GUT-tested.

Orders (ADR 0014): **Move** (to another site, when LANDED with somewhere to go),
alongside Take Off (ADR 0029). `Travel.available` extends for the LANDED context.

### Dedicated surface view
When LANDED the Nav Plot becomes a **`SurfaceView`** — a true-scale local map of
the body's surface showing its sites/POIs (shape + label, not colour alone, ADR
0012) and the ship's surface position; click a site to plot a Move. Take Off
returns to the system orrery. The surface view is the surface-side analog of the
orrery (ADR 0016); it reuses the terminal theme + selection signals.

### Persistence
`surface_site_id` saves with `location = LANDED` (ADR 0008); an in-progress
surface move recomputes on load. Sites are authored content.

## Consequences
- New `SurfaceLocationData` type; `BodyData.surface_locations` (+ `wild_touchdown`).
- `ShipState`: `surface_site_id` + `surface_speed_su_per_tick`.
- `SurfaceMath` core + tests; `Travel.available` gains Move (LANDED).
- New `SurfaceView`; the Helm hosts Land / Move / Take Off and a surface Target
  Info; the shell swaps orrery ↔ surface on land/take-off.
- Seeds bases/POIs, surface zones, and shuttle ops (Frigate+ land a shuttle, not
  the ship) later — those are deferred; the Scout lands directly.

## Alternatives rejected
- **Abstract hop times** (no surface positions) — simpler, but loses the spatial
  surface map the captain asked for and the reuse of the distance/time model.
- **Reuse the focus inset for the surface** — too small for a real site map;
  surface navigation deserves the main view.
- **One site per body** — can't move between POIs, which is the point.
