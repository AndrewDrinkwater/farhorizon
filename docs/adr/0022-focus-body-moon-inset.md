# ADR 0022 — Focus-a-body moon inset + moon orbit rings

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0016 (orrery), ADR 0018 (hierarchical bodies), ADR 0021
(scale modes). Closes the focus-a-body sub-view deferred from α0.2 (step 7).

## Context
Moons render as a small local cluster (~16–44 px) about the parent's projected
point (ADR 0018) — legible enough to see, but cramped: hard to read separations,
hard to click, and the orrery draws **no orbit rings** for them. α0.2 deferred a
"focus a planet to inspect/target its moons" sub-view. The captain now wants it,
with the key constraint that **the chart must show which planets have moons**
before any focus gesture is meaningful.

## Decision

**1. Moon orbit rings on the orrery.** The ring pass draws a faint ring for each
moon, centred on the **parent's projected point**, at the moon's projected local
radius (`(project_child(moon) − parent_proj).length()`). In LINEAR scale (ADR
0021) moons collapse onto the parent, so rings under ~2 px are skipped (honest,
uncluttered).

**2. "Has moons" affordance.** A planet with children draws a distinct
**satellite halo** (a thin ring just outside its marker) plus *n* small pips for
*n* moons — shape + count, never colour alone (ADR 0012). This is the cue that a
planet is focusable. `OrreryView` precomputes `parent_id → [moons]` at build.

**3. Trigger.** A Helm **"Focus" button**, enabled only when the selection is a
moon-bearing planet (explicit, discoverable — matches the Helm-control choice in
ADR 0021), **plus re-clicking the already-selected planet** as a shortcut. Either
emits **`EventBus.nav_focus_requested(body_id)`**.

**4. The inset (picture-in-picture).** A new presentation node, `MoonInsetView`,
anchored in a corner over the Nav Plot, hidden until a focus request. It shows
the focused planet centred and its moons by a **local linear layout** (true
offsets scaled to fill the inset — the room they never get in the full chart),
each moon with its own orbit ring. Moons are **clickable → `nav_target_selected`**;
since a moon is a `BodyData`, the existing course/scan pipeline flies to it
unchanged. A small **✕/Back** closes it (`nav_focus_closed`); focusing another
planet rebuilds it. The inset is **independent of the orrery scale mode** — always
a clear local view.

The local layout is a pure helper (`OrreryProjection.project_satellite` or a small
local-scale function): moon offset-from-parent → inset position, GUT-tested
(ordering + bearing + round-trip). The inset node itself is presentation
(smoke-built in tests, like the Helm console).

## Why
The inset preserves system context (the orrery stays visible) while giving moons
the space the compressed chart can't; the affordance + explicit Focus button make
a hidden capability discoverable; reusing `BodyData` + `nav_target_selected` means
no new course machinery.

## Consequences
- New `EventBus.nav_focus_requested(body_id)` + `nav_focus_closed()`.
- New `MoonInsetView` node (added in `main.gd` beside the orrery/scope).
- `OrreryView`: `_moons_by_parent`, the halo/pip affordance, moon orbit rings,
  and re-click→focus; Helm gains a Focus action gated on "selection has moons".
- Pure satellite-layout helper, GUT-tested.

## Alternatives rejected
- **Full-view zoom + Back** — loses the system context the inset keeps; the
  captain chose picture-in-picture.
- **Expanding drawer in place** — overlaps neighbouring bodies on the cramped
  chart.
- **No affordance, double-click only** — hidden; the captain explicitly wanted
  it evident that a planet has moons.
