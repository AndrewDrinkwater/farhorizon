# ADR 0008 — Save schema designed from the start

**Status:** accepted · **Date:** 2026-06-06

## Context
Retrofitting save/load onto a game built without it is painful and was a
fragility point before. Save is also explicitly an α0.1 deliverable.

## Decision
- Architect `GameState` to be **serializable from day one** (ADR 0002), and
  implement a **minimal but real** save/load in α0.1.
- **`SaveManager`** autoload owns serialize/deserialize. It walks the GameState
  tree; no system serializes itself.
- **Schema-versioned:** a version integer at the top of the save, with
  migration hooks per version.
- **Forgiving load:** missing keys fall back to defaults so older saves survive
  schema growth. (The one genuinely good idea carried from the POC.)
- References to authored content saved **by id**, rebuilt via TypeRegistry on
  load.

## Why
Designing for serialization upfront costs little and avoids a painful later
refactor. A versioned, forgiving format means the schema can grow across the
whole build without breaking saves each time a field is added.

## Consequences
- Every new persistent field must be added to `to_dict`/`from_dict` and given a
  sensible default — a small, consistent tax.
- Save round-trip is GUT-tested from the start.
