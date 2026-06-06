extends Node
## TypeRegistry — loads and hands out authored .tres Resources (ADR 0002).
##
## Read-only cache of immutable authored data. Runtime state references content
## by id; this resolves id -> Resource. Never mutate a returned Resource. More
## content types (hulls in step 5) get their own dir + typed getter here.

const SYSTEMS_DIR: String = "res://resources/systems"

var _systems: Dictionary = {}  # id: String -> SystemData


func _ready() -> void:
	_scan_systems()


func _scan_systems() -> void:
	var dir := DirAccess.open(SYSTEMS_DIR)
	if dir == null:
		push_warning("TypeRegistry: no systems dir at %s" % SYSTEMS_DIR)
		return
	dir.list_dir_begin()
	var fname: String = dir.get_next()
	while fname != "":
		if not dir.current_is_dir() and fname.ends_with(".tres"):
			var res: Resource = load("%s/%s" % [SYSTEMS_DIR, fname])
			if res is SystemData:
				var system: SystemData = res
				if system.id == "":
					push_warning("TypeRegistry: %s has no id; skipped" % fname)
				else:
					_systems[system.id] = system
		fname = dir.get_next()
	dir.list_dir_end()


func get_system(id: String) -> SystemData:
	return _systems.get(id, null)


func has_system(id: String) -> bool:
	return _systems.has(id)


func system_ids() -> Array:
	return _systems.keys()
