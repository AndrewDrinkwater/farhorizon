class_name SystemLoader
extends Node
## Runtime system loading (ADR 0024). On EventBus.system_change_requested it
## validates the id via TypeRegistry, resets the run to that system
## (GameState.load_system), and announces system_changed — the canonical
## "loaded system changed, re-init" signal every nav system listens to.
##
## This is the seed of warp / multi-system (β0.6): the jump action will reuse this
## exact path, gated by fuel. The debug console drives it ungated. Holds no refs to
## other systems (ADR 0003) — pure bus + services. NOT an autoload (a plain node).

func _ready() -> void:
	EventBus.system_change_requested.connect(_on_change_requested)


func _on_change_requested(system_id: String) -> void:
	var system := TypeRegistry.get_system(system_id)
	if system == null:
		push_warning("SystemLoader: unknown system '%s' — ignored" % system_id)
		return
	GameState.load_system(system)
	EventBus.system_changed.emit(system_id)
