extends GutTest
## TypeRegistry loads the authored star system(s) from .tres (ADR 0002). Also
## guards that the hardcoded "sol" content stays well-formed.


func test_sol_system_loads() -> void:
	var system := TypeRegistry.get_system("sol")
	assert_not_null(system, "sol system is authored and loaded")
	assert_eq(system.id, "sol", "id matches")
	assert_eq(system.bodies.size(), 5, "star + 3 planets + 1 station")
	assert_ne(system.ship_start, Vector2.ZERO, "has a ship start position")


func test_sol_has_star_planets_and_a_station() -> void:
	var system := TypeRegistry.get_system("sol")
	var has_star := false
	var planet_count := 0
	var station: BodyData = null
	for body: BodyData in system.bodies:
		match body.kind:
			BodyData.Kind.STAR:
				has_star = true
			BodyData.Kind.PLANET:
				planet_count += 1
			BodyData.Kind.STATION:
				station = body
	assert_true(has_star, "has a star")
	assert_eq(planet_count, 3, "has three planets")
	assert_not_null(station, "has a station")
	assert_true(station.can_dock, "station is dockable")
	assert_true(station.can_refuel, "station refuels (step 7)")


func test_bodies_carry_name_keys() -> void:
	# Display names go through tr() keys (ADR 0010); content must supply them.
	var system := TypeRegistry.get_system("sol")
	for body: BodyData in system.bodies:
		assert_ne(body.name_key, "", "body '%s' has a name key" % body.id)


func test_unknown_system_is_null() -> void:
	assert_null(TypeRegistry.get_system("does_not_exist"), "missing id -> null")
	assert_false(TypeRegistry.has_system("does_not_exist"), "has_system false for missing")
