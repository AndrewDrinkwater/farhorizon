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
## Where the ship is when not under way (ADR 0015). DEEP_SPACE at game start.
var location: int = Travel.Location.DEEP_SPACE
var location_body_id: String = ""  # body we're holding at / docked at ("" = none)
## The laid-in course (target state): {target_id, burn, engaged, origin}.
var current_order: Dictionary = {}


func to_dict() -> Dictionary:
	return {
		"hull_id": hull_id,
		"position": position,
		"heading": heading,
		"reaction_mass": reaction_mass,
		"max_reaction_mass": max_reaction_mass,
		"location": location,
		"location_body_id": location_body_id,
		"current_order": current_order,
	}


## Forgiving rebuild: missing keys fall back to defaults (ADR 0008).
static func from_dict(data: Dictionary) -> ShipState:
	var s := ShipState.new()
	s.hull_id = String(data.get("hull_id", s.hull_id))
	s.position = data.get("position", s.position)
	s.heading = float(data.get("heading", s.heading))
	s.reaction_mass = float(data.get("reaction_mass", s.reaction_mass))
	s.max_reaction_mass = float(data.get("max_reaction_mass", s.max_reaction_mass))
	s.location = int(data.get("location", s.location))
	s.location_body_id = String(data.get("location_body_id", s.location_body_id))
	s.current_order = data.get("current_order", s.current_order)
	return s
