class_name AltitudeIndicator
extends Control
## A vertical altitude / atmosphere gauge shown during descent / ascent (ADR 0033):
## orbit at the top, ground at the bottom, the atmosphere drawn as a band whose
## depth grows with pressure (vacuum → a thin "no atmosphere" sliver). The ship
## marker rides down (descent) or up (ascent) the gauge with the transition.
## Dumb presentation: the owner calls configure() each frame; state is shown by
## shape + label, not colour alone (ADR 0012).

const FILL_COLOR := Color(0.4, 0.55, 0.7, 0.18)
const FRAME_COLOR := Color(0.4, 0.55, 0.7, 0.5)
const SHIP_COLOR := Color(0.9, 0.95, 1.0)

# Atmosphere band depth as a fraction of the gauge height, by class (None→Crushing).
const BAND_FRACTION: Array[float] = [0.1, 0.3, 0.5, 0.7, 0.9]

var _atm: float = 0.0
var _progress: float = 0.0  # 0 at the start of the transition, 1 at the end
var _descending: bool = true
var _font: Font


func _init() -> void:
	custom_minimum_size = Vector2(150.0, 230.0)


func _ready() -> void:
	_font = ThemeDB.fallback_font


func configure(atm: float, progress: float, descending: bool) -> void:
	_atm = atm
	_progress = clampf(progress, 0.0, 1.0)
	_descending = descending
	queue_redraw()


func _draw() -> void:
	var top := 20.0
	var bottom := size.y - 20.0
	var x := size.x * 0.5
	var w := 40.0
	var cls := LandingMath.atmosphere_class(_atm)
	var band_top := lerpf(bottom, top, BAND_FRACTION[cls])

	# Atmosphere band (bottom region) + gauge frame.
	draw_rect(Rect2(x - w, band_top, w * 2.0, bottom - band_top), FILL_COLOR, true)
	draw_line(Vector2(x, top), Vector2(x, bottom), FRAME_COLOR, 2.0, true)
	draw_line(Vector2(x - w, bottom), Vector2(x + w, bottom), FRAME_COLOR, 2.0, true)  # ground

	draw_string(_font, Vector2(x - w, top - 4.0), tr("ALT_ORBIT"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Palette.TEXT_DIM)
	draw_string(_font, Vector2(x - w, bottom + 16.0), tr("ALT_GROUND"),
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 13, Palette.TEXT_DIM)
	var band_label := tr("ALT_VACUUM") if cls == LandingMath.AtmoClass.NONE \
		else tr(["ATMO_NONE", "ATMO_THIN", "ATMO_STANDARD", "ATMO_DENSE", "ATMO_CRUSHING"][cls])
	draw_string(_font, Vector2(x + w * 0.5 + 4.0, (band_top + bottom) * 0.5), band_label,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 12, Palette.TEXT)

	# Ship marker: top→bottom on descent, bottom→top on ascent.
	var y := lerpf(top, bottom, _progress) if _descending else lerpf(bottom, top, _progress)
	var tip := 1.0 if _descending else -1.0  # arrow points the way it travels
	draw_colored_polygon(PackedVector2Array([
		Vector2(x, y + 9.0 * tip), Vector2(x - 8.0, y - 6.0 * tip), Vector2(x + 8.0, y - 6.0 * tip),
	]), SHIP_COLOR)
