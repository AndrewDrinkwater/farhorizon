class_name SystemView
extends Node2D
## Builds the Helm Nav Plot: orbit rings, a static BodyView per body, the ship
## marker, and a camera. Clicking a body selects it as the course target (ADR
## 0013/0014) → emits EventBus.nav_target_selected. The camera follows the ship
## but can be panned freely (right-drag) and re-centred; wheel to zoom. Bodies
## sit at true AU distances, so the camera/markers carry the readability (see
## BodyView / OrbitRings). Presentation only — never mutates state.

const PIXELS_PER_WU: float = 1.0
## Mouse-wheel zoom step (multiplicative), within CameraFit's bounds.
const ZOOM_STEP: float = 1.12
## Default view framed at start (wu radius around the ship): the inner system, so
## the Sol↔1 AU layer reads well. Wheel/pan out for the far (40 AU) bodies. ~3 AU.
const DEFAULT_VIEW_RADIUS_WU: float = 3000.0
## Click tolerance in screen pixels (markers are a constant on-screen size).
const PICK_PX: float = 20.0

var _ship_view: ShipView
var _camera: Camera2D
var _system: SystemData
var _body_views: Dictionary = {}  # id: String -> BodyView
var _follow: bool = true  # camera tracks the ship until the player pans away


func build(system: SystemData) -> void:
	_system = system
	scale = Vector2(PIXELS_PER_WU, PIXELS_PER_WU)

	var rings := OrbitRings.new()
	add_child(rings)
	rings.setup(system)

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
	_camera.position = GameState.ship.position
	var zoom := CameraFit.fit_zoom(DEFAULT_VIEW_RADIUS_WU, get_viewport_rect().size)
	_camera.zoom = Vector2(zoom, zoom)
	add_child(_camera)
	_camera.make_current()

	EventBus.nav_target_selected.connect(_on_target_selected)
	# Re-follow when a course is engaged, so travel stays in view.
	EventBus.flight_state_changed.connect(_on_flight_state_changed)


func _process(_delta: float) -> void:
	if _follow and _camera != null and _ship_view != null:
		_camera.position = _ship_view.position


func _unhandled_input(event: InputEvent) -> void:
	if _system == null:
		return
	if event.is_action_pressed("recenter_view"):
		_follow = true
		return
	if event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				var target := _body_at(get_global_mouse_position())
				if target != null:
					EventBus.nav_target_selected.emit(target.id)
			MOUSE_BUTTON_WHEEL_UP:
				_apply_zoom(ZOOM_STEP)
			MOUSE_BUTTON_WHEEL_DOWN:
				_apply_zoom(1.0 / ZOOM_STEP)
	elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_RIGHT) != 0:
		# Right-drag pans the view (free look); stop following the ship.
		_follow = false
		_camera.position -= event.relative / _camera.zoom.x


func _apply_zoom(factor: float) -> void:
	if _camera == null:
		return
	var z := CameraFit.clamp_zoom(_camera.zoom.x * factor)
	_camera.zoom = Vector2(z, z)


func _on_flight_state_changed(state: int) -> void:
	if state == FlightCore.State.ENGAGING:
		_follow = true


## Keep the map's highlight in sync with the selected target (single source).
func _on_target_selected(target_id: String) -> void:
	for id: String in _body_views:
		_body_views[id].set_selected(id == target_id)


func _body_at(world_pos: Vector2) -> BodyData:
	# Pick in screen space: markers are a constant on-screen size, so a world-space
	# tolerance would miss distant bodies when zoomed out.
	var zoom: float = _camera.zoom.x if _camera != null else 1.0
	var nearest: BodyData = null
	var nearest_px := PICK_PX
	for body: BodyData in _system.bodies:
		var screen_dist := world_pos.distance_to(body.position) * zoom
		if screen_dist <= nearest_px:
			nearest_px = screen_dist
			nearest = body
	return nearest
