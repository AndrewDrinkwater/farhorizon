extends Node
## EventBus — central signal hub (ADR 0003).
##
## Declarations only, no logic. Systems emit and connect to these signals so
## they never hold direct references to each other. A grep of `EventBus.` shows
## the whole cross-system wiring diagram.
##
## Signal names/payloads here are the contract; keep them coarse and global.
## Intra-scene chatter uses local signals, not this bus.

# --- Clock (ADR 0004) ---
signal sim_tick(tick: int)
signal sim_speed_changed(speed: float)

# --- Orders (ADR 0014): compose -> issue -> acknowledge -> execute / belay ---
signal order_issued(order: Dictionary)
signal order_acknowledged(voice: String, line: String)
signal order_rejected(reason: String)
signal order_belayed()

# --- Helm / Nav Plot (ADR 0013) — UI compose-time selection ---
signal nav_target_selected(target_id: String)
## Burn intensity selected on the Helm — the nav views recompute travel-time
## annotations (ETA badges, isochrone rings) burn-aware (ADR 0019).
signal nav_burn_changed(burn: int)
## Empty-space waypoint selected on a nav view (ADR 0020) — a course destination
## with no entity id. Bodies/contacts still use nav_target_selected(id).
signal nav_point_selected(point: Vector2)
## Orrery scale mode flipped on the Helm (ADR 0021) — OrreryParams.ScaleMode.
signal nav_scale_changed(mode: int)
## A moon-bearing planet was focused / the focus inset closed (ADR 0022).
signal nav_focus_requested(body_id: String)
signal nav_focus_closed()

# --- Flight (ADR 0005) ---
signal flight_state_changed(state: int)

# --- Travel situation (ADR 0015) — location/course changed; UI re-derives orders ---
signal ship_context_changed()

# --- Sensors / contacts (ADR 0017) ---
signal contact_detected(contact_id: String)
signal contact_lost(contact_id: String)
signal contact_promoted(contact_id: String, tier: int)

# --- Fuel ---
signal fuel_changed(pool: int, value: float)

# --- Lifecycle ---
signal game_state_loaded()
signal settings_changed(key: String)
