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


func _fly_to_orbit(target_id: String, burn: int) -> void:
	EventBus.order_issued.emit({"type": "set_course", "target_id": target_id, "burn": burn})
	EventBus.order_issued.emit({"type": "engage"})
	for i in range(400):
		if _fc.get_state() == FlightCore.State.IN_ORBIT:
			return
		EventBus.sim_tick.emit(i + 1)


func test_burn_spends_reaction_mass_matching_the_cost_model() -> void:
	var verdant := _find("verdant")
	var dist := Vector2.ZERO.distance_to(verdant.position)
	var expected := FlightMath.rm_cost(dist, FlightMath.Burn.ECONOMY)
	_fly_to_orbit("verdant", FlightMath.Burn.ECONOMY)
	var spent := 100.0 - GameState.ship.reaction_mass
	assert_almost_eq(spent, expected, 0.5, "total RM spent equals the course cost")
	assert_lt(GameState.ship.reaction_mass, 100.0, "fuel was actually consumed")


func test_harder_burn_costs_more_fuel_for_the_same_trip() -> void:
	_fly_to_orbit("rubicon", FlightMath.Burn.ECONOMY)
	var economy_spent := 100.0 - GameState.ship.reaction_mass

	# Reset to a fresh full tank at the origin and fly the same route harder.
	GameState.ship = ShipState.new()
	GameState.ship.position = Vector2.ZERO
	_fly_to_orbit("rubicon", FlightMath.Burn.HARD)
	var hard_spent := 100.0 - GameState.ship.reaction_mass

	assert_gt(hard_spent, economy_spent, "hard burn drinks more reaction mass")


func test_engage_rejected_when_tank_cannot_complete_the_course() -> void:
	GameState.ship.reaction_mass = 1.0  # nowhere near enough
	EventBus.order_issued.emit({"type": "set_course", "target_id": "rubicon", "burn": FlightMath.Burn.HARD})
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "engage"})
	assert_signal_emitted(EventBus, "order_rejected", "insufficient RM is refused")
	assert_false(GameState.ship.current_order.get("engaged"), "course does not execute")
	assert_eq(_fc.get_state(), FlightCore.State.COURSE_SET, "stays laid in, not flying")
	# A frozen-but-ticking clock must not move a non-engaged ship.
	EventBus.sim_tick.emit(1)
	assert_eq(GameState.ship.position, Vector2.ZERO, "ship holds at origin")


func test_dock_at_station_refuels_to_capacity() -> void:
	var anchorage := _find("anchorage")
	GameState.ship.position = anchorage.position  # parked at the station
	GameState.ship.reaction_mass = 12.0
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "dock"})
	assert_eq(GameState.ship.reaction_mass, GameState.ship.max_reaction_mass, "tank refilled")
	assert_signal_emitted(EventBus, "fuel_changed", "refuel announced on the bus")
	assert_signal_emitted(EventBus, "order_acknowledged", "dock acknowledged")


func test_dock_rejected_away_from_a_station() -> void:
	GameState.ship.position = Vector2(5000.0, 5000.0)  # nowhere near any body
	GameState.ship.reaction_mass = 12.0
	watch_signals(EventBus)
	EventBus.order_issued.emit({"type": "dock"})
	assert_signal_emitted(EventBus, "order_rejected", "cannot dock in open space")
	assert_eq(GameState.ship.reaction_mass, 12.0, "no free fuel")
