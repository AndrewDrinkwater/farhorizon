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


func build(system: SystemData) -> void:
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
