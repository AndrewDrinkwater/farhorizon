class_name TGauge
extends VBoxContainer
## A segmented instrument gauge (ADR 0007/0035): a header (caption + mono numeric
## value, so it's never bar-only) over a row of segments that fill 0..1 and shift
## amber → red below the caution / alert thresholds. Reads via a binding callable
## returning { "ratio": float, "text": String }; refresh() re-reads it.
##
## Accessibility (ADR 0012): the numeric value and a ⚠ glyph at caution/alert carry
## the state too — it's never the segment colour alone.

const SEGMENTS: int = 20

var _header: Label
var _segments: Array[ColorRect] = []
var _caption_key: String
var _binding: Callable
var _caution: float = 0.30  # below this → amber
var _alert: float = 0.15    # below this → red


func _init(caption_key: String = "") -> void:
	add_theme_constant_override("separation", 3)
	_caption_key = caption_key
	_header = Label.new()
	_header.add_theme_font_override("font", TerminalTheme.mono_font())
	add_child(_header)

	var meter := HBoxContainer.new()
	meter.add_theme_constant_override("separation", 2)
	meter.custom_minimum_size = Vector2(0.0, 12.0)
	add_child(meter)
	for i in SEGMENTS:
		var seg := ColorRect.new()
		seg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seg.custom_minimum_size = Vector2(0.0, 12.0)
		seg.color = Palette.GAUGE_TRACK
		meter.add_child(seg)
		_segments.append(seg)


## Override the default fuel-style thresholds (low = bad).
func set_thresholds(caution: float, alert: float) -> TGauge:
	_caution = caution
	_alert = alert
	refresh()
	return self


func bind(binding: Callable) -> TGauge:
	_binding = binding
	refresh()
	return self


func refresh() -> void:
	if not _binding.is_valid():
		return
	var data: Dictionary = _binding.call()
	var ratio := clampf(float(data.get("ratio", 0.0)), 0.0, 1.0)

	var fill := Palette.STATUS_NOMINAL
	var glyph := ""
	if ratio <= _alert:
		fill = Palette.STATUS_ALERT
		glyph = "⚠ "
	elif ratio <= _caution:
		fill = Palette.STATUS_CAUTION
		glyph = "⚠ "

	var lit := int(round(ratio * SEGMENTS))
	for i in SEGMENTS:
		_segments[i].color = fill if i < lit else Palette.GAUGE_TRACK

	_header.text = "%s%s  %s" % [glyph, tr(_caption_key), String(data.get("text", ""))]
