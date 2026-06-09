# Navigation model — orrery + sensors

How the Helm Nav Plot represents a star system and folds in sensor range.
Decisions: ADR 0016 (orrery), ADR 0017 (sensors). This doc is the
implementation-facing companion — function contracts, parameters, test outlines,
and a suggested build order for the α0.2 navigation slice.

## The one idea

**Presentation scale ≠ simulation scale.** The simulation keeps realistically
scaled coordinates (Verdant 1 AU … Tethys 40 AU; `Travel.WU_PER_AU = 1000`);
fuel and ETA depend on them and never change. The Nav Plot is an *instrument*
that draws those real positions in whatever way is most legible. Two views:

- **Orrery (strategic):** the whole system on one screen. Distance log-compressed
  onto rings, bearing preserved. The default Helm view.
- **Tactical scope (local):** ship-centred, true scale. Sensor range is a clean
  circle here; contacts sit inside it.

Charted (gravimetric) bodies are always shown. Transient (non-gravimetric)
contacts appear only when inside sensor range — and the orrery shows them
**contacts-only** (the warped sensor boundary is not drawn; the scope shows the
real circle).

---

## Orrery projection (pure `core`)

`src/core/orrery_projection.gd` — no node deps, GUT-tested. The Nav Plot is a
thin renderer over this.

```gdscript
class_name OrreryProjection

# Tuning (authored constants, not logic):
#   center      : Vector2  screen-space hub (the star)
#   r_min       : float    real wu mapped to the inner ring (clamp below)
#   r_max       : float    real wu mapped to the outer ring (clamp above)
#   ring_inner  : float    inner ring radius, px
#   ring_outer  : float    outer ring radius, px

static func project(real_pos: Vector2, p: OrreryParams) -> Vector2:
    var r := real_pos.length()
    if r <= p.r_min:
        return p.center
    var t := (log(r) - log(p.r_min)) / (log(p.r_max) - log(p.r_min))
    var radius := lerpf(p.ring_inner, p.ring_outer, clampf(t, 0.0, 1.0))
    return p.center + real_pos.normalized() * radius
```

**Properties to hold (test outline):**

- `r == r_min` → `ring_inner`; `r == r_max` → `ring_outer`.
- Geometric mean of `r_min`,`r_max` → midway between the rings (log is linear in
  log-space).
- **Bearing preserved:** `project(pos).angle_to(center)` equals
  `pos.angle()` for any body (within epsilon).
- **Monotonic:** farther in real wu ⇒ farther on the chart.
- `r <= r_min` (incl. the star at 0) → `center` (no `log(0)`).
- `r > r_max` clamps to `ring_outer`.
- With the real anchors (1, 5.2, 9.5, 40 AU × 1000): all four land between the
  rings, ordered, none off-screen.

**Variant (optional toggle):** rank spacing — place bodies on evenly spaced
rings by sorted distance instead of log magnitude. Same signature, different
`t`. Maximally schematic; loses the "Tethys is *way* out" feel.

**Notes (refinements):**
- Project about the **system's star body**, not a hardcoded `(0,0)` — pass the
  star's real position as the hub origin (real positions are relative to it).
- The **ship** is projected with the same `project`. The **course line** samples
  the real path (ship→target) and projects each sample, so it renders as the
  gently-curved line ADR 0016 describes rather than a straight chord.

---

## Moons — parent-relative projection (ADR 0018)

A moon sits a hair off its planet in real wu, so a star-relative `project` would
stack it on the parent's ring. Instead, project the parent about the star, then
place the child in a **small local cluster** about the parent's projected point —
its real offset-from-parent, bearing preserved, compressed onto a small px band.

```gdscript
# p.moon_r_min / r_max : real wu offsets mapped to the local band
# p.moon_ring_inner / outer : local cluster radius, px (small, < the ring gap)
static func project_child(child_pos: Vector2, parent_pos: Vector2,
        parent_projected: Vector2, p: OrreryParams) -> Vector2:
    var offset := child_pos - parent_pos
    var d := offset.length()
    if d <= p.moon_r_min:
        return parent_projected
    var t := (log(d) - log(p.moon_r_min)) / (log(p.moon_r_max) - log(p.moon_r_min))
    var radius := lerpf(p.moon_ring_inner, p.moon_ring_outer, clampf(t, 0.0, 1.0))
    return parent_projected + offset.normalized() * radius
```

**Properties to hold:** bearing-**from-parent** preserved; child always at least
`moon_ring_inner` px from the parent (never overlaps it); monotonic in `d`;
`d <= moon_r_min` → the parent's projected point. The Nav Plot projects parents
first, then children off the parent's projected position.

---

## Sensors & contacts (pure `core` + state)

### Detection — pure `core`

`src/core/sensors.gd` — runs off `EventBus.sim_tick`; decided entirely in real
space, so the orrery's non-linearity never enters.

```gdscript
class_name Sensors

# Returns the entities whose real position is within `radius` of the ship.
static func contacts_in_range(
        ship_pos: Vector2, radius: float, entities: Array) -> Array:
    var found: Array = []
    for e in entities:
        if ship_pos.distance_to(e.position) <= radius:
            found.append(e)
    return found
```

