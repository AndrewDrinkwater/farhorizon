class_name ContactData
extends Resource
## Authored data for a transient (non-gravimetric) contact (ADR 0017): ships,
## derelicts, anomalies, signals, probes, debris. Detected only within sensor
## range. Immutable content loaded via TypeRegistry, referenced by id; runtime
## detection state lives in GameState. Position is real world units.

enum Kind { SHIP, DERELICT, ANOMALY, SIGNAL, PROBE, DEBRIS }

@export var id: String = ""
@export var name_key: String = ""
@export var kind: Kind = Kind.SIGNAL
@export var position: Vector2 = Vector2.ZERO
@export var tint: Color = Color(0.85, 0.78, 0.5)  # secondary channel only (ADR 0012)
