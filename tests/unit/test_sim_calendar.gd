extends GutTest
## Tick -> calendar derivation (CONVENTIONS.md). Pure integer math.


func test_start_of_run() -> void:
	assert_eq(SimCalendar.day(0), 0, "tick 0 is day 0")
	assert_eq(SimCalendar.hour(0), 0, "tick 0 is hour 0")


func test_within_first_day() -> void:
	assert_eq(SimCalendar.day(23), 0, "hour 23 is still day 0")
	assert_eq(SimCalendar.hour(23), 23, "tick 23 is hour 23")


func test_day_rollover() -> void:
	assert_eq(SimCalendar.day(24), 1, "tick 24 starts day 1")
	assert_eq(SimCalendar.hour(24), 0, "tick 24 is hour 0")


func test_arbitrary_tick() -> void:
	assert_eq(SimCalendar.day(49), 2, "49 / 24 = day 2")
	assert_eq(SimCalendar.hour(49), 1, "49 % 24 = hour 1")
