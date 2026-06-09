extends GutTest
## Render interpolation of the per-tick transit position (ADR 0004): the views draw
## the ship eased between its last two tick snapshots so it glides instead of
## stepping. Logic stays per-tick (FlightController); this is presentation only.

var _snapshot: Dictionary
var _ov: OrreryView


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.clock.speed = 0.0
	_ov = OrreryView.new()
	add_child_autofree(_ov)
	_ov.build(TypeRegistry.get_system("sol"))


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_eases_between_ticks_while_under_way() -> void:
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.current_order = {"engaged": true}
	_ov._ship_prev = Vector2(0.0, 0.0)
	_ov._ship_curr = Vector2(100.0, 0.0)
	_ov._tick_accum = 0.5 * SimClock.SECONDS_PER_TICK  # half-way to the next tick
	assert_eq(_ov._interp_ship(), Vector2(50.0, 0.0), "drawn eased halfway between the two ticks")


func test_clamps_at_the_current_tick() -> void:
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.current_order = {"engaged": true}
	_ov._ship_prev = Vector2(0.0, 0.0)
	_ov._ship_curr = Vector2(100.0, 0.0)
	_ov._tick_accum = 5.0 * SimClock.SECONDS_PER_TICK  # overshoot (slow frame) clamps
	assert_eq(_ov._interp_ship(), Vector2(100.0, 0.0), "never extrapolates past the current tick")


func test_live_position_when_not_under_way() -> void:
	GameState.ship.location = Travel.Location.HOLDING  # orbit is already per-frame
	GameState.ship.position = Vector2(7.0, 7.0)
	GameState.ship.current_order = {}
	assert_eq(_ov._interp_ship(), Vector2(7.0, 7.0), "holding/idle draws the live position")
