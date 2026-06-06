# α0.2 — "Navigation II: the Instrument"

**Status:** planned (pre-code) · **Goal:** the Helm Nav Plot becomes a legible
navigation *instrument* — an orrery chart with moons, sensor-detected contacts,
and a tactical scope — without changing the realistically-scaled simulation.

α0.1 proved the ship flies through real, AU-scaled space. That realism is great
for the *sim* (fuel, ETA) but hurts *reading* the system (40× span). α0.2
separates presentation from simulation: real coordinates stay the truth; the Nav
Plot draws them through a tested projection, adds body hierarchy (moons), and
folds in sensor range so navigation has decisions beyond "fly to the big rock."

Decisions: **ADR 0016** (orrery), **ADR 0017** (sensors/contacts), **ADR 0018**
(hierarchical bodies). Implementation companion: **`docs/navigation.md`**.

---

## Definition of done

α0.2 is complete when **all** of these are true:

1. **Orrery chart.** The whole system reads on one screen: radius log-compressed
   onto rings, **bearing exact**. Bodies, orbit rings, the ship marker, and the
   course line all render through the projection. Real distances / fuel / ETA are
   **unchanged** (verified: the same trip costs the same as in α0.1).
2. **Moons.** At least one planet has a moon (or moons). Moons render distinctly
   near their parent (no overlap), and are targetable / flyable like any body via
   Helm. A planet can be **focused** to inspect and target its moons.
3. **Sensors & contacts.** Charted (gravimetric) bodies are always shown.
   Transient (non-gravimetric) contacts — at least two authored — appear only
   within sensor range, as distinct **shape** icons that wink in/out as coverage
   changes. Detection is decided in **real space on `sim_tick`** (segment-checked,
   so warp can't skip a contact), and detection state is **saved**.
4. **Tactical scope.** A ship-centred, **true-scale** view shows the sensor range
   as a real circle with contacts inside it (the orrery never draws the warped
   bubble).
5. **It reads well.** A captain can take in the whole system at a glance, see
   where moons and contacts are, and target any of them — with none of the
   40 AU "everything's a dot in a corner" problem.
6. **Green tests.** GUT covers the `core`: orrery projection (incl. moons +
   bearing/monotonicity), sensor detection (incl. boundary + segment crossing),
   and contact-state save round-trip.

---

## In scope

- **`OrreryProjection`** (`src/core`) — pure log projection, parent + child
  (moon) variants, GUT-tested. Nav Plot becomes a thin renderer over it.
- **Body hierarchy** — `BodyData.parent_id`; author a moon or two into Sol;
  parent-relative projection; focus-a-body sub-view for moon targeting.
- **`ContactData`** authored type + transient entities listed in `SystemData`.
- **`Sensors`** (`src/core`) — `contacts_in_range` / segment check, pure + tested.
- **Detection wiring** — a `sim_tick`-driven system node; `EventBus` contact
  signals (`contact_detected` / `contact_lost` / `contact_promoted`); detection +
  tier state in `GameState` (saved, ADR 0008).
- **Orrery render of contacts** — transient shapes winking in/out.
- **Tactical scope** — true-scale ship-centred view + sensor circle, on the Helm.
- **Sensor radius** as a ship/hull base stat (a constant now; a hook for crew /
  refit later).
- Feel pass on the tuning knobs.

## Out of scope (deferred)

- **Scan / identify action** beyond passive detection (the `BLIP → IDENTIFIED`
  step as a player order) — detection lands; identifying is a later slice.
- Procedurally generated contacts (authored `.tres` for now).
- Multi-system / warp between systems, galaxy map.
- Crew actually widening sensor range (hook only; the crew system is later).
- The warped sensor bubble drawn on the orrery (optional future glow).
- Body nesting deeper than planet → moon.

---

## Suggested build order

Each step ends runnable and, where it's `core`, tested.

1. **`OrreryProjection` core + tests** — star-relative log projection; bearing,
   monotonicity, clamps, anchors (1 / 5.2 / 9.5 / 40 AU all land ordered between
   the rings).
2. **Orrery Nav Plot** — render bodies, orbit rings, ship, and the course line
   through the projection (project about the system's star body; sample the real
   path so the course curves). Confirm the system reads on one screen.
3. **Moons** — `BodyData.parent_id`; `project_child` + tests; author a moon;
   parent-then-child render; no overlap.
4. **`ContactData`** type + a couple of transient entities in `SystemData`.
5. **`Sensors` core + tests** (point + segment), the tick-driven detection node,
   `EventBus` contact signals, and saved `GameState` detection/tier state.
6. **Contacts on the orrery** — transient shape icons winking in/out.
7. **Focus-a-body sub-view** — expand a planet to inspect/target its moons
   (may be trimmed/deferred if step 3's render is already legible enough).
8. **Tactical scope** — true-scale ship-centred view, sensor circle + contacts.
9. **Feel pass** — log base / ring band, moon cluster band, sensor radius,
   contact glyphs. DEVLOG; confirm ADRs 0016/0017/0018.

---

## Tuning knobs (placeholders, expect to change by feel)

- Orrery `r_min` / `r_max` / `ring_inner` / `ring_outer` / log base.
- Moon local band (`moon_r_min/max`, `moon_ring_inner/outer`).
- Sensor radius (per hull); default tactical-scope zoom.
- Contact glyphs/shapes per kind; ring opacity.

None of these touch logic — they're data/constants, tuned late, like α0.1.
