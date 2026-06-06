extends GutTest
## Pure camera-fit zoom math (CONVENTIONS.md). Bounds + framing, independent of
## the exact tuning numbers.

const VP := Vector2(1920.0, 1080.0)  # half-min dimension = 540


func test_fits_extent_within_bounds() -> void:
	# extent 1000 wu -> 540/1000 = 0.54, comfortably inside [MIN, MAX].
	assert_almost_eq(CameraFit.fit_zoom(1000.0, VP), 0.54, 0.0001)


func test_large_system_clamps_to_min_zoom() -> void:
	assert_eq(CameraFit.fit_zoom(10000000.0, VP), CameraFit.MIN_ZOOM, "huge extent zooms all the way out")


func test_tiny_or_zero_extent_clamps_to_max_zoom() -> void:
	assert_eq(CameraFit.fit_zoom(1.0, VP), CameraFit.MAX_ZOOM, "tiny extent clamps in")
	assert_eq(CameraFit.fit_zoom(0.0, VP), CameraFit.MAX_ZOOM, "zero extent is safe")


func test_clamp_zoom_respects_bounds() -> void:
	assert_eq(CameraFit.clamp_zoom(99.0), CameraFit.MAX_ZOOM)
	assert_eq(CameraFit.clamp_zoom(0.0001), CameraFit.MIN_ZOOM)
	assert_almost_eq(CameraFit.clamp_zoom(0.5), 0.5, 0.0001)
