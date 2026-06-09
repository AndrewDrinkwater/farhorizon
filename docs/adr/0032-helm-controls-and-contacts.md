# ADR 0032 — Helm control groups + Nav contacts directory

**Status:** accepted · **Date:** 2026-06-09
**Builds on:** ADR 0013 (consoles), ADR 0007 (components), ADR 0025 (target info),
ADR 0015/0029/0030 (orders / context), ADR 0017 (contacts), ADR 0012.

## Context
The Helm carries ~15 action buttons in one flat set, most irrelevant to the
ship's current situation (Land only matters in orbit at a landable body; Dock only
at a station; surface Move only when landed). It reads as a wall of buttons, not a
control panel. There's also no list of what the ship is picking up.

## Decision

### Contextual control groups
Regroup the Helm's actions into labelled **clusters by function**:
- **Flight** — Lay In, Engage, Belay, All Stop, Clear Course
- **Docking** — Dock, Undock
- **Surface** — Land, Take Off, Move
- **Sensors** — Scan, Focus

A cluster **hides entirely when it doesn't apply** to the ship's current context
(derived from `Travel.available` + `location`): Docking appears only at a station,
Surface only in orbit at a landable body or when landed, etc. Within a *visible*
cluster, individual buttons still enable/disable per `Travel.available` — so the
captain sees what's possible *here*, greyed when not possible *now*. This both
unburdens the panel and gives the situation-aware "control panel" feel.

A small **context resolver** (pure, testable) maps ship context → which clusters
show; the Helm reads it and the controller already validates against
`Travel.available`, so the rule lives in one place.

### Nav contacts directory
A panel listing **all selectable targets** — charted bodies **and** transient
contacts — as a **hierarchy** and **filterable**:
- **Hierarchy:** star → planets → moons (parent-relative, ADR 0018); transient
  contacts grouped (by kind, or under "Contacts"). Reuses the body/contact model.
- **Filters:** by type/kind, by sensor tier (Blip / Identified, ADR 0017), and
  in-range — quickly narrow a busy system (Calder).
- Selecting an entry drives selection (`nav_target_selected` / contact id) →
  Target Info + plotting; inline scan/focus affordance where applicable.
- Derived from the system + live detection state; nothing new to save.

All `tr()` labels; state via shape/label not colour alone (ADR 0010/0012).

## Consequences
- Helm refactors into clustered control groups + the context resolver (which
  clusters show); `helm.md` layout updated.
- New **contacts directory** panel (tree + filter chips); new strings (cluster
  headers `HELM_GRP_*`, filter labels, directory headers).
- Pairs with ADR 0031: the directory lives in the Helm console now; could become
  its own view later. No order-lifecycle change (ADR 0014).

## Alternatives rejected
- **Group but always show every button (grey out)** — nothing ever disappears, so
  the panel stays a wall; the captain wanted unburdening.
- **Flat contact list** — doesn't scale to a dense system; the hierarchy + filters
  are what make a busy directory usable.
