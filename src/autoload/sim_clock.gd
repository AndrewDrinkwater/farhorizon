extends Node
## SimClock — the sole driver of simulation time (ADR 0004, CONVENTIONS.md).
##
## Discrete ticks: one tick = one in-game hour. At 1x speed the clock emits a
## tick every SECONDS_PER_TICK real seconds; the speed multiplier scales that,
## with 0 = paused. Nothing else owns a sim-affecting timer — every ticking
## system subscribes to EventBus.sim_tick instead.
##
## This node is a thin shell. The accumulation math lives in the pure, tested
## ClockMath (src/core); the *authoritative tick + speed* live in GameState.clock
## (ADR 0002) so the save is just a serialized tree — SimClock reads/advances
## them, it does not keep a divergent copy. Speed control is wired to the named
## input actions (ADR 0011). The one allowed auto-pause is on OS window-focus
## loss, gated by ConfigManager's pause_on_focus_loss (CONVENTIONS.md).

## Real seconds per tick at 1x speed (tuning constant, not logic). One tick = one
## in-game MINUTE, so 1 real second = 1 in-game minute at 1x and the sim steps
## every second (the clock and the ship update continuously, not once an hour).
const SECONDS_PER_TICK: float = 1.0

## Allowed speed multipliers exposed at the Helm/shell (0 = paused).
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

var _math: ClockMath

## Speed to restore when un-pausing (manual toggle); always a running speed.
var _last_running_speed: float = 1.0
## True only while the clock paused itself for focus loss, so focus regain
## restores exactly that and a manual pause-while-unfocused isn't clobbered.
var _focus_auto_paused: bool = false
var _speed_before_focus_loss: float = 1.0


func _ready() -> void:
	_math = ClockMath.new(SECONDS_PER_TICK)
	# Start at the configured default speed (falls back to 1x via DEFAULTS).
	var default_speed: float = float(ConfigManager.get_setting("gameplay", "default_sim_speed"))
	if default_speed > 0.0:
		_last_running_speed = default_speed
	GameState.clock.speed = default_speed
	EventBus.game_state_loaded.connect(_on_state_loaded)


func _process(delta: float) -> void:
	var ticks: int = _math.advance(delta, GameState.clock.speed)
	for _i: int in ticks:
		GameState.clock.tick += 1
		EventBus.sim_tick.emit(GameState.clock.tick)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("sim_pause"):
		toggle_pause()
	elif event.is_action_pressed("sim_speed_up"):
		speed_up()
	elif event.is_action_pressed("sim_speed_down"):
		speed_down()


func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		_on_focus_lost()
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN:
		_on_focus_gained()


# --- Public surface (read by UI, never mutated by it) ---

func get_tick() -> int:
	return GameState.clock.tick


func get_speed() -> float:
	return GameState.clock.speed


func is_paused() -> bool:
	return GameState.clock.speed <= 0.0


## Fractional progress to the next tick (0..1) for interpolated rendering.
func get_tick_fraction() -> float:
	return _math.get_tick_fraction() if _math != null else 0.0


func set_speed(speed: float) -> void:
	if is_equal_approx(speed, GameState.clock.speed):
		return
	if speed > 0.0:
		_last_running_speed = speed
	GameState.clock.speed = speed
	EventBus.sim_speed_changed.emit(speed)


## Step up through SPEEDS (caps at the fastest).
func speed_up() -> void:
	var idx: int = SPEEDS.find(get_speed())
	if idx == -1:
		idx = SPEEDS.find(1.0)
	set_speed(SPEEDS[mini(idx + 1, SPEEDS.size() - 1)])


## Step down through SPEEDS (floors at paused).
func speed_down() -> void:
	var idx: int = SPEEDS.find(get_speed())
	if idx == -1:
		idx = SPEEDS.find(1.0)
	set_speed(SPEEDS[maxi(idx - 1, 0)])


## Toggle between paused and the last running speed (player choice, ADR 0004).
func toggle_pause() -> void:
	if is_paused():
		set_speed(_last_running_speed)
	else:
		set_speed(0.0)


# --- Lifecycle ---

## A load replaced GameState.clock; drop sub-tick progress and refresh listeners.
func _on_state_loaded() -> void:
	_math.reset()
	_focus_auto_paused = false
	if GameState.clock.speed > 0.0:
		_last_running_speed = GameState.clock.speed
	EventBus.sim_speed_changed.emit(GameState.clock.speed)


# --- Window-focus auto-pause (the one allowed auto-pause; CONVENTIONS.md) ---

func _on_focus_lost() -> void:
	if not bool(ConfigManager.get_setting("gameplay", "pause_on_focus_loss")):
		return
	if is_paused():
		return  # nothing to do; leave the player's pause as-is
	_speed_before_focus_loss = get_speed()
	_focus_auto_paused = true
	set_speed(0.0)


func _on_focus_gained() -> void:
	if not _focus_auto_paused:
		return
	_focus_auto_paused = false
	set_speed(_speed_before_focus_loss)
