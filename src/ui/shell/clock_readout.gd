extends Label
## Interim on-screen mission-clock readout (build-order step 2). Shows the
## derived in-game calendar + current sim speed so you can watch the clock run.
##
## Reads SimClock through EventBus signals and getters only — it never mutates
## state (ADR 0007). Player-facing text is routed through tr() keys (ADR 0010);
## the calendar derivation is the pure SimCalendar (src/core). The shell HUD
## replaces this readout in build-order step 8.


func _ready() -> void:
	# unbind(1) drops each signal's payload — we re-read state in _refresh().
	EventBus.sim_tick.connect(_refresh.unbind(1))
	EventBus.sim_speed_changed.connect(_refresh.unbind(1))
	_refresh()


func _refresh() -> void:
	var tick: int = SimClock.get_tick()
	var clock_text: String = tr("CLOCK_FORMAT").format({
		"day": SimCalendar.day(tick),
		"hour": "%02d" % SimCalendar.hour(tick),
	})
	var speed_text: String
	if SimClock.is_paused():
		speed_text = tr("CLOCK_PAUSED")
	else:
		speed_text = tr("CLOCK_SPEED").format({"speed": int(SimClock.get_speed())})
	text = "%s  %s  [%s]" % [tr("HUD_CLOCK"), clock_text, speed_text]
