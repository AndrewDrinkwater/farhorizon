extends GutTest
## SimClock node behaviour: speed control + window-focus auto-pause. The pure
## tick math is covered in test_clock_math.gd; here we drive the live autoload's
## public surface. (Tick accumulation per frame is the thin shell over ClockMath.)

var _saved_speed: float


func before_each() -> void:
	_saved_speed = SimClock.get_speed()
	SimClock.set_speed(1.0)


func after_each() -> void:
	# Leave the live autoload as we found it.
	SimClock._focus_auto_paused = false
	SimClock.set_speed(_saved_speed)


func test_defaults_to_running() -> void:
	assert_false(SimClock.is_paused(), "clock runs at 1x by default")
	assert_eq(SimClock.get_speed(), 1.0, "default speed is 1x")


func test_speed_up_steps_and_caps() -> void:
	SimClock.speed_up()
	assert_eq(SimClock.get_speed(), 2.0, "1x -> 2x")
	SimClock.speed_up()
	assert_eq(SimClock.get_speed(), 4.0, "2x -> 4x")
	SimClock.speed_up()
	assert_eq(SimClock.get_speed(), 4.0, "4x is the cap")


func test_speed_down_steps_and_floors_at_paused() -> void:
	SimClock.set_speed(2.0)
	SimClock.speed_down()
	assert_eq(SimClock.get_speed(), 1.0, "2x -> 1x")
	SimClock.speed_down()
	assert_eq(SimClock.get_speed(), 0.0, "1x -> paused (floor)")
	SimClock.speed_down()
	assert_eq(SimClock.get_speed(), 0.0, "paused is the floor")


func test_toggle_pause_restores_last_running_speed() -> void:
	SimClock.set_speed(4.0)
	SimClock.toggle_pause()
	assert_true(SimClock.is_paused(), "toggling from running pauses")
	SimClock.toggle_pause()
	assert_eq(SimClock.get_speed(), 4.0, "toggling back restores the prior 4x")


func test_set_speed_emits_signal() -> void:
	watch_signals(EventBus)
	SimClock.set_speed(2.0)
	assert_signal_emitted(EventBus, "sim_speed_changed", "speed change announces on the bus")


func test_focus_loss_auto_pauses_and_restores() -> void:
	SimClock.set_speed(2.0)
	SimClock._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	assert_true(SimClock.is_paused(), "losing focus auto-pauses (CONVENTIONS.md)")
	SimClock._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_eq(SimClock.get_speed(), 2.0, "regaining focus restores the prior speed")


func test_focus_loss_leaves_manual_pause_untouched() -> void:
	SimClock.set_speed(0.0)  # player chose to pause
	SimClock._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	SimClock._notification(Node.NOTIFICATION_APPLICATION_FOCUS_IN)
	assert_true(SimClock.is_paused(), "a manual pause is not auto-resumed by focus")
