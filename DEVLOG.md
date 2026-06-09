# Far Horizon — DEVLOG

Session-by-session build history. Newest entries at the top.

---

## 2026-06-09 — Fix: laid-in solid-line bug; +4 AU range ring

- **Bug:** after engage → select new target → belay, the new (uncommitted) plot
  drew solid. The views inferred "laid in" from `current_order` existing, but a
  belayed course leaves the *old* course in `current_order` while the plot shows
  the *new* target. Now the Helm owns the truth (`_plot_laid_in`, set on Lay In,
  cleared on any re-plot/edit) and broadcasts it on `nav_route_changed(route,
  laid_in)`; the views style solid/dashed from that flag, not from `current_order`.
  Replaced the `_invalidate_laid_in`-drops-current_order hack.
- **Feature:** added a 4 AU range ring to the tactical distance-ring view.

172 GUT tests green; boots clean.

---

## 2026-06-09 — Build: course RM-over-route, plotted/laid-in colour, context toggle

Three nav refinements from in-engine feedback. **170 GUT tests green; boots clean.**

- **Route-aware RM/ETA:** the Helm readouts + Target Info summed only the direct
  ship→target leg (ignoring waypoints) while Engage fuel-gated on the full route —
  so dragging a detour didn't move the cost yet "insufficient RM" fired with no
  figure shown. Now over the whole route (`_plotted_distance`), with the ⚠ when it
  exceeds the tank.
- **Plotted vs laid-in style:** a merely-plotted course draws **dashed**, a laid-in
  one **solid** (obstruction red/amber still applies to either) — clearly distinct.
  Editing a laid-in course (new target/point or a dragged waypoint) un-commits it
  back to dashed until re-laid-in. (ADR 0028)
- **Context toggle (ADR 0021 amended):** the Schematic/True-scale switch is inert
  in the scope (always true-scale), so the one Helm toggle is retargeted by the
  active view (`nav_view_changed`): orrery → scale; scope → ring mode, swapping the
  concentric rings between **ETA** isochrones and **flat distance** (AU range
  rings). New `nav_view_changed` / `nav_ring_mode_changed`; `TacticalView.RingMode`.

---

## 2026-06-09 — Build: direct course plotting + drag-to-route (ADR 0028)

Reworked course plotting per captain feedback (ADR 0028, supersedes the
empty-click/Lay-In-reject bits of ADR 0020/0027). **166 GUT tests green; boots clean.**

- **Plot on select:** selecting a target plots a direct course immediately; Lay In
  + Engage stay (both re-issue from the live plot, so what flies is the plot).
- **No-go paints red, blocks Engage (not Lay In):** the course colours by
  `Zones.route_block` — red (no-go) / amber (hazard) / accent (clear).
  `_set_course` no longer rejects; `_engage` does (and `Travel.available` moves
  `route_nogo` from `lay_in` → `engage`).
- **Grab & drag:** pressing the plotted line inserts a waypoint on the nearest leg
  and drags it; pressing a handle drags it; release commits. The view maps
  screen↔real (orrery inverse projection + zoom/pan; scope true-scale) and pushes
  waypoints via `nav_waypoints_set`; the Helm adopts + re-emits. Idle-only, with a
  stuck-drag guard. Empty-click still plots a direct free-point course (ADR 0020).
- **Clear Course** wipes the plot entirely (selection + waypoints + a not-engaged
  laid-in order, via a new `clear_course` order).
- Views render the editable compose plot when idle (fat grabbable handles), the
  engaged `current_order` path when under way.

ADR 0028 recorded. Feel pass (drag feel, grab radius, red/amber legibility) by F5.

---

## 2026-06-09 — Build: Zones + course obstacle routing (ADR 0026/0027)

Built the Zones slice in order, tests green at each step. **164 GUT tests green;
boots clean.**

1. **ZoneData + content (ADR 0026):** authored `.tres` (by id) — geometry
   (CIRCLE/BAND/POLYGON, body-anchorable) + category + a generic `effects` tag bag.
   `SystemData.zones`. Authored the five Calder example zones (one of each
   shape/category) + `ZONE_*` strings.
2. **`Zones.contains` (pure):** per-shape membership in real space; GUT-tested
   (boundaries, zero-radius, band hole, degenerate polygon).
3. **`ZoneController`:** ticks on sim_tick (mirrors SensorController) — resolves
   anchored geometry, diffs membership → `zone_entered`/`zone_exited`; on-enter
   `trigger_event` fires `zone_trigger_fired` (once if `once`, recorded in
   `GameState.zones`, saved); reset on new_game/load/system_changed. Other effects
   authored-but-inert (the design-for-defer hook).
4. **Rendering:** zones draw beneath bodies — true shapes on the scope, warped on
   the orrery (boundary samples / polygon verts through the projection); outline +
   name·category label (shape + label, not colour alone). Anchor resolution moved
   into pure `Zones` and reused by the controller.
5. **Course obstacle routing (ADR 0027):** pure `Zones.segment_intersects` +
   `route_block` (nogo > hazard > clear). `current_order.waypoints`;
   `FlightController` flies the legs in order (fuel sums over legs); a no-go on any
   leg rejects Lay In (`ORDER_REJECT_OBSTRUCTION`), hazards warn. Helm: empty-click
   waypoints (with a body/contact target), Clear Route, a Target Info Route line,
   and a dim compose preview (`nav_route_changed`); both views render the engaged
   route through its waypoints.
6. **Feel pass:** in-engine vs Calder (zone outlines/labels, route legibility,
   no-go reject / hazard warn) is by F5. ADRs 0026 + 0027 confirmed.

---

## 2026-06-09 — Design: Zones + course obstacle routing (ADR 0026/0027)

Design session (no code). New primitive: **Zones** — authored spatial regions for
hazards, fields, no-go space, station/comms coverage, refuel bands, and
on-arrival triggers. Kept general so one primitive serves all of them.

- **ZoneData (ADR 0026):** geometry (circle / band / polygon, body-anchorable) +
  a **generic effect-tag bag** (consuming systems read recognised keys; new
  effects need no new type). Membership decided in real space on `sim_tick` via
  pure `Zones.contains`, with a `ZoneController` mirroring `SensorController`;
  `zone_entered`/`zone_exited`. **Only the on-enter trigger hook is wired this
  slice** (`zone_trigger_fired` for the future event system); `sensor_mult`,
  `rm_drain`, `refuel` etc. are authored-but-inert until their systems land.
- **Course obstacle routing (ADR 0027):** zones tagged `blocks_course` —
  **no-go** rejects a crossing leg, **hazard** warns. The captain plots around by
  dropping **waypoints** (multi-leg `current_order.waypoints`); each leg validated
  via pure `Zones.segment_intersects`. Auto-pathfinding deferred.
- `docs/zones.md` has the data shape, core contracts + tests, example zones for
  Calder Reach (one of each shape/category), and a 6-step build order.

Not built yet — ready to hand to Claude Code.

---

## 2026-06-09 — Build: nav iteration 2 (system loading, debug console, Calder, target panel)

