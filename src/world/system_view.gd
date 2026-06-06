class_name SystemView
extends Node2D
## Builds the spatial view of a star system from authored SystemData: a static
## BodyView per body, the ship marker, and a camera that follows the ship
## (ADR 0005). Presentation only — it reads GameState/authored data and never
## mutates state. The Helm Nav Plot (step 8) grows from this.

## Render scale: world units -> pixels. The single place wu maps to screen
## (CONVENTIONS.md "do not hardcode distances"). 1:1 for now, tune by feel.
const PIXELS_PER_WU: float = 1.0
## Camera zoom (tuning); < 1 zooms out to fit the system.
const CAMERA_ZOOM: float = 0.45

var _ship_view: ShipView
var _camera: Camera2D
var _system: SystemData


func build(system: SystemData) -> void:
	_system = system
	scale = Vector2(PIXELS_PER_WU, PIXELS_PER_WU)

	for body: BodyData in system.bodies:
		var view := BodyView.new()
		add_child(view)
		view.setup(body)

	_ship_view = ShipView.new()
	add_child(_ship_view)
	_ship_view.position = GameState.ship.position

	_camera = Camera2D.new()
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.ignore_rotation = true  # follow position, not heading — view stays upright
	_ship_view.add_child(_camera)
	_camera.make_current()


## TEMPORARY (step 6): click a body to plot + engage a Standard course, so the
## ship visibly flies before the Helm Nav Plot exists. Replaced by the proper
## compose → preview → confirm flow in step 8 (docs/consoles/helm.md).
func _unhandled_input(event: InputEvent) -> void:
	if _system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var world := get_global_mouse_position()
		var target := _body_at(world)
		if target != null:
			EventBus.order_issued.emit({
				"type": "set_course", "target_id": target.id, "burn": FlightMath.Burn.STANDARD,
			})
			EventBus.order_issued.emit({"type": "engage"})


func _body_at(world_pos: Vector2) -> BodyData:
	for body: BodyData in _system.bodies:
		# Generous pick radius so small bodies are easy to click.
		if world_pos.distance_to(body.position) <= maxf(body.radius, 30.0) + 40.0:
			return body
	return null
