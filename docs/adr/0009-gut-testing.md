# ADR 0009 — GUT testing from the start

**Status:** accepted · **Date:** 2026-06-06

## Context
This is the "slower and properly" rebuild. The developer chose GUT (Godot Unit
Test) from the start. We want rigor without making iteration miserable.

## Decision
- Install **GUT** at project init.
- **Pure logic lives in `src/core`** with no node dependencies, so it's
  unit-testable without running the game: SimClock tick math, flight ETA/fuel
  math, save round-trip, future mission rolls.
- Tests in `tests/` mirror `src/core`.
- Nodes (`flight/`, `world/`, `ui/`) stay thin shells over `core` logic and are
  exercised manually in-editor for feel.

## Why
Testing the *logic* (not the nodes) gives most of the safety for a fraction of
the effort, and forces a clean separation: pure functions in `core`, thin
nodes around them. That separation is itself an anti-clunk measure.

## Consequences
- Discipline to keep game logic out of `_process`/node code and inside
  testable `core` functions.
- A green test run is part of "done" for any `core` system.

## Alternatives rejected
- **Manual only** — too little safety for a "proper" rebuild.
- **GUT on everything incl. nodes** — slow and brittle; node behavior is better
  judged by feel in-editor.
