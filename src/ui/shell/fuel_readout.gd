extends Label
## Interim live reaction-mass readout (build-order step 7). Shows current / max RM
## so fuel is visible on the HUD. Replaced by the Helm Flight Status gauge in
## step 8.
##
## Reads GameState.ship via EventBus.fuel_changed / game_state_loaded; it never
## mutates (ADR 0007). Player-facing text via tr() keys (ADR 0010).


func _ready() -> void:
	EventBus.fuel_changed.connect(_on_fuel_changed)
	EventBus.game_state_loaded.connect(_refresh)
	_refresh()


func _on_fuel_changed(_pool: int, _value: float) -> void:
	_refresh()


func _refresh() -> void:
	var amount: String = tr("FUEL_FORMAT").format({
		"current": "%.0f" % GameState.ship.reaction_mass,
		"max": "%.0f" % GameState.ship.max_reaction_mass,
	})
	text = "%s  %s" % [tr("HUD_REACTION_MASS"), amount]
