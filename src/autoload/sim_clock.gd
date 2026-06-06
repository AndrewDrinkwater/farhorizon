extends Node
## SimClock — the sole driver of simulation time (ADR 0004, CONVENTIONS.md).
##
## Discrete ticks: one tick = one in-game hour. At 1x speed the clock emits
## ticks every SECONDS_PER_TICK real seconds. Speed multiplier scales that;
## 0 = paused. Nothing else owns a sim-affecting timer.
##
## SCAFFOLD STUB — tick accumulation + window-focus auto-pause are implemented
## in build-order step 2. Public surface is declared so other systems can be
## wired against it. See docs/ALPHA-0.1-SPEC.md.

## Real seconds per tick at 1x speed (tuning constant, not logic).
const SECONDS_PER_TICK: float = 2.0

## Allowed speed multipliers exposed at the Helm/shell (0 = paused).
const SPEEDS: Array[float] = [0.0, 1.0, 2.0, 4.0]

var _tick: int = 0
var _speed: float = 1.0


func get_tick() -> int:
	return _tick


func get_speed() -> float:
	return _speed


func set_speed(speed: float) -> void:
	if is_equal_approx(speed, _speed):
		return
	_speed = speed
	EventBus.sim_speed_changed.emit(_speed)

# TODO(step 2): accumulate real time in _process, emit EventBus.sim_tick per
# step, and auto-pause on window focus loss (CONVENTIONS.md).
