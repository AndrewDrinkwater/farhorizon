# ADR 0002 — Central GameState as the single state tree

**Status:** accepted · **Date:** 2026-06-06

## Context
The POC's clunk was partly tangled, distributed state — hard to change one
system without breaking another, and awkward to save. We need a clean
save/load story and easy cross-system reads.

## Decision
A single autoload, **`GameState`**, owns the entire runtime state tree (ship,
loaded system, clock values, fuel, run flags) as typed plain objects. It is
the *only* autoload that holds run state. Every state object implements
`to_dict()` / `from_dict()`. References to authored content are stored **by
id** (e.g. `hull_id = "scout"`), resolved through `TypeRegistry` on read.

## Why
- **Save = serialize one tree.** No system serializes itself ad hoc.
- **One place to look** for "what is true right now."
- **Clean separation** from authored Resource data (see ADR 0007/0002's
  partner rule): state never embeds Resources, only ids.

In Godot terms: an autoload is a globally-accessible singleton node. Keeping
exactly one stateful autoload means there's never ambiguity about where the
truth lives.

## Consequences
- Systems must route mutations through GameState rather than holding their
  own copies. Slightly more discipline, much easier saves.
- Change signals (via EventBus) notify the UI when state changes, since the
  UI binds to GameState for reads.

## Alternatives rejected
- **Distributed state across nodes** — more "Godot-native," but reproduces
  the POC's cross-system read and save pain.
