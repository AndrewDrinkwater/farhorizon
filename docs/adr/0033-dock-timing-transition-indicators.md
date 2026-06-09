# ADR 0033 — Dock/undock timing + transition indicators

**Status:** accepted · **Date:** 2026-06-09
**Builds on:** ADR 0015 (travel pipeline), ADR 0029 (timed transitions + the
modifiable-stat pattern), ADR 0014 (order lifecycle), ADR 0012.

## Context
Docking and undocking are **instant** today, while landing/take-off are timed —
inconsistent, and they skip the "manoeuvre takes time" beat. And the timed
vertical transitions (descent/ascent) have no visual: the captain can't *see* the
ship moving through the atmosphere. Add timed dock/undock and give both families
of transition a clear indicator.

## Decision

### Timed dock / undock
Dock and Undock become **timed transitions** on the discrete clock, consistent
with land/take-off (ADR 0029): new motion phases `DOCKING` / `UNDOCKING`, duration
a **modifiable stat** — `base_dock_ticks` / `base_undock_ticks` on `ShipState`
(future modifiers appended per ADR 0029). **Time only** (no RM). Refuel completes
on dock arrival (unchanged). Order availability/flow otherwise unchanged; an
in-progress dock/undock recomputes on load (ADR 0008).

### Altitude / atmosphere indicator (land / take-off)
A vertical gauge shown during descent/ascent: the body's atmosphere drawn as
**bands** derived from `atmosphere_atm` (the class bands None→Crushing, or a
pressure scale; ADR 0029), ground at the bottom, orbit at the top, with the **ship
marker moving down (descent) / up (ascent)** along it plus progress/ETA. Vacuum
shows a single "no atmosphere" band. A reusable component
(`AltitudeIndicator` / a banded `TGauge`).

### Dock approach indicator (dock / undock)
A simpler linear **approach progress** indicator (ship → docking ring) with ETA —
distinct from the vertical altitude gauge (a dock is a lateral approach, not a
descent), same "timed-transition feedback" family.

Both indicators appear only during their transition, reinforcing the order
lifecycle's *executing* beat (ADR 0014); state shown with shape/label, not colour
alone (ADR 0012); `tr()` labels.

## Consequences
- `FlightController` dock/undock become timed (`DOCKING`/`UNDOCKING` phases);
  `ShipState` gains `base_dock_ticks` / `base_undock_ticks`.
- New `AltitudeIndicator` (banded) + a dock approach indicator component; shown in
  the Helm's Flight Status / a transition overlay.
- New strings: `FLIGHT_STATE_DOCKING` / `_UNDOCKING`, indicator labels.
- `docs/landing.md` notes the altitude indicator; `helm.md` notes the indicators.

## Alternatives rejected
- **Keep dock/undock instant** — inconsistent with land/take-off and skips the
  manoeuvre beat the game leans on.
- **One generic indicator for both** — a vertical altitude band and a lateral dock
  approach read differently; two small purpose-built indicators are clearer than
  one compromised one.
- **Charge RM for docking** — out of scope here (could become a future modifier);
  time-only keeps it consistent with landing.
