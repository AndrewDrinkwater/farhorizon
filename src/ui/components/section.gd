class_name Section
extends VBoxContainer
## A titled cluster of command widgets (ADR 0034): a dim header over its widgets,
## hidden wholesale when its context doesn't apply. The control deck's unit of
## composition — generalizes the Helm control clusters (ADR 0032) so any console
## can declare its order groups as data.

var id: String


func _init(section_id: String = "", header_key: String = "") -> void:
	id = section_id
	add_theme_constant_override("separation", 4)
	if header_key != "":
		var header := Label.new()
		header.text = tr(header_key)
		header.add_theme_color_override("font_color", Palette.TEXT_DIM)
		add_child(header)


func add_widget(widget: Control) -> Section:
	add_child(widget)
	return self
