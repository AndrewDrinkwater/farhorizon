extends GutTest
## Pure zone membership (ADR 0026). Real-space geometry per shape; the segment
## tests land with the routing slice (ADR 0027).

var NONE := PackedVector2Array()


func test_circle_inside_outside_and_boundary() -> void:
	var c := Vector2(100.0, 100.0)
	assert_true(Zones.contains(ZoneData.Shape.CIRCLE, c, 50.0, 0.0, NONE, Vector2(120.0, 100.0)), "inside")
	assert_false(Zones.contains(ZoneData.Shape.CIRCLE, c, 50.0, 0.0, NONE, Vector2(200.0, 100.0)), "outside")
	assert_true(Zones.contains(ZoneData.Shape.CIRCLE, c, 50.0, 0.0, NONE, Vector2(150.0, 100.0)), "on the boundary counts")


func test_circle_zero_radius_is_only_the_centre() -> void:
	var c := Vector2.ZERO
	assert_true(Zones.contains(ZoneData.Shape.CIRCLE, c, 0.0, 0.0, NONE, c))
	assert_false(Zones.contains(ZoneData.Shape.CIRCLE, c, 0.0, 0.0, NONE, Vector2(1.0, 0.0)))


func test_band_between_inner_and_outer() -> void:
	var c := Vector2.ZERO
	# inner 300, outer 600
	assert_false(Zones.contains(ZoneData.Shape.BAND, c, 600.0, 300.0, NONE, Vector2(200.0, 0.0)), "inside the hole")
	assert_true(Zones.contains(ZoneData.Shape.BAND, c, 600.0, 300.0, NONE, Vector2(450.0, 0.0)), "in the annulus")
	assert_false(Zones.contains(ZoneData.Shape.BAND, c, 600.0, 300.0, NONE, Vector2(700.0, 0.0)), "beyond the outer")
	assert_true(Zones.contains(ZoneData.Shape.BAND, c, 600.0, 300.0, NONE, Vector2(300.0, 0.0)), "inner edge counts")
	assert_true(Zones.contains(ZoneData.Shape.BAND, c, 600.0, 300.0, NONE, Vector2(600.0, 0.0)), "outer edge counts")


func test_polygon_inside_outside() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	assert_true(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, sq, Vector2(50.0, 50.0)), "inside")
	assert_false(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, sq, Vector2(150.0, 50.0)), "outside")


func test_polygon_degenerate_is_never_inside() -> void:
	var two := PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	assert_false(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, two, Vector2(5.0, 0.0)),
		"fewer than three points is not a region")
	assert_false(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, NONE, Vector2.ZERO),
		"empty polygon is not a region")
