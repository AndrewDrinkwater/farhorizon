# ADR 0036 — Heading vs proposal: separating the active course from the selection

**Status:** accepted · **Date:** 2026-06-12
**Amends:** ADR 0028 (direct course plotting on select) — keeps select-to-plot, but
the plot is now a *proposal* distinct from the *active heading*, not a replacement
for it. Builds on ADR 0014/0015 (orders), ADR 0025 (Target Info), ADR 0019 (course).

## Context
Three concepts were visually + mentally conflated into "the course":
- **Heading** — the engaged `current_order`: where the ship is actually flying.
- **Target** — the current selection: what the captain is inspecting (Target Info).
- **Proposal** — the plotted course to the selection (ADR 0028 select-to-plot).

While flying to Tethys, clicking Cinder made Cinder read as "the course" (Course
Order + plot), even though the ship was still bound for Tethys; and on arrival the
proposal to the last-inspected target lingered looking like a live course. The
*data* was already separate (the engaged order never changed on select) — the
problem was that only one course was ever drawn, and the proposal was styled like a
committed course.

## Decision
One simple visual law: **SOLID means committed heading; GHOST means proposal.**

- **Heading** (engaged `current_order`) is drawn **solid** and is always shown while
  under way — on both nav views and in Flight Status. It changes *only* via Engage.
- **Proposal** (the selection's plotted course) is always drawn **ghosted** (dim,
  dashed), whether the ship is idle or already under way — it is never "active"
  until engaged. Shown in Target Info / Course Order.
- **Both can show at once:** flying to Tethys (solid) while Cinder is selected
  (ghost) reads unambiguously as "going to Tethys, considering Cinder." The proposal
  is suppressed only when it coincides with the heading (no double-draw).
- **Engage** promotes the proposal to the heading (a deliberate redirect, allowed
  mid-flight). **Lay In** commits the proposal without flying it.
- **On arrival** the heading clears (the ship drifts); the selection **stays a
  proposal** (ghost), never auto-engaged — so arriving never silently leaves a
  live-looking course.

## Consequences
- Nav views (`OrreryView`, `TacticalView`) draw the heading and the proposal as two
  distinct layers instead of an either/or; the proposal uses a dim "ghost" colour.
- The Helm stops clearing the selection on course completion (it becomes the
  proposal). No order-lifecycle / `core` / save changes — heading data already lived
  in `current_order`, proposal data in the compose state.

## Alternatives rejected
- **Select = inspect only (no proposal line)** — loses the at-a-glance "what would
  this course look like" that ADR 0028 gave; the ghost keeps it without the confusion.
- **Clear the selection on arrival** — simplest, but throws away a proposal the
  captain may want to engage next; the ghost makes keeping it unambiguous.
