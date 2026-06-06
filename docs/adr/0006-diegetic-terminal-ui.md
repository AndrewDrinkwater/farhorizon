# ADR 0006 — Diegetic terminal UI

**Status:** accepted · **Date:** 2026-06-06

## Context
UI flow was a named clunk. The developer's vision: *"I am a captain using a
terminal"* — a default main screen with full-screen layouts for menus, rather
than tabbing through disconnected screens.

## Decision
- **Stylistic terminal, no bezel.** Sci-fi console aesthetic (panels,
  readouts, alarm lights) that reads as a ship terminal, but no drawn cockpit
  frame — keeps it flexible and not art-bound.
- **Persistent main view:** the bridge terminal = system map + live HUD, clock
  always running and visible.
- **Menu layouts** (SHIP, CARGO, …) open as full-screen terminal layouts
  *over* the main view, never hiding that time passes.

## Why
The persistent, always-live main view fixes the POC's modal, time-hiding
screen flow and reinforces the "time is a resource" pillar. The terminal
fantasy gives the UI a coherent identity instead of being a stack of menus.
"No bezel" avoids a large art commitment while keeping the feel.

## Consequences
- Screens are layouts over a persistent shell, not separately-loaded scenes
  (avoids scene-reload jank and keeps HUD/clock persistent).
- The component library (ADR 0007) is what makes assembling these terminal
  layouts cheap.

## Alternatives rejected
- **Literal console bezel** — stronger fantasy but a real art commitment, and
  constrains layout flexibility.
- **Full-screen scene swap per screen** — reintroduces the disconnected,
  time-hiding flow we're removing.
