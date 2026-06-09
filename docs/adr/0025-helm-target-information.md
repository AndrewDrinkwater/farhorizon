# ADR 0025 — Helm Nav: Target Information panel replaces the Order Log

**Status:** accepted · **Date:** 2026-06-08
**Builds on:** ADR 0013 (consoles), ADR 0014 (order lifecycle), ADR 0017
(sensors/tiers), ADR 0019 (travel-time), ADR 0020 (nav targets & scan).
**Supersedes:** the Order Log region of the Helm (`docs/consoles/helm.md`). The
order *lifecycle* (ADR 0014) is unchanged — only its display moves.

## Context
On a navigation-focused console, a persistent acknowledgment log earns less
screen than information about the thing you've selected. Replace the Order Log
with a **Target Information** panel; relocate the brief ship-voice
acknowledgments to a transient line in Flight Status.

## Decision
Replace `_build_order_log` / `_order_log` (the `TList`) with a **Target
Information** panel (`HELM_TARGET_INFO`). Its contents are driven by the current
selection and are **burn-aware** (recompute on `nav_burn_changed`), reusing
`Travel.TargetKind`:

- **Charted body** (`BODY`): name; kind (Star / Planet / Moon / Station); parent
  (if a moon); distance (AU + wu); ETA at the current burn; RM cost; reachability
  (round-trip OK on current RM?); dock / refuel availability; a "has moons →
  Focus" affordance.
- **Contact** (`CONTACT`): name, or "Unknown contact" while a Blip; kind; sensor
  tier (Blip / Identified); distance; ETA / RM; scan availability (in range and
  not yet identified).
- **Waypoint** (`POINT`): bearing + distance; ETA; RM.
- **Nothing selected** (`NONE`): a short overview hint (e.g. body/contact counts,
  nearest unscanned contact).

**Acknowledgments relocate.** `order_acknowledged(voice, line)` (and
`order_rejected`) show as a **transient line in the Flight Status region** that
fades after a few seconds — no persistent log on the Helm. This keeps the
captain-voice beat (ADR 0014) without spending a whole panel on history.

Reuses existing logic: `FlightMath.eta_ticks` / `reach_wu` (ADR 0019), fuel,
sensor tier from `GameState`. Every state shown with a label/shape, not colour
alone (ADR 0012); all text via `tr()` (ADR 0010).

## Consequences
- `helm.md` layout: the Order Log row becomes **Target Information**; Flight
  Status gains a transient acknowledgment line.
- New strings: `HELM_TARGET_INFO` + field labels (type, parent, reachable, scan
  tier, dock/refuel) + a `HELM_TARGET_NONE` overview hint.
- No change to the order lifecycle (ADR 0014); only its presentation moves.
- The panel is a natural home later for richer body data (aspects, survey tiers).

## Alternatives rejected
- **Keep both log + target info** — Helm real estate is limited; the swap is the
  point.
- **Target info as a hover tooltip** — selection is explicit and persistent; a
  fixed panel reads better and survives the mouse leaving the body.
