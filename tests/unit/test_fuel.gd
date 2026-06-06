extends GutTest
## Reaction-mass consumption + refuel (step 7), against the live FlightController
## and GameState. Snapshots GameState so it leaves no trace.

var _snapshot: Dictionary
var _fc: FlightController


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.ship.position = Vector2.ZERO
	GameState.clock.speed = 0.0
	_fc = FlightController.new()
	add_child_autofree(_fc)


func after_each() -> void:
	GameState.from_dict(_snapshot)


func _find(id: String) -> BodyData:
	for b: BodyData in TypeRegistry.get_system("sol").bodies:
		if b.id == id:
			return b
	return null


func _fly_to_holding(target_id: String, burn: int) -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": target_id, "burn": burn})
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(2000):
		if GameState.ship.location == Travel.Location.HOLDING:
			return
		EventBus.sim_tick.emit(i + 1)


func test_burn_spends_reaction_mass_matching_the_cost_model() -> void:
	var verdant := _find("verdant")
	# The ship stops on the holding ring, so it travels to the ring, not the centre.
	var travel := Vector2.ZERO.distance_to(verdant.position) - Travel.holding_radius(verdant.radius)
	var expected := FlightMath.rm_cost(travel, FlightMath.Burn.ECONOMY)
	_fly_to_holding("verdant", FlightMath.Burn.ECONOMY)
	var spent := 100.0 - GameState.ship.reaction_mass
	assert_almost_eq(spent, expected, 0.5, "total RM spent equals the travelled-distance cost")
	assert_lt(GameState.ship.reaction_mass, 100.0, "fuel was actually consumed")


func test_harder_burn_costs_more_fuel_for_the_same_trip() -> void:
	_fly_to_holding("rubicon", FlightMath.Burn.ECONOMY)
	var economy_spent := 100.0 - GameState.ship.reaction_mass

	# Reset to a fresh full tank at the origin and fly the same route harder.
	GameState.ship = ShipState.new()
	GameState.ship.position = Vector2.ZERO
	_fly_to_holding("rubicon", FlightMath.Burn.HARD)
	var hard_spent := 100.0 - GameState.ship.reaction_mass

	assert_gt(hard_spent, economy_spent, "hard burn drinks more reaction mass")


func test_engage_rejected_when_tank_cannot_complete_the_course() -> void:
	GameState.ship.reaction_mass = 1.0  # nowhere near enough
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.HARD})
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "engage"})
	assert_signal_emitted(EventBus, "order_rejected", "insufficient RM is refused")
	assert_false(GameState.ship.current_order.get("engaged"), "course does not execute")
	assert_eq(_fc.get_state(), FlightCore.State.IDLE, "stays laid in, not flying")
	# A frozen-but-ticking clock must not move a non-engaged ship.
	EventBus.sim_tick.emit(1)
	assert_eq(GameState.ship.position, Vector2.ZERO, "ship holds at origin")


func test_dock_at_station_refuels_to_capacity() -> void:
	var anchorage := _find("anchorage")
	# Holding at the station (as if just arrived).
	GameState.ship.position = anchorage.position
	GameState.ship.location = Travel.Location.HOLDING
	GameState.ship.location_body_id = "anchorage"
	GameState.ship.reaction_mass = 12.0
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "dock"})
	assert_eq(GameState.ship.location, Travel.Location.DOCKED, "docked")
	assert_eq(GameState.ship.reaction_mass, GameState.ship.max_reaction_mass, "tank refilled")
	assert_signal_emitted(EventBus, "fuel_changed", "refuel announced on the bus")
	assert_signal_emitted(EventBus, "order_acknowledged", "dock acknowledged")


func test_dock_rejected_in_open_space() -> void:
	GameState.ship.position = Vector2(5000.0, 5000.0)  # drifting, not holding
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.reaction_mass = 12.0
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "dock"})
	assert_signal_emitted(EventBus, "order_rejected", "cannot dock without a holding area")
	assert_eq(GameState.ship.reaction_mass, 12.0, "no free fuel")
