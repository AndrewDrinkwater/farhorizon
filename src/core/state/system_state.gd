class_name SystemState
extends RefCounted
## Which star system is currently loaded, referenced by id (ADR 0002). Bodies
## are authored .tres resolved through TypeRegistry; state holds only the id.
## Empty id = no system loaded yet (the hardcoded system lands in step 4).

var system_id: String = ""


func to_dict() -> Dictionary:
	return {
		"system_id": system_id,
	}


## Forgiving rebuild: missing keys fall back to defaults (ADR 0008).
static func from_dict(data: Dictionary) -> SystemState:
	var s := SystemState.new()
	s.system_id = String(data.get("system_id", s.system_id))
	return s
