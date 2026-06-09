class_name ZoneController
extends Node
## Runs zone membership off SimClock ticks (ADR 0026), mirroring SensorController.
## Each tick it resolves anchored geometry from the loaded system, computes the
## ship's current zone set via pure Zones, diffs against last tick, and announces
## zone_entered / zone_exited. On entry, a zone with a `trigger_event` fires
## zone_trigger_fired (once if `once`, recorded in GameState so it doesn't re-fire)
## — the hook for the future event/mission system; all other effects are
## authored-but-inert until their consuming system reads them.
##
## Holds no system refs (ADR 0003) — reads GameState + TypeRegistry, writes
## GameState.zones. NOT an autoload (a plain system node, placed in the scene).

var _inside: Dictionary = {}  # zone_id -> true (last tick's membership)


func _ready() -> void:
	EventBus.sim_tick.connect(_on_sim_tick.unbind(1))
	EventBus.game_state_loaded.connect(_reset)
	EventBus.system_changed.connect(_reset.unbind(1))  # membership recomputes next tick


func _reset() -> void:
	_inside.clear()


func _on_sim_tick() -> void:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return
	var pos: Vector2 = GameState.ship.position
	var now: Dictionary = {}
	for zone: ZoneData in system.zones:
		var center := Zones.world_center(zone, system)
		var points := Zones.world_points(zone, system)
		if Zones.contains(zone.shape, center, zone.radius, zone.inner_radius, points, pos):
			now[zone.id] = true
			if not _inside.has(zone.id):
				_on_enter(zone)
	for zone_id: String in _inside:
		if not now.has(zone_id):
			EventBus.zone_exited.emit(zone_id)
	_inside = now


func _on_enter(zone: ZoneData) -> void:
	EventBus.zone_entered.emit(zone.id)
	var event_id := String(zone.effects.get("trigger_event", ""))
	if event_id == "":
		return
	if bool(zone.effects.get("once", false)):
		if GameState.zones.has_fired(zone.id):
			return
		GameState.zones.mark_fired(zone.id)
	EventBus.zone_trigger_fired.emit(zone.id, event_id)
