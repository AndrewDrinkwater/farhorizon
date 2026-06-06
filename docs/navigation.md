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

## Suggested build order (α0.2 navigation slice)

1. `OrreryProjection` core + tests.
2. Swap the Nav Plot layout to the orrery (display only; orbit rings → projected
   radii). Confirm the whole system reads on one screen.
3. `ContactData` type + author a couple of transient entities into `SystemData`.
4. `Sensors` core + tests; tick-driven detection node; `EventBus` contact
   signals; `GameState` detected/tier state (saved).
5. Orrery renders transient contacts (shape icons) winking in/out.
6. Tactical scope view on the Helm (true scale, sensor circle + contacts).
7. Feel pass (log base, ring band, sensor radius), DEVLOG entry, confirm ADRs.

Keep pure logic in `core` with green GUT tests before the nodes are called done.
