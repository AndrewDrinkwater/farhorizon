# Landing & surface navigation

Land on and take off from planets, and move between surface sites. Decisions:
ADR 0029 (landable bodies / atmosphere / land & take-off), ADR 0030 (surface
locations + planetary navigation). Implementation-facing companion: data shapes,
pure-core contracts + test outlines, example content, build order.

## The model

The ship's situation gains a surface leg of the journey:

```
DEEP_SPACE → (course) → HOLDING (orbit) → Land(site|open) → LANDED
                                   ↑                              │
                                   └────────── Take Off ──────────┘
LANDED → Move(site) → LANDED   (planetary flight time, on the surface map)
```

Space-side navigation (orrery/scope) is unchanged; LANDED swaps the Nav Plot to a
**surface view** of the body. Everything is on the discrete clock; durations are
**modifiable stats** (base × factors), with atmosphere the first factor.

## Data

**`BodyData`** gains:
```gdscript
@export var landable: bool = false
@export var atmosphere_atm: float = 0.0   # surface pressure, Earth atmospheres
# @export var atmosphere_composition: ...  # DEFERRED — chemical make-up (ADR 0029)
@export var wild_touchdown: Vector2 = Vector2.ZERO  # generic Open Landing surface pos (su)
@export var surface_locations: Array[SurfaceLocationData] = []
```

**`SurfaceLocationData`** (`src/data/surface_location_data.gd`, by id):
```gdscript
class_name SurfaceLocationData
extends Resource
enum Kind { WILD, SITE, BASE, POI }   # all landable points now; BASE/POI gain behaviour later
@export var id: String = ""
@export var name_key: String = ""
@export var kind: Kind = Kind.SITE
@export var surface_position: Vector2 = Vector2.ZERO  # surface units (su)
```

**`ShipState`** gains: `surface_site_id: String`, `surface_speed_su_per_tick:
float`, and base land stats `base_descent_ticks: int`, `base_ascent_ticks: int`
(on the ship for now; move to `HullData` later, ADR 0029). `location` uses the new
`Travel.Location.LANDED`.

## Units (CONVENTIONS.md)
- **Atmosphere:** Earth atmospheres (`atm`), a float. 0 = vacuum.
- **Surface map:** surface units (`su`), a per-body local plane; distinct from
  world units (`wu`). Planetary flight time uses `su`.

## Pure core

**`LandingMath`** (`src/core/landing_math.gd`, GUT-tested):
```gdscript
# Tunable thresholds; class is derived, never stored.
enum AtmoClass { NONE, THIN, STANDARD, DENSE, CRUSHING }
static func atmosphere_class(atm: float) -> int
# Time multiplier from pressure: 1.0 at vacuum, grows with atm (tunable curve).
static func atmosphere_factor(atm: float) -> float
# Modifiable stat: base × product of factors → ticks.
static func modified_ticks(base: int, factors: Array[float]) -> int
```
*Test outline:* class thresholds at each boundary; `atmosphere_factor(0) == 1.0`
and monotonic increasing; `modified_ticks(base, [])` == base; product applied and
rounded; descent vs ascent both run through the same chain.

**`SurfaceMath`** (`src/core/surface_math.gd`, GUT-tested):
```gdscript
static func surface_ticks(from: Vector2, to: Vector2, speed_su_per_tick: float) -> int
```
*Test outline:* zero distance → 0; symmetric; scales with distance; speed 0 guarded.

## Orders & availability (ADR 0029/0030, extends ADR 0015)

| Order | Available when |
|-------|----------------|
| **Land** (site or Open Landing) | HOLDING at a `landable` body, not under way |
| **Take Off** | LANDED |
| **Move** (to a site) | LANDED and the body has another reachable site |

Land/Take Off/Move are timed transitions on the clock; `Travel.available` is the
single source of truth the Helm enables buttons from and the controller validates.

## UI

- **SurfaceView** (`src/world/surface_view.gd`): true-scale local map of the
  body's surface — sites/POIs (shape + label), ship position, a plotted surface
  course. Shown while LANDED; the shell swaps orrery ↔ surface on land/take-off.
- **Helm:** Land (with a site picker incl. Open Landing), Take Off, Move; Target
  Info adapts to surface context (site name, kind, planetary ETA). Acknowledgments
  via the transient Flight Status line (ADR 0025).
- New strings (`tr()`, ADR 0010): `HELM_LAND`, `HELM_TAKE_OFF`, `HELM_MOVE`,
  `HELM_OPEN_LANDING`, atmosphere class labels, surface readouts, voice lines
  (`VOICE_SHIP_LANDED`, `VOICE_SHIP_AIRBORNE`, `VOICE_SHIP_ARRIVED_SITE`).

## Example content

Make a few bodies landable (author into Calder Reach / Sol):

| body | landable | atmosphere_atm | sites |
|------|----------|----------------|-------|
| `halcyon` (Calder) | yes | 1.1 (Standard) | Open Landing + `halcyon_camp` (SITE) + `halcyon_dig` (POI) |
| `ember` (Calder) | yes | 0.2 (Thin) | Open Landing + `ember_vent` (POI) |
| `toll` (moon) | yes | 0.0 (vacuum) | Open Landing only |
| `bastion` (gas giant) | no | 30 | — (no surface) |
| `verdant` (Sol) | yes | 0.9 (Standard) | Open Landing + `verdant_outpost` (BASE) |

Surface positions in `su` on each body's local map; add `LOC_*` + `SURF_*`
strings.

## Build order

1. `BodyData` (landable, atmosphere_atm, wild_touchdown) + `SurfaceLocationData`
   + `ShipState` surface/land stats; author the example bodies/sites + strings.
2. `LandingMath` + `SurfaceMath` core + GUT tests.
3. `Travel.Location.LANDED` + `Travel.available` Land/Take Off/Move; Helm orders;
   descent/ascent + surface-move timed transitions in the flight controller.
4. `SurfaceView` + shell orrery↔surface swap; surface Target Info; site picker.
5. Persistence (LANDED + surface_site_id saved; in-progress phase recomputes).
6. Feel pass (atmosphere curve, base land ticks, surface speed); DEVLOG; confirm
   ADRs 0029/0030.

Keep pure logic in `core` with green GUT tests before the nodes are called done.