**Test outline:** inside / outside / exactly on the boundary; empty list; several
mixed; `radius == 0`; ship moving so a contact enters then leaves across ticks.

**Refinement — segment check (avoid warp tunnelling).** At Hard burn (2c) the
ship can cover more than the sensor radius in one tick and skip a small contact
between point samples. So detection per tick tests the **segment travelled**
(last pos → new pos) as a capsule, not just the endpoint:

```gdscript
static func contacts_in_segment(
        from: Vector2, to: Vector2, radius: float, entities: Array) -> Array:
    var found: Array = []
    for e in entities:
        if _point_to_segment_distance(e.position, from, to) <= radius:
            found.append(e)
    return found
```

The detection node calls `contacts_in_segment(prev_ship_pos, ship_pos, radius, …)`
each tick. `contacts_in_range` stays for the stationary/point case + as the unit
under test for the basic boundary properties. **Test outline:** a contact only
crossed mid-segment is caught; degenerate `from == to` matches the point check;
endpoints and the perpendicular-distance case.

### Detection tiers

`UNDETECTED → BLIP (in range, unidentified) → IDENTIFIED (scanned)`. In-range is
detection (automatic); identify is a scan action (later). Forward-compatible with
the design's contact → identified → surveyed → explored ladder.

### Wiring

- A system-side node ticks on `EventBus.sim_tick`, calls `contacts_in_range`
  against the system's transient entities, and diffs against last tick:
  newly in → `EventBus.contact_detected(id)`; dropped → `contact_lost(id)`.
- Detection/identify state per contact lives in `GameState` (saved, ADR 0008).
- The Nav Plot listens and adds/removes transient icons; it never computes
  detection itself.

### Data

- `ContactData` (`src/data/`, authored `.tres`, by id via TypeRegistry):
  `id`, `kind` (ship/derelict/anomaly/signal/probe/debris), `position`,
  display name key, glyph/shape, default tier.
- `SystemData` gains a list of transient entities (alongside its charted bodies).
- Sensor radius: a ship/hull base stat now; widened later by crew skill / refit.

---

## The two views on the Helm

- **Orrery** is the default Nav Plot: charted bodies on log rings, transient
  contacts winking in/out as distinct shapes, course line between projected
  points. (ADR 0016)
- **Tactical scope** is a ship-centred true-scale view (inset or toggle): sensor
  range as a real circle, contacts inside it, no radial distortion. Built with
  the orrery in this slice. (ADR 0017)

Both honour ADR 0012 — contact/charted state is carried by shape + label, not
colour alone.

---

## Travel-time legibility (ADR 0019)

The orrery's log compression strips *time* out of the geometry — equal screen
distance ≠ equal travel time. Fix: on a schematic, **label** magnitude, don't
read it. Everything here is **burn-aware** (recompute on a burn-selector change).

**Orrery — time labelled:**
- **Per-body ETA badges:** each charted body shows time-to-reach at the selected
  burn (`FlightMath.eta_ticks(dist, burn)` → duration via the calendar helper).
- **Time-pip course line:** the plotted line is graduated with a pip per fixed
  time unit and tagged with its ETA, so leg length reads as duration.

