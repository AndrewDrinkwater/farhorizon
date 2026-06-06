class_name CourseLine
extends Node2D
## Nav Plot course overlay (helm.md): a dashed line from the ship to its current
## course target, with a destination marker, drawn while a course is laid in or
## executing. Drawn in world space (it spans the real distance) but with widths
## kept constant on-screen by dividing by the camera zoom. Presentation only.

const WIDTH_PX: float = 2.0
const DASH_PX: float = 10.0
const MARKER_PX: float = 13.0

## Set by SystemView so the line tracks the (interpolated) ship marker.
var ship_view: Node2D


func _process(_delta: float) -> void:
	queue_redraw()


func _draw() -> void:
	var order: Dictionary = GameState.ship.current_order
	if String(order.get("type", "")) != "course":
		return
	var body := _resolve_body(String(order.get("target_id", "")))
	if body == null:
		return
	var inv_zoom := _inverse_zoom()
	var from: Vector2 = ship_view.position if ship_view != null else GameState.ship.position
	var to: Vector2 = body.position
	draw_dashed_line(from, to, Palette.ACCENT, WIDTH_PX * inv_zoom, DASH_PX * inv_zoom)
	draw_arc(to, MARKER_PX * inv_zoom, 0.0, TAU, 32, Palette.ACCENT, 1.5 * inv_zoom, true)


func _inverse_zoom() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.zoom.x > 0.0:
		return 1.0 / camera.zoom.x
	return 1.0


func _resolve_body(target_id: String) -> BodyData:
	if target_id == "":
		return null
	var system := TypeRegistry.get_system(GameState.system.system_id)
	if system == null:
		return null
	for body: BodyData in system.bodies:
		if body.id == target_id:
			return body
	return null