Built the whole nav-iter-2 batch (ADR 0024 + 0025 + Calder content), in order,
tests green at each step. **144 GUT tests green; boots clean.**

1. **Runtime system loading (ADR 0024):** `GameState.load_system(system)` resets
   the run (id, ship→ship_start, clear course, DEEP_SPACE, reset contact
   discovery; fuel kept). New `EventBus.system_change_requested` / `system_changed`;
   a `SystemLoader` node validates the id and announces. Nav views / sensors /
   flight / Helm re-init on `system_changed` (views gained a build-once-connect +
   `_init_system` rebuild path). The seed of warp later. GUT: state reset + loader.
2. **Debug console (ADR 0024):** `toggle_console` (backtick); `DebugActions`
   command runner (`help`, `systems`, `system <id>`, `refuel`, `tp <body>|<x y>`)
   that mutates GameState + emits existing signals (sanctioned debug exception;
   release-gate TODO noted); `DebugConsole` overlay (toggles via `_input` so the
   backtick never lands in the field). GUT: every command.
3. **Calder Reach (content):** 2nd system .tres — 1 star + 8 planets + 6 moons +
   2 stations + 7 contacts; positions `round(AU*1000*(cosθ,sinθ))`; Bastion has 3
   moons; contacts spread across/beyond the start sensor range. Reach via
   `system calder`. GUT: density + moon-parent integrity + sol→calder switch.
4. **Target Information panel (ADR 0025):** the Order Log became a burn-aware
   Target Info panel (name, type, distance AU+wu/bearing, ETA, RM + reachability,
   status: parent/dock/refuel/moons/contact-tier/scan; overview when nothing
   selected). Ship-voice acks moved to a transient, fading line in Flight Status.
5. **Feel pass:** in-engine tuning vs Calder is by F5 (orrery density, moon
   clustering, isochrones, sensor sweep). ADRs 0024 + 0025 confirmed.

---

## 2026-06-08 — Design: nav iteration 2 (tooling, 2nd system, target panel)

Design session (no code). Three nav-polish asks from the captain, turned into a
build plan + ADRs:

- **Runtime system loading + debug console (ADR 0024):** `system_change_requested`
  / `system_changed` signals and a clean load path (reset ship/course/contacts,
  rebuild views) — the seed of warp later. A dev-only `DebugConsole` (backtick)
  driving a `DebugActions` helper: `system <id>`, `refuel`, `tp <body|x y>`.
- **Helm Target Information panel (ADR 0025):** the Order Log box becomes a
  burn-aware Target Info panel (body/contact/waypoint details); ship-voice
  acknowledgments move to a transient line in Flight Status.
- **Calder Reach (content):** a large second system — 1 star, 8 planets, 6 moons,
  2 stations, 7 contacts — specced in `docs/navigation.md` to stress the orrery,
  moon insets, isochrones, and the sensor sweep.

Build order + the full body/contact table are in `docs/navigation.md` ("Nav
iteration 2"). Not built yet — ready to hand to Claude Code.

---

## 2026-06-08 — α0.3 nav feel pass (in-engine feedback)

First in-engine drive surfaced five issues; addressed four + added pan/zoom.

- **Near-star course balloon (fixed):** `project_path` was flooring inner points
  onto `ring_inner`, so a course past the star bulged into a big arc. Now the
  inner region (r < r_min) **ramps from ring_inner toward the hub** — the curve is
  pulled inward (a real fly-by passes close to the star), continuous at r_min.
  Test updated.
- **True-scale crowding → pan & zoom (ADR 0023):** `OrreryView` gains mouse-wheel
  zoom (about the cursor) + right/middle-drag pan, as a view transform applied in
  the projection wrappers — positions move, marker/label sizes stay constant.
  Resets on a scale-mode flip. Empty-space picking unprojects through the inverse.
- **Lay-in label clutter (fixed):** per-body ETA badges now show only in the
  overview and are suppressed while composing/flying a course; the redundant
  mid-line leg-ETA label was dropped (ADR 0019 amended).
- **Between-pip legend (added):** a Helm `Pip` readout shows what one course-line
  pip spans at the selected burn (`PIP_TICKS` min · `reach_wu` wu).
- **Scale control → toggle switch:** moved out of the Course Order panel into a
  `CheckButton` slide switch in a `PanelContainer` **above** the box (ADR 0021/0023).

Still open from the feedback: deeper declutter if needed once zoomed. **129 GUT
tests green**; app boots clean headless. ADR 0023 added; 0019 amended.

---

## 2026-06-08 — α0.3: orrery scale toggle + moon rings + focus inset

Three nav-view slices (ADR 0021 + 0022), built B→A→C.

- **Moon orbit rings (B):** the orrery ring pass now draws a faint ring per moon
  about its parent's projected point; skipped when they collapse in true scale.
- **Orrery scale toggle (A, ADR 0021):** `OrreryParams.mode {LOG, LINEAR}`;
  `OrreryProjection` branches on the radius map only (same signatures) — LINEAR is
  true-scale (`r_max → ring_outer`), `project_path` collapses to `project`, moons
  take their real scaled offset. `EventBus.nav_scale_changed`; a Helm segmented
  control (`Schematic | True scale`) mirroring the burn selector, initial-broadcast
  on `_ready`. 6 LINEAR projection tests; LOG tests unchanged.
- **Focus inset (C, ADR 0022):** a "has-moons" affordance on the orrery (satellite
  halo + a pip per moon, capped); a Helm **Focus** button gated on
  "selection has moons" **plus re-click** the selected planet, both emitting
  `nav_focus_requested`. New `MoonInsetView` (a `MOUSE_FILTER_STOP` Control PiP,
  top-centre) shows the planet + its moons spread out via the pure
  `OrreryProjection.project_satellite` (tested), each on its own ring and clickable
  → `nav_target_selected` (moons are bodies, so the existing course/scan pipeline
  flies to them). ✕ closes (`nav_focus_closed`). Closes the α0.2 step-7 deferral.

**129 GUT tests green** (was 118). Feel pass still open (scale readability, halo
style, inset size/position). ADRs 0021 + 0022 confirmed.

---

## 2026-06-08 — α0.3: nav targets (contacts + waypoints) + the scan action

Opened α0.3 ("Navigation III: Targets & the Scan") — spec + **ADR 0020**. The
captain can now plot a course to anything on the Nav Plot, and identify contacts.

- **Generalized course (ADR 0020):** `current_order` carries a frozen `dest:
  Vector2` alongside `target_id` (a body id, a contact id, or "" for a free
  point). `FlightController` resolves the destination per kind and arrival per
  kind: a **body** still settles into its holding orbit; a **contact or free
  point** *drifts* — stops on the point, drops the course, IDLE in deep space.
  Engage fuel-gates on the resolved `dest`. Resync-after-load generalized.
- **Empty-space waypoints:** new `EventBus.nav_point_selected(point)`; both views
  pick the nearest body/detected-contact under the cursor, else drop a waypoint —
  orrery via the new pure `OrreryProjection.unproject` (inverse log map), tactical
  scope via its true scale. A crosshair marks the selected point.
- **Scan action:** `{type:"scan", contact_id}` — legal only in sensor range, on a
  BLIP; promotes BLIP → IDENTIFIED (`contact_promoted`, saved). Helm **Scan**
  button gated by `Travel.available` (new `scan` + `has_nav_selection`).
- **Identity reads:** an unscanned contact is a hollow diamond labelled "Unknown
  contact"; scanning fills the diamond and reveals the authored name (shape +
  label, not colour — ADR 0012), on orrery + scope.
