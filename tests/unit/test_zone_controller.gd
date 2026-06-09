extends GutTest
## ZoneController membership + triggers (ADR 0026): drives sim_tick against the
## authored Calder zones. Snapshots GameState so it leaves no trace.

var _snapshot: Dictionary
var _zc: ZoneController


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "calder"
	GameState.ship = ShipState.new()
	GameState.zones = ZonesState.new()
	_zc = ZoneController.new()
	add_child_autofree(_zc)


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_enter_and_exit_the_anchored_corona() -> void:
	# calder_corona is a no-go circle r=300 anchored on the star at the origin.
	watch_signals(EventBus)
	GameState.ship.position = Vector2(100.0, 0.0)  # inside
	EventBus.sim_tick.emit(1)
	assert_signal_emitted_with_parameters(EventBus, "zone_entered", ["calder_corona"])

	GameState.ship.position = Vector2(5000.0, 0.0)  # well outside
	EventBus.sim_tick.emit(2)
	assert_signal_emitted_with_parameters(EventBus, "zone_exited", ["calder_corona"])


func test_no_event_when_staying_put_outside() -> void:
	GameState.ship.position = Vector2(5000.0, 5000.0)  # outside every nearby zone
	EventBus.sim_tick.emit(1)
	watch_signals(EventBus)
	EventBus.sim_tick.emit(2)
	assert_signal_not_emitted(EventBus, "zone_entered", "no spurious enter when stationary outside")


func test_one_shot_trigger_fires_exactly_once() -> void:
	# drift_signal is a free trigger circle near Drift with once:true.
	var center := Vector2(-14100.0, 11900.0)
	watch_signals(EventBus)
	GameState.ship.position = center
	EventBus.sim_tick.emit(1)
	assert_signal_emitted_with_parameters(EventBus, "zone_trigger_fired",
		["drift_signal", "ev_drift_signal"])
	assert_true(GameState.zones.has_fired("drift_signal"), "recorded as fired")

	# Leave and come back — it must not fire a second time.
	GameState.ship.position = Vector2(0.0, 0.0)
	EventBus.sim_tick.emit(2)
	GameState.ship.position = center
	EventBus.sim_tick.emit(3)
	assert_signal_emit_count(EventBus, "zone_trigger_fired", 1, "one-shot fires once across re-entries")
