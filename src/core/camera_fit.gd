class_name CameraFit
extends RefCounted
## Pure camera-zoom math (CONVENTIONS.md "camera zoom min/max bounds"). Picks a
## Camera2D zoom that frames a system of a given extent within the viewport, and
## defines the zoom bounds the wheel operates within. No node deps; GUT-testable.

## Camera2D zoom bounds (zoom value: larger = more zoomed in).
const MIN_ZOOM: float = 0.12
const MAX_ZOOM: float = 1.5
## Padding factor so bodies aren't flush against the screen edge.
const MARGIN: float = 1.18


## Zoom that fits a circle of `extent_radius` wu (around the camera centre) inside
## the smaller half-dimension of `viewport`, clamped to the zoom bounds.
static func fit_zoom(extent_radius: float, viewport: Vector2,
		min_zoom: float = MIN_ZOOM, max_zoom: float = MAX_ZOOM) -> float:
	if extent_radius <= 0.0:
		return max_zoom
	var half_screen: float = minf(viewport.x, viewport.y) * 0.5
	return clampf(half_screen / extent_radius, min_zoom, max_zoom)


## Clamp a proposed zoom to the bounds (used by wheel zoom).
static func clamp_zoom(zoom: float, min_zoom: float = MIN_ZOOM, max_zoom: float = MAX_ZOOM) -> float:
	return clampf(zoom, min_zoom, max_zoom)
