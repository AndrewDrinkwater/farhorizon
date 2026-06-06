extends GutTest
## Pure sensor detection (ADR 0017): real-space range + segment (capsule) check.


func _contact(pos: Vector2) -> ContactData:
	var c := ContactData.new()
	c.position = pos
	return c


func test_in_range_inside_outside_and_boundary() -> void:
	var entities := [_contact(Vector2(50.0, 0.0)), _contact(Vector2(200.0, 0.0)), _contact(Vector2(100.0, 0.0))]
	var found := Sensors.contacts_in_range(Vector2.ZERO, 100.0, entities)
	assert_eq(found.size(), 2, "inside + exactly-on-boundary count; outside does not")


func test_in_range_empty_and_zero_radius() -> void:
	assert_eq(Sensors.contacts_in_range(Vector2.ZERO, 100.0, []).size(), 0)
	assert_eq(Sensors.contacts_in_range(Vector2.ZERO, 0.0, [_contact(Vector2(1.0, 0.0))]).size(), 0)


func test_segment_catches_mid_path_contact() -> void:
	# A contact off to the side of a long fast hop: missed by either endpoint,
	# caught by the segment (capsule) test.
	var c := _contact(Vector2(500.0, 30.0))
	var from := Vector2.ZERO
	var to := Vector2(1000.0, 0.0)
	assert_eq(Sensors.contacts_in_range(from, 50.0, [c]).size(), 0, "not near the start")
	assert_eq(Sensors.contacts_in_range(to, 50.0, [c]).size(), 0, "not near the end")
	assert_eq(Sensors.contacts_in_segment(from, to, 50.0, [c]).size(), 1, "but the path passes within range")


func test_segment_degenerates_to_point() -> void:
	var c := _contact(Vector2(40.0, 0.0))
	var p := Vector2.ZERO
	assert_eq(Sensors.contacts_in_segment(p, p, 50.0, [c]).size(), 1, "from == to behaves like a point check")


func test_segment_respects_radius() -> void:
	var c := _contact(Vector2(500.0, 80.0))
	var from := Vector2.ZERO
	var to := Vector2(1000.0, 0.0)
	assert_eq(Sensors.contacts_in_segment(from, to, 50.0, [c]).size(), 0, "80 wu off a 50 wu sweep = miss")
	assert_eq(Sensors.contacts_in_segment(from, to, 100.0, [c]).size(), 1, "wider sweep catches it")
