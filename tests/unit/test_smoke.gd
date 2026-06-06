extends GutTest
## Smoke tests — prove the scaffold loads and the foundations are wired.
## Run via the GUT panel (bottom dock) or headless (see SETUP.md).


func test_game_version_is_set() -> void:
	assert_eq(GameVersion.GAME_VERSION, "0.1.0", "GAME_VERSION should be 0.1.0")
	assert_gt(GameVersion.SAVE_SCHEMA_VERSION, 0, "schema version is positive")


func test_autoloads_present() -> void:
	assert_not_null(EventBus, "EventBus autoload loaded")
	assert_not_null(GameState, "GameState autoload loaded")
	assert_not_null(SimClock, "SimClock autoload loaded")
	assert_not_null(SaveManager, "SaveManager autoload loaded")
	assert_not_null(TypeRegistry, "TypeRegistry autoload loaded")
	assert_not_null(ConfigManager, "ConfigManager autoload loaded")


func test_sim_clock_defaults() -> void:
	assert_eq(SimClock.get_tick(), 0, "clock starts at tick 0")
	assert_true(SimClock.SECONDS_PER_TICK > 0.0, "tick duration is positive")


func test_config_manager_returns_defaults() -> void:
	assert_eq(
		ConfigManager.get_setting("accessibility", "colorblind_safe"), true,
		"colourblind-safe defaults on (ADR 0012)"
	)
