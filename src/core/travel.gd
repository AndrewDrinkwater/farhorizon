class_name Travel
extends RefCounted
## Travel pipeline rules (ADR 0015): the ship's Location, and the pure derivation
## of which orders are legal given the current situation. No node deps — this is
## the single GUT-tested source of truth the Helm uses to enable/disable buttons
## and the FlightController validates against.

## World units per astronomical unit — the spatial scale (CONVENTIONS.md). Bodies
## are placed at realistic AU distances (×this); flight speeds derive from it too
## (FlightMath: Warp 1 = light crosses 1 AU in 8 ticks).
const WU_PER_AU: float = 1000.0

## Where the ship is when not under way. LANDED is the surface context (ADR 0029).
enum Location { DEEP_SPACE, HOLDING, DOCKED, LANDED }

## What a Nav Plot selection points at (ADR 0020). BODY/CONTACT carry an id;
## POINT is a free waypoint in empty space (no id); NONE = nothing selected.
enum TargetKind { NONE, BODY, CONTACT, POINT }

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
	Location.LANDED: "TRAVEL_LANDED",
}


## tr() key for a location (ADR 0010).
static func location_key(location: int) -> String:
	return _LOCATION_KEYS.get(location, "TRAVEL_DEEP_SPACE")


## Which orders are legal in the given context. `context` keys:
##   location: int            — Travel.Location
##   location_can_dock: bool  — is the body we're holding/docked at a station
##   in_transit: bool         — a course is engaged (under way)
##   has_course: bool         — a course is laid in (engaged or not)
##   nav_target_id: String    — the Nav Plot selection ("" = none / a free point)
##   nav_target_is_here: bool — the selection is the body we're already at
##   has_nav_selection: bool  — anything selected, incl. a free point (ADR 0020;
##                              defaults to nav_target_id != "" for back-compat)
##   nav_target_is_contact: bool — the selection is a sensor contact
##   nav_target_in_range: bool   — that contact is within sensor range
##   nav_target_tier: int        — that contact's detection tier (Sensors.Tier)
##   route_nogo: bool            — a no-go zone crosses the composed route (ADR 0027)
##   landable_here: bool         — the body we're HOLDING at is landable (ADR 0029)
##   in_transition: bool         — a land/take-off/surface-move is under way (busy)
##   has_other_site: bool        — LANDED with another surface site to Move to (ADR 0030)
## Returns a bool per order id (lay_in/engage/belay/all_stop/dock/undock/scan/land/take_off/move).
static func available(context: Dictionary) -> Dictionary:
	var location: int = int(context.get("location", Location.DEEP_SPACE))
	var in_transit: bool = bool(context.get("in_transit", false))
	var has_course: bool = bool(context.get("has_course", false))
	var nav_target: String = String(context.get("nav_target_id", ""))
	var nav_here: bool = bool(context.get("nav_target_is_here", false))
	var can_dock_here: bool = bool(context.get("location_can_dock", false))
	var has_selection: bool = bool(context.get("has_nav_selection", nav_target != ""))
	var is_contact: bool = bool(context.get("nav_target_is_contact", false))
	var in_range: bool = bool(context.get("nav_target_in_range", false))
	var tier: int = int(context.get("nav_target_tier", Sensors.Tier.UNDETECTED))
	var route_nogo: bool = bool(context.get("route_nogo", false))  # a no-go on the route (ADR 0027)
	var landable_here: bool = bool(context.get("landable_here", false))
	var in_transition: bool = bool(context.get("in_transition", false))
	var has_other_site: bool = bool(context.get("has_other_site", false))
	var landed: bool = location == Location.LANDED
	var busy: bool = in_transit or in_transition  # mid-transition: no new orders
	return {
		"lay_in": has_selection and not nav_here and not busy and not landed,
		"engage": has_course and location != Location.DOCKED and not landed and not route_nogo and not busy,
		"belay": in_transit,
		"all_stop": in_transit,
		"dock": location == Location.HOLDING and can_dock_here and not busy,
		"undock": location == Location.DOCKED,
		"scan": is_contact and in_range and tier == Sensors.Tier.BLIP and not busy,
		"land": location == Location.HOLDING and landable_here and not busy,
		"take_off": landed and not in_transition,
		"move": landed and has_other_site and not in_transition,
	}
