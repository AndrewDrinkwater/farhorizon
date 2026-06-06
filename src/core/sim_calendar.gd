class_name SimCalendar
extends RefCounted
## Pure tick -> calendar derivation (CONVENTIONS.md). One tick = one in-game
## minute; the calendar (day / hour-of-day / minute-of-hour) is derived from the
## tick count, never stored. No node dependencies, so it is GUT-testable. Display
## string assembly (with `tr()` keys) lives in the UI; this stays integer math.

const MINUTES_PER_HOUR: int = 60
const HOURS_PER_DAY: int = 24
const MINUTES_PER_DAY: int = MINUTES_PER_HOUR * HOURS_PER_DAY  # 1440


## Whole in-game days elapsed at `tick` (day 0 is the first day).
static func day(tick: int) -> int:
	return tick / MINUTES_PER_DAY


## Hour of the current day at `tick`, 0..23.
static func hour(tick: int) -> int:
	return (tick / MINUTES_PER_HOUR) % HOURS_PER_DAY


## Minute of the current hour at `tick`, 0..59.
static func minute(tick: int) -> int:
	return tick % MINUTES_PER_HOUR
