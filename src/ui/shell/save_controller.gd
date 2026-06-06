class_name SaveController
extends Node
## Shell-level save/load on the named input actions (ADR 0011): sim_save (F5) and
## sim_load (F9). Drives SaveManager and shows a brief toast. Loading emits
## game_state_loaded, which the rest of the UI/flight already react to.
##
## Minimal by design — a proper save/slots screen is post-α0.1; this makes the
## save/load spine (done-criterion 4) usable in-game.

const TOAST_SECONDS: float = 2.0

var _toast: Label


func _ready() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 64
	add_child(layer)
	_toast = Label.new()
	_toast.visible = false
	_toast.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_toast.position = Vector2(0.0, 24.0)
	_toast.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_toast.add_theme_color_override("font_color", Palette.ACCENT)
	layer.add_child(_toast)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sim_save"):
		_save()
	elif event.is_action_pressed("sim_load"):
		_load()


func _save() -> void:
	_show("SAVE_DONE" if SaveManager.save_game() else "SAVE_FAILED")


func _load() -> void:
	if not SaveManager.has_save():
		_show("LOAD_NONE")
		return
	_show("LOAD_DONE" if SaveManager.load_game() else "LOAD_FAILED")


func _show(message_key: String) -> void:
	_toast.text = tr(message_key)
	_toast.visible = true
	await get_tree().create_timer(TOAST_SECONDS).timeout
	if is_instance_valid(_toast):
		_toast.visible = false
