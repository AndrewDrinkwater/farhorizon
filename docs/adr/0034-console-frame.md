# ADR 0034 — Console frame: a data-driven ship-OS layout

**Status:** accepted · **Date:** 2026-06-10
**Builds on:** ADR 0007 (config-driven components), ADR 0013 (UI as captain's
consoles), ADR 0031 (console shell + bar), ADR 0032 (Helm control groups).
**Supersedes:** the per-console ad-hoc `_place(...)` layout in `helm_console` /
`ship_console` (the pixel-offset panels, not the orders/logic they hold).

## Context
ADR 0031 gave us a shell that hosts one console at a time. But each console then
hand-builds its own layout with magic pixel offsets (`HelmConsole._place(panel,
…, -210.0, …)`). That is fragile (the Flight cluster recently overhung the bottom
because its band was a fixed rect too short for its content), it duplicates layout
work per console, and it gives every department a *different* shape — fighting the
"this is one ship's operating system" feel we want.

We want the ship's terminal to read like a consistent OS: every department
(Helm, Ship/Engineering, and later Comms / Survey / Crew / Cargo) uses the **same
frame** — a persistent top bar, a dominant main view, two flanking context
panels, and a bottom **control deck** that is "where I give orders." Only the
*content* of each region changes per department and per context; the frame does
not. The control deck in particular is one reusable container we feed different
command sections into (flight orders today; scan/probe orders when Survey lands).

## Decision
A **`ConsoleFrame`** owns a fixed set of **responsive slot regions**; consoles
**describe** what fills each region with a **code-built layout descriptor**
(ADR 0007's "config-driven components" extended from single widgets to whole
screens). The frame builds **master widgets** from the descriptor into the slots.

### Regions (every console, same shape)
- **Top bar** — *shell-global*, lives in `ConsoleShell` (not per-console): the
  mission clock + critical resource readouts (reaction mass, hull, system) +
  the console tabs. Stellaris-style status strip. Persistent across consoles.
- **Main view** — the department's dominant display (Helm: the nav-view stage;
  Ship: a systems schematic). Owned by the console; the frame just hosts it.
- **Left / right context panels** — context-aware info & widgets for the active
  console + current selection. **Collapsible to drawers.**
- **Control deck** — the bottom band, "this is where I give orders": data-driven
  command **sections** (a titled cluster of widgets/buttons). One container, fed
  different sections per console and per context.

The regions are laid out with **containers + anchors/ratios, never per-panel pixel
offsets** — so content can never overhang (a region sizes to its content or to the
space available; the deck pushes the body up rather than falling off-screen).

### Descriptor (code-built first; `.tres` later)
A console hands the frame a descriptor: a tree of `region → sections → widgets`,
each widget entry `{type, title_key, data_source_id, actions, weight}`. The frame
maps `type` → an existing master widget (`TReadout`, `TButton`, `TGauge`, `TList`,
`TLight`, a `Section` cluster, a stage host) and wires `data_source_id` to a named
live provider. Today the descriptor is built in GDScript (typed, easy to iterate);
once the widget vocabulary is proven it can be promoted to an authored
`ConsoleLayoutData` `.tres` referenced via `TypeRegistry` (the "content is `.tres`"
convention) with **no change to the frame** — that promotion is explicitly out of
scope for this ADR.

### Visibility resolver (pure, tested)
Which sections/clusters are shown is **derived from context**, reusing the
`HelmGroups`-style pure resolver pattern (ADR 0032): a `core` function maps
(situation) → visible section ids, GUT-tested, no node deps. A whole section hides
when it doesn't apply; widgets within grey per `Travel.available`.

## Consequences
- New `ConsoleFrame` (slot regions) + a `Section` master widget + a small
  code-built descriptor type; the shell grows a **global top bar**.
- `HelmConsole` and `ShipConsole` are refactored to *describe* their layout and
  drop content into frame slots instead of `_place(...)`. The Helm keeps owning
  its nav-view stage (ADR 0031) — the stage just becomes the `main` slot's host.
- `TimeControls` (clock + speed) folds into the top bar; the bottom-left clock
  chrome moves up. No clock/sim behaviour changes (ADR 0006).
- The whole class of "panel overhangs / off-screen offset" bugs is designed out.
- Forward-compatible: a new department registers a console + a descriptor; it gets
  the ship-OS shape for free. `.tres` layouts can land later behind the same frame.

## Alternatives rejected
- **Keep per-console `_place` layouts** — the status quo: fragile, duplicated,
  inconsistent shape per department. The overhang bug is a symptom, not a one-off.
- **Author layouts as `.tres` from day one** — right end-state, but data-binding
  -by-id is hard to nail before the widget vocabulary is proven; we'd be designing
  the serialization before the thing it serializes. Code-built first, promote later.
- **Split-screen all consoles** — rejected already in ADR 0031; one active console
  + the bar is the captain's-terminal model.
