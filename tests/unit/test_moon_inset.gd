extends GutTest
## Focus inset (ADR 0022): opens on a moon-bearing planet, lists its moons, and a
## moon click targets it. Presentation node; we exercise its focus logic + build.

var _inset: MoonInsetView


func before_each() -> void:
	GameState.system.system_id = "sol"
	_inset = MoonInsetView.new()
	add_child_autofree(_inset)
	_inset.build(TypeRegistry.get_system("sol"))


func test_builds_hidden() -> void:
	assert_not_null(_inset)
	assert_false(_inset.visible, "inset starts closed")


func test_focusing_a_moon_bearing_planet_opens_with_its_moons() -> void:
	EventBus.nav_focus_requested.emit("verdant")  # Verdant has the moon Cinder
	assert_true(_inset.visible, "inset opens on a moon-bearing planet")
	assert_false(_inset._moons.is_empty(), "its moons are listed")


func test_focusing_a_moonless_planet_does_not_open() -> void:
	EventBus.nav_focus_requested.emit("rubicon")  # no moons
	assert_false(_inset.visible, "nothing to focus -> stays closed")


func test_close_hides_and_announces() -> void:
	EventBus.nav_focus_requested.emit("verdant")
	watch_signals(EventBus)
	_inset._close()
	assert_false(_inset.visible, "closed")
	assert_signal_emitted(EventBus, "nav_focus_closed", "close announced on the bus")
