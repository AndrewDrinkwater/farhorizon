# ADR 0035 — Console control-feel pass (instrument polish)

**Status:** accepted · **Date:** 2026-06-10
**Builds on:** ADR 0007 (config-driven components), ADR 0012 (accessibility),
ADR 0013/0031/0034 (consoles / shell / frame), ADR 0019 (mono numerics).
**Amends:** ADR 0006 — softens the strict "stylistic, no bezel / uniform panels"
stance to allow distinct *panel roles* and instrument styling (but still **no**
drawn cockpit / skeuomorphism — that fuller direction stays on the backlog).

## Context
The console shell shipped as a grid of identical dark panels — a functional
*dashboard*, not a ship's *control console*. The captain's read: every panel has
the same weight, the centre is an empty void, values are text not instruments,
and buttons have no hierarchy. This is a presentation pass to give it control
feel; **no game logic changes**, all at the theme + component level so every
console inherits it.

## Decision
Five moves, in `TerminalTheme` + the `T*` components + `Palette`:

1. **Panel roles.** Two treatments instead of one: **screens** (nav plot, target
   / readout panels) — darker inset, header strip with a live lamp; vs **control
   banks** (the button clusters) — lighter raised surface. The **nav plot is the
   hero**: largest, framed, and given a backdrop even when empty — a faint
   cross-hair / grid, range rings, and the ship marker centred with heading (an
   "on" display, not black space).
2. **Instruments over text.** Vitals render as `TGauge` (segmented, amber/red
   thresholds) not `label: value`; a row of `TLight` **status lamps**
   (FLT / SENS / DOCK / CAUTION) in the top bar / Flight Status; **all numeric
   readouts in the mono face** (Share Tech Mono) via the theme.
3. **Button hierarchy.** A primary/commit variant on `TButton` — filled accent,
   heavier — for the one commit action per context (Engage; Land / Dock in their
   clusters); everything else stays secondary. Clusters read as labelled control
   banks (grouping from ADR 0032).
4. **Honest placeholder states.** Stub panels (the Ship console's empty boxes)
   show an explicit "offline / no data" instrument state, not blank bordered
   rectangles that read as broken.
5. **Density.** Tighten dead space; a consistent header accent rule across panels.

Accessibility preserved — state is still carried by shape / label / lamp, not
colour alone (ADR 0012). Strings unchanged; this is styling, not new content.

## Consequences
- A styling pass on `TerminalTheme`, `Palette`, and the `T*` components
  (`TGauge` thresholds, `TLight` usage, `TButton` primary variant, `TPanel`
  screen vs control variants) + a nav-plot idle backdrop.
- No `core`/logic/save changes; no new EventBus signals.
- Every current and future console inherits the instrument feel for free.

## Alternatives rejected
- **Fuller bezel / CRT / drawn cockpit** — strongest fantasy but a real art
  commitment and a bigger break from ADR 0006; parked on the backlog as the
  "diegetic frame" option.
- **Leave as-is** — the dashboard feel the captain flagged.
