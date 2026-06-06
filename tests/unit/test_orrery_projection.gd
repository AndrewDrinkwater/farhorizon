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


func test_child_preserves_bearing_from_parent_and_clears_it() -> void:
	var parent_proj := Vector2(700.0, 300.0)
	var offset := Vector2.from_angle(-0.6) * 150.0
	var child := OrreryProjection.project_child(offset, parent_proj, _p)
	var local := child - parent_proj
	assert_almost_eq(local.angle(), offset.angle(), 0.0001, "bearing from parent preserved")
	assert_gte(local.length(), _p.moon_ring_inner - 0.01, "never overlaps the parent")


func test_child_tiny_offset_sits_on_parent() -> void:
	var parent_proj := Vector2(700.0, 300.0)
	var child := OrreryProjection.project_child(Vector2(_p.moon_r_min * 0.5, 0.0), parent_proj, _p)
	assert_eq(child, parent_proj)
