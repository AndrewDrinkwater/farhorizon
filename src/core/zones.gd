class_name Zones
extends RefCounted
## Pure zone geometry (ADR 0026/0027): membership now, segment intersection in the
## routing slice. Decided entirely in real space, so the orrery's non-linearity
## never enters (mirrors Sensors, ADR 0017). No node deps; GUT-tested. The
## ZoneController resolves anchored centres/points before calling these.


## --- Anchor resolution (ADR 0018): geometry offset by the anchor body ---

## World offset for a zone's geometry: the anchor body's position, or zero if free.
static func anchor_offset(zone: ZoneData, system: SystemData) -> Vector2:
	if zone.anchor_body_id == "":
		return Vector2.ZERO
	for body: BodyData in system.bodies:
		if body.id == zone.anchor_body_id:
			return body.position
	return Vector2.ZERO


## Resolved world centre of a CIRCLE/BAND zone.
static func world_center(zone: ZoneData, system: SystemData) -> Vector2:
	return anchor_offset(zone, system) + zone.center


## Resolved world polygon vertices (anchor-offset applied). Empty for non-polygons.
static func world_points(zone: ZoneData, system: SystemData) -> PackedVector2Array:
	if zone.shape != ZoneData.Shape.POLYGON:
		return PackedVector2Array()
	var offset := anchor_offset(zone, system)
	if offset == Vector2.ZERO:
		return zone.points
	var out := PackedVector2Array()
	for p: Vector2 in zone.points:
		out.append(p + offset)
	return out


## Sample a circle boundary into `segments` real-space points (for warped/true
## rendering — the view maps each point through its own projection).
static func ring_points(center: Vector2, radius: float, segments: int = 48) -> PackedVector2Array:
	var out := PackedVector2Array()
	for i in segments:
		var a := TAU * float(i) / float(segments)
		out.append(center + Vector2(cos(a), sin(a)) * radius)
	return out


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


## Does the segment a→b touch the zone? (course-leg validation, ADR 0027)
static func segment_intersects(shape: int, center: Vector2, radius: float, inner: float,
		points: PackedVector2Array, a: Vector2, b: Vector2) -> bool:
	match shape:
		ZoneData.Shape.CIRCLE:
			var closest := Geometry2D.get_closest_point_to_segment(center, a, b)
			return center.distance_to(closest) <= radius
		ZoneData.Shape.BAND:
			var c := Geometry2D.get_closest_point_to_segment(center, a, b)
			if center.distance_to(c) > radius:
				return false  # entirely beyond the outer edge
			# Entirely within the inner hole? (the disc is convex, so both ends inside ⇒ all inside)
			return not (center.distance_to(a) <= inner and center.distance_to(b) <= inner)
		ZoneData.Shape.POLYGON:
			if points.size() < 3:
				return false
			if Geometry2D.is_point_in_polygon(a, points) or Geometry2D.is_point_in_polygon(b, points):
				return true
			for i in points.size():
				var e0 := points[i]
				var e1 := points[(i + 1) % points.size()]
				if Geometry2D.segment_intersects_segment(a, b, e0, e1) != null:
					return true
			return false
	return false


## Obstruction levels for course-leg validation (ADR 0027), worst-wins.
enum Block { CLEAR, HAZARD, NOGO }


## Worst obstruction across a route's consecutive legs, from zones tagged
## `blocks_course` ("nogo" → reject the leg; "hazard" → warn). `route` is the full
## ordered point list (ship, waypoints…, destination). Pure (resolves anchors).
static func route_block(system: SystemData, route: PackedVector2Array) -> int:
	var worst := Block.CLEAR
	for i in range(route.size() - 1):
		worst = maxi(worst, _leg_block(system, route[i], route[i + 1]))
		if worst == Block.NOGO:
			return Block.NOGO
	return worst


static func _leg_block(system: SystemData, a: Vector2, b: Vector2) -> int:
	var worst := Block.CLEAR
	for zone: ZoneData in system.zones:
		var tag := String(zone.effects.get("blocks_course", ""))
		if tag == "":
			continue
		if segment_intersects(zone.shape, world_center(zone, system), zone.radius,
				zone.inner_radius, world_points(zone, system), a, b):
			if tag == "nogo":
				return Block.NOGO
			elif tag == "hazard":
				worst = Block.HAZARD
	return worst
