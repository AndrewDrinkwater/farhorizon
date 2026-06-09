class_name ShipState
extends RefCounted
## Runtime ship state (ADR 0002). The authored hull is referenced by id and
## resolved through TypeRegistry on read — never embedded (CONVENTIONS.md).
## Fuel/flight detail fills in at build-order steps 5-7; this is the step-3 stub
## that proves the tree serializes. The active order lives here so a mid-order
## save resumes (ADR 0014); empty dict = no active order.

var hull_id: String = "scout"
var position: Vector2 = Vector2.ZERO
var heading: float = 0.0  # radians
var reaction_mass: float = 100.0  # RM (CONVENTIONS.md "Fuel")
var max_reaction_mass: float = 100.0  # tank capacity; refuel fills to this
var sensor_range: float = 3000.0  # wu (~3 AU) — detection radius (ADR 0017)
## Where the ship is when not under way (ADR 0015). DEEP_SPACE at game start.
var location: int = Travel.Location.DEEP_SPACE
var location_body_id: String = ""  # body we're holding at / docked at ("" = none)
var orbit_angle: float = 0.0  # angle on the holding ring while HOLDING (radians)
## The laid-in course (target state): {target_id, burn, engaged, origin}.
var current_order: Dictionary = {}

## Surface / landing (ADR 0029/0030). While LANDED, the surface site the ship is at
## ("" = Open Landing / wild touchdown). Base land stats live here until HullData
## exists; durations are modified (LandingMath) — these are the unmodified bases.
var surface_site_id: String = ""
var surface_position: Vector2 = Vector2.ZERO  # actual surface coords (su) — site or free point
var surface_speed_su_per_tick: float = 50.0  # planetary flight speed (su/tick)
var base_descent_ticks: int = 6
var base_ascent_ticks: int = 5


func to_dict() -> Dictionary:
	return {
		"hull_id": hull_id,
		"position": position,
		"heading": heading,
		"reaction_mass": reaction_mass,
		"max_reaction_mass": max_reaction_mass,
		"sensor_range": sensor_range,
		"location": location,
		"location_body_id": location_body_id,
		"orbit_angle": orbit_angle,
		"current_order": current_order,
		"surface_site_id": surface_site_id,
		"surface_position": surface_position,
		"surface_speed_su_per_tick": surface_speed_su_per_tick,
		"base_descent_ticks": base_descent_ticks,
		"base_ascent_ticks": base_ascent_ticks,
	}


## Forgiving rebuild: missing keys fall back to defaults (ADR 0008).
static func from_dict(data: Dictionary) -> ShipState:
	var s := ShipState.new()
	s.hull_id = String(data.get("hull_id", s.hull_id))
	s.position = data.get("position", s.position)
	s.heading = float(data.get("heading", s.heading))
	s.reaction_mass = float(data.get("reaction_mass", s.reaction_mass))
	s.max_reaction_mass = float(data.get("max_reaction_mass", s.max_reaction_mass))
	s.sensor_range = float(data.get("sensor_range", s.sensor_range))
	s.location = int(data.get("location", s.location))
	s.location_body_id = String(data.get("location_body_id", s.location_body_id))
	s.orbit_angle = float(data.get("orbit_angle", s.orbit_angle))
	s.current_order = data.get("current_order", s.current_order)
	s.surface_site_id = String(data.get("surface_site_id", s.surface_site_id))
	s.surface_position = data.get("surface_position", s.surface_position)
	s.surface_speed_su_per_tick = float(data.get("surface_speed_su_per_tick", s.surface_speed_su_per_tick))
	s.base_descent_ticks = int(data.get("base_descent_ticks", s.base_descent_ticks))
	s.base_ascent_ticks = int(data.get("base_ascent_ticks", s.base_ascent_ticks))
	return s
