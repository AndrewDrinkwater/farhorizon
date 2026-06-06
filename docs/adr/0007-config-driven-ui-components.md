# ADR 0007 — Config-driven UI components

**Status:** accepted · **Date:** 2026-06-06

## Context
The terminal UI (ADR 0006) needs many panels, readouts, gauges, and alarm
lights across many screens. Hand-building each screen one-off is slow and
inconsistent — and was part of the POC's UI clunk.

## Decision
Build a **library of configurable components**, each taking a *data binding*
(what to read) and a *layout spec* (where/how to draw). Screens are assembled
from these components.

Initial component set:
| Component | Purpose |
|-----------|---------|
| `TPanel` | Container / framed region, variable size |
| `TButton` | Command button → emits an intent on EventBus |
| `TReadout` | Labeled value, bound to a GameState path |
| `TGauge` / `TBar` | Segmented / continuous level (fuel, progress) |
| `TLight` | Status dot / alarm light, state-driven color |
| `TList` | Scrollable list of records |
| `TDisplay` | Generic variable-size display region |

Rules:
- Components **read** by binding to GameState; they **write** only by emitting
  intents on EventBus. They never mutate state directly.
- A screen = a layout that places components and wires their bindings.

## Why
Config-driven components make new terminal screens cheap and visually
consistent, and enforce the "UI sends intents, never mutates" principle in one
place. It matches the developer's framing: components fed data + layouts, with
multiple types (buttons, variable-size displays, alarms/lights).

## Scope note
We chose **config-driven components**, *not* full resource-authored layouts.
Layouts are built in code/scenes for now; promoting layouts themselves to
`.tres` is a possible later step if it earns its keep. Avoids over-engineering
the UI before the loop exists.

## Consequences
- A little upfront engineering on the component API before screens get fast.
- The minimal theme + 2–3 core components come first; the rest grow as screens
  need them (not a full library up front).

## Alternatives rejected
- **Resource-authored layouts now** — powerful but over-built for this stage.
- **Hand-placed one-off components** — simpler but reproduces inconsistent,
  slow-to-build screens.
