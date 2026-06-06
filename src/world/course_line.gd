class_name CourseLine
extends Node2D
## Nav Plot course overlay (helm.md): a dashed line from the ship to its current
## course target, with a destination marker, drawn while a course is laid in or
## executing. Presentation only — reads GameState/authored data, never mutates.

const DASH: float = 12.0
const WIDTH: float = 2.0

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
	var from: Vector2 = ship_view.position if ship_view != null else GameState.ship.position
	var to: Vector2 = body.position
	draw_dashed_line(from, to, Palette.ACCENT, WIDTH, DASH)
	# Destination marker: a ring just outside the body.
	draw_arc(to, body.radius + 6.0, 0.0, TAU, 32, Palette.ACCENT, 1.5, true)


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
