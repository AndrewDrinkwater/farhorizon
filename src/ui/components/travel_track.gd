class_name TravelTrack
extends Control
## A travel progress line (ADR 0035): a horizontal track with a ship marker gliding
## from origin to destination as the course is flown. Pure presentation; the owner
## (TravelBar) feeds it 0..1 progress. Endpoints + traversed segment carry the state
## by shape, not colour alone (ADR 0012).

var _progress: float = 0.0


func _init() -> void:
	custom_minimum_size = Vector2(280.0, 18.0)


func set_progress(p: float) -> void:
	_progress = clampf(p, 0.0, 1.0)
	queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	var w := size.x
	var x := w * _progress
	draw_line(Vector2(0.0, y), Vector2(w, y), Palette.PANEL_BORDER, 2.0)         # full course
	draw_line(Vector2(0.0, y), Vector2(x, y), Palette.STATUS_NOMINAL, 2.0)       # traversed
	draw_circle(Vector2(0.0, y), 3.0, Palette.TEXT_DIM)                          # origin
	draw_circle(Vector2(w, y), 3.5, Palette.STATUS_INFO)                         # destination
	# Ship marker — a triangle pointing the way (shape channel).
	var p := Vector2(x, y)
	draw_colored_polygon(PackedVector2Array([
		p + Vector2(-6.0, -5.0), p + Vector2(7.0, 0.0), p + Vector2(-6.0, 5.0),
	]), Palette.ACCENT)
