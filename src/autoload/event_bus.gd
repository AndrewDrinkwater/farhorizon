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
## The compose-time route changed (ADR 0027) — ship → waypoints → destination; the
## nav views draw it as the plotted course. Empty = nothing plotted.
signal nav_route_changed(route: PackedVector2Array)
## A nav view edited the route's waypoints by drag (ADR 0028) — the Helm adopts
## this ordered intermediate-point list as the plotted route's waypoints.
signal nav_waypoints_set(waypoints: PackedVector2Array)

# --- Flight (ADR 0005) ---
signal flight_state_changed(state: int)
## The ship reached its destination (a course finished) — the Helm clears the plot.
signal course_completed()

# --- Travel situation (ADR 0015) — location/course changed; UI re-derives orders ---
signal ship_context_changed()

# --- Sensors / contacts (ADR 0017) ---
signal contact_detected(contact_id: String)
signal contact_lost(contact_id: String)
signal contact_promoted(contact_id: String, tier: int)

# --- Zones (ADR 0026) — ship entered/left an authored region; a region's
# on-enter trigger fired (for the future event system to consume). ---
signal zone_entered(zone_id: String)
signal zone_exited(zone_id: String)
signal zone_trigger_fired(zone_id: String, event_id: String)

# --- Fuel ---
signal fuel_changed(pool: int, value: float)

# --- System loading (ADR 0024) — switch the loaded star system at runtime;
# the seed of warp/multi-system later (which reuses this exact path, gated). ---
signal system_change_requested(system_id: String)  # intent
signal system_changed(system_id: String)            # done — nav systems re-init

# --- Lifecycle ---
signal game_state_loaded()
signal settings_changed(key: String)
