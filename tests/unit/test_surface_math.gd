extends GutTest
## Pure planetary-surface navigation math (ADR 0030).


func test_zero_distance_is_zero_ticks() -> void:
	assert_eq(SurfaceMath.surface_ticks(Vector2(10, 20), Vector2(10, 20), 50.0), 0)


func test_symmetric() -> void:
	var a := Vector2(0, 0)
	var b := Vector2(300, 400)  # 500 su
	assert_eq(SurfaceMath.surface_ticks(a, b, 50.0), SurfaceMath.surface_ticks(b, a, 50.0))


func test_scales_with_distance_and_speed() -> void:
	assert_eq(SurfaceMath.surface_ticks(Vector2.ZERO, Vector2(200, 0), 50.0), 4, "200 su at 50/tick")
	assert_eq(SurfaceMath.surface_ticks(Vector2.ZERO, Vector2(400, 0), 50.0), 8, "twice as far")
	assert_eq(SurfaceMath.surface_ticks(Vector2.ZERO, Vector2(200, 0), 100.0), 2, "twice as fast")


func test_non_positive_speed_is_guarded() -> void:
	assert_eq(SurfaceMath.surface_ticks(Vector2.ZERO, Vector2(200, 0), 0.0), 0, "no div-by-zero")
