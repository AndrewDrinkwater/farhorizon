extends GutTest
## TypeRegistry loads the authored star system(s) from .tres (ADR 0002). Also
## guards that the hardcoded "sol" content stays well-formed.


func test_sol_system_loads() -> void:
	var system := TypeRegistry.get_system("sol")
	assert_not_null(system, "sol system is authored and loaded")
	assert_eq(system.id, "sol", "id matches")
	assert_eq(system.bodies.size(), 6, "star + 3 planets + 1 station + 1 moon")
	assert_ne(system.ship_start, Vector2.ZERO, "has a ship start position")


func test_sol_has_a_moon_with_a_parent() -> void:
	var system := TypeRegistry.get_system("sol")
	var moon: BodyData = null
	for body: BodyData in system.bodies:
		if body.kind == BodyData.Kind.MOON:
			moon = body
	assert_not_null(moon, "has a moon")
	assert_eq(moon.parent_id, "verdant", "moon orbits its parent planet")


func test_sol_has_transient_contacts() -> void:
	var system := TypeRegistry.get_system("sol")
	assert_gte(system.contacts.size(), 2, "authored transient contacts present")


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


func test_calder_reach_loads_at_the_specced_density() -> void:
	var system := TypeRegistry.get_system("calder")
	assert_not_null(system, "Calder Reach is authored and loaded")
	assert_eq(system.id, "calder")
	assert_eq(system.bodies.size(), 17, "1 star + 8 planets + 6 moons + 2 stations")
	assert_eq(system.contacts.size(), 7, "seven transient contacts")
	var stars := 0
	var planets := 0
	var moons := 0
	var stations := 0
	for body: BodyData in system.bodies:
		match body.kind:
			BodyData.Kind.STAR: stars += 1
			BodyData.Kind.PLANET: planets += 1
			BodyData.Kind.MOON: moons += 1
			BodyData.Kind.STATION: stations += 1
		assert_ne(body.name_key, "", "body '%s' has a name key" % body.id)
	assert_eq(stars, 1, "one star")
	assert_eq(planets, 8, "eight planets (incl. the gas giant)")
	assert_eq(moons, 6, "six moons")
	assert_eq(stations, 2, "two stations")


func test_calder_moons_reference_real_parents() -> void:
	var system := TypeRegistry.get_system("calder")
	var ids: Dictionary = {}
	for body: BodyData in system.bodies:
		ids[body.id] = body
	for body: BodyData in system.bodies:
		if body.kind == BodyData.Kind.MOON:
			assert_true(ids.has(body.parent_id), "moon '%s' parent '%s' exists" % [body.id, body.parent_id])
			assert_ne(body.kind, ids[body.parent_id].kind, "a moon's parent isn't itself a moon")


func test_calder_zones_load_one_of_each_shape_and_category() -> void:
	var system := TypeRegistry.get_system("calder")
	assert_eq(system.zones.size(), 5, "five authored zones")
	var shapes: Dictionary = {}
	var categories: Dictionary = {}
	for zone: ZoneData in system.zones:
		shapes[zone.shape] = true
		categories[zone.category] = true
		assert_ne(zone.name_key, "", "zone '%s' has a name key" % zone.id)
	assert_true(shapes.has(ZoneData.Shape.CIRCLE), "a circle zone")
	assert_true(shapes.has(ZoneData.Shape.BAND), "a band zone")
	assert_true(shapes.has(ZoneData.Shape.POLYGON), "a polygon zone")
	assert_eq(categories.size(), 5, "all five categories represented")


func test_calder_zone_effects_authored() -> void:
	var system := TypeRegistry.get_system("calder")
	var by_id: Dictionary = {}
	for zone: ZoneData in system.zones:
		by_id[zone.id] = zone
	assert_eq(String(by_id["calder_corona"].effects.get("blocks_course", "")), "nogo", "corona is no-go")
	assert_eq(String(by_id["bastion_belt"].effects.get("blocks_course", "")), "hazard", "belt is a hazard")
	assert_eq(by_id["calder_corona"].anchor_body_id, "calder", "corona anchored to the star")
	assert_true(bool(by_id["drift_signal"].effects.get("once", false)), "drift trigger is one-shot")


func test_unknown_system_is_null() -> void:
	assert_null(TypeRegistry.get_system("does_not_exist"), "missing id -> null")
	assert_false(TypeRegistry.has_system("does_not_exist"), "has_system false for missing")
