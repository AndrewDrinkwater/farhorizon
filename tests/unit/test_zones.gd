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


func test_anchor_resolution_offsets_geometry() -> void:
	var system := TypeRegistry.get_system("calder")
	var bastion: BodyData = null
	for b: BodyData in system.bodies:
		if b.id == "bastion":
			bastion = b
	var belt: ZoneData = null
	for z: ZoneData in system.zones:
		if z.id == "bastion_belt":
			belt = z
	assert_eq(Zones.world_center(belt, system), bastion.position, "band centred on its anchor body")
	# A free zone is unaffected.
	var veil: ZoneData = null
	for z: ZoneData in system.zones:
		if z.id == "veil_cloud":
			veil = z
	assert_eq(Zones.world_points(veil, system), veil.points, "free polygon keeps absolute points")


func test_ring_points_lie_on_the_circle() -> void:
	var pts := Zones.ring_points(Vector2(10.0, 20.0), 100.0, 16)
	assert_eq(pts.size(), 16)
	for p: Vector2 in pts:
		assert_almost_eq(p.distance_to(Vector2(10.0, 20.0)), 100.0, 0.01, "on the boundary")


func test_polygon_degenerate_is_never_inside() -> void:
	var two := PackedVector2Array([Vector2(0, 0), Vector2(10, 0)])
	assert_false(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, two, Vector2(5.0, 0.0)),
		"fewer than three points is not a region")
	assert_false(Zones.contains(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, NONE, Vector2.ZERO),
		"empty polygon is not a region")


# --- segment_intersects (ADR 0027) ---

func test_circle_segment_clip_inside_outside() -> void:
	var c := Vector2.ZERO
	# A leg passing through the disc.
	assert_true(Zones.segment_intersects(ZoneData.Shape.CIRCLE, c, 100.0, 0.0, NONE,
		Vector2(-200.0, 0.0), Vector2(200.0, 0.0)), "leg crosses the disc")
	# A leg clipping the edge (closest approach == radius).
	assert_true(Zones.segment_intersects(ZoneData.Shape.CIRCLE, c, 100.0, 0.0, NONE,
		Vector2(-200.0, 100.0), Vector2(200.0, 100.0)), "tangent leg touches")
	# A leg passing wide.
	assert_false(Zones.segment_intersects(ZoneData.Shape.CIRCLE, c, 100.0, 0.0, NONE,
		Vector2(-200.0, 300.0), Vector2(200.0, 300.0)), "wide leg misses")
	# A leg fully inside.
	assert_true(Zones.segment_intersects(ZoneData.Shape.CIRCLE, c, 100.0, 0.0, NONE,
		Vector2(-10.0, 0.0), Vector2(10.0, 0.0)), "leg fully inside counts")


func test_band_segment_only_in_hole_misses() -> void:
	var c := Vector2.ZERO  # inner 100, outer 300
	assert_false(Zones.segment_intersects(ZoneData.Shape.BAND, c, 300.0, 100.0, NONE,
		Vector2(-50.0, 0.0), Vector2(50.0, 0.0)), "leg entirely in the inner hole misses the annulus")
	assert_true(Zones.segment_intersects(ZoneData.Shape.BAND, c, 300.0, 100.0, NONE,
		Vector2(-400.0, 0.0), Vector2(400.0, 0.0)), "leg crossing the annulus hits")
	assert_false(Zones.segment_intersects(ZoneData.Shape.BAND, c, 300.0, 100.0, NONE,
		Vector2(-400.0, 400.0), Vector2(400.0, 400.0)), "leg beyond the outer edge misses")


func test_polygon_segment_crossing_and_clear() -> void:
	var sq := PackedVector2Array([Vector2(0, 0), Vector2(100, 0), Vector2(100, 100), Vector2(0, 100)])
	assert_true(Zones.segment_intersects(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, sq,
		Vector2(-50.0, 50.0), Vector2(150.0, 50.0)), "leg crosses the square")
	assert_false(Zones.segment_intersects(ZoneData.Shape.POLYGON, Vector2.ZERO, 0.0, 0.0, sq,
		Vector2(-50.0, 200.0), Vector2(150.0, 200.0)), "leg passes clear")


func test_route_block_picks_worst_and_routes_around() -> void:
	var system := TypeRegistry.get_system("calder")
	# A leg straight through the star (calder_corona is a no-go disc at the origin).
	var through := PackedVector2Array([Vector2(-2000.0, 0.0), Vector2(2000.0, 0.0)])
	assert_eq(Zones.route_block(system, through), Zones.Block.NOGO, "crossing the corona is no-go")
	# Routing well around it via a waypoint clears the no-go.
	var around := PackedVector2Array([Vector2(-2000.0, 0.0), Vector2(0.0, 3000.0), Vector2(2000.0, 0.0)])
	assert_ne(Zones.route_block(system, around), Zones.Block.NOGO, "a detour around the corona is allowed")
