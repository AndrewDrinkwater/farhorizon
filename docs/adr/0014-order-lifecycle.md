# ADR 0014 — Order lifecycle: acknowledged intents, voiced by crew slot

**Status:** accepted · **Date:** 2026-06-06

## Context
The captain commands; the ship executes. An order (set course, all stop, dock)
is not an instant state change — it's issued, acknowledged by whoever holds the
post, then carried out over the clock. This is the diegetic form of the
architecture's "UI emits intents, systems execute" rule.

## Decision
Orders follow a four-phase lifecycle:

1. **Compose** — the console builds an order (e.g. `SetCourse{target_id, burn}`).
2. **Issue** — on confirm, the UI emits `order_issued(order)` on EventBus. The
   owning system validates; failure emits `order_rejected(reason)`.
3. **Acknowledge** — a brief beat where the post replies. The system emits
   `order_acknowledged(voice, line)`. This beat maps onto the existing flight
   `Engaging` state (no new state).
4. **Execute** — the system runs the order over SimClock ticks (e.g. the flight
   state machine), to completion or until **belayed** (abort).

**One active order per console at a time** (Helm). A small order queue is a
possible later extension, not now.

**Voice by crew slot.** The acknowledgment voice is resolved from the post:
- post manned by an officer → that officer answers, by name;
- post unmanned (α0.1) → the ship's computer answers.
A single resolver (`post → officer | null`, null = ship voice) serves every
console, so the crew system later enables named voices everywhere with no
console changes.

**Persistence.** The **active order is stored in `ShipState`** so a mid-order
save resumes correctly. The acknowledgment beat is transient and not saved; on
load the ship resumes its executing flight state.

## Why
The lifecycle gives orders weight and sells the chain of command without new
architecture — it's intents (ADR 0003) plus an acknowledgment beat. Storing the
active order in GameState keeps mid-flight saves correct (ADR 0008). The voice
resolver cleanly defers the crew system while designing for it.

## Consequences
- `ShipState` gains a `current_order` field (serialized).
- EventBus gains order signals: `order_issued`, `order_acknowledged`,
  `order_rejected`, `order_belayed`.
- The flight state machine is unchanged; `Engaging` carries the ack.

## Alternatives rejected
- **Immediate orders** (no ack) — snappier but loses the fiction the design
  wants.
- **Order queue now** — more depth than α0.1 needs; deferred.
