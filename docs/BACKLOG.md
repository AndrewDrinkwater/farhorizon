# Backlog

Parked ideas — not scheduled, not specced into ADRs. Each is a sketch to revisit
later; promote to a spec/ADR when picked up.

---

## Oblique (tilted) orrery — fake-3D Nav Plot

**Idea:** tilt the strategic orrery so the orbital plane reads as 3D, while the
game stays pure 2D. Stylistic "captain's holo-table" feel.

**Scope (as discussed):** *subtle vertical squash, orrery only* — no height axis,
scope + surface views stay flat.

**How:** a presentation-only affine transform on the `OrreryView` draw layer —
`screen_y = plane_y × cos(tilt)` (rings → ellipses). No new data, no core/logic
changes; it's another presentation transform on top of the existing log
projection (same "presentation ≠ simulation" principle as ADR 0016/0019).

**Real work / gotchas:**
- Apply the **inverse** (un-squash mouse Y) before picking / drag-to-route —
  one more step in the existing orrery inverse.
- Orbit rings, sensor circle, isochrones, zone discs become **ellipses** (scale a
  circle — easy, looks better).
- **Labels/badges stay upright** (anchor at the tilted point, don't squash text).
- Keep the tilt **mild (~25–35°)** — the orrery exists for legibility; a strong
  tilt re-crowds the vertical.
- Safe behind a toggle / tunable angle; easy to remove if it doesn't feel right.

**If promoted:** a small presentation-only ADR + a contained `OrreryView` change.
Optional later: a height/inclination axis with drop-lines for true orrery
verticality (needs a per-body elevation value).

*Parked 2026-06-09.*

---

## Moving NPCs / live contacts

**Idea:** transient contacts (ships, haulers, probes, patrols) that actually
**move** and act, instead of sitting static — so a sensor sweep feels alive and
the frontier feels inhabited.

**Why it's parked:** this is game *logic and intelligence*, not a nav refinement —
it needs its own design pass. Open questions it raises:
- **Behaviour model:** goals/states (patrol, haul a route, flee, investigate),
  not just velocity. Likely a small behaviour/FSM per contact kind.
- **Motion on the discrete clock:** contacts move per `sim_tick` in real space
  (pairs with the existing `Sensors` segment check); detection already handles
  things entering/leaving range.
- **Save:** contacts become *runtime state* (position, goal, heading), not purely
  authored — `GameState` must serialize them; authored `ContactData` becomes a
  spawn template.
- **Performance:** many moving contacts ticking + re-detection each tick.
- **Interaction surface:** do they react to the player (hail, evade, intercept)?
  Ties into a future Comms/encounter system.

**If promoted:** its own design doc + ADR(s); don't bolt onto the contact model
piecemeal. The static `ContactData` + `Sensors` work is forward-compatible (a
moving contact is a `ContactData` template + runtime motion state).

*Parked 2026-06-09.*
