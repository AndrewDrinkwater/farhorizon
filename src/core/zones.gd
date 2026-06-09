class_name Zones
extends RefCounted
## Pure zone geometry (ADR 0026/0027): membership now, segment intersection in the
## routing slice. Decided entirely in real space, so the orrery's non-linearity
## never enters (mirrors Sensors, ADR 0017). No node deps; GUT-tested. The
## ZoneController resolves anchored centres/points before calling these.


## Is `point` inside the zone? `center`/`points` are already anchor-resolved.
static func contains(shape: int, center: Vector2, radius: float, inner: float,
		points: PackedVector2Array, point: Vector2) -> bool:
	match shape:
		ZoneData.Shape.CIRCLE:
			return center.distance_to(point) <= radius
		ZoneData.Shape.BAND:
			var d := center.distance_to(point)
			return d >= inner and d <= radius
		ZoneData.Shape.POLYGON:
			return points.size() >= 3 and Geometry2D.is_point_in_polygon(point, points)
	return false
