# ADR 0010 — Localisation-ready from the start

**Status:** accepted · **Date:** 2026-06-06

## Context
The diegetic terminal UI is text-heavy. Hardcoding display strings now means
hunting hundreds of literals later if we ever localise. We are not translating
anything yet — but we want to never have to retrofit.

## Decision
- **All player-facing text goes through translation keys** from day one, using
  Godot's built-in `tr("KEY")` / `TranslationServer`.
- Strings live in a **string table** (CSV imported by Godot to `.translation`),
  keyed by stable identifiers (e.g. `HUD_REACTION_MASS`, `FLIGHT_STATE_WARPING`).
- Only **English** exists for now; adding a language later = adding a column.
- **Number / date / time formatting** is centralised in one helper (in
  `src/core`), so the in-game clock/calendar and numeric readouts format in one
  place — and that place is localisation-aware later.
- Internal/debug strings and log messages are exempt (not player-facing).

## Why
The discipline costs almost nothing now and removes a large, error-prone
retrofit. Centralised formatting also keeps the terminal's numeric readouts
consistent and tunable.

## Consequences
- A `TButton`/`TReadout` label is a key, not a literal; the component resolves
  it via `tr()`.
- New UI text must be added to the string table — a small, consistent habit.
- GUT can assert that no key is missing from the table.

## Alternatives rejected
- **Hardcode now, localise later** — the exact expensive retrofit this avoids.
