class_name ClockMath
extends RefCounted
## Pure tick-accumulation math for SimClock (ADR 0004). No node dependencies, so
## it is fully GUT-testable without the engine. The SimClock node is a thin shell
## that feeds it real `delta` + the current speed and emits one `sim_tick` per
## whole tick this returns.
##
## Model: at 1x speed one tick elapses every `seconds_per_tick` real seconds.
## Speed is a plain multiplier on real time (0 = paused — time simply does not
## accumulate, so the world freezes cleanly with no lost fractional progress).

## Real seconds of accumulated (speed-scaled) time per emitted tick.
var seconds_per_tick: float

var _accumulator: float = 0.0


func _init(p_seconds_per_tick: float) -> void:
	assert(p_seconds_per_tick > 0.0, "seconds_per_tick must be positive")
	seconds_per_tick = p_seconds_per_tick


## Advance by `delta` real seconds at `speed` multiplier (0 = paused). Returns
## the number of whole ticks that elapsed; the caller emits one signal each.
## Sub-tick remainder is preserved across calls so no time is lost.
func advance(delta: float, speed: float) -> int:
	if speed <= 0.0 or delta <= 0.0:
		return 0
	_accumulator += delta * speed
	var ticks: int = 0
	while _accumulator >= seconds_per_tick:
		_accumulator -= seconds_per_tick
		ticks += 1
	return ticks


## Fractional progress toward the next tick, in real seconds [0, seconds_per_tick).
## The view uses this for interpolation; logic never reads it (ADR 0004).
func get_accumulator() -> float:
	return _accumulator


## Progress toward the next tick as a 0..1 fraction (for interpolated rendering).
func get_tick_fraction() -> float:
	return _accumulator / seconds_per_tick


## Drop any partial progress (e.g. on load, where the tick is restored exactly).
func reset() -> void:
	_accumulator = 0.0
