class_name TimeControls
extends PanelContainer
## Persistent shell time controls (ADR 0006, helm.md): the mission clock readout
## plus pause / 1× / 2× / 4× buttons. These set the captain's *watch speed* and
## live in the shell, not inside any console. Reads SimClock; the speed buttons
## emit through SimClock (a service), the console never sees them.

const SPEEDS: Array[float] = [1.0, 2.0, 4.0]

var _clock: Label
var _pause_button: Button
var _speed_buttons: Dictionary = {}  # speed: float -> Button


func _init() -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	add_child(row)

	_clock = Label.new()
	_clock.custom_minimum_size = Vector2(220.0, 0.0)
	row.add_child(_clock)

	_pause_button = TButton.new()
	_pause_button.setup("TIME_PAUSE", Callable(SimClock, "toggle_pause"))
	row.add_child(_pause_button)

	for speed: float in SPEEDS:
		var button := TButton.new()
		button.setup("", Callable(SimClock, "set_speed").bind(speed))
		button.text = "%d×" % int(speed)
		row.add_child(button)
		_speed_buttons[speed] = button


func _ready() -> void:
	EventBus.sim_tick.connect(_refresh.unbind(1))
	EventBus.sim_speed_changed.connect(_refresh.unbind(1))
	EventBus.game_state_loaded.connect(_refresh)
	_refresh()


func _refresh() -> void:
	var tick := SimClock.get_tick()
	var clock_text := tr("CLOCK_FORMAT").format({
		"day": SimCalendar.day(tick),
		"hour": "%02d" % SimCalendar.hour(tick),
	})
	_clock.text = "%s  %s" % [tr("HUD_CLOCK"), clock_text]

	# Highlight the active control (non-colour cue: the label too, via the dim/bright).
	var paused := SimClock.is_paused()
	_pause_button.modulate = Palette.ACCENT if paused else Color.WHITE
	for speed: float in _speed_buttons:
		var active: bool = not paused and is_equal_approx(SimClock.get_speed(), speed)
		_speed_buttons[speed].modulate = Palette.ACCENT if active else Color.WHITE
