class_name BodyData
extends Resource
## Authored data for one static body in a star system (ADR 0005). Immutable
## content loaded via TypeRegistry; never mutated at runtime, never embedded in
## save state (referenced by id). Positions are in world units (wu,
## CONVENTIONS.md). Display name is a tr() key (ADR 0010); kind gives a
## non-colour channel for accessibility (ADR 0012).

enum Kind { STAR, PLANET, STATION, MOON }

@export var id: String = ""
@export var name_key: String = ""
@export var kind: Kind = Kind.PLANET
@export var position: Vector2 = Vector2.ZERO  # world units (absolute, static)
## The body this orbits (ADR 0018): "" for the star; a planet id for a moon. The
## orrery projects moons relative to their parent. Position stays absolute.
@export var parent_id: String = ""
@export var radius: float = 40.0  # visual radius in wu
@export var tint: Color = Color.WHITE  # secondary channel only (ADR 0012)
@export var can_dock: bool = false
@export var can_refuel: bool = false
