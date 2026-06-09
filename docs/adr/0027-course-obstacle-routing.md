# ADR 0027 — Course obstacle avoidance + waypoint routes

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0015 (travel pipeline / `current_order`), ADR 0020 (empty-space
waypoints), ADR 0026 (zones), ADR 0014 (order lifecycle).

## Context
Courses today are a single straight leg (ship → target). With zones (ADR 0026),
some regions are obstacles: a stellar corona or restricted space you must not fly
through, and hazards (radiation, gas) you'd rather avoid. The captain needs to be
able to **plot around** them.

## Decision

**Two tiers of obstruction**, from a zone's `blocks_course` effect (ADR 0026):
- **`nogo`** (e.g. stellar corona, restricted space) — a course leg that crosses
  it is **rejected** (`order_rejected`, "Unable — obstruction in path").
- **`hazard`** (radiation, gas) — a crossing leg is **allowed but warned** (a
  Helm flag on compose / Target Info), captain's call.

**Manual waypoint routes.** `current_order` gains an ordered
`waypoints: Array[Vector2]` (intermediate points) before the final target. The
captain composes a route by clicking empty space to drop waypoints (reusing
`nav_point_selected`, ADR 0020); the course flies the legs in order, passing
through each waypoint without stopping, then arrives/holds at the final target.
ETA and reaction mass sum over the legs. Each leg is validated independently, so
you route around a no-go by laying waypoints to either side until every leg is
clear.

**Validation — pure `core`.** `Zones.segment_intersects(shape_params, a, b) ->
bool` per shape (circle/band: segment-to-centre distance vs radii; polygon:
`Geometry2D` segment-vs-polygon). `Travel`/course validation checks each leg
against blocking zones: any `nogo` crossing → reject; any `hazard` crossing →
warn flag. GUT-tested.

**Compose flow on the Helm.** Select target → if the direct leg hits a `nogo`,
the Lay In is blocked with the reason and the captain adds waypoints to route
around (each addition re-validates); `hazard` crossings show a warning but Lay In
stays enabled. The route persists in `current_order` (saved, ADR 0008).

**Deferred:** automatic pathfinding around obstacles (compute the detour for you)
— manual waypoints ship first; auto-route is a later convenience that can reuse
`segment_intersects`.

## Consequences
- `ShipState.current_order` gains `waypoints` (serialized); `FlightController`
  flies multi-leg routes (motion machine per leg, no stop between legs); ETA/RM
  sum over legs.
- `Zones.segment_intersects` added (pure, tested); course validation reads
  `blocks_course`.
- Helm: waypoint compose (add/clear), a route preview on the Nav Plot, and the
  no-go reject / hazard warn surfaced via existing `order_rejected` + a compose
  flag.
- No change to the order *lifecycle* (ADR 0014); a route is still one order.

## Alternatives rejected
- **Auto-pathfinding now** — much more to build and tune; manual waypoints give
  the capability first.
- **One straight leg only (ignore obstacles)** — the captain couldn't avoid a
  no-go at all.
- **Hard-block everything** — removes the captain's judgement on survivable
  hazards; the two-tier split keeps agency.
