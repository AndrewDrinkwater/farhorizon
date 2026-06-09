class_name SensorController
extends Node
## Runs sensor detection off SimClock ticks (ADR 0017). Each tick it tests the
## segment the ship travelled against the system's transient contacts (pure
## Sensors, real space), diffs against the saved detection state, and announces
## changes on EventBus. Holds no system refs (ADR 0003) — reads GameState +
## TypeRegistry, writes GameState.contacts. NOT an autoload (a plain system node).

var _prev_pos: Vector2 = Vector2.ZERO


func _ready() -> void:
	_prev_pos = GameState.ship.position
	EventBus.sim_tick.connect(_on_sim_tick)
	EventBus.game_state_loaded.connect(_on_state_loaded)
	EventBus.system_changed.connect(_on_state_loaded.unbind(1))  # re-detect from the new start


func _on_state_loaded() -> void:
	_prev_pos = GameState.ship.position


func _on_sim_tick(_tick: int) -> void:
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return
	var radius: float = GameState.ship.sensor_range
	var in_range := Sensors.contacts_in_segment(_prev_pos, GameState.ship.position, radius, system.contacts)
	_prev_pos = GameState.ship.position

	var in_ids: Dictionary = {}
	for contact: ContactData in in_range:
		in_ids[contact.id] = true
		if GameState.contacts.tier_of(contact.id) == Sensors.Tier.UNDETECTED:
			GameState.contacts.set_tier(contact.id, Sensors.Tier.BLIP)
			EventBus.contact_detected.emit(contact.id)

	# A BLIP that's no longer in range drops back to undetected (IDENTIFIED stays).
	for contact: ContactData in system.contacts:
		if not in_ids.has(contact.id) and GameState.contacts.tier_of(contact.id) == Sensors.Tier.BLIP:
			GameState.contacts.set_tier(contact.id, Sensors.Tier.UNDETECTED)
			EventBus.contact_lost.emit(contact.id)
