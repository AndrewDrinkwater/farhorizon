# ADR 0037 — Timed, concurrent, interruptible scan

**Status:** accepted · **Date:** 2026-06-13
**Builds on:** ADR 0017 (sensors / contact ladder), ADR 0020 (scan order),
ADR 0014/0015 (orders). **Amends** the instant scan from ADR 0020.

## Context
Scanning a contact was instant and only allowed while stopped. The captain wanted
to scan anomalous readings **while under way**, with the scan **taking time** (a
stat better sensors / crew improve later), and being **interrupted if the contact
leaves sensor range**. An instant, stop-only scan can't express any of that.

## Decision
Scan becomes a **timed activity that runs concurrently with flight** — it does NOT
live in `current_order` (you keep flying / holding / docked while it runs):

- **State on `ShipState`** (saved, so a mid-scan save resumes): `scan_contact_id`
  (""=idle), `scan_ticks_left`, `scan_ticks_total`, and a modifiable stat
  `base_scan_ticks` (default **5** in-game minutes; sensors/crew lower it later, the
  same modifiable-stat pattern as the dock/land durations).
- **Lifecycle in `FlightController`**, ticked at the top of `_on_sim_tick` before
  the flight/transition handling: starting a scan validates (in range, an
  un-identified contact, not already scanning) and begins the countdown; each tick
  decrements it; reaching zero promotes BLIP → IDENTIFIED. If the contact leaves
  sensor range (or winks out) mid-scan it is **interrupted** (stays a BLIP).
- **Availability** (`Travel.available`): allowed while under way; blocked only mid
  dock/land transition or while another scan already runs. One scan at a time.
- **Signals**: `scan_started` / `scan_interrupted`; completion stays `contact_promoted`.
  A new system clears any active scan (its contacts are gone).

## Consequences
- New `ShipState` scan fields + `base_scan_ticks`; `FlightController` gains
  `_tick_scan` / `_scan_ticks` / `_clear_scan`; `Travel.available` scan rule changes
  (allow-while-moving, block-while-scanning); Target Info shows scan progress.
- It's a second concurrent activity alongside the single `current_order` — the first
  thing the ship does "in the background"; future background actions can follow the
  same shape rather than being squeezed into `current_order`.

## Alternatives rejected
- **Keep scan in `current_order`** — can't scan while flying (the order slot is the
  flight); concurrency is the whole point.
- **Instant scan, allowed while moving** — simplest, but loses the time cost and the
  out-of-range interruption the captain asked for.
