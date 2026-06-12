class_name ThrottlePill
extends Control
## The Helm throttle (ADR 0035): a vertical pill of five burn tiers (low at the
## bottom, flank at the top) drawn as a stack of bars — a lever, not three buttons.
## Click a bar to set the burn; bars up to the selected tier light. Emits via the
## supplied callable (UI never mutates state, ADR 0014). The selected tier carries
## state by FILL HEIGHT + the named label, not colour alone (ADR 0012).

const CAP_H: float = 18.0
const BAR_H: float = 20.0
const GAP: float = 5.0
const NAME_H: float = 20.0
const MIN_W: float = 30.0   # bottom (slowest) bar width
const MAX_W: float = 64.0   # top (flank) bar width — a throttle wedge

const NAME_KEY: Dictionary = {
	FlightMath.Burn.ECONOMY: "HELM_BURN_ECONOMY",
	FlightMath.Burn.CRUISE: "HELM_BURN_CRUISE",
	FlightMath.Burn.STANDARD: "HELM_BURN_STANDARD",
	FlightMath.Burn.HARD: "HELM_BURN_HARD",
	FlightMath.Burn.FLANK: "HELM_BURN_FLANK",
}

var _font: Font
var _level: int = 2  # index into FlightMath.BY_SPEED (STANDARD)
var _on_select: Callable


func _init() -> void:
	_font = ThemeDB.fallback_font
	custom_minimum_size = Vector2(MAX_W + 16.0, CAP_H + 5.0 * (BAR_H + GAP) + NAME_H)


func setup(on_select: Callable) -> ThrottlePill:
	_on_select = on_select
	return self


func set_burn(burn: int) -> void:
	var idx := FlightMath.BY_SPEED.find(burn)
	_level = idx if idx >= 0 else 2
	queue_redraw()


func _draw() -> void:
	var cx := size.x * 0.5
	draw_string(_font, Vector2(0.0, 13.0), tr("HELM_THROTTLE"), HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 12, Palette.TEXT_DIM)
	# Five bars: tier 0 (slowest) at the bottom, tier 4 (flank) at the top.
	for seg in 5:
		var tier := 4 - seg  # top row = highest tier
		var w := lerpf(MIN_W, MAX_W, float(tier) / 4.0)
		var y := CAP_H + float(seg) * (BAR_H + GAP)
		var rect := Rect2(cx - w * 0.5, y, w, BAR_H)
		var lit := tier <= _level
		draw_rect(rect, Palette.STATUS_NOMINAL if lit else Palette.GAUGE_TRACK, true)
		draw_rect(rect, Palette.PANEL_BORDER, false, 1.0)
	var name_key: String = NAME_KEY.get(FlightMath.BY_SPEED[_level], "HELM_BURN_STANDARD")
	draw_string(_font, Vector2(0.0, size.y - 5.0), tr(name_key), HORIZONTAL_ALIGNMENT_CENTER,
		size.x, 13, Palette.ACCENT)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		var seg := int(floorf((event.position.y - CAP_H) / (BAR_H + GAP)))
		if seg < 0 or seg > 4:
			return
		var tier := 4 - seg
		if _on_select.is_valid():
			_on_select.call(FlightMath.BY_SPEED[tier])
