extends GutTest
## Pure landing math (ADR 0029): atmosphere class thresholds + the modifiable-stat
## chain. Independent of the exact tuning numbers where possible.


func test_atmosphere_class_thresholds() -> void:
	assert_eq(LandingMath.atmosphere_class(0.0), LandingMath.AtmoClass.NONE, "vacuum")
	assert_eq(LandingMath.atmosphere_class(0.2), LandingMath.AtmoClass.THIN, "trace")
	assert_eq(LandingMath.atmosphere_class(0.9), LandingMath.AtmoClass.STANDARD, "near Earth")
	assert_eq(LandingMath.atmosphere_class(LandingMath.STANDARD_ATM), LandingMath.AtmoClass.DENSE,
		"boundary lands in the upper class")
	assert_eq(LandingMath.atmosphere_class(30.0), LandingMath.AtmoClass.CRUSHING, "gas giant")


func test_atmosphere_factor_is_one_at_vacuum_and_monotonic() -> void:
	assert_almost_eq(LandingMath.atmosphere_factor(0.0), 1.0, 0.0001, "vacuum costs nothing extra")
	assert_lt(LandingMath.atmosphere_factor(0.0), LandingMath.atmosphere_factor(0.9), "more atm, more time")
	assert_lt(LandingMath.atmosphere_factor(0.9), LandingMath.atmosphere_factor(5.0), "monotonic")


func test_modified_ticks_chain() -> void:
	assert_eq(LandingMath.modified_ticks(6, []), 6, "empty chain leaves the base")
	assert_eq(LandingMath.modified_ticks(6, [1.5]), 9, "single factor applied")
	assert_eq(LandingMath.modified_ticks(5, [1.55]), 8, "product rounded (7.75 → 8)")
	assert_eq(LandingMath.modified_ticks(4, [1.5, 2.0]), 12, "factors multiply")


func test_descent_and_ascent_share_the_chain() -> void:
	# Both durations are modified_ticks with the same atmosphere factor.
	var f := LandingMath.atmosphere_factor(1.1)
	assert_eq(LandingMath.modified_ticks(6, [f]), int(round(6.0 * f)), "descent")
	assert_eq(LandingMath.modified_ticks(5, [f]), int(round(5.0 * f)), "ascent, same chain")
