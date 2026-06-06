extends GutTest
## Tick-accumulation math (ADR 0004). Pure logic — no engine needed.

const SPT: float = 2.0  # seconds per tick at 1x, matching the SimClock constant


func _math() -> ClockMath:
	return ClockMath.new(SPT)


func test_accumulates_to_one_tick() -> void:
	var m := _math()
	assert_eq(m.advance(SPT, 1.0), 1, "one tick after exactly seconds_per_tick at 1x")
	assert_almost_eq(m.get_accumulator(), 0.0, 0.0001, "no remainder left")


func test_partial_does_not_tick_but_is_preserved() -> void:
	var m := _math()
	assert_eq(m.advance(1.0, 1.0), 0, "half a tick worth of time emits nothing")
	assert_almost_eq(m.get_accumulator(), 1.0, 0.0001, "remainder accumulated")
	assert_eq(m.advance(1.0, 1.0), 1, "second half completes the tick")


func test_speed_scales_ticks() -> void:
	var m := _math()
	# 1s of real time at 2x = 2s of sim time = exactly one tick.
	assert_eq(m.advance(1.0, 2.0), 1, "2x doubles the rate")
	var m2 := _math()
	# 1s at 4x = 4s of sim time = two ticks (SPT=2), no remainder.
	assert_eq(m2.advance(1.0, 4.0), 2, "4x emits two ticks per real second")
	assert_almost_eq(m2.get_accumulator(), 0.0, 0.0001, "no remainder at 4x")


func test_multiple_ticks_in_one_advance() -> void:
	var m := _math()
	assert_eq(m.advance(5.0, 1.0), 2, "5s / 2s-per-tick = 2 whole ticks")
	assert_almost_eq(m.get_accumulator(), 1.0, 0.0001, "1s carried over")


func test_pause_emits_nothing_and_freezes() -> void:
	var m := _math()
	assert_eq(m.advance(100.0, 0.0), 0, "speed 0 emits no ticks")
	assert_almost_eq(m.get_accumulator(), 0.0, 0.0001, "paused time does not accumulate")


func test_pause_preserves_prior_progress() -> void:
	var m := _math()
	m.advance(1.0, 1.0)  # 1s of progress toward a 2s tick
	assert_eq(m.advance(10.0, 0.0), 0, "no ticks while paused")
	assert_almost_eq(m.get_accumulator(), 1.0, 0.0001, "progress survives the pause")
	assert_eq(m.advance(1.0, 1.0), 1, "resumes and completes the tick")


func test_zero_or_negative_delta_is_noop() -> void:
	var m := _math()
	assert_eq(m.advance(0.0, 1.0), 0, "zero delta emits nothing")
	assert_eq(m.advance(-1.0, 1.0), 0, "negative delta is ignored")


func test_tick_fraction_reports_progress() -> void:
	var m := _math()
	m.advance(1.0, 1.0)  # halfway to the next tick (1s of 2s)
	assert_almost_eq(m.get_tick_fraction(), 0.5, 0.0001, "fraction is accumulator/spt")


func test_reset_clears_accumulator() -> void:
	var m := _math()
	m.advance(1.0, 1.0)
	m.reset()
	assert_almost_eq(m.get_accumulator(), 0.0, 0.0001, "reset drops partial progress")
