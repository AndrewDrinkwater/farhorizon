class_name SimCalendar
extends RefCounted
## Pure tick -> calendar derivation (CONVENTIONS.md). One tick = one in-game
## hour; the calendar is derived from the tick count, never stored. No node
## dependencies, so it is GUT-testable. Display string assembly (with `tr()`
## keys) lives in the UI; this stays language-agnostic integer math.

const HOURS_PER_DAY: int = 24


## Whole in-game days elapsed at `tick` (day 0 is the first day).
static func day(tick: int) -> int:
	return tick / HOURS_PER_DAY


## Hour of the current day at `tick`, 0..23.
static func hour(tick: int) -> int:
	return tick % HOURS_PER_DAY
