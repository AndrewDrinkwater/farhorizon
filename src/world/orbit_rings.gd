class_name OrbitRings
extends Node2D
## Faint concentric guide rings from the star at each body's orbital radius — the
## chart structure that makes true-scale distances legible. Drawn in world space
## (the rings are the real orbits) with a constant on-screen line width. Pure
## presentation; reads authored data, never mutates state.

const COLOR: Color = Color(0.35, 0.45, 0.58, 0.30)
const WIDTH_PX: float = 1.0
const SEGMENTS: int = 192

var _system: SystemData
var _star_pos: Vector2 = Vector2.ZERO


func setup(system: SystemData) -> void:
	_system = system
	for body: BodyData in system.bodies:
		if body.kind == BodyData.Kind.STAR:
			_star_pos = body.position
			break
	queue_redraw()


func _process(_delta: float) -> void:
	queue_redraw()  # line width tracks the camera zoom


func _draw() -> void:
	if _system == null:
		return
	var width := WIDTH_PX * _inverse_zoom()
	for body: BodyData in _system.bodies:
		if body.kind == BodyData.Kind.STAR:
			continue
		var radius := body.position.distance_to(_star_pos)
		draw_arc(_star_pos, radius, 0.0, TAU, SEGMENTS, COLOR, width, true)


func _inverse_zoom() -> float:
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.zoom.x > 0.0:
		return 1.0 / camera.zoom.x
	return 1.0