**Tactical scope — time as rings:** concentric **isochrone rings** at fixed
durations for the selected burn, drawn as clean circles next to the sensor
circle. Read "how long to anything" by which ring it falls in. Isochrones live
*here*, not on the orrery: a ship-centred time-circle would warp on the
star-centred chart (same reason the sensor boundary isn't drawn on the orrery);
on the true-scale scope it stays a circle.

**New pure helper** (`FlightMath`, inverse of `eta_ticks`) for placing rings:

```gdscript
# Distance (wu) reachable in `ticks` at a burn.
static func reach_wu(burn: int, ticks: int) -> float:
    return speed_wu_per_tick(burn) * float(ticks)
```

**Test outline:** `reach_wu(burn, eta_ticks(d, burn))` ≈ `d` (round-trips within
one tick's distance); Hard reaches farther than Standard than Economy for the
same ticks; `ticks == 0` → 0.

Rejected: a time-based orrery projection (compress by ETA, not distance) — the
map would re-flow as the ship moves or the burn changes; keep the layout stable
(distance), annotate the variable (time).

---

## Build order

The canonical α0.2 build order lives in `docs/ALPHA-0.2-SPEC.md` (it covers the
whole milestone — moons and the focus-a-body sub-view as well as the navigation
slice below). The nav-specific steps that doc folds in, in order:

1. `OrreryProjection` core + tests; swap the Nav Plot layout to the orrery
   (display only; orbit rings → projected radii) — the whole system on one screen.
2. `ContactData` type + a couple of transient entities in `SystemData`.
3. `Sensors` core + tests; tick-driven detection node; `EventBus` contact
   signals; `GameState` detected/tier state (saved).
4. Orrery renders transient contacts (shape icons) winking in/out.
5. Tactical scope view on the Helm (true scale, sensor circle + contacts).
6. **Travel-time legibility (ADR 0019):** `FlightMath.reach_wu` + tests; per-body
   ETA badges + time-pip course line on the orrery; burn-aware isochrone rings on
   the tactical scope; recompute on burn change.
7. Feel pass (log base, ring band, sensor radius, isochrone steps), DEVLOG entry,
   confirm ADRs.

Keep pure logic in `core` with green GUT tests before the nodes are called done.

---

## Nav iteration 2 — tooling, a second system, the Target panel

A navigation-polish batch (ADR 0024, ADR 0025 + the content below). Goal: stress
the nav systems against a dense system, get fast dev iteration, and make the Helm
read like a nav console.

**Build order:**

1. **Runtime system loading (ADR 0024):** `system_change_requested` /
   `system_changed` signals + the load handler (validate id, reset ship to
   `ship_start`, clear course, `DEEP_SPACE`, reset contact discovery, rebuild
   orrery/tactical/inset). Add the views' rebuild path. GUT the state reset.
2. **Debug command console (ADR 0024):** `toggle_console` action (backtick); a
   `DebugConsole` overlay + `DebugActions` helper; commands `help`, `systems`,
   `system <id>`, `refuel`, `tp <body_id>|<x> <y>`.
3. **Calder Reach (content, below):** author the second `SystemData` `.tres` +
   strings. Switch to it via `system calder` and stress the orrery, moon insets,
   isochrones, sensor sweep.
4. **Target Information panel (ADR 0025):** replace the Helm Order Log with the
   burn-aware Target Info panel; move ship-voice acknowledgments to a transient
   Flight Status line.
5. Feel pass against Calder Reach (orrery density, moon clustering, contact
   legibility); DEVLOG; confirm ADRs.

### Calder Reach — the stress-test system (content)

A frontier system, kept in the game and used to stress nav. `WU_PER_AU = 1000`;
`position = round(AU × 1000 × Vector2(cos θ, sin θ))` with θ from the bearing.
1 star + 8 planets + 6 moons + 2 stations + 7 contacts. Ship start ≈ 1 AU.

**Charted bodies** (`SystemData.bodies`, `BodyData`):

| id | name key | kind | parent | AU | bearing | dock/refuel |
|----|----------|------|--------|----|---------|-------------|
| `calder` | `BODY_CALDER` | STAR | — | 0 | — | — |
| `ember` | `BODY_EMBER` | PLANET | — | 0.5 | 20° | — |
| `halcyon` | `BODY_HALCYON` | PLANET | — | 1.1 | 200° | — |
| `toll` | `BODY_TOLL` | MOON | `halcyon` | +0.03 | 40° | — |
| `cradle` | `BODY_CRADLE` | PLANET | — | 1.8 | 110° | — |
| `meridian` | `BODY_MERIDIAN` | STATION | — | 2.4 | 320° | dock + refuel |
| `bastion` | `BODY_BASTION` | PLANET (gas giant) | — | 6.0 | 60° | — |
| `hearth` | `BODY_HEARTH` | MOON | `bastion` | +0.04 | 0° | — |
| `pallid` | `BODY_PALLID` | MOON | `bastion` | +0.06 | 150° | — |
| `vex` | `BODY_VEX` | MOON | `bastion` | +0.05 | 250° | — |
| `sable` | `BODY_SABLE` | PLANET | — | 11 | 250° | — |
| `wane` | `BODY_WANE` | MOON | `sable` | +0.05 | 90° | — |
| `drift` | `BODY_DRIFT` | PLANET | — | 19 | 140° | — |
| `calyx` | `BODY_CALYX` | PLANET | — | 30 | 30° | — |
| `mote` | `BODY_MOTE` | MOON | `calyx` | +0.04 | 200° | — |
| `greaves` | `BODY_GREAVES` | STATION | — | 38 | 300° | dock + refuel |
| `thule` | `BODY_THULE` | PLANET | — | 45 | 160° | — |

Moons: `position = parent.position + round(AU_offset × 1000 × Vector2(cos θ,
sin θ))` (offsets above are small — 30–60 wu — to exercise parent-relative
projection and inset, ADR 0018/0022). `radius`/`tint` per kind; tint is a
secondary channel only (ADR 0012).

**Transient contacts** (`SystemData.contacts`, `ContactData`):

| id | name key | kind | AU | bearing |
|----|----------|------|----|---------|
| `solane` | `CONTACT_SOLANE` | DERELICT | 3.0 | 80° |
| `drift9` | `CONTACT_DRIFT9` | PROBE | 1.5 | 190° |
| `hauler` | `CONTACT_HAULER` | SHIP | 5.0 | 40° |
| `echovex` | `CONTACT_ECHOVEX` | SIGNAL | 6.2 | 62° |
| `hollow` | `CONTACT_HOLLOW` | SIGNAL | 7.0 | 210° |
| `pale` | `CONTACT_PALE` | ANOMALY | 12 | 130° |
| `cinderfield` | `CONTACT_CINDERFIELD` | DEBRIS | 20 | 150° |

Spread so some sit inside the start sensor range (≈3 AU) and some only reveal as
you fly the sweep. Add a `SYSTEM_CALDER` system name key and a display name for
each id above to `localization/strings.csv` (ADR 0010).

