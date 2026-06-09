extends GutTest
## Helm control-group context resolver (ADR 0032): which clusters apply to a
## situation. Pure; independent of the button wiring.


func _groups(overrides: Dictionary) -> Dictionary:
	var base := {"location": Travel.Location.DEEP_SPACE, "location_can_dock": false, "landable_here": false}
	base.merge(overrides, true)
	return HelmGroups.visible_groups(base)


func test_deep_space_shows_flight_and_sensors_only() -> void:
	var g := _groups({"location": Travel.Location.DEEP_SPACE})
	assert_true(g["flight"])
	assert_true(g["sensors"])
	assert_false(g["docking"], "no station here")
	assert_false(g["surface"], "not at a landable body")


func test_holding_at_a_station_shows_docking() -> void:
	var g := _groups({"location": Travel.Location.HOLDING, "location_can_dock": true})
	assert_true(g["docking"], "a dockable body → Docking cluster")
	assert_false(g["surface"], "a station is not landable")


func test_holding_at_a_landable_body_shows_surface() -> void:
	var g := _groups({"location": Travel.Location.HOLDING, "landable_here": true})
	assert_true(g["surface"], "landable orbit → Surface cluster")
	assert_false(g["docking"], "not a station")


func test_docked_shows_docking_and_flight() -> void:
	var g := _groups({"location": Travel.Location.DOCKED})
	assert_true(g["docking"], "Undock lives here")
	assert_true(g["flight"], "can still plan a course")
	assert_false(g["surface"])


func test_landed_shows_surface_only() -> void:
	var g := _groups({"location": Travel.Location.LANDED})
	assert_true(g["surface"], "Take Off / Move")
	assert_false(g["flight"], "no space flight on the surface")
	assert_false(g["sensors"])
	assert_false(g["docking"])
