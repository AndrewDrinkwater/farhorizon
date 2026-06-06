class_name ShipView
extends Node2D
## The ship marker — a triangle at the ship's world position, pointed along its
## heading. Reads GameState.ship (ADR 0002 binding); it never mutates.
##
## The authoritative position updates once per SimClock tick (FlightController) —
## both along a course and around a holding orbit — and this view interpolates
## between ticks for smooth motion (ADR 0004). Logic never reads the interpolated
## value; only the rendered transform uses it.

## Constant on-screen size (the node cancels the camera zoom, like BodyView).
const SIZE: float = 13.0
const TINT: Color = Color(0.9, 0.95, 1.0)

## Render interpolation endpoints: where we were at the last tick, and the latest
## authoritative position (re-read each frame so handler ordering can't matter).
var _from: Vector2
var _to: Vector2


func _ready() -> void:
	_to = GameState.ship.position
	_from = _to
	position = _to
	EventBus.sim_tick.connect(_on_sim_tick)


func _on_sim_tick(_tick: int) -> void:
	# A tick advanced the authoritative position; interpolate from wherever we
	# are now toward the new value over the coming tick interval.
	_from = position


func _process(_delta: float) -> void:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.zoom.x > 0.0:
		scale = Vector2.ONE / camera.zoom.x  # constant on-screen marker size

	var ship: ShipState = GameState.ship
	# Holding/docked: position is driven smoothly per-frame by the controller
	# (the orbit), so read it directly rather than tick-interpolating.
	if ship.location != Travel.Location.DEEP_SPACE:
		position = ship.position
		rotation = ship.heading
		_from = position
		_to = position
		return
	# Under way / drifting: interpolate the authoritative position between ticks.
	_to = ship.position
	position = _from.lerp(_to, clampf(SimClock.get_tick_fraction(), 0.0, 1.0))
	rotation = ship.heading


func _draw() -> void:
	var nose := Vector2(SIZE, 0.0)
	var wing := SIZE * 0.7
	var tri := PackedVector2Array([
		nose, Vector2(-SIZE * 0.6, -wing), Vector2(-SIZE * 0.6, wing),
	])
	draw_colored_polygon(tri, TINT)
