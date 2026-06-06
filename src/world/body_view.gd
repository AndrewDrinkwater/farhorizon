class_name BodyView
extends Node2D
## Static visual for one BodyData (ADR 0005 — bodies never move). Shape encodes
## kind (star = ringed disc, station = diamond, planet = disc) so the type reads
## without relying on colour (ADR 0012); a tr() name label is always shown.
## Pure presentation: reads authored data, never mutates state.

## World-space label scale so names stay legible under the zoomed-out camera.
const LABEL_SCALE: float = 2.2

var data: BodyData


func setup(p_data: BodyData) -> void:
	data = p_data
	position = data.position
	var label := Label.new()
	label.text = tr(data.name_key) if data.name_key != "" else data.id
	label.scale = Vector2(LABEL_SCALE, LABEL_SCALE)
	label.position = Vector2(data.radius + 8.0, -data.radius)
	add_child(label)
	queue_redraw()


func _draw() -> void:
	if data == null:
		return
	match data.kind:
		BodyData.Kind.STAR:
			draw_circle(Vector2.ZERO, data.radius, data.tint)
			draw_arc(Vector2.ZERO, data.radius + 10.0, 0.0, TAU, 64, data.tint, 2.0, true)
		BodyData.Kind.STATION:
			var r := data.radius
			var diamond := PackedVector2Array([
				Vector2(0.0, -r), Vector2(r, 0.0), Vector2(0.0, r), Vector2(-r, 0.0),
			])
			draw_colored_polygon(diamond, data.tint)
			draw_polyline(diamond + PackedVector2Array([Vector2(0.0, -r)]),
				Color.WHITE, 1.5, true)
		_:
			draw_circle(Vector2.ZERO, data.radius, data.tint)
