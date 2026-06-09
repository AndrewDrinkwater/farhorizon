# ADR 0029 — Landable bodies, atmosphere, land & take-off

**Status:** accepted · **Date:** 2026-06-09
**Builds on:** ADR 0005 (bodies), ADR 0015 (travel pipeline / location), ADR 0004
(discrete clock), ADR 0008 (save), ADR 0012 (accessibility).
**Paired with:** ADR 0030 (surface locations + planetary navigation).

## Context
The ship needs to land on and take off from planets. Landing/ascent take time,
governed by a ship stat and the body's atmosphere now, and by mass / pilot skill
/ equipment later — so the duration must be a **modifiable stat**, not a constant.

## Decision

### Body attributes (`BodyData`)
- `landable: bool` — gates landing.
- `atmosphere_atm: float` — surface pressure in **Earth atmospheres** (scientific;
  0 = vacuum, 1 = Earth, ~90 = Venus). The single source of truth for atmosphere.
- *(deferred)* `atmosphere_composition` — chemical make-up, added later (drives
  suits / hazards). Noted now so the model anticipates it.
- A **display class** is *derived* from `atmosphere_atm` (None / Thin / Standard /
  Dense / Crushing) via tunable thresholds — for UI + future gating, not stored.

### Location: LANDED
`Travel.Location` gains `LANDED`. Flow extends ADR 0015:
`HOLDING (orbit) → Land → LANDED → Take Off → HOLDING`. You must be **HOLDING at a
landable body** to land; **Take Off** returns to HOLDING.

### Land / Take Off as timed transitions
Descent and ascent are timed phases on the discrete clock (like transit, ADR
0015), consuming **time only** for now (no RM — RM can become another modifier
later). Orders (ADR 0014 lifecycle) added: **Land** (choose a surface site or the
generic Open Landing — ADR 0030), **Take Off**. `Travel.available` is extended:
Land when HOLDING at a landable body and not under way; Take Off when LANDED.

### Landing/ascent time is a modifiable stat
The duration is a **base ship stat passed through a modifier chain**:

```
ticks = round(base_ticks × Π factors)
factors now:  atmosphere_factor(atmosphere_atm)   # 1.0 at vacuum, grows with pressure
factors later: mass, pilot skill, ship equipment  # just appended to the chain
```

`LandingMath` (pure `core`, GUT-tested): `atmosphere_factor(atm)`,
`atmosphere_class(atm)`, `descent_ticks(base, factors)`, `ascent_ticks(...)`.
Implement atmosphere only now; the chain shape is the whole point — new
influences are new factors, no signature change. (Seeds a general
modifiable-stat pattern; we build only the landing case here, not a global stat
engine.)

**Base stats live on `ShipState` for now** (`base_descent_ticks`,
`base_ascent_ticks`) since there's no `HullData` yet; move to `HullData` when
hulls land. Fully modifiable already.

### Persistence
`location = LANDED` + the surface site (ADR 0030) save (ADR 0008); the in-progress
descent/ascent phase recomputes on load. `landable`/`atmosphere_atm` are authored.

## Consequences
- `BodyData`: `landable`, `atmosphere_atm` (+ deferred composition).
- `Travel.Location.LANDED`; `Travel.available` gains Land / Take Off.
- `LandingMath` core + tests; `ShipState` base descent/ascent stats.
- Helm gains Land / Take Off orders; the order lifecycle (ADR 0014) is unchanged.
- Example: make a few Calder/Sol bodies landable with real `atmosphere_atm`.

## Alternatives rejected
- **Constant landing time** — can't be influenced by atmosphere/mass/skill; the
  brief is explicitly a modifiable stat.
- **Atmosphere as an opaque enum** — loses the scientific value (pressure) the
  captain wants; the class is better *derived* from the number.
- **Land directly from deep space** — skipping orbit removes the approach beat;
  keep HOLDING → Land.
