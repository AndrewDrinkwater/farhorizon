# ADR 0018 — Hierarchical bodies: moons and parent-relative orrery

**Status:** accepted · **Date:** 2026-06-06
**Builds on:** ADR 0005 (static bodies, real coords), ADR 0016 (orrery Nav Plot),
ADR 0002 (authored data by id).

## Context
α0.2 adds **moons** — charted bodies that orbit a planet rather than the star.
Two problems fall out of the existing model:

1. **Projection overlap.** The orrery (ADR 0016) compresses radius **about the
   star**. A moon a hair further out than its planet (e.g. 1.0 vs 1.002 AU) lands
   on essentially the same ring — moon and planet collapse into one dot.
2. **"Orrery" can imply animation.** An orrery traditionally *moves*. ADR 0005
   deliberately made bodies **static** to remove the moving-target navigation
   problem; moons must not quietly reopen that.

## Decision
**Body hierarchy via `parent_id`.** `BodyData` gains an optional `parent_id`:
star → none; planet → the star (implicit/none is fine); moon → its planet. α0.2
is two levels deep (planet → moon); the field generalises but deeper nesting is
out of scope.

**Positions stay absolute real world-units** — the single source of truth (ADR
0005). A moon is authored at its real absolute position (near its parent). The
**flight system treats every body uniformly**: a moon is just another charted
body to target, hold at, and burn toward — no special travel code. Fuel/ETA are
unchanged.

**Static positions reaffirmed.** Body positions do not change at runtime. Any
orbital motion is **cosmetic only** (a view effect, like the ship's holding
orbit) and never alters a body's real position or a laid-in target. The orrery is
a *display style*, not animated orbital mechanics.

**Parent-relative orrery projection.** Parents project about the star (ADR 0016);
children project in a small **local cluster** about their parent's projected
point — the child's real offset-from-parent, bearing preserved, compressed onto a
small pixel band. Pure `core` (`OrreryProjection`), GUT-tested. See
`docs/navigation.md` for the `project_child` contract.

**Focus-a-body sub-view.** At strategic zoom a dense moon cluster still crowds, so
a planet can be **focused** (click/zoom) to expand and target its moons locally —
distinct from the system orrery. (Targeting a moon happens here.)

## Why
Moons add navigational texture — sub-destinations and places to tuck POIs — with
zero change to the flight sim. Parent-relative projection keeps them legible on
the orrery; absolute static positions preserve the ADR 0005 win and keep the save
trivial.

## Consequences
- `BodyData` gains `parent_id` (authored content; resolved via TypeRegistry, not
  saved state).
- `OrreryProjection` gains child projection + tests; the Nav Plot renders parents
  then children.
- A focus-a-body interaction on the Helm (may be deferred within α0.2).
- No change to `FlightController`, fuel, or save schema.

## Alternatives rejected
- **Animate orbits** — reintroduces moving targets (ADR 0005's whole point).
- **Project moons about the star** — the overlap that prompted this.
- **Fold moons into their planet** (one marker) — loses moons as real,
  flyable sub-destinations.
