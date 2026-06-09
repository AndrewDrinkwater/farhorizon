extends GutTest
## Console shell (ADR 0031): hosts multiple consoles, shows one at a time, switches
## cleanly and emits console_changed. Snapshots GameState.

var _snapshot: Dictionary
var _shell: ConsoleShell


func before_each() -> void:
	_snapshot = GameState.to_dict()
	GameState.system.system_id = "sol"
	GameState.ship = ShipState.new()
	GameState.clock.speed = 0.0
	_shell = ConsoleShell.new()
	add_child_autofree(_shell)


func after_each() -> void:
	GameState.from_dict(_snapshot)


func test_registers_helm_and_ship() -> void:
	assert_true(_shell._consoles.has("helm"), "Helm registered")
	assert_true(_shell._consoles.has("ship"), "Ship/Engineering registered")


func test_shows_exactly_one_console() -> void:
	var visible_count := 0
	for id: String in _shell._consoles:
		if _shell._consoles[id].visible:
			visible_count += 1
	assert_eq(visible_count, 1, "exactly one console is shown at a time")


func test_switching_emits_and_swaps() -> void:
	_shell._activate("helm")
	watch_signals(EventBus)
	_shell._activate("ship")
	assert_signal_emitted(EventBus, "console_changed", "switching announces the new console")
	assert_true(_shell._consoles["ship"].visible, "Ship now shown")
	assert_false(_shell._consoles["helm"].visible, "Helm hidden")
	assert_eq(_shell.active_console(), "ship")


func test_cycle_wraps_through_order() -> void:
	_shell._activate(_shell._order[0])
	for _i in range(_shell._order.size()):
		var before := _shell.active_console()
		var idx := _shell._order.find(before)
		_shell._activate(_shell._order[(idx + 1) % _shell._order.size()])
		assert_ne(_shell.active_console(), before, "cycling moves to a different console")
	assert_eq(_shell.active_console(), _shell._order[0], "a full cycle returns to the start")
