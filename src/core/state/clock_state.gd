class_name ClockState
extends RefCounted
## Persisted clock values (ADR 0002, 0004). The live driver is the SimClock node,
## but the *truth* lives here in GameState so the save is just a serialized tree.
## One tick = one in-game hour (CONVENTIONS.md); the calendar is derived, never
## stored (see SimCalendar). Plain data + to_dict/from_dict, no node deps.

var tick: int = 0
var speed: float = 1.0


func to_dict() -> Dictionary:
	return {
		"tick": tick,
		"speed": speed,
	}


## Forgiving rebuild: missing keys fall back to defaults (ADR 0008).
static func from_dict(data: Dictionary) -> ClockState:
	var s := ClockState.new()
	s.tick = int(data.get("tick", s.tick))
	s.speed = float(data.get("speed", s.speed))
	return s
