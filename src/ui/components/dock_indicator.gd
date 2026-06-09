class_name DockIndicator
extends Control
## A horizontal dock-approach gauge shown during dock / undock (ADR 0033): a lateral
## approach (distinct from the vertical altitude gauge), ship at one end, the dock
## ring at the other, the ship sliding in (dock) or out (undock) with the manoeuvre.
## Dumb presentation; the owner calls configure() each frame (shape + label, ADR 0012).

const TRACK_COLOR := Color(0.4, 0.55, 0.7, 0.5)
const SHIP_COLOR := Color(0.9, 0.95, 1.0)

var _progress: float = 0.0  # 0 at the start of the transition, 1 at the end
var _undocking: bool = false
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(230.0, 70.0)


func _ready() -> void:
	_font = ThemeDB.fallback_font


func configure(progress: float, undocking: bool) -> void:
	_progress = clampf(progress, 0.0, 1.0)
	_undocking = undocking
	queue_redraw()


func _draw() -> void:
	var y := size.y * 0.5
	var left := 24.0
	var right := size.x - 24.0
	draw_line(Vector2(left, y), Vector2(right, y), TRACK_COLOR, 2.0, true)

	# Dock ring at the right; ship slides toward it (dock) / away (undock).
	draw_arc(Vector2(right, y), 9.0, 0.0, TAU, 24, TRACK_COLOR, 2.0, true)
	draw_string(_font, Vector2(right - 18.0, y - 14.0), tr("DOCK_RING"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Palette.TEXT_DIM)

	var t := (1.0 - _progress) if _undocking else _progress
	var x := lerpf(left, right - 14.0, t)
	# Ship triangle points toward the ring (docking) or away (undocking).
	var dir := -1.0 if _undocking else 1.0
	draw_colored_polygon(PackedVector2Array([
		Vector2(x + 9.0 * dir, y), Vector2(x - 6.0 * dir, y - 7.0), Vector2(x - 6.0 * dir, y + 7.0),
	]), SHIP_COLOR)
