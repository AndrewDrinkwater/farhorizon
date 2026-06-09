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
