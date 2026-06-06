class_name Travel
extends RefCounted
## Travel pipeline rules (ADR 0015): the ship's Location, and the pure derivation
## of which orders are legal given the current situation. No node deps — this is
## the single GUT-tested source of truth the Helm uses to enable/disable buttons
## and the FlightController validates against.

## Where the ship is when not under way.
enum Location { DEEP_SPACE, HOLDING, DOCKED }

## Distance (wu) beyond a body's own radius at which ships hold/orbit. The
## holding area is this ring, not the body centre — ships arrive onto it and
## depart from it (so there's no diving through the body).
const HOLDING_GAP: float = 26.0


static func holding_radius(body_radius: float) -> float:
	return body_radius + HOLDING_GAP

const _LOCATION_KEYS: Dictionary = {
	Location.DEEP_SPACE: "TRAVEL_DEEP_SPACE",
	Location.HOLDING: "TRAVEL_HOLDING",
	Location.DOCKED: "TRAVEL_DOCKED",
}


## tr() key for a location (ADR 0010).
static func location_key(location: int) -> String:
	return _LOCATION_KEYS.get(location, "TRAVEL_DEEP_SPACE")


## Which orders are legal in the given context. `context` keys:
##   location: int            — Travel.Location
##   location_can_dock: bool  — is the body we're holding/docked at a station
##   in_transit: bool         — a course is engaged (under way)
##   has_course: bool         — a course is laid in (engaged or not)
##   nav_target_id: String    — the Nav Plot selection ("" = none)
##   nav_target_is_here: bool — the selection is the body we're already at
## Returns a bool per order id (lay_in/engage/belay/all_stop/dock/undock).
static func available(context: Dictionary) -> Dictionary:
	var location: int = int(context.get("location", Location.DEEP_SPACE))
	var in_transit: bool = bool(context.get("in_transit", false))
	var has_course: bool = bool(context.get("has_course", false))
	var nav_target: String = String(context.get("nav_target_id", ""))
	var nav_here: bool = bool(context.get("nav_target_is_here", false))
	var can_dock_here: bool = bool(context.get("location_can_dock", false))
	return {
		"lay_in": nav_target != "" and not nav_here and not in_transit,
		"engage": has_course and not in_transit and location != Location.DOCKED,
		"belay": in_transit,
		"all_stop": in_transit,
		"dock": location == Location.HOLDING and can_dock_here and not in_transit,
		"undock": location == Location.DOCKED,
	}
