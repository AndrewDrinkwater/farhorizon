class_name SystemView
extends Node2D
## Builds the spatial view of a star system from authored SystemData: a static
## BodyView per body, the ship marker, and a camera that follows the ship
## (ADR 0005). This is the Helm Nav Plot's map: clicking a body selects it as the
## course target (compose-time intent, ADR 0013/0014) — it emits
## EventBus.nav_target_selected and the Helm console takes it from there. The map
## owns its own selection highlight. Presentation only — never mutates state.

## Render scale: world units -> pixels. The single place wu maps to screen
## (CONVENTIONS.md "do not hardcode distances"). 1:1 for now, tune by feel.
const PIXELS_PER_WU: float = 1.0
## Camera zoom (tuning); < 1 zooms out to fit the system.
const CAMERA_ZOOM: float = 0.45

var _ship_view: ShipView
var _camera: Camera2D
var _system: SystemData
var _body_views: Dictionary = {}  # id: String -> BodyView


func build(system: SystemData) -> void:
	_system = system
	scale = Vector2(PIXELS_PER_WU, PIXELS_PER_WU)

	for body: BodyData in system.bodies:
		var view := BodyView.new()
		add_child(view)
		view.setup(body)
		_body_views[body.id] = view

	_ship_view = ShipView.new()
	add_child(_ship_view)
	_ship_view.position = GameState.ship.position

	_camera = Camera2D.new()
	_camera.zoom = Vector2(CAMERA_ZOOM, CAMERA_ZOOM)
	_camera.ignore_rotation = true  # follow position, not heading — view stays upright
	_ship_view.add_child(_camera)
	_camera.make_current()

	EventBus.nav_target_selected.connect(_on_target_selected)


func _unhandled_input(event: InputEvent) -> void:
	if _system == null:
		return
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var target := _body_at(get_global_mouse_position())
		if target != null:
			EventBus.nav_target_selected.emit(target.id)


## Keep the map's highlight in sync with the selected target (single source).
func _on_target_selected(target_id: String) -> void:
	for id: String in _body_views:
		_body_views[id].set_selected(id == target_id)


func _body_at(world_pos: Vector2) -> BodyData:
	for body: BodyData in _system.bodies:
		# Generous pick radius so small bodies are easy to click.
		if world_pos.distance_to(body.position) <= maxf(body.radius, 30.0) + 40.0:
			return body
	return null
