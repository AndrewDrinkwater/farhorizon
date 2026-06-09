class_name DebugActions
extends RefCounted
## Dev-only command runner for the debug console (ADR 0024). Parses a command line,
## mutates GameState / emits the EXISTING change signals, and returns output text to
## display. This is the sanctioned exception to "UI emits intents, never mutates"
## (ADR 0007) — a debug tool, not gameplay UI; keeping the actions here (not as
## signals on EventBus) avoids polluting the bus with dev-only intents.
##
## Debug text is exempt from localisation (ADR 0010) — plain literals on purpose.
##
## TODO(release): gate this + the DebugConsole out of release builds (a
## ConfigManager / build flag) so players can't teleport/refuel.

const COMMANDS := "help · systems · system <id> · refuel · tp <body_id> | <x> <y>"


## Run one command line; returns text to show in the console.
static func run(line: String) -> String:
	var parts := line.strip_edges().split(" ", false)
	if parts.is_empty():
		return ""
	var cmd := String(parts[0])
	var args: Array = parts.slice(1)
	match cmd:
		"help":
			return "commands: " + COMMANDS
		"systems":
			return "systems: " + ", ".join(TypeRegistry.system_ids())
		"system":
			return _system(args)
		"refuel":
			return _refuel()
		"tp":
			return _tp(args)
		_:
			return "unknown command '%s' — try 'help'" % cmd


static func _system(args: Array) -> String:
	if args.is_empty():
		return "usage: system <id>  (try 'systems')"
	var id := String(args[0])
	if not TypeRegistry.has_system(id):
		return "no such system '%s'" % id
	EventBus.system_change_requested.emit(id)
	return "loading system '%s'..." % id


static func _refuel() -> String:
	GameState.ship.reaction_mass = GameState.ship.max_reaction_mass
	EventBus.fuel_changed.emit(Fuel.Pool.REACTION_MASS, GameState.ship.reaction_mass)
	return "refuelled to %.0f RM" % GameState.ship.reaction_mass


static func _tp(args: Array) -> String:
	var pos: Vector2
	if args.size() == 1:
		var body := _body(String(args[0]))
		if body == null:
			return "no such body '%s' in this system" % String(args[0])
		pos = body.position
	elif args.size() >= 2:
		pos = Vector2(float(args[0]), float(args[1]))
	else:
		return "usage: tp <body_id>  |  tp <x> <y>"
	GameState.ship.position = pos
	GameState.ship.location = Travel.Location.DEEP_SPACE
	GameState.ship.location_body_id = ""
	GameState.ship.current_order = {}
	EventBus.ship_context_changed.emit()
	return "teleported to (%.0f, %.0f)" % [pos.x, pos.y]


static func _body(id: String) -> BodyData:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == id:
			return body
	return null
