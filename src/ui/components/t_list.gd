class_name TList
extends ScrollContainer
## Scrollable record list (ADR 0007), newest first — used for the Helm order log.
## Capped so it can't grow without bound.

const MAX_RECORDS: int = 50

var _box: VBoxContainer


func _init() -> void:
	horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_box = VBoxContainer.new()
	_box.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_theme_constant_override("separation", 2)
	add_child(_box)


## Prepend a record (newest on top), trimming the oldest past the cap.
func add_record(line: String) -> void:
	var label := Label.new()
	label.text = line
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_child(label)
	_box.move_child(label, 0)
	while _box.get_child_count() > MAX_RECORDS:
		_box.get_child(_box.get_child_count() - 1).free()


func clear() -> void:
	for child in _box.get_children():
		child.free()
