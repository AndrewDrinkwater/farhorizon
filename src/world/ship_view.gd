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
## Sim-seconds (at 1x) to ease from the arrival point out onto the orbit ring.
const ENTRY_TIME: float = 0.9

## Render interpolation endpoints: where we were at the last tick, and the latest
## authoritative position (re-read each frame so handler ordering can't matter).
var _from: Vector2
var _to: Vector2
# Orbit state. _orbit_blend eases 0->1 from the arrival radius to the ring, so
# the ship spirals into orbit instead of popping onto the ring.
var _orbiting: bool = false
var _orbit_angle: float = 0.0
var _orbit_blend: float = 0.0
var _orbit_entry_radius: float = 0.0


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
			if not _orbiting:
				_begin_orbit(ship, body)
			_update_orbit(ship, body, delta)
			_from = position
			_to = position
			return
	_orbiting = false
	# Under way / drifting: interpolate the authoritative position between ticks.
	_to = ship.position
	position = _from.lerp(_to, clampf(SimClock.get_tick_fraction(), 0.0, 1.0))
	rotation = ship.heading


## Start an orbit from wherever the ship currently is, so there's no jump: the
## entry radius/angle are taken from the current rendered position. A fresh dock
## (e.g. on load) starts already settled on the ring.
func _begin_orbit(ship: ShipState, body: BodyData) -> void:
	_orbiting = true
	var to_ship := position - body.position
	_orbit_entry_radius = to_ship.length()
	_orbit_angle = to_ship.angle() if _orbit_entry_radius > 1.0 else ship.heading + PI
	_orbit_blend = 1.0 if ship.location == Travel.Location.DOCKED else 0.0


func _update_orbit(ship: ShipState, body: BodyData, delta: float) -> void:
	var step := delta * SimClock.get_speed()
	if ship.location == Travel.Location.HOLDING:
		_orbit_blend = minf(1.0, _orbit_blend + step / ENTRY_TIME)
		_orbit_angle += step * (TAU / ORBIT_PERIOD)
	var radius := lerpf(_orbit_entry_radius, body.radius + ORBIT_GAP, smoothstep(0.0, 1.0, _orbit_blend))
	position = body.position + Vector2.from_angle(_orbit_angle) * radius
	rotation = _orbit_angle + PI * 0.5  # face the direction of travel


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
