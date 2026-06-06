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

# --- Flight (ADR 0005) ---
signal flight_state_changed(state: int)

# --- Fuel ---
signal fuel_changed(pool: int, value: float)

# --- Lifecycle ---
signal game_state_loaded()
signal settings_changed(key: String)
