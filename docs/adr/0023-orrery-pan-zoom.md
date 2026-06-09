# ADR 0023 — Orrery pan & zoom

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0016 (orrery), ADR 0021 (scale modes).

## Context
The true-scale (LINEAR, ADR 0021) orrery puts a far-out planet at the edge and
crushes the inner system into the hub — ship, planets, and labels overlap and
can't be read or clicked. A fit-to-viewport projection alone can't serve both
ends of a 40× span. The view needs to *move*: zoom into the crowded region.

## Decision
Add **mouse-wheel zoom** and **drag-pan** to `OrreryView`, applied as a screen
**view transform on top of the projection** (not baked into `OrreryProjection`,
which stays a pure fit-to-ring map):

- `_zoom: float` (clamped) and `_pan: Vector2` live on the view. A point is drawn
  at `_view(p) = center + (p - center) * zoom + pan`; input unprojects through the
  inverse `_unview`. The transform is applied inside the projection wrappers
  (`_project_real` / `_project_course_point` / `_project_bodies`), so every marker,
  ring, label, contact, and the course line move together — and **marker/label
  sizes stay constant** (only positions transform; text doesn't balloon).
- **Wheel** zooms about the cursor (the world point under the cursor stays put).
- **Right- or middle-drag** pans; left-click stays selection/waypoint/focus.
- Switching scale mode (ADR 0021) resets zoom/pan, so each mode reframes cleanly.

Applies to both scale modes (zoom is useful in LOG too); the ship-centred tactical
scope (ADR 0017) is unchanged.

## Why
A view transform is orthogonal to the projection: the pure ring map stays tested
and unaware, while the node owns interactive framing. Transforming positions (not
a `draw_set_transform` scale) keeps labels legible at any zoom.

## Consequences
- `OrreryView` gains zoom/pan state + wheel/drag input; the projection wrappers
  apply `_view`, and empty-space picking unprojects through `_unview`.
- Orbit-ring centres use the viewed hub; radii scale with zoom naturally.
- Pure `OrreryProjection` is untouched (no new tests there); zoom/pan is view
  behaviour, validated in-engine.

## Alternatives rejected
- **`draw_set_transform` scale** — scales text/markers too (labels balloon).
- **Auto-declutter only** (hide labels, shrink markers) — bodies still overlap
  *spatially* in true scale; zoom is the actual fix (declutter is complementary).
- **Bake zoom into `OrreryParams`** — couples interactive state into the pure
  projection; the transform belongs on the view.
