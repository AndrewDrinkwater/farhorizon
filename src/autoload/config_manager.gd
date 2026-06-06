extends Node
## ConfigManager — player settings, separate from save games (ADR 0011).
##
## Persists to user://settings.cfg via ConfigFile. Holds settings only (never
## run state). Settings survive across different saves. Input remapping will
## live here later; named input actions are defined in Project Settings.

const CONFIG_PATH: String = "user://settings.cfg"

## Section -> { key: default }. Add new settings here with a sensible default.
const DEFAULTS: Dictionary = {
	"display": {
		"fullscreen": false,
	},
	"audio": {
		"master_volume": 1.0,
	},
	"gameplay": {
		"default_sim_speed": 1.0,
		"pause_on_focus_loss": true,
	},
	"accessibility": {
		"colorblind_safe": true,
		"high_contrast": false,
	},
	"localization": {
		"locale": "en",
	},
}

var _config: ConfigFile = ConfigFile.new()


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var err: int = _config.load(CONFIG_PATH)
	if err != OK:
		# First run (or unreadable): write defaults out.
		save_settings()


func save_settings() -> void:
	for section: String in DEFAULTS:
		var keys: Dictionary = DEFAULTS[section]
		for key: String in keys:
			if not _config.has_section_key(section, key):
				_config.set_value(section, key, keys[key])
	_config.save(CONFIG_PATH)


func get_setting(section: String, key: String) -> Variant:
	var fallback: Variant = null
	if DEFAULTS.has(section) and DEFAULTS[section].has(key):
		fallback = DEFAULTS[section][key]
	return _config.get_value(section, key, fallback)


func set_setting(section: String, key: String, value: Variant) -> void:
	_config.set_value(section, key, value)
	_config.save(CONFIG_PATH)
	EventBus.settings_changed.emit("%s/%s" % [section, key])
