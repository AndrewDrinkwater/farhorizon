class_name NavBackdrop
extends Node2D
## An idle instrument backdrop for the nav plot (ADR 0035): a faint framed region
## with a grid behind the orrery / scope, so the stage reads as a powered, contained
## display — never black void. No cross-hair / reticle (they didn't earn their keep
## and read as confusing) and no range rings (they competed with the orrery's real
## orbit rings). Drawn in local space — the Helm parents it under a clip Control
## sized to the plot region, so set_view_rect receives a local rect (origin 0).

const GRID_STEP: float = 64.0
const BRACKET: float = 22.0  # corner-bracket arm length

var _view_rect: Rect2 = Rect2()


func _ready() -> void:
	get_viewport().size_changed.connect(queue_redraw)


func set_view_rect(rect: Rect2) -> void:
	_view_rect = rect
	queue_redraw()


func _region() -> Rect2:
	if _view_rect.size.x > 0.0 and _view_rect.size.y > 0.0:
		return _view_rect
	return Rect2(Vector2.ZERO, get_viewport_rect().size)


func _draw() -> void:
	var region := _region()
	var grid := Color(Palette.ACCENT, 0.045)

	# Recessed screen surface — a distinct darker fill so the plot reads as a screen.
	draw_rect(region, Palette.SCREEN_BG, true)

	# Faint grid aligned to the centre, clipped to the region.
	var x := region.position.x + fmod(region.size.x * 0.5, GRID_STEP)
	while x < region.end.x:
		draw_line(Vector2(x, region.position.y), Vector2(x, region.end.y), grid, 1.0)
		x += GRID_STEP
	var y := region.position.y + fmod(region.size.y * 0.5, GRID_STEP)
	while y < region.end.y:
		draw_line(Vector2(region.position.x, y), Vector2(region.end.x, y), grid, 1.0)
		y += GRID_STEP

	# A distinct screen frame: a thin full border + bright accent corner brackets.
	draw_rect(region, Palette.PANEL_BORDER, false, 1.0)
	_corner_brackets(region)


## L-shaped accent brackets at each corner — the "this is a screen" cue (ADR 0035).
func _corner_brackets(region: Rect2) -> void:
	var col := Color(Palette.ACCENT, 0.55)
	var w := 2.0
	var top_left := region.position
	var top_right := Vector2(region.end.x, region.position.y)
	var bot_left := Vector2(region.position.x, region.end.y)
	var bot_right := region.end
	for corner: Array in [[top_left, 1.0, 1.0], [top_right, -1.0, 1.0], [bot_left, 1.0, -1.0], [bot_right, -1.0, -1.0]]:
		var p: Vector2 = corner[0]
		var sx: float = corner[1]
		var sy: float = corner[2]
		draw_line(p, p + Vector2(BRACKET * sx, 0.0), col, w)
		draw_line(p, p + Vector2(0.0, BRACKET * sy), col, w)
