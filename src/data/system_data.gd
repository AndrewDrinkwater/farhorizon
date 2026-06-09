class_name SystemData
extends Resource
## Authored data for one star system (ADR 0005). A bag of static BodyData plus
## the ship's start position. Immutable content loaded via TypeRegistry and
## referenced from state by `id` only (ADR 0002). Positions are in world units.

@export var id: String = ""
@export var name_key: String = ""
@export var bodies: Array[BodyData] = []  # charted (gravimetric) bodies
@export var contacts: Array[ContactData] = []  # transient entities (ADR 0017)
@export var zones: Array[ZoneData] = []  # authored spatial regions (ADR 0026)
@export var ship_start: Vector2 = Vector2.ZERO  # world units


## The first dockable body, or null. Convenience for refuel/dock flows (step 7).
func first_station() -> BodyData:
	for body: BodyData in bodies:
		if body.can_dock:
			return body
	return null
