# Zones — authored spatial regions

Zones are authored regions in a system that apply effects while the ship is
inside, or fire a trigger on entry. Decisions: ADR 0026 (the zone primitive),
ADR 0027 (course obstacle avoidance + routes). This is the implementation-facing
companion — data shape, pure-core contracts, test outlines, example content, and
a build order. Mirrors the sensor/contact model (ADR 0017) deliberately.

## The one idea

A zone is **geometry + a bag of effect tags**. Geometry says *where*; the tags
say *what happens*, and each consuming system reads only the tags it understands.
New effects are new tags, not new zone types. Membership is decided in real
space on `sim_tick` (the orrery's distortion never enters), exactly like sensor
detection.

## Data — `ZoneData` (`src/data/zone_data.gd`, authored `.tres`, by id)

```gdscript
class_name ZoneData
extends Resource

enum Shape { CIRCLE, BAND, POLYGON }
# Display/affordance channel only (non-colour, ADR 0012):
enum Category { HAZARD, FIELD, NOGO, FACILITY, TRIGGER }

@export var id: String = ""
@export var name_key: String = ""
@export var category: Category = Category.FIELD
@export var shape: Shape = Shape.CIRCLE

# Anchoring (ADR 0018): "" = free (absolute); else positioned at the body.
@export var anchor_body_id: String = ""
@export var center: Vector2 = Vector2.ZERO     # free CIRCLE/BAND centre (wu)
@export var radius: float = 0.0                # CIRCLE / BAND outer (wu)
@export var inner_radius: float = 0.0          # BAND inner (wu)
@export var points: PackedVector2Array = []    # POLYGON, wu (relative if anchored)

# Generic effect bag — consuming systems read recognised keys (ADR 0026).
@export var effects: Dictionary = {}
@export var tint: Color = Color(0.6, 0.6, 0.7) # secondary channel only (ADR 0012)
```

**Recognised effect keys** (author freely; honoured as each system lands):

| key | value | read by | status |
|-----|-------|---------|--------|
| `trigger_event` | event id (String) | event/mission system | **wired** (hook fires) |
| `once` | bool | trigger hook | **wired** |
| `blocks_course` | `"nogo"` \| `"hazard"` | course validation (ADR 0027) | this batch |
| `sensor_mult` | float (e.g. 0.5, 1.5) | Sensors (ADR 0017) | authored-inert |
| `rm_drain` | float per tick | fuel | authored-inert |
| `refuel` | bool | fuel/dock | authored-inert |

`SystemData` gains: `@export var zones: Array[ZoneData] = []`.

## Geometry — pure `core` (`src/core/zones.gd`, GUT-tested)

The pure functions take **resolved** geometry (centre/points already offset by the
anchor body); the controller resolves anchors before calling.

```gdscript
class_name Zones

# Is `point` inside the zone?
static func contains(shape: int, center: Vector2, radius: float,
        inner: float, points: PackedVector2Array, point: Vector2) -> bool

# Does segment a→b touch the zone? (course-leg validation, ADR 0027)
static func segment_intersects(shape: int, center: Vector2, radius: float,
        inner: float, points: PackedVector2Array, a: Vector2, b: Vector2) -> bool
```

- CIRCLE: `contains` = `center.distance_to(point) <= radius`;
  `segment_intersects` = point-to-segment distance from `center` ≤ `radius`.
- BAND: `contains` = `inner <= d <= radius`; `segment_intersects` = the segment
  reaches the annulus (min dist to centre ≤ `radius` and not entirely inside
  `inner`).
- POLYGON: `Geometry2D.is_point_in_polygon`; segment via `Geometry2D`
  segment/polygon intersection (or seg-vs-edge tests).

**Test outline:** inside / outside / on each boundary (circle, band inner+outer,
polygon edge & vertex); degenerate radius/empty polygon; `segment_intersects` for
a leg that only clips the zone mid-span, a leg fully inside, a leg fully outside,
and endpoints-on-boundary.

## Runtime — `ZoneController` (`src/flight/`, mirrors `SensorController`)

- On `EventBus.sim_tick`: resolve anchored centres/points from the loaded system,
  compute the ship's current zone set via `Zones.contains`, diff vs last tick →
  `EventBus.zone_entered(zone_id)` / `zone_exited(zone_id)`.
- On enter, if the zone has `trigger_event`: emit
  `EventBus.zone_trigger_fired(zone_id, event_id)`; if `once`, record it in
  `GameState` so it doesn't re-fire (saved, ADR 0008).
- Reset membership + (non-fired) state on `system_changed` (ADR 0024).

`EventBus` additions: `zone_entered(zone_id)`, `zone_exited(zone_id)`,
`zone_trigger_fired(zone_id, event_id)`.

## Rendering

Zones draw on the nav views beneath bodies/contacts (ADR 0026): true shapes on
the tactical scope; warped on the orrery (project polygon vertices / circle
boundary samples through `OrreryProjection`). Outline + category label/shape now
(non-colour, ADR 0012); the real visual pass comes later.

## Course interaction (ADR 0027)

`current_order` gains ordered `waypoints: Array[Vector2]`. Course validation runs
each leg through `Zones.segment_intersects` against zones with `blocks_course`:
`nogo` → reject the Lay In (`order_rejected`); `hazard` → warn but allow. Plot
around a no-go by dropping waypoints (`nav_point_selected`) until every leg is
clear. ETA/RM sum over legs; `FlightController` flies the legs in order.

## Example zones (author into the test systems)

Add to **Calder Reach** (exercises every shape/category):

| id | name key | category | shape | anchor | geometry | effects |
|----|----------|----------|-------|--------|----------|---------|
| `calder_corona` | `ZONE_CALDER_CORONA` | NOGO | CIRCLE | `calder` | r ≈ 0.3 AU | `blocks_course:"nogo"` |
| `bastion_belt` | `ZONE_BASTION_BELT` | HAZARD | BAND | `bastion` | inner 0.3 / outer 0.6 AU | `blocks_course:"hazard"`, `sensor_mult:0.6` |
| `veil_cloud` | `ZONE_VEIL_CLOUD` | FIELD | POLYGON | — | ~8 AU, hand-shaped | `sensor_mult:0.5` |
| `meridian_net` | `ZONE_MERIDIAN_NET` | FACILITY | CIRCLE | `meridian` | r ≈ 0.6 AU | `sensor_mult:1.5` |
| `drift_signal` | `ZONE_DRIFT_SIGNAL` | TRIGGER | CIRCLE | — | near Drift (~19 AU), r ≈ 0.4 AU | `trigger_event:"ev_drift_signal"`, `once:true` |

Add `ZONE_*` name keys to `localization/strings.csv` (ADR 0010). Anchored
geometry is relative to the body (`world = body.position + offset`).

## Build order

1. `ZoneData` type + `SystemData.zones`; author the Calder example zones + strings.
2. `Zones.contains` (all shapes) + GUT tests.
3. `ZoneController` on `sim_tick`; `zone_entered`/`zone_exited`; the
   `trigger_event` hook + `zone_trigger_fired`; `GameState` fired-trigger set
   (saved) + reset on system change.
4. Render zones on the tactical scope (true) and orrery (warped), beneath
   bodies; category as a non-colour channel.
5. `Zones.segment_intersects` + tests; `current_order.waypoints`; multi-leg
   `FlightController`; course validation reads `blocks_course` (nogo reject /
   hazard warn); Helm waypoint compose + route preview (ADR 0027).
6. Feel pass; DEVLOG; confirm ADRs 0026/0027.

Keep pure logic in `core` with green GUT tests before the nodes are called done.
