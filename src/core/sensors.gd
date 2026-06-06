class_name Sensors
extends RefCounted
## Pure sensor detection (ADR 0017): which entities are within range of the ship,
## decided in REAL space (never display scale). No node deps; GUT-tested. The
## detection node runs this off EventBus.sim_tick.

## Detection ladder: in-range is automatic (BLIP); IDENTIFIED is a scan action
## (later). Forward-compatible with contact→identified→surveyed→explored.
enum Tier { UNDETECTED, BLIP, IDENTIFIED }


## Entities (each with a `.position`) within `radius` of a point.
static func contacts_in_range(ship_pos: Vector2, radius: float, entities: Array) -> Array:
	var found: Array = []
	for e in entities:
		if ship_pos.distance_to(e.position) <= radius:
			found.append(e)
	return found


## Entities within `radius` of the segment travelled this tick (capsule test), so
## a fast (Hard-burn) hop can't tunnel past a small contact between point samples.
static func contacts_in_segment(from: Vector2, to: Vector2, radius: float, entities: Array) -> Array:
	var found: Array = []
	for e in entities:
		if _point_to_segment_distance(e.position, from, to) <= radius:
			found.append(e)
	return found


## Shortest distance from point `p` to segment `a`→`b`.
static func _point_to_segment_distance(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq == 0.0:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)
