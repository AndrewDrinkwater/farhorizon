class_name TLight
extends HBoxContainer
## Status light (ADR 0007/0012): a coloured dot AND a glyph AND a text label —
## state is never encoded by colour alone. Driven by set_state().

var _dot: ColorRect
var _glyph: Label
var _text: Label


func _init(caption_key: String = "") -> void:
	add_theme_constant_override("separation", 8)
	if caption_key != "":
		var caption := Label.new()
		caption.text = tr(caption_key)
		caption.add_theme_color_override("font_color", Palette.TEXT_DIM)
		caption.custom_minimum_size = Vector2(110.0, 0.0)
		add_child(caption)

	_dot = ColorRect.new()
	_dot.custom_minimum_size = Vector2(14.0, 14.0)
	_dot.color = Palette.STATUS_IDLE
	add_child(_dot)

	_glyph = Label.new()
	add_child(_glyph)

	_text = Label.new()
	add_child(_text)


## Colour + glyph + label together (the glyph/label are the non-colour channels).
func set_state(color: Color, glyph: String, label: String) -> void:
	_dot.color = color
	_glyph.text = glyph
	_text.text = label
