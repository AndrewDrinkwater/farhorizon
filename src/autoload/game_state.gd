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


## Reset the tree to a fresh run (used by "new game" and as the load baseline).
func new_game() -> void:
	clock = ClockState.new()
	ship = ShipState.new()
	system = SystemState.new()
	contacts = ContactsState.new()


## Serialize the whole tree to a plain Dictionary (SaveManager wraps it with the
## version stamps — versioning is SaveManager's concern, not the state's).
func to_dict() -> Dictionary:
	return {
		"clock": clock.to_dict(),
		"ship": ship.to_dict(),
		"system": system.to_dict(),
		"contacts": contacts.to_dict(),
	}


## Rebuild the tree from a Dictionary. Forgiving: missing branches/keys fall back
## to defaults so older saves survive schema growth (ADR 0008).
func from_dict(data: Dictionary) -> void:
	clock = ClockState.from_dict(data.get("clock", {}))
	ship = ShipState.from_dict(data.get("ship", {}))
	system = SystemState.from_dict(data.get("system", {}))
	contacts = ContactsState.from_dict(data.get("contacts", {}))
