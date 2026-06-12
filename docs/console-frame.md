# Console frame — the ship-OS layout

The frame every captain's console is built on (ADR 0034). One consistent shape;
only the content per region changes by department and by context.

```
┌──────────────────────  TOP BAR (shell-global)  ──────────────────────┐
│  clock · RM · hull · system · alerts        [Helm][Ship][Comms]…tabs   │
├──────────┬─────────────────────────────────────────────┬─────────────┤
│  LEFT    │                                              │   RIGHT     │
│ context  │              MAIN VIEW (department)          │  context    │
│ (drawer) │         (Helm: nav stage · Ship: schematic)  │  (drawer)   │
├──────────┴─────────────────────────────────────────────┴─────────────┤
│            CONTROL DECK — "this is where I give orders"                │
│   data-driven sections · widgets · buttons (context-aware per screen)  │
└───────────────────────────────────────────────────────────────────────┘
```

## Regions
- **Top bar** — shell-global (`ConsoleShell`). Mission clock + speed (folds in
  `TimeControls`), critical resource readouts (reaction mass / hull / system),
  console tabs. Persistent; identical across consoles.
- **Main view** — the console's dominant display, hosted by the frame's `main`
  slot. The Helm puts its nav-view stage here (orrery / scope / surface / inset,
  ADR 0031); Ship a systems schematic. Full-bleed within the slot.
- **Left / right** — context panels, collapsible to drawers (a thin tab toggles
  the drawer open/closed). Hold info + widgets for the console + current selection.
- **Control deck** — the bottom band. Holds **sections** (titled clusters of
  widgets/buttons). One reusable container fed different sections by context.

Layout is containers + anchors/ratios only — **no per-panel pixel offsets**. A
region sizes to content or to available space; the deck pushes the body row up
rather than overhanging (the bug class ADR 0034 designs out).

## The descriptor (code-built; `.tres` later)
A console returns a descriptor: `region → sections → widgets`.

```
{
  region: LEFT | RIGHT | DECK | MAIN,
  sections: [
    { id, title_key, visible_when, widgets: [
        { type, title_key?, data_source_id?, action_id?, weight? }, …
    ] }, …
  ]
}
```

- `type` ∈ the master-widget vocabulary: `readout`, `button`, `gauge`, `light`,
  `list`, `label`, `stage` (the main-view host), `custom` (an opaque Control the
  console supplies, e.g. the directory or the transition indicators).
- `data_source_id` → a named live provider the console registers; the frame reads
  it on refresh. `action_id` → an order callable the console registers.
- `visible_when` → a section id resolved by the pure visibility resolver.

The frame instantiates widgets and owns refresh; the console owns providers +
action callables + the resolver. Promotion to `ConsoleLayoutData` `.tres` is a
later, frame-transparent step (out of scope here).

## Master widgets
Existing primitives, reused: `TReadout`, `TButton`, `TGauge`, `TLight`, `TList`,
`Label`. New: **`Section`** (a titled VBox cluster that hides wholesale) and the
frame's slot/region manager. `custom` lets a console drop a bespoke Control
(directory, altitude/dock indicators, the nav stage) into a slot unchanged.

## Pure core (GUT-tested)
- **Visibility resolver** — `(situation) → visible section ids`, generalizing
  `HelmGroups.visible_groups` (ADR 0032). No node deps.
- Frame region math if any (region rects from ratios) stays trivial / container-
  driven; the resolver is the testable piece.

## Build order (each step runnable + GUT-green, clean boot)
1. **Frame skeleton + global top bar.** `ConsoleFrame` with the slot regions
   (container-based, responsive); move clock/resources/tabs into a shell top bar.
   Refactor the **Helm** to drop its existing panels into named slots (directory →
   left; flight-status + target-info → right; clusters → deck; nav stage → main;
   transition indicators → custom overlay). Delete `_place`. Confirm the overhang
   is gone and the Helm behaves exactly as before.
2. **Data-driven control deck.** Add the `Section` widget + the code-built
   descriptor; Helm's Flight / Docking / Surface / Sensors clusters become
   descriptor sections fed into the deck. Generalize `HelmGroups` → the shared
   visibility resolver; GUT-test it.
3. **Side panels/drawers + Ship onto the frame.** Left/right become descriptor-
   driven with collapse-to-drawer; bring **Ship/Engineering** onto the frame as
   the second proof (its readouts + TBD sections via the descriptor). Strings,
   tests, DEVLOG, confirm ADR 0034.

## Out of scope
- Authored `.tres` layouts (`ConsoleLayoutData`) — later, frame-transparent.
- New gameplay systems behind Ship/Engineering (still stubs).
- Drag-to-rearrange / user-customisable layouts.
