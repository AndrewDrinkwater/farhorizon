class_name ZonesState
extends RefCounted
## Runtime zone state (ADR 0026): the set of one-shot zone triggers that have
## already fired, so they don't re-fire. Part of the GameState tree; saved so a
## resumed run remembers (ADR 0008). Current membership is recomputed on load (not
## stored). Reset on system change (ADR 0024).

var fired_triggers: Dictionary = {}  # zone_id: String -> true


func has_fired(zone_id: String) -> bool:
	return fired_triggers.has(zone_id)


func mark_fired(zone_id: String) -> void:
	fired_triggers[zone_id] = true


func to_dict() -> Dictionary:
	return {"fired_triggers": fired_triggers.duplicate(true)}


static func from_dict(data: Dictionary) -> ZonesState:
	var s := ZonesState.new()
	var raw: Dictionary = data.get("fired_triggers", {})
	for key: Variant in raw:
		s.fired_triggers[String(key)] = true
	return s
