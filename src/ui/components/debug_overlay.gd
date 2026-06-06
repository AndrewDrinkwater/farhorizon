extends CanvasLayer
## Toggleable live debug overlay (ADR 0012), bound to the `toggle_debug` action.
## Shows sim + flight internals for tuning the time-driven sim.
##
## Reads state only; it never mutates (ADR 0012). Off by default and not part of
## the release UI. Debug text is exempt from localisation (ADR 0010), so these
## strings are deliberately plain literals — except the flight-state name, which
## reuses the player-facing tr() label so it reads the same as the HUD.

var _label: Label
var _flight_state: int = FlightCore.State.IDLE


func _ready() -> void:
	layer = 128  # draw above everything
	visible = false
	var panel := PanelContainer.new()
	panel.position = Vector2(40.0, 110.0)
	_label = Label.new()
	panel.add_child(_label)
	add_child(panel)
	EventBus.flight_state_changed.connect(_on_flight_state_changed)


func _on_flight_state_changed(state: int) -> void:
	_flight_state = state


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_debug"):
		visible = not visible


func _process(_delta: float) -> void:
	if not visible:
		return
	var pos := GameState.ship.position
	_label.text = "\n".join([
		"DEBUG OVERLAY  (F3 to toggle)",
		"tick:      %d" % SimClock.get_tick(),
		"speed:     %.1fx%s" % [SimClock.get_speed(), "  (paused)" if SimClock.is_paused() else ""],
		"sec/tick:  %.2f" % SimClock.SECONDS_PER_TICK,
		"flight:    %s" % tr(FlightCore.state_key(_flight_state)),
		"ship pos:  (%.0f, %.0f) wu" % [pos.x, pos.y],
		"reaction:  %.1f RM" % GameState.ship.reaction_mass,
		"fps:       %d" % Engine.get_frames_per_second(),
	])
