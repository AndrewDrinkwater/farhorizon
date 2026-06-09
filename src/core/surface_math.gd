class_name SurfaceMath
extends RefCounted
## Pure planetary-surface navigation math (ADR 0030): the time to move between two
## surface points at a ship's surface speed. Surface units (su) are a per-body
## local plane, distinct from world units. No node deps; GUT-tested.


## Whole ticks to move `from`→`to` at `speed_su_per_tick` (rounded, ADR 0030).
## Non-positive speed is guarded to 0 (the controller never passes it).
static func surface_ticks(from: Vector2, to: Vector2, speed_su_per_tick: float) -> int:
	if speed_su_per_tick <= 0.0:
		return 0
	return int(round(from.distance_to(to) / speed_su_per_tick))
