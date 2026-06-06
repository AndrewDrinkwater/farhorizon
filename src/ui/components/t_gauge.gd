class_name TGauge
extends VBoxContainer
## Continuous level (ADR 0007): a header (caption + numeric value, so it's never
## bar-only) over a 0..1 progress bar. Reads via a binding callable returning
## { "ratio": float, "text": String }; refresh() re-reads it.

var _header: Label
var _bar: ProgressBar
var _caption_key: String
var _binding: Callable


func _init(caption_key: String = "") -> void:
	add_theme_constant_override("separation", 2)
	_caption_key = caption_key
	_header = Label.new()
	_header.text = tr(caption_key)
	add_child(_header)

	_bar = ProgressBar.new()
	_bar.min_value = 0.0
	_bar.max_value = 1.0
	_bar.step = 0.0
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0.0, 12.0)
	add_child(_bar)


func bind(binding: Callable) -> TGauge:
	_binding = binding
	refresh()
	return self


func refresh() -> void:
	if not _binding.is_valid():
		return
	var data: Dictionary = _binding.call()
	_bar.value = clampf(float(data.get("ratio", 0.0)), 0.0, 1.0)
	_header.text = "%s  %s" % [tr(_caption_key), String(data.get("text", ""))]
