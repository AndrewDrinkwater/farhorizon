class_name FlightCore
extends RefCounted
## Pure flight state-machine logic (ADR 0005). No node deps, so it's GUT-testable
## and the canonical owner of the flight State enum (Helm + debug read it). The
## FlightController node is a thin shell that feeds it GameState + ticks.
##
## α0.1 movement is a straight line at the burn's constant cruise speed
## (FlightMath). The Accelerating/Cruising/Decelerating states are presentation
## phases derived from course progress — real accel ramps can replace them later
## without changing the machine's shape.

## Order matches localization/strings.csv FLIGHT_STATE_* and is the int payload
## of EventBus.flight_state_changed.
enum State {
	IDLE,
	COURSE_SET,
	ENGAGING,
	ACCELERATING,
	CRUISING,
	DECELERATING,
	ARRIVING,
	IN_ORBIT,
}

## Fractions of the course spent in the ramp phases (presentation only in α0.1).
const ACCEL_FRACTION: float = 0.25
const DECEL_FRACTION: float = 0.25

## Within this distance (wu) of the target counts as arrived.
const ARRIVE_DISTANCE: float = 1.0

const _STATE_KEYS: Dictionary = {
	State.IDLE: "FLIGHT_STATE_IDLE",
	State.COURSE_SET: "FLIGHT_STATE_COURSE_SET",
	State.ENGAGING: "FLIGHT_STATE_ENGAGING",
	State.ACCELERATING: "FLIGHT_STATE_ACCELERATING",
	State.CRUISING: "FLIGHT_STATE_CRUISING",
	State.DECELERATING: "FLIGHT_STATE_DECELERATING",
	State.ARRIVING: "FLIGHT_STATE_ARRIVING",
	State.IN_ORBIT: "FLIGHT_STATE_IN_ORBIT",
}


## tr() key for a flight state (ADR 0010).
static func state_key(state: int) -> String:
	return _STATE_KEYS.get(state, "FLIGHT_STATE_IDLE")


## Advance one tick from `pos` toward `target` at `burn` speed, clamped so the
## ship never overshoots (the final tick lands exactly on the target).
static func step_position(pos: Vector2, target: Vector2, burn: int) -> Vector2:
	var to_target: Vector2 = target - pos
	var rem: float = to_target.length()
	var sp: float = FlightMath.speed_wu_per_tick(burn)
	if rem <= sp or rem == 0.0:
		return target
	return pos + to_target / rem * sp


static func has_arrived(pos: Vector2, target: Vector2) -> bool:
	return pos.distance_to(target) <= ARRIVE_DISTANCE


## The executing phase for a ship at `pos` on a course `origin`→`target` at
## `burn`. Phases come from progress along the course; the final tick (target
## within one step) is ARRIVING, and reaching the target is IN_ORBIT.
static func executing_state(origin: Vector2, target: Vector2, pos: Vector2, burn: int) -> int:
	var rem: float = pos.distance_to(target)
	if rem <= ARRIVE_DISTANCE:
		return State.IN_ORBIT
	if rem <= FlightMath.speed_wu_per_tick(burn):
		return State.ARRIVING
	var total: float = origin.distance_to(target)
	if total <= 0.0:
		return State.IN_ORBIT
	var progress: float = clampf((total - rem) / total, 0.0, 1.0)
	if progress < ACCEL_FRACTION:
		return State.ACCELERATING
	if progress < 1.0 - DECEL_FRACTION:
		return State.CRUISING
	return State.DECELERATING
