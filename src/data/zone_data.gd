class_name ZoneData
extends Resource
## Authored spatial region (ADR 0026): geometry + a generic bag of effect tags.
## Immutable content loaded via TypeRegistry, referenced by id; never mutated at
## runtime, never embedded in save state. Positions are world units (wu). One
## primitive serves hazards, fields, no-go space, facilities and triggers — the
## `category` is a non-colour display channel (ADR 0012); `effects` is read by
## whichever consuming system understands a given key (new effects = new keys, not
## new types). Membership is decided in real space (Zones + ZoneController).

enum Shape { CIRCLE, BAND, POLYGON }
enum Category { HAZARD, FIELD, NOGO, FACILITY, TRIGGER }

@export var id: String = ""
@export var name_key: String = ""
@export var category: Category = Category.FIELD
@export var shape: Shape = Shape.CIRCLE

## Anchoring (ADR 0018): "" = free (absolute geometry); else positioned relative to
## the named body (a planet's radiation band, a station's coverage net).
@export var anchor_body_id: String = ""
@export var center: Vector2 = Vector2.ZERO     # CIRCLE / BAND centre (offset if anchored)
@export var radius: float = 0.0                # CIRCLE radius / BAND outer radius (wu)
@export var inner_radius: float = 0.0          # BAND inner radius (wu)
@export var points: PackedVector2Array = []    # POLYGON vertices (offset if anchored)

## Generic effect bag — consuming systems read the keys they recognise (ADR 0026):
## blocks_course ("nogo"|"hazard"), sensor_mult, rm_drain, refuel, trigger_event, once.
@export var effects: Dictionary = {}
@export var tint: Color = Color(0.6, 0.6, 0.7)  # secondary channel only (ADR 0012)
