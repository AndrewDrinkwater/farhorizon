class_name ContactsState
extends RefCounted
## Runtime detection state for transient contacts (ADR 0017): id → detection tier
## (Sensors.Tier). Absent = UNDETECTED. Part of the GameState tree; saved so a
## resumed run remembers what's been found (ADR 0008).

var tiers: Dictionary = {}  # id: String -> tier: int


func tier_of(id: String) -> int:
	return int(tiers.get(id, Sensors.Tier.UNDETECTED))


func set_tier(id: String, tier: int) -> void:
	tiers[id] = tier


func to_dict() -> Dictionary:
	return {"tiers": tiers.duplicate(true)}


static func from_dict(data: Dictionary) -> ContactsState:
	var s := ContactsState.new()
	var raw: Dictionary = data.get("tiers", {})
	for key: Variant in raw:
		s.tiers[String(key)] = int(raw[key])
	return s
