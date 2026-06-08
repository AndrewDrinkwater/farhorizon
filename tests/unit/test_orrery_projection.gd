extends GutTest
## Orrery projection (ADR 0016/0018): log-compressed radius, exact bearing.

var _p: OrreryParams


func before_each() -> void:
	_p = OrreryParams.new()
	_p.center = Vector2(960.0, 540.0)
	_p.r_min = 300.0
	_p.r_max = 45000.0
	_p.ring_inner = 60.0
	_p.ring_outer = 450.0


func _radius(real: Vector2) -> float:
	return OrreryProjection.project(real, _p).distance_to(_p.center)


func test_r_min_maps_to_inner_ring() -> void:
	assert_almost_eq(_radius(Vector2(_p.r_min, 0.0)), _p.ring_inner, 0.01)


func test_r_max_maps_to_outer_ring() -> void:
	assert_almost_eq(_radius(Vector2(_p.r_max, 0.0)), _p.ring_outer, 0.01)


func test_geometric_mean_lands_midway() -> void:
	# log is linear in log-space, so sqrt(r_min*r_max) → halfway between rings.
	var mean := sqrt(_p.r_min * _p.r_max)
	assert_almost_eq(_radius(Vector2(mean, 0.0)), (_p.ring_inner + _p.ring_outer) * 0.5, 0.01)


func test_bearing_is_preserved() -> void:
	var real := Vector2.from_angle(1.1) * 5200.0
	var projected := OrreryProjection.project(real, _p) - _p.center
	assert_almost_eq(projected.angle(), real.angle(), 0.0001, "direction unchanged")


func test_monotonic_in_real_distance() -> void:
	assert_lt(_radius(Vector2(1000.0, 0.0)), _radius(Vector2(9500.0, 0.0)),
		"farther in real wu = farther on the chart")


func test_star_clamps_to_hub() -> void:
	assert_eq(OrreryProjection.project(Vector2.ZERO, _p), _p.center, "no log(0)")
	assert_eq(OrreryProjection.project(Vector2(_p.r_min * 0.5, 0.0), _p), _p.center, "inner clamp")


func test_beyond_r_max_clamps_to_outer_ring() -> void:
	assert_almost_eq(_radius(Vector2(_p.r_max * 10.0, 0.0)), _p.ring_outer, 0.01)


func test_real_anchors_land_ordered_between_rings() -> void:
	var au := 1000.0
	var verdant := _radius(Vector2(1.0 * au, 0.0))
	var rubicon := _radius(Vector2(5.2 * au, 0.0))
	var anchorage := _radius(Vector2(9.5 * au, 0.0))
	var tethys := _radius(Vector2(40.0 * au, 0.0))
	assert_lt(verdant, rubicon)
	assert_lt(rubicon, anchorage)
	assert_lt(anchorage, tethys)
	assert_gte(verdant, _p.ring_inner)
	assert_lte(tethys, _p.ring_outer)


func test_project_path_floors_inner_radius_instead_of_collapsing() -> void:
	# Inside r_min, the course projection floors onto the inner ring (so a course
	# near the star arcs around the hub) rather than collapsing to the centre.
	var near := Vector2.from_angle(0.7) * (_p.r_min * 0.3)
	var projected := OrreryProjection.project_path(near, _p)
	assert_almost_eq(projected.distance_to(_p.center), _p.ring_inner, 0.01, "floored to inner ring")
	assert_almost_eq((projected - _p.center).angle(), near.angle(), 0.0001, "bearing preserved")


func test_unproject_round_trips_project() -> void:
	# A real point within the ring band → project → unproject recovers it.
	for spec: Array in [[2.0, 1000.0], [-0.8, 5200.0], [2.7, 40000.0]]:
		var real: Vector2 = Vector2.from_angle(float(spec[0])) * float(spec[1])
		var back := OrreryProjection.unproject(OrreryProjection.project(real, _p), _p)
		assert_almost_eq(back.length(), real.length(), real.length() * 0.001, "radius recovered")
		assert_almost_eq(back.angle(), real.angle(), 0.0001, "bearing recovered")


func test_unproject_hub_click_is_origin() -> void:
	assert_eq(OrreryProjection.unproject(_p.center, _p), Vector2.ZERO)


func test_project_path_exact_hub_is_centre() -> void:
	assert_eq(OrreryProjection.project_path(Vector2.ZERO, _p), _p.center, "no bearing at the hub")


