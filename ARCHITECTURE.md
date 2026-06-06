# Far Horizon — Architecture

**Status:** planning (pre-code). This document is the agreed shape of the
rebuild. Code does not exist yet; this is what we build against.

This is the *execution* plan. The design vision lives in `README` /
the design doc; this document says how we build it without the clunk
the POC had. The three things that felt clunky in the POC were **time/tick
handling**, **UI flow**, and **flight feel** — so each gets a deliberate,
named design here.

---

## 1. Principles

1. **One source of truth for state.** A single owned `GameState` tree holds
   everything that changes at runtime. Systems read it; they mutate it only
   through well-defined paths. Save = serialize that tree.
2. **Decouple through an EventBus.** Systems don't hold references to each
   other. They emit and listen to signals on a central hub. The clock, the
   flight controller, and the UI never import each other.
3. **Hard line between data and state.** Authored content lives in immutable
   `.tres` Resources loaded via `TypeRegistry`. Runtime state is separate
   plain objects in `GameState`. We never mutate a Resource at runtime.
4. **The clock is authoritative and discrete.** All simulation advances on
   discrete `SimClock` ticks. The view may interpolate for smoothness, but
   the tick is the truth. This is what makes time legible, deterministic,
   and save-friendly.
5. **UI sends intents, never mutates.** The terminal UI emits *commands*
   ("plot course to X at burn Y"); systems validate and apply them. UI is a
   view + an input surface, nothing more.
6. **Typed, tested, logged.** Strictly typed GDScript, GUT tests on pure
   logic from the start, an ADR for every big fork, DEVLOG per session.

---

## 2. Engine & conventions

| Choice | Decision |
|--------|----------|
| Engine | Godot, latest stable 4.x (exact version pinned at project init) |
| Language | GDScript only, **strictly typed** everywhere |
| Renderer | Forward+ (desktop) |
| Style | Godot official style guide: `snake_case` methods/vars, `PascalCase` classes, `class_name` on shared types, `_private` prefix for internals |
| Target | Desktop, 1920×1080 design resolution, 16:9, scaled to other 16:9 sizes |
| Source control | git from commit one, GitHub remote set up at project init |
| Testing | GUT, from the start, on pure logic |
| Docs | `DEVLOG.md` per session, ADRs in `docs/adr/` |
| Audience | Built with a developer newer to Godot 4 — docs and code comments explain Godot-specific patterns (autoloads, signals, Resources) as they appear |

---

## 3. The autoload set (few and disciplined)

Six singletons. Everything else is a regular node or Resource.

| Autoload | Responsibility | Holds state? |
|----------|----------------|--------------|
| **EventBus** | Central signal hub. Declares every cross-system signal. No logic. | No |
| **GameState** | The single owned runtime state tree (ship, system, clock values, fuel). Serializable. | **Yes — the only run state** |
| **SimClock** | Drives discrete ticks, owns speed multiplier, emits tick signals. | Transient only (its values mirror into GameState for save) |
| **SaveManager** | Schema-versioned serialize/deserialize of GameState. | No |
| **TypeRegistry** | Loads and hands out authored `.tres` Resources. Read-only cache. | No (immutable data) |
| **ConfigManager** | Player settings (resolution, volume, language, keybinds, accessibility), persisted to `user://settings.cfg`, **separate from saves**. | Settings only (not run state) |

Rule of thumb: if it's *the truth about the current run*, it lives in
GameState. If it's *a player setting*, it's in ConfigManager. If it's *a
service*, it's a stateless autoload. If it's *authored content*, it's a
Resource behind TypeRegistry.

---

## 4. State model

`GameState` is a tree of plain `RefCounted`/`Resource`-free data objects
(custom typed classes), owned top-down:

```
GameState
├── clock        (current tick, speed, calendar derivation)
├── ship         (position, heading, fuel pools, hull ref → id, current_order)
├── system       (which star system is loaded, by id)
└── flags / run metadata
```

- Every node knows how to `to_dict()` / `from_dict()`.
- `SaveManager` walks the tree; no system serializes itself ad hoc.
- Load is **forgiving**: missing keys fall back to defaults so old saves
  survive schema growth. (Carried over from the POC's one genuinely good
  idea.)
- Schema version stored at the top; migration hooks per version.

References to authored content are stored **by id**, not by embedding the
Resource — e.g. `ship.hull_id = "scout"`, resolved through TypeRegistry on
read. This keeps saves small and data/state cleanly separated.

---

## 5. The time model — discrete SimClock

The fix for the #1 clunk.

- **One tick = one in-game hour** (placeholder unit; tune freely).
- `SimClock` accumulates real time and fires `EventBus.sim_tick(tick_count)`
  on each step. Nothing else owns a timer that affects simulation.
