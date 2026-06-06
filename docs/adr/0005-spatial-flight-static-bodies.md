# ADR 0005 — Spatial flight, static bodies, burn-intensity

**Status:** accepted · **Date:** 2026-06-06

## Context
Flight felt clunky in the POC for two concrete reasons the developer named:
**no real pathfinding**, and **contending with moving targets** (chasing a
body while it orbits). The player wanted *more control* but course-setting
felt limited.

## Decision
- **Bodies are static.** Planets and stations hold fixed positions in a
  system. No orbital motion at flight timescales → no moving target, no
  intercept math. (Cosmetic orbits could be added later without affecting
  navigation.)
- **Flight is spatially real.** The ship occupies a real `(x, y)` in the
  system world; the camera follows it. The player commands courses, not
  thrust.
- **`FlightController` state machine**, extensible by adding states:
  `Idle → CourseSet → Engaging → Accelerating → Cruising → Decelerating →
  Arriving → InOrbit`, with `Abort` returning to `CourseSet` from any moving
  state.
- **Course command flow:** click a body → preview ETA + reaction-mass cost →
  confirm to engage.
- **Burn intensity** (`Economy / Standard / Hard`) is the control lever: a
  real time-vs-fuel tradeoff per course. Higher burn = shorter ETA, more
  reaction mass.
- **Progress advances per SimClock tick**; rendered position interpolates
  between ticks (see ADR 0004).

## Why
Static bodies remove the exact thing that made flight feel bad, with near-zero
downside this early. A named state machine makes flight legible and easy to
extend (the developer explicitly wanted "a flight state engine we can amend
later"). Burn intensity gives the requested "more control" while staying true
to "command courses, not vectors," and seeds richer controls (waypoints,
approach choice) later without changing the machine.

## Consequences
- Orbital mechanics are explicitly out of scope; revisit only if the design
  ever demands moving bodies.
- ETA/fuel math lives in `src/core` as pure, GUT-tested functions.

## Alternatives rejected
- **Orbit + auto-retargeting course** and **orbit + intercept solve** — both
  reintroduce the moving-target problem we're trying to eliminate.
