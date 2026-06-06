class_name TPanel
extends PanelContainer
## Framed container with an optional title (ADR 0007). Add content via content().
## Pure layout — no bindings of its own.

var _content: VBoxContainer


func _init(title_key: String = "") -> void:
	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 6)
	add_child(outer)

	if title_key != "":
		var title := Label.new()
		title.text = tr(title_key)
		title.add_theme_color_override("font_color", Palette.ACCENT)
		outer.add_child(title)

	_content = VBoxContainer.new()
	_content.add_theme_constant_override("separation", 4)
	outer.add_child(_content)


## The container to place child components into.
func content() -> VBoxContainer:
	return _content
