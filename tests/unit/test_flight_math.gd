extends GutTest
## Pure ETA/fuel math (ADR 0005). Asserts the time-vs-fuel tradeoff holds and the
## edge cases behave, independent of the exact tuning numbers.


func test_distance_is_euclidean() -> void:
	assert_almost_eq(FlightMath.distance(Vector2.ZERO, Vector2(3.0, 4.0)), 5.0, 0.0001)
	assert_eq(FlightMath.distance(Vector2(10.0, 10.0), Vector2(10.0, 10.0)), 0.0)


func test_eta_rounds_up() -> void:
	var sp := FlightMath.speed_wu_per_tick(FlightMath.Burn.STANDARD)
	assert_eq(FlightMath.eta_ticks(sp, FlightMath.Burn.STANDARD), 1, "exactly one tick")
	assert_eq(FlightMath.eta_ticks(sp + 0.01, FlightMath.Burn.STANDARD), 2, "partial tick rounds up")
	assert_eq(FlightMath.eta_ticks(sp * 2.0, FlightMath.Burn.STANDARD), 2, "exact multiple")


func test_higher_burn_is_faster() -> void:
	var d := 100000.0  # large enough to distinguish ETAs at lightspeed-scale burns
	var eco := FlightMath.eta_ticks(d, FlightMath.Burn.ECONOMY)
	var std := FlightMath.eta_ticks(d, FlightMath.Burn.STANDARD)
	var hard := FlightMath.eta_ticks(d, FlightMath.Burn.HARD)
	assert_lt(hard, std, "hard burn beats standard")
	assert_lt(std, eco, "standard beats economy")


func test_higher_burn_costs_more_fuel() -> void:
	var d := 1000.0
	var eco := FlightMath.rm_cost(d, FlightMath.Burn.ECONOMY)
	var std := FlightMath.rm_cost(d, FlightMath.Burn.STANDARD)
	var hard := FlightMath.rm_cost(d, FlightMath.Burn.HARD)
	assert_lt(eco, std, "economy is cheapest")
	assert_lt(std, hard, "hard is dearest")


func test_fuel_scales_linearly_with_distance() -> void:
	var single := FlightMath.rm_cost(500.0, FlightMath.Burn.STANDARD)
	var double := FlightMath.rm_cost(1000.0, FlightMath.Burn.STANDARD)
	assert_almost_eq(double, single * 2.0, 0.0001, "twice the distance, twice the RM")


func test_zero_distance_is_free_and_instant() -> void:
	assert_eq(FlightMath.eta_ticks(0.0, FlightMath.Burn.HARD), 0)
	assert_eq(FlightMath.rm_cost(0.0, FlightMath.Burn.HARD), 0.0)


func test_preview_bundles_distance_eta_and_affordability() -> void:
	var p := FlightMath.preview(Vector2.ZERO, Vector2(1000.0, 0.0), FlightMath.Burn.STANDARD, 100.0)
	assert_almost_eq(p["distance"], 1000.0, 0.0001)
	assert_eq(p["eta_ticks"], FlightMath.eta_ticks(1000.0, FlightMath.Burn.STANDARD))
	assert_almost_eq(p["rm_cost"], FlightMath.rm_cost(1000.0, FlightMath.Burn.STANDARD), 0.0001)
	assert_true(p["affordable"], "100 RM covers a 1000 wu standard burn")


func test_preview_flags_insufficient_fuel() -> void:
	var p := FlightMath.preview(Vector2.ZERO, Vector2(5000.0, 0.0), FlightMath.Burn.HARD, 1.0)
	assert_false(p["affordable"], "1 RM cannot afford a long hard burn")


func test_reach_wu_round_trips_against_eta() -> void:
	# reach_wu(burn, eta_ticks(d, burn)) should recover d to within one tick's
	# travel — eta rounds ticks up, so reach is the distance at that whole tick.
	for burn: int in [FlightMath.Burn.ECONOMY, FlightMath.Burn.STANDARD, FlightMath.Burn.HARD]:
		var d := 7350.0
		var ticks := FlightMath.eta_ticks(d, burn)
		var reach := FlightMath.reach_wu(burn, ticks)
		var one_tick := FlightMath.speed_wu_per_tick(burn)
		assert_almost_eq(reach, d, one_tick, "reach within one tick of the original distance")
		assert_true(reach >= d, "rounded-up ETA reaches at least the distance")


func test_reach_wu_higher_burn_goes_farther() -> void:
	var t := 20
	var eco := FlightMath.reach_wu(FlightMath.Burn.ECONOMY, t)
	var std := FlightMath.reach_wu(FlightMath.Burn.STANDARD, t)
	var hard := FlightMath.reach_wu(FlightMath.Burn.HARD, t)
	assert_lt(eco, std, "economy covers least in fixed time")
	assert_lt(std, hard, "hard covers most in fixed time")


func test_reach_wu_zero_or_negative_ticks_is_zero() -> void:
	assert_eq(FlightMath.reach_wu(FlightMath.Burn.STANDARD, 0), 0.0)
	assert_eq(FlightMath.reach_wu(FlightMath.Burn.HARD, -5), 0.0)


func test_invalid_burn_is_reported() -> void:
	assert_true(FlightMath.is_valid_burn(FlightMath.Burn.ECONOMY))
	assert_false(FlightMath.is_valid_burn(99), "unknown burn id rejected")
