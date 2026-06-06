# Far Horizon — Conventions

Canonical units, constants, and rules every system follows. When a number's
meaning is ambiguous, this doc is the answer. Keep it short and current.

---

## Time

- **Tick = the atomic unit of sim time.** One tick = **1 in-game minute**
  (tunable without touching logic). At 1× the clock runs `SECONDS_PER_TICK = 1`
  real second per tick, so 1 real second = 1 in-game minute.
- All time-based logic is expressed in **ticks**, never raw `delta`.
- **Real-time mapping** is set by `SECONDS_PER_TICK` at 1× speed (a tuning
  constant, not logic). Speed multipliers: `0× / 1× / 2× / 4×`.
- **In-game calendar** is derived from the tick count (e.g. day = tick / 24).
  Display formatting lives in the one formatting helper (ADR 0010).

## Space & scale

- The system world uses **world units (wu)**. Define `WU_PER_*` constants once;
  do not hardcode distances elsewhere.
- Bodies are **static** — fixed positions per system (ADR 0005).
- Camera zoom operates in defined min/max wu-per-screen bounds (tuning).

## Fuel

- **Reaction Mass** — thrust/manoeuvring; spent per burn, scaled by burn
  intensity (`Economy / Standard / Hard`). Units: `RM`.
- **Warp Fuel** — FTL; *out of scope for α0.1*, defined later.
- Burn costs and ETA multipliers are tuning constants, not logic.

## Versioning

- A single **`GAME_VERSION`** constant (semantic-ish, e.g. `0.1.0`) is the one
  source of truth. Shown in the UI and **written into every save** for
  migration (ADR 0008).
- **Save `SCHEMA_VERSION`** is separate from `GAME_VERSION` — the save format
  can change independently of the game version.

## Window focus

- Losing window focus **auto-pauses the sim** (sets speed to 0×) as a comfort
  default; regaining focus restores the previous speed. (A `ConfigManager`
  setting can disable this later.) This is the one exception to "the sim never
  auto-pauses" — it's an OS-focus courtesy, not a UI modal.

## Identifiers & data

- Authored content is referenced **by string id** (e.g. `hull_id = "scout"`),
  resolved through `TypeRegistry` (ADR 0002). Never embed a Resource in state.
- Ids are stable, lower_snake_case, and never reused for a different thing.

## Randomness (deferred, but reserved)

- When procgen arrives, **all randomness flows through one seeded `Rng`
  service** (seed stored in save for reproducibility). Not built in α0.1, but
  no system should call `randi()` directly — route through `Rng` when it lands.

## Strings & formatting

- Player-facing text → translation keys via `tr()` (ADR 0010).
- Numbers/dates/times → the single formatting helper. No ad-hoc `str()`
  formatting of player-facing values.

## Code style

- Strictly typed GDScript; Godot official style guide (ADR 0001).
- Pure logic in `src/core` (no node deps, GUT-tested); nodes are thin shells.
- Cross-system communication via `EventBus`; intra-scene via local signals.
