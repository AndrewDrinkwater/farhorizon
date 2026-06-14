extends Node
## GameState — the single owned runtime state tree (ADR 0002).
##
## The ONLY autoload that holds saved run state. Everything "true about the
## current run" lives here as typed plain objects (src/core/state); SaveManager
## serializes this whole tree (ADR 0008). Authored content is referenced by id,
## never embedded. Systems read these fields and mutate them through defined
## paths; the UI binds here for reads and emits intents to change them.

var clock: ClockState = ClockState.new()
var ship: ShipState = ShipState.new()
var system: SystemState = SystemState.new()
var contacts: ContactsState = ContactsState.new()  # transient detection state (ADR 0017)
var zones: ZonesState = ZonesState.new()  # fired one-shot zone triggers (ADR 0026)


## Reset the tree to a fresh run (used by "new game" and as the load baseline).
func new_game() -> void:
	clock = ClockState.new()
	ship = ShipState.new()
	system = SystemState.new()
	contacts = ContactsState.new()
	zones = ZonesState.new()


## Switch to a loaded star system (ADR 0024): store the new id, reset the ship to
## the system's start (clear course, drift in deep space), and reset transient
## contact discovery. The defined mutation path the SystemLoader/warp drives;
## authored content stays referenced by id. Fuel is left as-is (warp doesn't refill).
func load_system(system_data: SystemData) -> void:
	if system_data == null:
		return
	system.system_id = system_data.id
	ship.position = system_data.ship_start
	ship.heading = 0.0
	ship.orbit_angle = 0.0
	ship.current_order = {}
	ship.location = Travel.Location.DEEP_SPACE
	ship.location_body_id = ""
	ship.scan_contact_id = ""  # any in-progress scan ends with the old system's contacts
	ship.scan_ticks_left = 0
	ship.scan_ticks_total = 0
	contacts = ContactsState.new()  # nothing discovered in the new system yet
	zones = ZonesState.new()        # triggers re-arm in the new system


## Serialize the whole tree to a plain Dictionary (SaveManager wraps it with the
## version stamps — versioning is SaveManager's concern, not the state's).
func to_dict() -> Dictionary:
	return {
		"clock": clock.to_dict(),
		"ship": ship.to_dict(),
		"system": system.to_dict(),
		"contacts": contacts.to_dict(),
		"zones": zones.to_dict(),
	}


## Rebuild the tree from a Dictionary. Forgiving: missing branches/keys fall back
## to defaults so older saves survive schema growth (ADR 0008).
func from_dict(data: Dictionary) -> void:
	clock = ClockState.from_dict(data.get("clock", {}))
	ship = ShipState.from_dict(data.get("ship", {}))
	system = SystemState.from_dict(data.get("system", {}))
	contacts = ContactsState.from_dict(data.get("contacts", {}))
	zones = ZonesState.from_dict(data.get("zones", {}))
