extends Node
## GameState — the single owned runtime state tree (ADR 0002).
##
## This is the ONLY autoload that holds saved run state. Everything that is
## "true about the current run" lives here; SaveManager serializes this whole
## tree (ADR 0008). Authored content is referenced by id, never embedded.
##
## SCAFFOLD STUB — fields and serialization are filled in build-order step 3.
## See docs/ALPHA-0.1-SPEC.md.

## Bumped to match the save schema this build writes.
var schema_version: int = GameVersion.SAVE_SCHEMA_VERSION

# TODO(step 3): real state objects — clock, ship (incl. current_order), system.
# var clock: ClockState
# var ship: ShipState
# var system: SystemState


func to_dict() -> Dictionary:
	# TODO(step 3): walk the tree into a plain Dictionary.
	return {
		"schema_version": schema_version,
	}


func from_dict(_data: Dictionary) -> void:
	# TODO(step 3): rebuild the tree; forgiving about missing keys.
	pass
