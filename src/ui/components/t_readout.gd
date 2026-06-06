class_name TReadout
extends HBoxContainer
## Labelled value (ADR 0007): a caption (tr key) + a value. Reads via a binding
## callable returning the display String; refresh() re-reads it. The owning
## console calls refresh() on the relevant EventBus signals.

var _caption: Label
var _value: Label
var _binding: Callable


func _init(caption_key: String = "") -> void:
	add_theme_constant_override("separation", 8)
	_caption = Label.new()
	_caption.text = tr(caption_key)
	_caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
	_caption.custom_minimum_size = Vector2(110.0, 0.0)
	add_child(_caption)

	_value = Label.new()
	add_child(_value)


func bind(binding: Callable) -> TReadout:
	_binding = binding
	refresh()
	return self


func set_value(text_value: String) -> void:
	_value.text = text_value


func refresh() -> void:
	if _binding.is_valid():
		_value.text = String(_binding.call())
