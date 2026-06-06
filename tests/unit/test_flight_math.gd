extends GutTest
## Pure ETA/fuel math (ADR 0005). Asserts the time-vs-fuel tradeoff holds and the
## edge cases behave, independent of the exact tuning numbers.


func test_distance_is_euclidean() -> void:
	assert_almost_eq(FlightMath.distance(Vector2.ZERO, Vector2(3.0, 4.0)), 5.0, 0.0001)
	assert_eq(FlightMath.distance(Vector2(10.0, 10.0), Vector2(10.0, 10.0)), 0.0)


func test_eta_rounds_up() -> void:
	# Standard = 120 wu/tick: 121 wu needs 2 ticks, 240 wu exactly 2.
	assert_eq(FlightMath.eta_ticks(121.0, FlightMath.Burn.STANDARD), 2, "partial tick rounds up")
	assert_eq(FlightMath.eta_ticks(240.0, FlightMath.Burn.STANDARD), 2, "exact multiple")


func test_higher_burn_is_faster() -> void:
	var d := 1000.0
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


func test_invalid_burn_is_reported() -> void:
	assert_true(FlightMath.is_valid_burn(FlightMath.Burn.ECONOMY))
	assert_false(FlightMath.is_valid_burn(99), "unknown burn id rejected")
