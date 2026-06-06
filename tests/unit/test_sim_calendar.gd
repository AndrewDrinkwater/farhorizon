extends GutTest
## Tick -> calendar derivation (CONVENTIONS.md). One tick = one in-game minute.


func test_start_of_run() -> void:
	assert_eq(SimCalendar.day(0), 0, "tick 0 is day 0")
	assert_eq(SimCalendar.hour(0), 0, "tick 0 is hour 0")
	assert_eq(SimCalendar.minute(0), 0, "tick 0 is minute 0")


func test_within_first_hour() -> void:
	assert_eq(SimCalendar.minute(45), 45, "45 minutes in")
	assert_eq(SimCalendar.hour(45), 0, "still hour 0")
	assert_eq(SimCalendar.day(45), 0, "still day 0")


func test_hour_rollover() -> void:
	assert_eq(SimCalendar.hour(90), 1, "90 min = 1h 30m -> hour 1")
	assert_eq(SimCalendar.minute(90), 30, "...minute 30")


func test_day_rollover() -> void:
	assert_eq(SimCalendar.day(1440), 1, "1440 min = 1 day")
	assert_eq(SimCalendar.hour(1440), 0, "...hour 0")
	assert_eq(SimCalendar.minute(1440), 0, "...minute 0")


func test_arbitrary_tick() -> void:
	# 1505 min = 1 day, 1 hour, 5 minutes.
	assert_eq(SimCalendar.day(1505), 1)
	assert_eq(SimCalendar.hour(1505), 1)
	assert_eq(SimCalendar.minute(1505), 5)
