class_name TButton
extends Button
## Command button (ADR 0007): on press it invokes the supplied callable, which
## emits an intent/order on EventBus. The button never mutates state itself.

var _on_press: Callable


## Configure with a tr() label key and the callable to run on press. Returns self
## for fluent construction.
func setup(label_key: String, on_press: Callable) -> TButton:
	text = tr(label_key)
	_on_press = on_press
	pressed.connect(_emit)
	return self


## Like setup() but with already-resolved/dynamic text (e.g. a composed directory
## row), not a tr() key. The caller localizes the text.
func setup_text(label: String, on_press: Callable) -> TButton:
	text = label
	_on_press = on_press
	pressed.connect(_emit)
	return self


func _emit() -> void:
	if _on_press.is_valid():
		_on_press.call()
