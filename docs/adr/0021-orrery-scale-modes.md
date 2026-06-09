# ADR 0021 — Orrery scale modes (schematic ↔ true scale)

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0016 (orrery projection), ADR 0019 (travel-time legibility).

## Context
The strategic Nav Plot (`OrreryView`) log-compresses radius so the whole system
reads on one screen (ADR 0016). That's the right *default*, but it deliberately
distorts distance — a captain sometimes wants to see the **real layout** (how far
Tethys actually is). The ship-centred tactical scope (ADR 0017) is true-scale but
*local*; there's no true-scale view of the *whole system*.

## Decision
Give the orrery a **scale mode**, switchable from the Helm, keeping the same
star-centred, whole-system, bearing-exact framing in both:

- **`LOG`** (default) — today's log-compressed radius (ADR 0016).
- **`LINEAR`** — radius proportional to real distance (`r_max → ring_outer`); the
  true picture (inner system small, outer system accurate).

The mode lives on **`OrreryParams.mode`** (`enum ScaleMode { LOG, LINEAR }`), so
the four `OrreryProjection` functions keep their **exact signatures** and branch
only on the radius mapping — the view doesn't fork:

- `project` — LOG: log map. LINEAR: `clampf(r / r_max, 0, 1) * ring_outer`.
- `unproject` — inverse of each (LINEAR: `radius_px * r_max / ring_outer`).
- `project_path` — in LINEAR there is no hub singularity, so it equals `project`
  (a near-star course is a straight line through the centre, which is correct).
- `project_child` — LINEAR uses the moon's true scaled offset (moons collapse
  onto the parent — honest at true scale; targeting them uses LOG mode or the
  focus inset, ADR 0022).

**Flipping it:** a Helm segmented control (`Schematic | True scale`) mirroring the
burn selector; emits **`EventBus.nav_burn_changed`**'s sibling
**`nav_scale_changed(mode)`**; `OrreryView` rebuilds params + redraws. The control
carries a text label, so the mode isn't signalled by colour alone (ADR 0012).

**Not saved run state.** Scale is a view preference, so it stays out of
`GameState` (ADR 0008): ephemeral, defaults to `LOG` each session. Persisting it
via `ConfigManager` is a later nicety.

**Amended 2026-06-09 — context-aware toggle.** The scope (ADR 0017) is always
true-scale, so the Schematic/True-scale switch is inert there. The one Helm toggle
is now retargeted by the active view (`EventBus.nav_view_changed`): in the orrery
it flips scale (this ADR); in the tactical scope it flips the concentric **ring
mode** between **ETA** (isochrones, burn-aware — ADR 0019) and **flat distance**
(range rings in AU), via `nav_ring_mode_changed` → `TacticalView.RingMode`.

## Why
One mode flag on the pure params keeps a single projection contract and a single
renderer; the captain gets the real layout on demand without losing the schematic
default or the ship-centred scope.

## Consequences
- `OrreryProjection` grows LINEAR branches (pure, GUT-tested both ways); existing
  LOG tests stay green (default mode unchanged).
- New `EventBus.nav_scale_changed`; a Helm scale control (active-state + initial
  broadcast on `_ready`, like the burn buttons).
- The adaptive course subdivision (ADR 0016 zig-zag fix) is a harmless 1-segment
  no-op in LINEAR — no regression.
- Linear mode *could* later draw the sensor circle honestly (it's undistorted) —
  out of scope here (ADR 0017 only barred the *warped* bubble).

## Alternatives rejected
- **A separate true-scale view node** (a third scene like the tactical scope) —
  duplicates all the body/contact/course rendering; a mode flag reuses it.
- **A keyboard toggle** — the captain asked for a discoverable Helm control that
  shows the current mode.
