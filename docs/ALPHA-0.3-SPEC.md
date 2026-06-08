# α0.3 — "Navigation III: Targets & the Scan"

**Status:** in progress · **Goal:** the captain can plot a course to anything on
the Nav Plot — a charted body (as before), a **sensor contact**, or an
**arbitrary point in empty space** — and **scan** a contact to identify it.

α0.2 made the Nav Plot legible (orrery, moons, sensors, tactical scope,
travel-time). α0.3 makes it *actionable beyond bodies*: navigation gains
destinations that aren't gravimetric, and the contact ladder gets its first
player-driven rung (`BLIP → IDENTIFIED`).

Decisions: **ADR 0020** (generalized nav targets + scan), **ADR 0021** (orrery
scale modes), **ADR 0022** (focus-a-body moon inset). Builds on ADR 0014/0015
(orders/travel), ADR 0017 (sensors), ADR 0016/0018 (orrery + moons).

---

## Definition of done

α0.3 is complete when **all** of these are true:

1. **Course to a contact.** A detected contact (anomaly/derelict/signal/…) can be
   selected and a course laid in + flown to it, with the same preview (distance /
   ETA / RM) and fuel gating as a body.
2. **Course to empty space.** Clicking empty space on either nav view drops a
   **waypoint**; a course can be laid in + flown to it. The orrery unprojects the
   click through the inverse log map; the tactical scope through its true scale.
3. **Drift on arrival.** Reaching a contact or a waypoint stops the ship on the
   point, drops the course, and leaves it `IDLE`/drifting in deep space (a body
   still settles into its holding orbit, unchanged).
4. **Scan identifies.** With a contact in sensor range, a **Scan** order promotes
   it `BLIP → IDENTIFIED`; the identity (authored name) becomes visible and the
   state is **saved**. Scan is refused out of range or when already identified.
5. **Identification reads.** An unscanned contact shows as an "unknown" shape;
   a scanned one shows its name + a distinct (filled) shape — shape + label, never
   colour alone (ADR 0012).
6. **Green tests.** GUT covers the new `core`: `OrreryProjection.unproject`
   (round-trips `project`), `Travel.available` scan/selection rules, and the
   `FlightController` point/contact courses + scan (in/out of range, tier gating).
7. **Orrery scale toggle (ADR 0021).** A Helm control flips the orrery between
   schematic (log) and true-scale (linear) — same star-centred, bearing-exact
   chart; real distances/fuel/ETA unchanged. Both projection modes GUT-tested.
8. **Moon focus + rings (ADR 0022).** The orrery shows which planets have moons
   (a satellite affordance) and draws moon orbit rings; focusing a moon-bearing
   planet opens an inset showing its moons spread out, each targetable/flyable.

---

## In scope

- **Generalized course** — `current_order.dest: Vector2`; `target_id` may be a
  body id, contact id, or `""`. `FlightController` resolves destination + arrival
  per kind (body → holding ring; contact/point → drift).
- **`nav_point_selected`** signal; empty-click waypoint on both views.
- **`OrreryProjection.unproject`** (pure, tested) — inverse of `project`.
- **Scan order** — `{type:"scan", contact_id}`; range + tier validation; promotes
  to `IDENTIFIED`; `contact_promoted` + saved state; Helm **Scan** button gated by
  `Travel.available`.
- **`Travel.available`** gains `scan` + `has_nav_selection`.
- **Contact identity rendering** — BLIP "unknown" hollow shape → IDENTIFIED named
  filled shape, on orrery + scope.
- **Orrery scale modes (ADR 0021)** — `OrreryParams.mode {LOG, LINEAR}`;
  `OrreryProjection` branches (pure, tested); `nav_scale_changed`; Helm segmented
  scale control.
- **Moon focus + rings (ADR 0022)** — moon orbit rings on the orrery; a "has
  moons" affordance; `nav_focus_requested`/`nav_focus_closed`; a `MoonInsetView`
  picture-in-picture with a pure local-satellite layout; Helm Focus action +
  re-click trigger.

## Out of scope (deferred)

- Station-keeping / "hold at a point" location state (drift-on-arrival for now).
- Survey/explore rungs beyond IDENTIFIED; scan giving more than the name.
- Editing/naming saved waypoints; multiple queued waypoints (one course at a time).
- Procedural contacts; crew/skill affecting scan.
- Focus-a-body moon sub-view (still deferred from α0.2).

---

## Suggested build order

Each step ends runnable and, where it's `core`, tested.

1. **`OrreryProjection.unproject` core + tests** — inverse log map; round-trips
   `project` for points within the ring band.
2. **Generalized course** — `dest` in the order; `FlightController` resolves
   body/contact/point, drifts on non-body arrival; engage fuel-gates on `dest`.
   Tests: point course, contact course, resume-after-load.
3. **Scan order + `Travel.available` scan rule** — controller validation + tier
   promotion; `contact_promoted`. Tests: in/out of range, already-identified.
4. **Selection plumbing** — `nav_point_selected`; both views pick
   body/contact/empty; Helm selection model (body/contact/point) + preview.
5. **Helm Scan button** — gated by availability; emits the scan order; ack logged.
6. **Identity rendering** — BLIP-unknown vs IDENTIFIED-named on orrery + scope;
   selected-waypoint marker.
7. **Moon orbit rings** — orrery ring pass draws faint rings about each parent's
   projected point (skipped when they collapse in true scale).
8. **Orrery scale toggle (ADR 0021)** — `OrreryParams.mode` + `OrreryProjection`
   LINEAR branches + tests; `nav_scale_changed`; Helm scale control.
9. **Has-moons affordance** — satellite halo + pips; `_moons_by_parent`.
10. **Focus inset (ADR 0022)** — `nav_focus_requested`; Helm Focus button +
    re-click; `MoonInsetView` local layout + moon rings + clickable moons + close.
11. **Feel pass** — waypoint marker, scan range cue, contact glyphs, scale
    readability, satellite affordance, inset size. DEVLOG; confirm ADR 0020/0021/0022.

---

## Tuning knobs (placeholders, expect to change by feel)

- Waypoint/crosshair marker size; contact unknown-vs-identified glyphs.
- Whether scan needs the ship stopped (currently: in range, not under way).
- Arrival threshold for drift-stop on a point/contact.
