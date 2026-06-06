# ADR 0016 — Orrery Nav Plot: log-compressed display

**Status:** accepted · **Date:** 2026-06-06
**Builds on:** ADR 0005 (spatial flight, static bodies, real coords), ADR 0015
(travel pipeline), ADR 0006/0013 (terminal UI / consoles).
**Supersedes:** the true-scale Nav Plot *layout* from the "Nav Plot chart aids"
work (display only — simulation distances are unchanged).

## Context
Distances are realistically scaled and that's valuable in the *simulation* —
Verdant 1 AU, Rubicon 5.2 AU, Anchorage 9.5 AU, Tethys 40 AU (`WU_PER_AU =
1000`); fuel and ETA depend on them. But on the *display* a 40× span means you
can't see the whole system at once and the inner bodies crowd, even with
constant-size markers and a free camera. The captain's read: realism is hurting
gameability — you can't take the system in, and target picking is fiddly.

## Decision
**Decouple presentation scale from simulation scale.** Real coordinates remain
the single source of truth (sim, fuel, ETA, flight) — untouched. The Nav Plot
renders bodies through a pure **orrery projection**:

- Convert each body's real position to polar about the star.
- **Compress the radius** with a log map onto a fixed band of screen rings;
  **preserve the bearing (angle) exactly.** Preserving angle keeps direction
  truthful; compressing radius makes the whole system legible on one screen.
- The star clamps to the hub (`log(0)` is undefined): real radius ≤ `r_min`
  maps to centre.
- Orbit rings stay, now drawn at the projected (log) radii.
- Markers/labels keep their fixed on-screen size and screen-space picking (from
  the chart-aids work) — that already fixes targeting; the orrery fixes
  see-it-all.

The projection is a **pure `core` function** (`OrreryProjection.project`,
GUT-tested); the Nav Plot node is a thin shell over it. Its parameters
(`r_min`, `r_max`, `ring_inner`, `ring_outer`, log base) are tuning constants,
not logic. The course line is drawn between projected points (gently curved by
the non-linear map); travel is still computed in real space and fast-forwarded
on the clock.

A companion **true-scale tactical scope** view (ADR 0017) provides the local,
undistorted picture; the orrery is the *strategic* chart.

See `docs/navigation.md` for the function contract, parameters, and test outline.

## Why
The orrery keeps the realistic sim (where realism pays off) while presenting it
as a legible instrument (where fun lives). It's a display transform, so it costs
nothing in the simulation and is fully reversible/tunable.

## Consequences
- New pure `core` projection function + tests; Nav Plot becomes a thin renderer
  over it.
- Orbit rings and course line move to projected space.
- Tuning knobs are data; the log base / ring band are play-tuned by feel.

## Alternatives rejected
- **Keep true scale** — the status quo that prompted this; can't show the system
  at once.
- **Rank/index ring spacing** (place bodies by sorted distance, ignoring
  magnitude) — maximally schematic and legible, but loses the felt sense that
  Tethys is *far* out. Kept as a possible toggle, not the default.
- **Node-graph chart** (bodies as nodes, no spatial layout) — most legible but
  discards direction/position; the orrery keeps the explorer's spatial feel.
