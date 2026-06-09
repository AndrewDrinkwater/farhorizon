class_name SurfaceLocationData
extends Resource
## A named point on a body's surface (ADR 0030): a landing site, base, or POI.
## Immutable authored content held on BodyData.surface_locations, referenced by id;
## never mutated at runtime. `surface_position` is in surface units (su) on the
## body's local map — distinct from world units. `kind` is a non-colour display
## channel (ADR 0012); BASE/POI gain behaviour later (missions, forward bases).

enum Kind { WILD, SITE, BASE, POI }

@export var id: String = ""
@export var name_key: String = ""
@export var kind: Kind = Kind.SITE
@export var surface_position: Vector2 = Vector2.ZERO  # surface units (su)
