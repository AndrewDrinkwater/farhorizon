class_name HelmGroups
extends RefCounted
## Which Helm control clusters apply to the ship's situation (ADR 0032). Pure +
## GUT-tested: the Helm hides a whole cluster when its flag is false, and greys
## individual buttons via Travel.available within a visible cluster — so the rule
## for "what's even relevant here" lives in one place.
##
## Clusters: Flight (lay in / engage / belay / all stop / clear), Docking (dock /
## undock), Surface (land / take off / move), Sensors (scan / focus).

## context keys: location:int, location_can_dock:bool, landable_here:bool.
static func visible_groups(context: Dictionary) -> Dictionary:
	var location: int = int(context.get("location", Travel.Location.DEEP_SPACE))
	var can_dock: bool = bool(context.get("location_can_dock", false))
	var landable: bool = bool(context.get("landable_here", false))
	var landed := location == Travel.Location.LANDED
	var holding := location == Travel.Location.HOLDING
	return {
		# Flight + Sensors are space operations — present unless on the surface.
		"flight": not landed,
		"sensors": not landed,
		# Docking only at a station (orbiting a dockable body, or docked).
		"docking": (holding and can_dock) or location == Travel.Location.DOCKED,
		# Surface only in orbit at a landable body, or while landed.
		"surface": (holding and landable) or landed,
	}
