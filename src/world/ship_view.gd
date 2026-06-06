class_name ShipView
extends Node2D
## The ship marker — a triangle at the ship's world position, pointed along its
## heading. Reads GameState.ship (ADR 0002 binding); it never mutates.
##
## Under way: the authoritative position updates once per SimClock tick
## (FlightController) and this view interpolates between ticks for smooth motion
## (ADR 0004). HOLDING at a body: the ship cosmetically circles it — "holding"
## means orbiting (the authoritative position stays at the body for logic; the
## orbit is view-only and advances on sim time, so it freezes when paused).

const SIZE: float = 28.0
const TINT: Color = Color(0.9, 0.95, 1.0)

## Orbit radius beyond the body's own radius (wu), and seconds per orbit at 1x.
const ORBIT_GAP: float = 26.0
const ORBIT_PERIOD: float = 30.0

## Render interpolation endpoints: where we were at the last tick, and the latest
## authoritative position (re-read each frame so handler ordering can't matter).
var _from: Vector2
var _to: Vector2
var _orbit_angle: float = 0.0


func _ready() -> void:
	_to = GameState.ship.position
	_from = _to
	position = _to
	EventBus.sim_tick.connect(_on_sim_tick)


func _on_sim_tick(_tick: int) -> void:
	# A tick advanced the authoritative position; interpolate from wherever we
	# are now toward the new value over the coming tick interval.
	_from = position


func _process(delta: float) -> void:
	var ship: ShipState = GameState.ship
	# Holding at a body = orbiting it (cosmetic). Docked = parked at the same
	# offset but not moving. Both advance/freeze with the sim clock.
	if ship.location != Travel.Location.DEEP_SPACE:
		var body := _resolve_body(ship.location_body_id)
		if body != null:
			if ship.location == Travel.Location.HOLDING:
				_orbit_angle += delta * SimClock.get_speed() * (TAU / ORBIT_PERIOD)
			var radius := body.radius + ORBIT_GAP
			position = body.position + Vector2.from_angle(_orbit_angle) * radius
			rotation = _orbit_angle + PI * 0.5  # face the direction of travel
			_from = position
			_to = position
			return
	# Under way / drifting: interpolate the authoritative position between ticks.
	_to = ship.position
	position = _from.lerp(_to, clampf(SimClock.get_tick_fraction(), 0.0, 1.0))
	rotation = ship.heading


func _resolve_body(body_id: String) -> BodyData:
	if body_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == body_id:
			return body
	return null


func _draw() -> void:
	var nose := Vector2(SIZE, 0.0)
	var wing := SIZE * 0.7
	var tri := PackedVector2Array([
		nose, Vector2(-SIZE * 0.6, -wing), Vector2(-SIZE * 0.6, wing),
	])
	draw_colored_polygon(tri, TINT)
