class_name BodyView
extends Node2D
## Map marker for one BodyData (ADR 0005 — bodies never move). Shape encodes kind
## (star = ringed disc, station = diamond, planet = disc) so type reads without
## colour (ADR 0012); a tr() name label is always shown. At AU scale a real planet
## would be sub-pixel, so the marker is drawn at a CONSTANT ON-SCREEN size by
## cancelling the camera zoom — it's a map icon, not a to-scale body. Pure
## presentation: reads authored data, never mutates state.

const STAR_PX: float = 13.0
const PLANET_PX: float = 7.0
const STATION_PX: float = 7.0
const SELECT_GAP_PX: float = 8.0

var data: BodyData
var _selected: bool = false


func set_selected(selected: bool) -> void:
	if _selected == selected:
		return
	_selected = selected
	queue_redraw()


func setup(p_data: BodyData) -> void:
	data = p_data
	position = data.position
	var label := Label.new()
	label.text = tr(data.name_key) if data.name_key != "" else data.id
	label.position = Vector2(_marker_px() + 4.0, -9.0)  # local px (node is zoom-cancelled)
	add_child(label)
	queue_redraw()


func _process(_delta: float) -> void:
	# Cancel the camera zoom so the marker (drawn in px) stays a constant size.
	var camera := get_viewport().get_camera_2d()
	if camera != null and camera.zoom.x > 0.0:
		scale = Vector2.ONE / camera.zoom.x


func _draw() -> void:
	if data == null:
		return
	if _selected:
		draw_arc(Vector2.ZERO, _marker_px() + SELECT_GAP_PX, 0.0, TAU, 40, Palette.ACCENT, 1.5, true)
	match data.kind:
		BodyData.Kind.STAR:
			draw_circle(Vector2.ZERO, STAR_PX, data.tint)
			draw_arc(Vector2.ZERO, STAR_PX + 4.0, 0.0, TAU, 48, data.tint, 1.5, true)
		BodyData.Kind.STATION:
			var r := STATION_PX
			var diamond := PackedVector2Array([
				Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0), Vector2(0.0, -r),
			])
			draw_colored_polygon(diamond.slice(0, 4), data.tint)
			draw_polyline(diamond, Color.WHITE, 1.0, true)
		_:
			draw_circle(Vector2.ZERO, PLANET_PX, data.tint)


func _marker_px() -> float:
	match data.kind:
		BodyData.Kind.STAR:
			return STAR_PX
		BodyData.Kind.STATION:
			return STATION_PX
		_:
			return PLANET_PX