- **Tests:** `unproject` round-trips `project`; `Travel.available` scan/selection
  rules; `FlightController` point course, contact course, undetected-reject, scan
  in/out of range. **118 GUT tests green** (was 109).

Deferred (ADR 0020): station-keeping/"hold at a point", survey rung beyond
IDENTIFIED, multi-waypoint queues. Feel pass (markers, glyphs) still to do.

---

## 2026-06-08 — Build: travel-time legibility (ADR 0019, α0.2 step 9)

Built the ADR 0019 slice — time is now explicit on both nav views and burn-aware
(recomputes when the Helm burn selector changes).

- **Core:** `FlightMath.reach_wu(burn, ticks)` (inverse of `eta_ticks`; non-positive
  ticks → 0). 3 tests: round-trips against `eta_ticks` within one tick's distance,
  monotonic in burn, zero/negative guard. **106/106 green.**
- **Wiring:** new `EventBus.nav_burn_changed(burn)`; `HelmConsole` emits it on burn
  select + once on `_ready` to sync the views. Views mirror the burn and redraw.
- **Orrery (`OrreryView`):** per-body **ETA badge** under each label (`eta_ticks`
  ship→body at the selected burn; star excluded — it's the hub); **time-pip course
  line** — a pip every `PIP_TICKS` (30) in-game minutes along the real path (even
  fractions, since speed is constant per burn; the projection warps the spacing),
  tagged with the leg ETA at the midpoint.
- **Tactical scope (`TacticalView`):** **isochrone rings** for `ISOCHRONE_TICKS`
  [10/20/30/60/120 min] via `reach_wu × _px_per_wu`; rings too small to read or
  past the scope edge at the current burn are skipped, each carries a duration
  label (time not by colour alone — ADR 0012).
- Time annotations use `Palette.STATUS_NOMINAL` (green) — distinct from the
  accent-blue course/selection. New `tr()` keys `NAV_DURATION_HM` / `NAV_DURATION_M`.

Also fixed a latent orrery course-line artifact surfaced while reviewing the
pips: the line was sampled uniformly in real distance, but the log-radial
projection bends it most where the straight path passes near the star (small
radius, fast bearing sweep), so cross-system courses kinked into a zig-zag.
Replaced the fixed 20-sample loop with adaptive chord-flattening subdivision
(`_subdivide_course`, ≤512 segs) drawn as one `draw_polyline` — smooth for any
geometry, cheap on the flat outer legs. A second pass fixed courses plotted
*through* the star: there the standard projection collapses everything inside
`r_min` to the hub and the bearing flips, spiking the line through centre.
Added pure `OrreryProjection.project_path` (floors onto the inner ring at the
true bearing instead of collapsing) and route the course line + pips through it,
so a near-star leg arcs smoothly around the hub. +3 projection tests (109 green).

Tuning left for the step-10 feel pass: pip interval, isochrone durations, badge
placement (flagged in `docs/ALPHA-0.2-SPEC.md` knobs). ADR 0019 confirmed.

---

## 2026-06-06 — Design: travel-time legibility on the nav views (ADR 0019)

Design session (no code). The captain found the orrery counter-intuitive — its
log compression strips any sense of travel time from the geometry. Reframe: on a
schematic, magnitude is *labelled*, not read. Decided (ADR 0019), all burn-aware:

- **Orrery:** per-body **ETA badges** (`FlightMath.eta_ticks` → duration) and a
  **time-pip course line** tagged with its ETA. Time is read off labels, not
  distance.
- **Tactical scope:** **isochrone rings** at fixed durations for the selected
  burn, as clean concentric circles next to the sensor circle — the reach
  planner. (Isochrones belong on the scope: a ship-centred time-circle warps on
  the star-centred orrery, like the sensor boundary.)
- New pure helper `FlightMath.reach_wu(burn, ticks)` (inverse of `eta_ticks`) to
  place the rings; reuse the Helm burn signal to recompute on burn change.
- Rejected a time-based orrery projection (unstable — re-flows with ship/burn).

Folded into `docs/navigation.md` (new section + helper contract + tests) and the
α0.2 build order (now step 7). Not built yet.

---

## 2026-06-06 — Build: tactical scope (α0.2 step 8)

Added the tactical scope — the radar to the orrery's chart plotter. `TacticalView`
is a ship-centred, **true-scale** screen-space view: the sensor range as a real
circle (+ a half-range guide), bodies at true local proportions, detected
contacts inside the circle, and the course as a straight true line. Toggled with
the orrery via the new `toggle_tactical` action (**T**); the hidden view ignores
input and idle-redraw. Verified by screenshot (ship-centred circle, Sol/Verdant/
Cinder at true scale, Kepri inside). 103/103 green.

**Trim:** the focus-a-body moon sub-view (step 7) is deferred to α0.3 — with the
moon clustered ~36 px off its parent on the orrery it's already directly
clickable/targetable, so the sub-view isn't needed yet. α0.2 nav slice is
otherwise complete bar a formal feel pass.

---

## 2026-06-06 — Build: orrery Nav Plot + moons + sensor contacts (α0.2 steps 1-6)

Built the navigation slice through contacts. Core first, tested, then the render.
- **Core (GUT):** `OrreryProjection` (log radius, exact bearing) + `project_child`
  for moons; `Sensors` range + segment (capsule) detection.
- **Data/state:** `BodyData.parent_id` + `Kind.MOON`, `ContactData`,
  `SystemData.contacts`, `ShipState.sensor_range`, `GameState.ContactsState`
  (saved), EventBus contact signals. Authored Verdant's moon **Cinder** + three
  transients (Kepri derelict / Veil anomaly / Echo signal) into Sol.
- **Orrery render:** new screen-space `OrreryView` replaces the world-space map —
  the whole 1→40 AU system on one screen, bodies on log rings (bearing exact),
  moons clustered by their parent, ship + curved (sampled) course line,
  screen-space picking. Retired the old world nodes (SystemView/BodyView/
  ShipView/OrbitRings/CourseLine) and the Camera2D/pan path.
- **Sensors wired:** `SensorController` ticks the segment check → `ContactsState`
  → orrery draws detected transients as a distinct blip glyph (shape, not colour;
  ADR 0012) winking in/out.

Verified by screenshots (full system reads at once; Cinder beside Verdant; Kepri
winks in once in range) and `tier_of` checks. 103/103 green. Still to do:
tactical scope, focus-a-body moon sub-view, feel pass.

---

## 2026-06-06 — α0.2 spec: "Navigation II" (orrery + moons + sensors)

Spec session (no code). Turned the navigation design into a milestone:
- **`docs/ALPHA-0.2-SPEC.md`** — "Navigation II: the Instrument": orrery Nav Plot
  (display only; real AU distances/fuel unchanged), moons, charted/transient
  contacts via real-space sensor detection, and a true-scale tactical scope.
  Definition-of-done + build order in the α0.1 style.
- **ADR 0018 (proposed)** — hierarchical bodies: `BodyData.parent_id`, moons as
  ordinary flyable charted bodies at absolute static positions, parent-relative
  orrery projection, and a focus-a-body sub-view. Reaffirms ADR 0005 (bodies
  static; any orbital motion is cosmetic only — the orrery is a display style,
  not animated mechanics).
- Folded three refinements into `docs/navigation.md`: a `project_child` moon
  contract; a **segment (capsule) sensor check** so Hard-burn warp can't tunnel
  past a contact between ticks; and projecting about the star body + sampling the
  course path (curved line). Decision log + CLAUDE pointers updated to 0018 and
  the 0.2 spec.

Awaiting sign-off on ADR 0018 / the spec before building. Suggested first code:
`OrreryProjection` + `Sensors` pure `core` with GUT tests.

---

## 2026-06-06 — Design: orrery Nav Plot + sensor/contact model (α0.2 prep)

Design session (no code). The realistic 40 AU scale was hurting gameability —
can't see the system at once, fiddly targeting, navigation lacked decisions.
Resolved by separating **presentation scale from simulation scale**:

- **Orrery Nav Plot (ADR 0016):** keep real coordinates as the sim truth; the
  Nav Plot renders bodies through a pure log projection — compress radius onto
  rings, preserve bearing — so the whole system fits one screen. Supersedes the
  true-scale layout (display only; AU distances/fuel unchanged).
- **Sensor & contact model (ADR 0017):** split contacts into **charted**
  (gravimetric — always shown) and **transient** (non-gravimetric — only within
  sensor range). Detection is pure `core`, decided in real space on `sim_tick`,
  so the chart's non-linearity never matters. Orrery shows **contacts-only**
  (no warped sensor boundary); a true-scale **tactical scope** shows the real
  sensor circle. Sensor range becomes a decision (sweep coverage; upgrade
  sensors → Grow/crew).
- Wrote `docs/navigation.md` with the `OrreryProjection.project` and
  `Sensors.contacts_in_range` contracts + test outlines, and a suggested α0.2
  nav-slice build order.

Not built yet — this is the α0.2 design, ready to fold into the milestone spec.

---

## 2026-06-06 — Standard burn = Warp 1 (light speed)

Per the captain: Standard cruise is now **Warp 1 = c**, so 1 AU (8 light-minutes)
takes 8 in-game minutes = 8 real seconds at 1×. The burns now straddle light
speed — Economy 0.5c (slow sub-light), Standard 1c, Hard 2c — superseding the
earlier 2.5/4/6× set (which had Economy above Standard once Standard became 1c).
Distances/fuel unchanged (RM is per-wu). Verified 1 AU @ Standard = 8 ticks.
85/85 green.

---

## 2026-06-06 — Nav Plot chart aids (true scale, readable)

True AU scale spans 40×, so the inner planets crowded at any whole-system zoom
and the default view was too wide. Kept distances exactly real and added chart
structure + navigation (captain's call):
- **Orbit rings:** faint concentric circles from the star at each body's orbital
  radius (`OrbitRings`), constant on-screen line width. The map now reads as a
  real chart — each body sits on its AU ring.
- **Inner-system default zoom:** start framed on ~3 AU so the Sol↔1 AU layer is
  spacious (was ~14 AU).
- **Free camera:** right-drag to pan (free look), wheel to zoom, `C` (new
  `recenter_view` action) to re-centre on the ship; the camera also re-follows
  when a course is engaged. Camera is now independent of the ship (was a child).

Verified by screenshots: the inner view is spacious with Verdant on its ring,
and zoomed out the concentric rings show the full 1→40 AU structure. 85/85 green.

---

## 2026-06-06 — Warp/c speed model + realistic AU distances

Re-anchored speed + spacing to physics, per the captain:
- **Warp 1 = the speed of light.** Light crosses 1 AU in 8 ticks (~8 in-game
  minutes; real ~8.3, rounded). `Travel.WU_PER_AU = 1000`; Warp 1 =
  `WU_PER_AU / 8 = 125` wu/tick. Verified: 1 AU @ Warp 1 = exactly 8 min.
- **Burns are warp factors:** Economy 2.5× c, Standard 4× c, Hard 6× c
  (312.5 / 500 / 750 wu/tick).
- **Realistic spacing** (AU × WU_PER_AU): Verdant 1 AU, Rubicon 5.2 AU, Anchorage
  Station 9.5 AU, Tethys (outer) **40 AU**; ship starts ~1 AU out. The 40 AU haul
  is ~129 min / 72 RM on Economy (reachable), but exceeds a tank on the faster
  burns — so the station's refuel matters.
- **Readable at AU scale:** body + ship markers are now drawn at a **constant
  on-screen size** (the node cancels the camera zoom), with screen-space click
  picking, a much lower zoom floor (`CameraFit.MIN_ZOOM = 0.004`), and a default
  view framing the inner ~14 AU. Wheel out to see the whole 40 AU system; every
  body stays a legible, clickable marker at any zoom. Course line widths are
  zoom-compensated too.

Verified via screenshots (default + zoomed-out) and a math check of the anchors.
85/85 green.

---

## 2026-06-06 — Fix: clock/ship felt frozen — tick is now 1 in-game minute

The previous pass set `SECONDS_PER_TICK = 60` with tick = 1 hour, so at 1× the
sim only stepped once per real minute: the (hours-only) clock sat still for 60s
and the ship's first move was a minute after engaging — it read as broken.

Retuned the tick unit (ADR 0004 allows it): **1 tick = 1 in-game minute**,
`SECONDS_PER_TICK = 1` → 1 real second = 1 in-game minute, and the whole sim
steps every second. The clock now shows `Day D · HH:MM` advancing each second;
the ship moves every second (smoothly interpolated). Same trip/fuel feel as
intended (nearest planet ≈ 2.5 in-game hours ≈ 2.5 min at 1×):
- `SimCalendar` derives day / hour / minute from minute-ticks.
- Burn speeds rescaled to wu-per-minute (1.2 / 2.0 / 3.4); RM rates unchanged
  (cost is per-wu, so fuel feel is identical).
- Helm ETA shows `Hh MMm`; CONVENTIONS updated.

Verified on the real clock: tick increments ~1/second at 1× and the ship moves
from engage. 85/85 green.

---

## 2026-06-06 — Scale + pacing pass (deliberate, to spec)

Set scale/pacing to the captain's chosen feel (was placeholder):
- **Time mapping:** `SECONDS_PER_TICK = 60` → 1 real second = 1 in-game minute at
  1× (1 tick = 1 in-game hour).
- **Trips:** re-spaced Sol so the nearest planet is a ~3-tick standard burn
  (~3 in-game hours / ~3 real minutes at 1×; ~2 on a Hard burn). Outer bodies
  ~5-9 ticks. Verified by a fly-test (Verdant standard = 3 ticks).
- **Fuel:** lowered RM rates (0.012 / 0.020 / 0.034) for a "loose" tank — nearest
  hop ~6 RM of 100, so well over 5 trips before refuelling.
- **Orbit rework (forced by 60s ticks):** the holding orbit moved from per-tick
  to **smooth per-frame** in `FlightController._process` (real-time, ~30s/orbit,
  speed-scaled, freezes when paused). Still authoritative, so arrival/departure
  stay jump-free; `ShipView` reads the position directly while holding. The
  camera's fit-to-system framing handles the new spacing automatically.

Knobs (all clearly marked, none touch logic): `SimClock.SECONDS_PER_TICK`,
`FlightMath` burn speeds + RM rates, `Travel.HOLDING_GAP`,
`FlightController.ORBIT_PERIOD_SECONDS`, body spacing in `tools/build_sol_system.gd`.
84/84 green.

---

## 2026-06-06 — Fix: arrive/depart through the body; orbit is now authoritative

Two travel bugs, same root cause: the holding orbit was a view-only effect while
the authoritative position sat at the body *centre*. So on arrival the ship
interpolated into the centre then the view yanked it out to the ring; on
departure the course started from the centre.

Fix: the **holding ring is authoritative** (`Travel.holding_radius` =
body radius + gap). The ship now stops *on the ring* at the approach angle
(clamped so a crossing step never dives through the body), and `FlightController`
advances the orbit per tick (`ShipState.orbit_angle`, one orbit per in-game day),
so the view just interpolates the real position. Arrival and departure are both
from the ring — no centre dive, no centre jump. `ShipView` reverted to plain
interpolation (no view-side orbit). `orbit_angle` is serialized.

**Tests:** added holding-orbit-advances and depart-from-ring-not-centre; updated
arrival + fuel expectations (ship travels to the ring, not the centre). 84/84
green; verified with a real-clock screenshot (ship sits on the ring beside the
planet, orbiting).

---

## 2026-06-06 — Holding = orbiting (ship circles the body)

Gave "holding" a visual meaning: when the ship is HOLDING at a body it slowly
circles it (and parks at the same offset when DOCKED). The orbit is cosmetic —
the authoritative position stays at the body for logic (ADR 0004) — and advances
on sim time, so it scales with speed and freezes when paused. Implemented in
`ShipView` (orbit radius = body radius + gap, ~30s/orbit at 1×). The ship eases
onto the ring from wherever it arrives (a smoothstep radius blend over ~0.9s)
instead of popping. Verified the rendered distance settling smoothly onto the
ring (74 wu), and screenshotted the ship orbiting Verdant; Flight Status reads
"Holding: Verdant". 82/82 tests still green.

---

## 2026-06-06 — Travel pipeline: location / course / context orders (ADR 0015)

Reworked travel so available orders are derived from the ship's situation, not
shown unconditionally. Separated three axes on `ShipState`:

- **Location** (`Travel.Location`: `DEEP_SPACE` / `HOLDING` / `DOCKED`
  + `location_body_id`) — where we are when not under way. Stations have a
  holding area you arrive into, and dock from.
- **Course** (`current_order`) — the laid-in target+burn; `engaged` = under way.
  Nav-target *selection* is separate UI compose state (you lay in a course to
  commit it).
- **Motion** (`FlightCore.State`, now motion-only: Idle + transit phases;
  dropped COURSE_SET/IN_ORBIT).

**`Travel.available(context)`** (pure, GUT-tested) is the one source of truth for
which orders are legal: Lay In (target elsewhere, not under way), Engage (course
laid in, not under way, not docked), Belay/All Stop (under way), Dock (holding at
a station), Undock (docked). The Helm enables/disables buttons from it; the
FlightController validates against the same rules. Transitions: engage departs to
deep space; arrival auto-enters HOLDING and consumes the course; belay keeps the
course (re-engageable), all-stop drops it; dock refuels, undock returns to
holding. Retired establish/break-orbit; added Undock and `ship_context_changed`.
Status now reads the situation ("Holding: Anchorage", "Cruising → Rubicon",
"Drifting"). Location is serialized (resumes on load).

**Tests:** new `test_travel` (5); reworked flight/fuel/helm tests for the model.
**82/82 green** headless; verified the context-gated buttons + status via
screenshot.

---

## 2026-06-06 — Fix: Helm console rendered off-screen

Playtest caught the Helm panels invisible. Cause: `HelmConsole` (a plain Control
under another plain Control) stayed size (0,0) — `set_anchors_preset(FULL_RECT)`
doesn't lay out a child of a non-Container parent — so its corner-anchored panels
landed off-screen (e.g. Course Order at y=−300). Fixed by setting explicit
full-rect anchors/offsets in `_ready`. Verified with a screenshot harness
(`tools/screenshot.gd`, a non-headless dev utility): all three panels now sit at
their corners with the map behind. The console is persistent (always on, no
toggle). 74/74 still green.

---

## 2026-06-06 — Session 9: Polish + feel pass — α0.1 complete (step 9)

Milestone wrap. Clarity/camera polish, a usable save/load, done-criteria confirmed.

- **Camera (scale-tuning debt):** `CameraFit` (src/core, tested) defines zoom
  min/max bounds; `SystemView` frames the whole system at boot (computed zoom,
  not a blind constant) and the mouse wheel zooms within bounds. Resolves the
  camera half of the scale debt; body spacing + tick/burn numbers remain
  feel-tuning (clearly-marked constants, none touch logic).
- **Nav Plot clarity:** `CourseLine` draws a dashed ship→target line + a
  destination marker while a course is laid in/executing (helm.md), tracking the
  interpolated ship marker.
- **Save/load in-game:** `sim_save` (F5) / `sim_load` (F9) actions + a
  `SaveController` with a toast — makes the (already-tested) save/load spine
  usable. Load emits `game_state_loaded`; the console, fuel, clock, and flight
  resync off it.
- **Fix:** the debug overlay + boot line mislabelled the debug key as F1; it's
  bound to **F3**. Corrected.

**α0.1 done-criteria — confirmed:**
1. **Plot + burn** — Helm Nav Plot: click a body → ETA + RM preview → burn
   selector → Lay In / Engage. ✓
2. **Fly on the clock** — FlightController over discrete ticks, interpolated
   render; pause / 1× / 2× / 4× in the shell, clock runs while the console is up. ✓
3. **Fuel matters** — RM spent per burn, refuel by docking at the station, live
   gauge. ✓
4. **Save / load** — position, fuel, tick, system round-trip via SaveManager,
   schema-versioned; F5/F9 in-game. ✓
5. **It feels good** — legible named states, ETA, abort (Belay) always available,
   course line; static bodies = no moving-target clunk. (Numeric feel left for
   in-engine tuning.) ✓
6. **Green tests** — clock, ETA/fuel, save round-trip, + flight/console/voice:
   **74/74 GUT green** headless. ✓

**Status:** α0.1 "The Ship Flies" is complete. Next is α0.2 scoping (agree scope,
write the milestone spec, then build) — see CLAUDE.md.

---

## 2026-06-06 — Session 8: The Helm console (step 8)

The α0.1 spine is now played through a real captain's terminal.

- **Minimal terminal theme** (ADR 0006): `Palette` (colourblind-safe Okabe–Ito
  status colours) + `TerminalTheme` (panel/button styleboxes, default font for
  now — Orbitron/Share Tech Mono are a later drop-in), applied once at the shell
  root so all Controls inherit it.
- **Config-driven component library** (ADR 0007): `TPanel`, `TButton`,
  `TReadout`, `TGauge`, `TLight`, `TList`. They read via binding callables and
  write only by invoking intents — never mutate state. `TLight` carries colour
  **and** glyph **and** label (never colour alone, ADR 0012).
- **Helm console** (`src/ui/consoles/helm_console.gd`, ADR 0013) assembled from
  those components over the Nav Plot map:
  - **Nav Plot:** click a body to select it as target (map emits
    `nav_target_selected`, owns its highlight ring); retired the temporary
    click-to-fly.
  - **Course Order:** selected target, burn selector (Economy/Standard/Hard),
    live ETA + RM-cost preview (with a ⚠ non-colour cue when unaffordable), and
    the order buttons — Lay In / Engage / Belay / All Stop / Establish Orbit /
    Dock.
  - **Flight Status:** flight-state light (state name + glyph + colour),
    distance + ETA to the active target, reaction-mass gauge.
  - **Order Log:** acknowledgments + rejections, newest first.
- **Order lifecycle** (ADR 0014): the console *composes* and *issues*;
  `FlightController` validates → the post *acknowledges* (ship voice) → *executes*
  over ticks → *belay* aborts. Added `CrewVoice.speaker_for(post)` — the seam the
  crew system plugs into (α0.1: always the ship's computer). Added
  `establish_orbit` / `break_orbit` orders. Acks/rejections flow to the Order Log.
- **Shell** (ADR 0006): `main` now assembles the persistent shell — Nav Plot map
  + `TimeControls` (clock + pause/1×/2×/4×, in the shell not the console) + the
  Helm console on a themed, mouse-transparent UI layer so empty-space clicks
  reach the map. Retired the standalone clock/fuel HUD labels (folded into the
  time bar + flight status).

**Tests:** `test_crew_voice` (2) + `test_helm_console` (5: builds clean,
select→lay-in issues the right order, no-target no-op, burn carries into the
order, ack logs). Whole suite **70/70 green** headless; full shell boots clean.

**Next:** build-order step 9 — polish + feel pass (tick rate, burn costs, camera
zoom range + fit-to-system, clarity), confirm all α0.1 done-criteria, and the
scale-tuning debt. Save/load round-trip (criterion 4) is already in from step 3.

---

## 2026-06-06 — Session 7: Fuel — reaction mass bites (step 7)

Burns now cost reaction mass, the burn choice matters, and you can refuel.

- **Consumption per tick:** `FlightController` spends RM for the distance
  actually covered each tick (`FlightMath.rm_cost`), so the total over a course
  equals the preview cost exactly. Emits `EventBus.fuel_changed`.
- **Fuel bites at engage:** engaging now validates the tank can complete the
  course (cost ≤ reaction mass) and rejects with `ORDER_REJECT_INSUFFICIENT_RM`
  otherwise — the real time-vs-fuel decision (ADR 0005). Pick a cheaper burn or
  refuel.
- **Refuel at station:** a `dock` order refills to capacity when the ship is at a
  `can_refuel` body, else rejects (`ORDER_REJECT_NOT_AT_STATION`). Added
  `ShipState.max_reaction_mass` (tank capacity, saved; additive — no schema bump,
  forgiving load covers it). The full Dock/Undock + crew voice are step 8; the
  temporary click now docks when you click the station you're parked at.
- **Live HUD:** `FuelReadout` shows current / max RM (tr() keys), updating on
  `fuel_changed` / load. `Fuel.Pool` enum added (Reaction Mass now; Warp
  reserved). Debug overlay already shows RM.

**Tests:** `test_fuel` (5: spend matches the cost model, harder burn drinks more,
engage refused without fuel, dock refuels, dock refused in open space) + the ship
round-trip now covers `max_reaction_mass`. Whole suite **63/63 green** headless;
scene boots clean.

**Next:** build-order step 8 — the Helm console: terminal shell + minimal theme +
config-driven components, Nav Plot with click-to-target, course preview, burn
selector, order buttons, flight status, order log, and the full
issue→acknowledge→execute lifecycle with ship-voice acks. (Retires the temporary
click-to-fly.)

---

## 2026-06-06 — Session 6: FlightController — the ship flies (step 6)

The vertical spine moves: plot → engage → fly on the clock → orbit, with abort.

- **`FlightCore`** (`src/core/flight_core.gd`, pure, GUT-tested) — owns the
  `State` enum (Idle → CourseSet → Engaging → Accelerating → Cruising →
  Decelerating → Arriving → InOrbit, matching the FLIGHT_STATE_* strings) plus
  `step_position` (clamped, never overshoots), `executing_state` (phase from
  course progress), `has_arrived`, `state_key`. α0.1 movement is straight-line at
  constant burn speed; the ramp phases are presentation, swappable later.
- **`FlightController`** (`src/flight/`, plain system node — not an autoload) is
  the system side of the order lifecycle (ADR 0014): validates orders off
  `EventBus` (`set_course` / `engage` / `all_stop`, `order_belayed` = abort),
  executes one `FlightCore.step` per `sim_tick`, writes `GameState.ship`
  (position/heading), and emits `flight_state_changed`. Holds no system refs
  (ADR 0003); reads GameState + TypeRegistry only. The course lives in
  `ShipState.current_order` (target_id, burn, engaged, origin) so a mid-flight
  save resumes — `game_state_loaded` recomputes the phase from geometry (the
  transient Engaging beat isn't persisted). Abort returns to CourseSet (ADR 0005).
- **Interpolated rendering (ADR 0004):** `ShipView` lerps between the last tick's
  rendered position and the live authoritative position using
  `SimClock.get_tick_fraction()` — smooth motion over the coarse tick; logic
  never reads the interpolated value.
- **Runnable now:** a TEMPORARY click-to-fly in `SystemView` (click a body →
  plot + engage a Standard course) so flight is visible before the Helm Nav Plot;
  replaced by the proper compose→preview→confirm flow in step 8. Debug overlay
  now shows flight state, ship position, and reaction mass. Order-reject reasons
  added as tr() keys.

**Tests:** `test_flight_core` (6) + `test_flight_controller` (6: lay-in/ack,
reject unknown target, engage→fly→orbit, belay→hold, all-stop→idle, load-resume).
Whole suite **58/58 green** headless; scene boots clean.

**Next:** build-order step 7 — reaction-mass consumption per burn on each tick,
refuel at the station, live fuel on the HUD (GUT: fuel).

---

## 2026-06-06 — Session 5: Flight ETA/fuel math (step 5)

The time-vs-fuel model, as pure tested logic before any flight node exists.

- **`FlightMath`** (`src/core/flight_math.gd`, node-free, GUT-tested) — the
  canonical owner of the **`Burn` enum** (Economy / Standard / Hard, used by
  Helm + FlightController later) plus: `distance`, `eta_ticks` (ceil — a partial
  tick still costs a tick), `rm_cost` (reaction mass, linear in distance), and a
  `preview()` that bundles distance + ETA + RM + affordability for the Helm
  course plot.
- **Model (α0.1, deliberately simple, ADR 0005):** straight-line course at a
  fixed per-burn cruise speed; RM spent per world-unit. Higher burn = faster but
  dearer per wu — the real lever. Speeds (60/120/240 wu/tick) and RM rates
  (0.020/0.035/0.060 per wu) are **tuning constants** (CONVENTIONS.md), expected
  to shift at the step-9 feel pass and likely to move onto per-hull authored data
  later. (See the scale/tuning notes — distances are in wu, scale-agnostic.)

**Tests:** `test_flight_math` (9) asserts the tradeoff holds (higher burn →
fewer ticks, more RM), ceil rounding, linear fuel scaling, zero-distance
free/instant, preview bundling + insufficient-fuel flag — all independent of the
exact numbers. Whole suite **46/46 green** headless.

**Next:** build-order step 6 — `FlightController` state machine driving the ship
along a course on SimClock ticks (interpolated rendering), with abort.

---

## 2026-06-06 — Session 4: World + static bodies (step 4)

The system is on screen: a star, planets, a station, and the ship.

- **Authored data types** (`src/data`, immutable `.tres`, ADR 0002/0005):
  `BodyData` (id, name_key, kind STAR/PLANET/STATION, position in wu, radius,
  tint, can_dock/can_refuel) and `SystemData` (id, name_key, bodies, ship_start).
- **The hardcoded "Sol" system** — `resources/systems/sol.tres`: star + 3 planets
  + 1 dockable station. Authored via a regenerable tool (`tools/build_sol_system.gd`,
  run headless) rather than hand-edited, so the typed sub-resource array stays
  valid; the `.tres` is the committed artifact.
- **TypeRegistry** now scans `resources/systems/` on ready and resolves
  `get_system(id)` / `has_system` / `system_ids` (read-only cache, by id).
- **World nodes** (`src/world`, presentation-only — read state, never mutate):
  `BodyView` (kind drives the shape — star = ringed disc, station = diamond,
  planet = disc — so type reads without colour, ADR 0012; tr() name label),
  `ShipView` (heading-pointed triangle tracking `GameState.ship`), `SystemView`
  (builds bodies + ship + a ship-following `Camera2D`, `ignore_rotation` so the
  view stays upright). `PIXELS_PER_WU` is the single wu→screen scale.
- **Shell wiring:** `main` bootstraps the start system into GameState (system_id
  + ship start), builds the `SystemView`, and moves the HUD (title + clock
  readout) into a `CanvasLayer` so it stays screen-fixed under the world camera.
- **Strings:** system + body display names added (all via tr(), ADR 0010).

**Tests:** `test_type_registry` (4) guards the authored content loads and stays
well-formed (star/3 planets/station, dock+refuel, name keys present). Whole
suite **37/37 green** headless; scene boots clean with system 'sol'.

**Next:** build-order step 5 — pure ETA/fuel math in `src/core` (GUT-tested),
the foundation for the course preview and FlightController.

---

## 2026-06-06 — Session 3: GameState tree + SaveManager round-trip (step 3)

The state tree and a real, versioned save/load.

- **Typed state objects** in `src/core/state` (pure, node-free, GUT-tested):
  `ClockState` (tick, speed), `ShipState` (hull_id, position, heading,
  reaction_mass, current_order — the step-3 stub), `SystemState` (system_id).
  Each implements `to_dict()` + a forgiving static `from_dict()`; authored
  content is referenced by id, never embedded (ADR 0002).
- **`GameState`** now owns the tree (`clock`/`ship`/`system`) with `new_game()`,
  `to_dict()`, and a forgiving `from_dict()` that falls back to defaults for
  missing branches (ADR 0008). It's the single source of truth.
- **`SimClock` reads/advances `GameState.clock` directly** rather than keeping a
  divergent copy — the live tick/speed *is* the saved value, so the save is just
  a serialized tree (resolves the ADR 0002 / "transient mirror" tension cleanly).
  On `game_state_loaded` it drops sub-tick progress and refreshes listeners.
- **`SaveManager`** writes a version-stamped payload (`game_version`,
  `schema_version`, `state`) via `var_to_str` (round-trips `Vector2` cleanly,
  human-readable) to `user://save_0.sav`. Load is forgiving, emits
  `EventBus.game_state_loaded`, and has a `_migrate()` hook for future schema
  bumps. The clock readout also refreshes on load.

**Tests:** added `test_state_objects` (4) and `test_save_manager` (5: full
round-trip incl. Vector2 + active order, version stamps, load-emits-signal,
no-save no-op, partial/forgiving load). Whole suite **33/33 green** headless;
main scene boots clean.

**Note:** `SAVE_PATH` moved from the scaffold's `.tres` to `.sav` (it's a
serialized dict, not a Resource). No saves existed, so no migration needed.

**Next:** build-order step 4 — load a hardcoded star system `.tres` (star,
planets, station) via TypeRegistry, place body nodes + camera, ship at a start
position.

---

## 2026-06-06 — Session 2: Gate + SimClock tick loop (α0.1 build-order step 2)

First real compile/run of the scaffold, then the discrete clock.

**Gate (step 1 verification).** Ran the project headless in Godot 4.6.2 (mono).
The scaffold compiled and the smoke test passed **4/4** untouched — no scaffold
fixes needed. Only wrinkle was the run command itself: on PowerShell the GUT
`-gconfig=...` arg must be quoted (`"-gconfig=.gutconfig.json"`) or Godot sees
`Unknown arguments`.

**SimClock (step 2).**
- **Pure tick math in `src/core`** (ADR 0004): `ClockMath` accumulates
  speed-scaled real time and returns whole ticks (sub-tick remainder preserved
  across frames; speed 0 freezes with no lost progress). `SimCalendar` derives
  day/hour from the tick count. Both node-free and GUT-tested.
- **`SimClock` node** is now a thin shell: drives `ClockMath` in `_process`,
  emits `EventBus.sim_tick(tick)`. Speed `0/1/2/4×` via `set_speed` /
  `speed_up` / `speed_down` / `toggle_pause`, wired to the `sim_pause`,
  `sim_speed_up`, `sim_speed_down` actions. Boots at `default_sim_speed`.
- **Window-focus auto-pause** (CONVENTIONS.md, the one allowed auto-pause):
  pauses on `NOTIFICATION_APPLICATION_FOCUS_OUT`, restores the prior speed on
  focus-in, gated by `ConfigManager.pause_on_focus_loss`. A manual pause is left
  untouched (separate flag), so focus regain doesn't un-pause the player.
- **On-screen clock readout** (`src/ui/shell/clock_readout.gd`) — derived
  calendar + speed, all via `tr()` keys (new `CLOCK_FORMAT/SPEED/PAUSED`).
  **Debug overlay** (`src/ui/components/debug_overlay.gd`, ADR 0012) toggled by
  `toggle_debug` (F1): tick / speed / sec-per-tick / FPS, read-only, debug text
  exempt from localisation. Both hosted by the interim `main` shell.
- **Localisation wired up**: registered `strings.en.translation` in
  `project.godot` `[internationalization]` so `tr()` works without the manual
  editor step (SETUP.md updated; that step is now automated).

**Tests:** `test_clock_math` (9), `test_sim_calendar` (4), `test_sim_clock` (7),
plus the smoke suite (4) — **24/24 green** headless. Main scene boots clean.

**Next:** build-order step 3 — `GameState` + `SaveManager` minimal state tree
(clock + stub ship) with a save/load round-trip (GUT: round-trip).

---

## 2026-06-06 — Session 1: Project scaffold (α0.1 build-order step 1)

First code. Stood up the Godot project skeleton against the plan — no gameplay
yet, just the foundation everything hangs off.

- **Godot 4.6** (latest stable, Forward+), GDScript, 1920×1080. `project.godot`
  with the six autoloads registered, named input actions (`sim_pause`,
  `sim_speed_up/down`, `toggle_debug`), and the GUT plugin enabled.
- **Six autoloads** created: `EventBus` (all signals declared, incl. order +
  clock), `GameState`/`SimClock`/`SaveManager`/`TypeRegistry` as typed stubs
  with public surfaces + TODOs pointing at their build-order step, and
  `ConfigManager` implemented (settings in `user://settings.cfg`, separate from
  saves).
- **`GameVersion`** constants (`GAME_VERSION` 0.1.0, `SAVE_SCHEMA_VERSION` 1).
- **Localisation** string table `localization/strings.csv` (Helm/flight keys);
  `tr()` ready. One manual editor step to register the locale (SETUP.md).
- **GUT 9.6.0** vendored into `addons/gut`; `tests/unit/test_smoke.gd` asserts
  the autoloads load and defaults hold; `.gutconfig.json` added.
- Repo hygiene: `.gitignore` (`.godot/`, `*.translation`, etc.), `.gitattributes`
  (LF), `icon.svg`, `README.md`, `SETUP.md`, full `src/` tree with `.gitkeep`.
- Runnable placeholder scene (`src/ui/shell/main.tscn`) so the project boots.

Couldn't run a live compile (no Godot in this environment); verified structure,
GUT's `GutTest`/headless runner, and plugin manifest by hand. **First open in
Godot 4.6 is the real check** — see SETUP.md.

**Next:** build-order step 2 — implement SimClock ticks + EventBus, window-focus
auto-pause, and the debug overlay.

---

## 2026-06-06 — Session 0c: Consoles + the Helm console

Defined the first console and, with it, the UI's organizing model.

- **Consoles, not screens.** The UI is a set of captain's **consoles** (bridge
  posts); **Helm** is the first (flight + navigation). Supersedes the flat
  screen list. Each console is a post a crew officer can man later. (ADR 0013)
- **Orders, not actions.** The captain *issues orders*; the ship executes. Order
  lifecycle: compose → issue → **acknowledge** (a beat) → execute → belay. One
  active order per console. The active order is stored in `ShipState` so
  mid-order saves resume. This is the diegetic form of "UI emits intents". (ADR 0014)
- **Voice by crew slot.** Acknowledgments are voiced by whoever holds the post —
  a named officer if manned, the ship's computer if not (α0.1). One resolver
  serves every console; the crew system later lights up named voices everywhere.
- **Helm α0.1 orders:** Set Course (+ burn), Engage / Belay, All Stop,
  Establish / Break Orbit, Dock. Spec: `docs/consoles/helm.md`.

The α0.1 spine is now played *through* the Helm console.

**Next:** review, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0b: Cross-cutting concerns + data model

Reviewed what else to plan early. Added project-wide disciplines as ADRs and a
conventions doc, and produced a data-model diagram of entities + runtime flow.

**Added (decided cheap-now, expensive-later):**
- **Localisation-ready** — all player text via `tr()` keys + string table; one
  formatting helper. English only for now. (ADR 0010)
- **Settings + input actions** — `ConfigManager` (sixth autoload), settings in
  `user://settings.cfg` separate from saves; named input actions, no raw
  keycodes. (ADR 0011)
- **Accessibility + debug overlay** — colourblind-safe palette, never colour
  alone, toggleable live debug overlay. (ADR 0012)
- **CONVENTIONS.md** — canonical units (tick = hour, world units, fuel),
  `GAME_VERSION` + save `SCHEMA_VERSION`, window-focus auto-pause.

**Deferred (reserved):** single seeded `Rng` service for all randomness —
arrives with procgen, not α0.1.

**Data model:** confirmed the flow — UI reads GameState + emits intents; all
cross-system traffic via EventBus; authored `.tres` immutable, referenced by id;
SaveManager serializes the one GameState tree. (Diagram produced for review.)

**Next:** review the updated docs, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0: Planning the rebuild

Greenfield restart of Far Horizon — "slower and properly." Old POC treated as
discarded (rebuild from the design vision, not the old code). No game code this
session; the output is the architecture plan and the α0.1 milestone spec, for
review before any code is written.

**Why the restart:** the POC worked but was clunky. The named clunk was in
three places — **time/tick handling**, **UI flow**, and **flight feel** — so
each got a deliberate design here.

**Decisions locked (see `docs/adr/`):**
- Godot latest stable 4.x, GDScript strictly typed, Forward+, 1080p 16:9. (0001)
- Single owned **GameState** tree as the only stateful autoload. (0002)
- Central **EventBus** for all cross-system signals. (0003)
- **Discrete SimClock** — one authoritative tick, interpolated rendering;
  speed 0/1/2/4×; never auto-pauses for UI. Fixes the time clunk. (0004)
- **Spatial flight, static bodies, burn-intensity** lever. Static bodies kill
  the moving-target problem; a named flight state machine stays extensible.
  Fixes the flight clunk. (0005)
- **Diegetic terminal UI** — persistent live main view, full-screen menu
  layouts over it, stylistic (no bezel). Fixes the UI-flow clunk. (0006)
- **Config-driven UI components** fed data + layout. (0007)
- **Save schema from the start**, versioned + forgiving. (0008)
- **GUT testing from the start** on pure `core` logic. (0009)

**Five autoloads, no more:** EventBus, GameState, SimClock, SaveManager,
TypeRegistry.

**α0.1 "The Ship Flies" — done =** plot a course with burn choice, fly it on
the clock, spend/refuel reaction mass, save/load the run, and it feels good.
Build order and scope in `docs/ALPHA-0.1-SPEC.md`.

**Flagged for a later design-doc revision:** flight/travel section, the UI
model, and ship progression/tiers — the rebuild supersedes parts of the
original doc in these areas.

**Open / assumed:** GitHub remote to be created at project init; exact Godot
patch version to pin at scaffold time.

**Next session:** review these docs, sign off or adjust, then scaffold the
project.
