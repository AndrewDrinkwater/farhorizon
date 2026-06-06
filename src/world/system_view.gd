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
## Mouse-wheel zoom step (multiplicative), within CameraFit's bounds.
const ZOOM_STEP: float = 1.12

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

	var course_line := CourseLine.new()
	add_child(course_line)

	_ship_view = ShipView.new()
	add_child(_ship_view)
	_ship_view.position = GameState.ship.position
	course_line.ship_view = _ship_view

	_camera = Camera2D.new()
	var zoom := CameraFit.fit_zoom(_system_extent() * CameraFit.MARGIN, get_viewport_rect().size)
	_camera.zoom = Vector2(zoom, zoom)
	_camera.ignore_rotation = true  # follow position, not heading — view stays upright
	_ship_view.add_child(_camera)
	_camera.make_current()

	EventBus.nav_target_selected.connect(_on_target_selected)


## Radius (wu) from the ship's start that encloses every body — used to frame the
## system at the right initial zoom (CONVENTIONS.md camera bounds).
func _system_extent() -> float:
	var extent: float = 0.0
	for body: BodyData in _system.bodies:
		extent = maxf(extent, GameState.ship.position.distance_to(body.position) + body.radius)
	return extent


func _unhandled_input(event: InputEvent) -> void:
	if _system == null or not (event is InputEventMouseButton) or not event.pressed:
		return
	match event.button_index:
		MOUSE_BUTTON_LEFT:
			var target := _body_at(get_global_mouse_position())
			if target != null:
				EventBus.nav_target_selected.emit(target.id)
		MOUSE_BUTTON_WHEEL_UP:
			_apply_zoom(ZOOM_STEP)
		MOUSE_BUTTON_WHEEL_DOWN:
			_apply_zoom(1.0 / ZOOM_STEP)


func _apply_zoom(factor: float) -> void:
	if _camera == null:
		return
	var z := CameraFit.clamp_zoom(_camera.zoom.x * factor)
	_camera.zoom = Vector2(z, z)


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