func test_project_path_matches_project_outside_inner_ring() -> void:
	# Beyond r_min the two agree — only the inner clamp differs.
	var real := Vector2.from_angle(-1.3) * 12000.0
	assert_almost_eq(
		OrreryProjection.project_path(real, _p).distance_to(_p.center),
		OrreryProjection.project(real, _p).distance_to(_p.center), 0.01)


# --- LINEAR (true-scale) mode (ADR 0021) ---

func _linear() -> OrreryParams:
	var p := OrreryParams.new()
	p.mode = OrreryParams.ScaleMode.LINEAR
	p.center = Vector2(960.0, 540.0)
	p.r_min = 300.0
	p.r_max = 45000.0
	p.ring_inner = 60.0
	p.ring_outer = 450.0
	return p


func test_linear_maps_r_max_to_outer_ring() -> void:
	var p := _linear()
	var radius := OrreryProjection.project(Vector2(p.r_max, 0.0), p).distance_to(p.center)
	assert_almost_eq(radius, p.ring_outer, 0.01, "r_max sits on the outer ring")


func test_linear_radius_is_proportional() -> void:
	var p := _linear()
	var near := OrreryProjection.project(Vector2(10000.0, 0.0), p).distance_to(p.center)
	var far := OrreryProjection.project(Vector2(20000.0, 0.0), p).distance_to(p.center)
	assert_almost_eq(far, near * 2.0, 0.01, "twice the real distance, twice the chart radius")


func test_linear_preserves_bearing_and_clamps_and_centres() -> void:
	var p := _linear()
	var real := Vector2.from_angle(0.9) * 12000.0
	assert_almost_eq((OrreryProjection.project(real, p) - p.center).angle(), real.angle(), 0.0001)
	assert_eq(OrreryProjection.project(Vector2.ZERO, p), p.center, "the star is the hub")
	assert_almost_eq(OrreryProjection.project(Vector2(p.r_max * 5.0, 0.0), p).distance_to(p.center),
		p.ring_outer, 0.01, "beyond r_max clamps to the outer ring")


func test_linear_unproject_round_trips() -> void:
	var p := _linear()
	var real := Vector2.from_angle(-2.0) * 18000.0
	var back := OrreryProjection.unproject(OrreryProjection.project(real, p), p)
	assert_almost_eq(back.length(), real.length(), real.length() * 0.001, "radius recovered")
	assert_almost_eq(back.angle(), real.angle(), 0.0001, "bearing recovered")


func test_linear_project_path_equals_project() -> void:
	# No log singularity in linear, so the course projection is the plain map.
	var p := _linear()
	var real := Vector2.from_angle(1.7) * 6000.0
	assert_eq(OrreryProjection.project_path(real, p), OrreryProjection.project(real, p))


func test_child_preserves_bearing_from_parent_and_clears_it() -> void:
	var parent_proj := Vector2(700.0, 300.0)
	var offset := Vector2.from_angle(-0.6) * 150.0
	var child := OrreryProjection.project_child(offset, parent_proj, _p)
	var local := child - parent_proj
	assert_almost_eq(local.angle(), offset.angle(), 0.0001, "bearing from parent preserved")
	assert_gte(local.length(), _p.moon_ring_inner - 0.01, "never overlaps the parent")


func test_satellite_farthest_moon_sits_on_the_inset_edge() -> void:
	var center := Vector2(170.0, 150.0)
	var offset := Vector2.from_angle(0.4) * 600.0  # the farthest moon
	var at := OrreryProjection.project_satellite(offset, center, 120.0, 600.0)
	assert_almost_eq(at.distance_to(center), 120.0, 0.01, "farthest moon on the inset edge")
	assert_almost_eq((at - center).angle(), offset.angle(), 0.0001, "bearing preserved")


func test_satellite_is_proportional_and_centres_the_parent() -> void:
	var center := Vector2(170.0, 150.0)
	var half := OrreryProjection.project_satellite(Vector2(300.0, 0.0), center, 120.0, 600.0)
	assert_almost_eq(half.distance_to(center), 60.0, 0.01, "half the offset, half the inset radius")
	assert_eq(OrreryProjection.project_satellite(Vector2.ZERO, center, 120.0, 600.0), center,
		"a zero offset sits on the parent")


func test_child_tiny_offset_sits_on_parent() -> void:
	var parent_proj := Vector2(700.0, 300.0)
	var child := OrreryProjection.project_child(Vector2(_p.moon_r_min * 0.5, 0.0), parent_proj, _p)
	assert_eq(child, parent_proj)
