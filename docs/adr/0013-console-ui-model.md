# ADR 0013 — UI organized as captain's consoles

**Status:** accepted · **Date:** 2026-06-06
**Supersedes:** the flat screen list (NAV/SHIP/CREW/…) implied by the design doc.

## Context
The UI is a diegetic ship terminal (ADR 0006) operated by a captain. A flat
list of screens doesn't match that fantasy. The captain works **consoles** —
posts on the bridge — each grouping the orders and readouts for one domain.

## Decision
The organizing unit of the UI is the **console**, not a screen.
- **Helm** is the first console (flight + navigation). Others follow: Ops,
  Science, Comms, Engineering, etc. The old screen list reorganizes into these.
- A console is a layout assembled from config-driven components (ADR 0007),
  opened over the persistent terminal shell with the mission clock still
  running (ADR 0006).
- Each console is a **post** that can be manned by a crew officer later; manning
  affects voice (ADR 0014) and, eventually, capability.

## Why
Consoles match the "captain operating a terminal" model, give the UI a coherent
identity, and create a natural home for the crew/station system: a console is a
post an officer can occupy. It also scales — new domains are new consoles, not
ad-hoc screens.

## Consequences
- Per-console specs live in `docs/consoles/` (see `helm.md`).
- The α0.1 spine is played through the Helm console.
- "Screen" terminology is retired in favour of "console" for operational UI.
  (Plainer management views, if any, can still exist but are the exception.)