- **Speed control:** `0×` (pause), `1×`, `2×`, `4×`. Speed = ticks emitted
  per real second. Pause simply stops emitting; the world freezes cleanly.
- **The sim never auto-pauses for UI.** Opening any screen or reading a
  decision leaves the clock running. The player may *choose* to pause.
- **Authoritative tick, interpolated view.** The clock is discrete and is
  the truth for all logic (flight progress, fuel burn, future missions).
  The *rendering* of the ship interpolates between the last tick's position
  and the next so motion looks smooth despite a coarse tick. Logic never
  reads the interpolated value.

Why discrete: deterministic, trivial to save (just a tick count),
reproducible, and every future ticking system (missions, probes, supplies)
hangs off the same single signal instead of its own fragile timer. The
POC's tick clunk came from multiple competing timers; here there is one.

---

## 6. Flight — spatial, static bodies, burn-intensity

The fix for the flight clunk. Two root causes in the POC: **no real
pathing** and **chasing moving targets**. Both are designed out.

**Bodies are static.** Planets and stations hold fixed positions in the
system. No orbital motion at flight timescales, so there is no intercept
math and no moving target to chase. (Orbits, if ever wanted, become a
cosmetic layer that doesn't affect navigation.)

**Flight is spatially real.** The ship is a node at a real `(x, y)` in the
system world; the camera follows it. The player commands courses, not
thrust vectors.

**Flight state machine** (`FlightController`), extensible by adding states:

```
Idle → CourseSet → Engaging → Accelerating → Cruising → Decelerating → Arriving → InOrbit
                      └───────────────── Abort ──────────────────┘ → CourseSet
```

- **Course command:** click a body on NAV → preview shows ETA + reaction-mass
  cost → confirm to engage. ("Command courses, not vectors.")
- **Burn intensity** is the player's control lever: `Economy / Standard /
  Hard`. Higher burn = shorter ETA, more reaction mass spent. This is the
  real time-vs-fuel decision the design wants, and it's the seed for richer
  course control later (waypoints, approach choice) without changing the
  state machine.
- Progress advances **per SimClock tick** (distance covered = f(burn, dt));
  position renders interpolated between ticks.
- **Abort** is always available mid-flight, returning to CourseSet.

Same machine on every future hull; tiers change fuel cost and turn rate,
not the control scheme.

---

## 7. UI — the captain's terminal

The fix for the UI-flow clunk, and a stronger fantasy: **you are a captain
operating a ship terminal**, not a player tabbing through menus.

**Framing:** stylistic sci-fi console — panels, readouts, alarm lights —
read as a terminal, but no drawn cockpit bezel (keeps it flexible and not
art-bound).

**Organizing unit: the console (not a screen).** The captain works *consoles* —
bridge posts, each grouping the orders and readouts for one domain. **Helm** is
the first (flight + navigation); Ops, Science, Comms, Engineering follow. This
supersedes the flat screen list. Each console is a **post** an officer can man
later (which affects voice — see orders below). Per-console specs live in
`docs/consoles/` (see `helm.md`). (ADR 0013)

**Shape:**
- A persistent **terminal shell**: the active console (the system map + live
  HUD at Helm), clock always running and visible. Time controls (pause / 1× /
  2× / 4×) live in the shell, not in any console.
- **Other consoles** open as full layouts *over* the shell, never hiding that
  time is passing.

**Orders, not actions.** A console doesn't change state directly; it **issues an
order**. Orders follow a lifecycle — *compose → issue → acknowledge → execute* —
where the owning system validates, the post **acknowledges** (a brief beat, e.g.
the helm's "course laid in"), then executes over the clock; **belay** aborts. One
active order per console. The **acknowledgment voice is resolved from the crew
slot**: a manned post answers by name, an unmanned post (α0.1) answers in the
ship's computer voice. The active order is stored in `ShipState` so mid-order
saves resume. This is the diegetic form of "UI emits intents, systems execute."
(ADR 0014)

**Config-driven component library.** Consoles are *assembled from data*, not
hand-built one-off. A small library of components, each taking a data
binding + layout spec:

| Component | Purpose |
|-----------|---------|
| `TPanel` | Container / framed region, variable size |
| `TButton` | Command button → emits an intent on EventBus |
| `TReadout` | Labeled value (numeric/text), bind to a GameState path |
| `TGauge` / `TBar` | Segmented/continuous level (fuel, progress) |
| `TLight` | Status dot / alarm light, state-driven color |
| `TList` | Scrollable list of records (contacts, log) |
| `TDisplay` | Generic variable-size display region |

- Components **bind to GameState** (read) and **emit intents/orders** (write).
  They never mutate state directly.
- A console is a layout config that places components and wires their
  bindings — so building/rearranging a terminal is mostly data.
- **Theme:** minimal foundation now (Orbitron display, Share Tech Mono
  numerics, core palette + a couple of base components), expanded as
  screens demand it. Not a full library up front.

**Data flow, end to end:**

```
GameState ──(read/bind)──▶ UI components ──(render)──▶ screen
   ▲                                              │
   │                                              │ user acts
SaveManager                                       ▼
   ▲          systems ◀──(intent signal)── EventBus ◀── TButton
   │              │
   └──────────────┘ apply → mutate GameState → emit change signal → UI updates
```

---

## 8. Project structure

```
far-horizon/
├── project.godot
├── ARCHITECTURE.md
├── DEVLOG.md
├── docs/
│   ├── ALPHA-0.1-SPEC.md
│   └── adr/                      # one file per decision
├── src/
│   ├── autoload/                 # EventBus, GameState, SimClock, SaveManager, TypeRegistry
│   ├── core/                     # pure logic: clock math, flight/ETA math, fuel — GUT-tested
│   ├── flight/                   # FlightController state machine, ship node
│   ├── world/                    # system scene, body nodes, camera
│   ├── data/                     # Resource type defs (HullData, SystemData, BodyData...)
│   └── ui/
│       ├── theme/                # fonts, palette, base theme
│       ├── components/           # config-driven component library
│       ├── shell/                # persistent terminal shell + time controls
│       └── consoles/             # Helm first, then Ops/Science/Comms/...
├── resources/                    # authored .tres data
│   ├── systems/
│   └── ships/
├── tests/                        # GUT tests (mirror src/core)
└── assets/                       # placeholder art, fonts
```

Principle: **pure logic lives in `src/core` with no node dependencies**, so
it's unit-testable without the engine. Nodes in `flight/`, `world/`, `ui/`
are thin shells over that logic.

---

## 9. What we deliberately changed from the design doc

The interview surfaced three areas where the rebuild supersedes the doc;
these need a doc revision pass (tracked, not done yet):

1. **Flight/travel.** Static bodies + spatially-real flight + burn-intensity
   replaces any orbital/intercept implications in the doc's travel section.
2. **UI model.** The diegetic-terminal + **console** model (ADR 0013) supersedes
   the doc's flat screen list. The domains still exist; they're now consoles
   (Helm first) assembled from components, operated via the order lifecycle
   (ADR 0014).
3. **Ship progression / tiers.** Flagged for reconsideration — revisit the
   Scout→Capital structure and its specifics before we get near it (post-α0.1).

---

## 10. Cross-cutting concerns (decided early, cheap now)

These are project-wide disciplines adopted from the start because retrofitting
them is expensive. See `docs/CONVENTIONS.md` for the concrete constants/rules.

- **Localisation-ready.** All player-facing text goes through `tr()` keys + a
  string table; numbers/dates through one formatting helper. English only for
  now. (ADR 0010)
- **Settings + input actions.** `ConfigManager` holds settings separate from
  saves; all input reads named actions, never raw keycodes. (ADR 0011)
- **Accessibility + debug overlay.** Colourblind-safe palette, never colour
  alone (state also carries an icon/label), plus a toggleable live debug
  overlay for the time-driven sim. (ADR 0012)
- **Conventions doc.** Canonical units (tick = hour, world units, fuel),
  `GAME_VERSION` + save `SCHEMA_VERSION`, window-focus auto-pause. (CONVENTIONS.md)
- **Deferred but reserved:** a single seeded `Rng` service for all randomness
  arrives with procgen — no system calls `randi()` directly. Not in α0.1.

## 11. Decision log

Each major fork has an ADR in `docs/adr/`. See:

- 0001 — Engine, language, renderer, style
- 0002 — Central GameState as single state tree
- 0003 — EventBus for system communication
- 0004 — Discrete SimClock, authoritative tick + interpolated view
- 0005 — Spatial flight with static bodies and burn-intensity
- 0006 — Diegetic terminal UI
- 0007 — Config-driven UI components
- 0008 — Save schema designed from the start
- 0009 — GUT testing from the start
- 0010 — Localisation-ready from the start
- 0011 — Settings persistence and named input actions
- 0012 — Accessibility palette and debug overlay
- 0013 — UI organized as captain's consoles
- 0014 — Order lifecycle: acknowledged intents, voiced by crew slot
- 0015 — Travel pipeline: location, course, and context-derived orders
- 0016 — Orrery Nav Plot: log-compressed display (presentation ≠ sim scale)
- 0017 — Sensor & contact model: charted vs transient, real-space detection
- 0018 — Hierarchical bodies: moons and parent-relative orrery
