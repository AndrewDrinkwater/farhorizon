# Far Horizon — DEVLOG

Session-by-session build history. Newest entries at the top.

---

## 2026-06-06 — Session 0c: Consoles + the Helm console

Defined the first console and, with it, the UI's organizing model.

- **Consoles, not screens.** The UI is a set of captain's **consoles** (bridge
  posts); **Helm** is the first (flight + navigation). Supersedes the flat
  screen list. Each console is a post a crew officer can man later. (ADR 0013)
- **Orders, not actions.** The captain *issues orders*; the ship executes. Order
  lifecycle: compose → issue → **acknowledge** (a beat) → execute → belay. One
  active order per console. The active order is stored in `ShipState` so
  mid-order saves resume. This is the diegetic form of "UI emits intents". (ADR 0014)
- **Voice by crew slot.** Acknowledgments are voiced by whoever holds the post —
  a named officer if manned, the ship's computer if not (α0.1). One resolver
  serves every console; the crew system later lights up named voices everywhere.
- **Helm α0.1 orders:** Set Course (+ burn), Engage / Belay, All Stop,
  Establish / Break Orbit, Dock. Spec: `docs/consoles/helm.md`.

The α0.1 spine is now played *through* the Helm console.

**Next:** review, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0b: Cross-cutting concerns + data model

Reviewed what else to plan early. Added project-wide disciplines as ADRs and a
conventions doc, and produced a data-model diagram of entities + runtime flow.

**Added (decided cheap-now, expensive-later):**
- **Localisation-ready** — all player text via `tr()` keys + string table; one
  formatting helper. English only for now. (ADR 0010)
- **Settings + input actions** — `ConfigManager` (sixth autoload), settings in
  `user://settings.cfg` separate from saves; named input actions, no raw
  keycodes. (ADR 0011)
- **Accessibility + debug overlay** — colourblind-safe palette, never colour
  alone, toggleable live debug overlay. (ADR 0012)
- **CONVENTIONS.md** — canonical units (tick = hour, world units, fuel),
  `GAME_VERSION` + save `SCHEMA_VERSION`, window-focus auto-pause.

**Deferred (reserved):** single seeded `Rng` service for all randomness —
arrives with procgen, not α0.1.

**Data model:** confirmed the flow — UI reads GameState + emits intents; all
cross-system traffic via EventBus; authored `.tres` immutable, referenced by id;
SaveManager serializes the one GameState tree. (Diagram produced for review.)

**Next:** review the updated docs, then decide on scaffolding the project.

---

## 2026-06-06 — Session 0: Planning the rebuild

Greenfield restart of Far Horizon — "slower and properly." Old POC treated as
discarded (rebuild from the design vision, not the old code). No game code this
session; the output is the architecture plan and the α0.1 milestone spec, for
review before any code is written.

**Why the restart:** the POC worked but was clunky. The named clunk was in
three places — **time/tick handling**, **UI flow**, and **flight feel** — so
each got a deliberate design here.

**Decisions locked (see `docs/adr/`):**
- Godot latest stable 4.x, GDScript strictly typed, Forward+, 1080p 16:9. (0001)
- Single owned **GameState** tree as the only stateful autoload. (0002)
- Central **EventBus** for all cross-system signals. (0003)
- **Discrete SimClock** — one authoritative tick, interpolated rendering;
  speed 0/1/2/4×; never auto-pauses for UI. Fixes the time clunk. (0004)
- **Spatial flight, static bodies, burn-intensity** lever. Static bodies kill
  the moving-target problem; a named flight state machine stays extensible.
  Fixes the flight clunk. (0005)
- **Diegetic terminal UI** — persistent live main view, full-screen menu
  layouts over it, stylistic (no bezel). Fixes the UI-flow clunk. (0006)
- **Config-driven UI components** fed data + layout. (0007)
- **Save schema from the start**, versioned + forgiving. (0008)
- **GUT testing from the start** on pure `core` logic. (0009)

**Five autoloads, no more:** EventBus, GameState, SimClock, SaveManager,
TypeRegistry.

**α0.1 "The Ship Flies" — done =** plot a course with burn choice, fly it on
the clock, spend/refuel reaction mass, save/load the run, and it feels good.
Build order and scope in `docs/ALPHA-0.1-SPEC.md`.

**Flagged for a later design-doc revision:** flight/travel section, the UI
model, and ship progression/tiers — the rebuild supersedes parts of the
original doc in these areas.

**Open / assumed:** GitHub remote to be created at project init; exact Godot
patch version to pin at scaffold time.

**Next session:** review these docs, sign off or adjust, then scaffold the
project.
