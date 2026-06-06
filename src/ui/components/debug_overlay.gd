extends CanvasLayer
## Toggleable live debug overlay (ADR 0012), bound to the `toggle_debug` action.
## Shows sim internals — tick, speed, FPS — for tuning the time-driven sim.
##
## Reads state only; it never mutates (ADR 0012). Off by default and not part of
## the release UI. Debug text is exempt from localisation (ADR 0010), so these
## strings are deliberately plain literals.

var _label: Label


func _ready() -> void:
	layer = 128  # draw above everything
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(40.0, 110.0)
	_label = Label.new()
	panel.add_child(_label)
	add_child(panel)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	_label.text = "\n".join([
		"DEBUG OVERLAY  (F1 to toggle)",
		"tick:      %d" % SimClock.get_tick(),
		"speed:     %.1fx%s" % [SimClock.get_speed(), "  (paused)" if SimClock.is_paused() else ""],
		"sec/tick:  %.2f" % SimClock.SECONDS_PER_TICK,
		"fps:       %d" % Engine.get_frames_per_second(),
	])
