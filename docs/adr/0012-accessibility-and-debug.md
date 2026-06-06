# ADR 0012 — Accessibility palette and debug overlay

**Status:** accepted · **Date:** 2026-06-06

## Context
The terminal UI leans heavily on colour — alarm lights, status dots, flight
state colours. Colour-only encoding excludes colourblind players and is hard to
unpick once a whole component library depends on it. Separately, a time-driven
sim is much easier to develop with a live debug view.

## Decision
**Accessibility:**
- Adopt a **colourblind-safe palette** for status/alarm colours from the start.
- **Never colour alone:** every state encoded by colour is *also* encoded by an
  icon, label, or shape. A `TLight` shows colour **and** a glyph/state text; a
  flight state is named, not just tinted.
- Bake this into the component contracts (ADR 0007) so screens can't
  accidentally rely on colour only.
- A high-contrast / colourblind toggle is a `ConfigManager` setting (ADR 0011).

**Debug overlay:**
- A **toggleable debug overlay** (bound to the `toggle_debug` input action)
  shows live sim internals: current tick, sim speed, ship position/heading,
  fuel pools, flight state, FPS.
- It reads GameState only; it never mutates. Off by default; not in release UI.
- A lightweight logger writes structured debug lines (exempt from localisation,
  ADR 0010).

## Why
Colourblind-safe + never-colour-alone is far cheaper to honour while the
component library is small than to retrofit later. The debug overlay pays for
itself immediately when tuning the clock, burns, and flight.

## Consequences
- Components carry a non-colour channel for state — a minor design constraint
  with broad payoff.
- The debug overlay is an early, reusable development tool.
