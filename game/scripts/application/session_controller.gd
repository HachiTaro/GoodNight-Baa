extends Node
## Owns the in-memory session; changing a view never creates a new run.
signal page_changed(page: String)
signal session_changed
signal settings_changed

const DEFAULT_SETTINGS = {"master": 0.8, "music": 0.6, "sfx": 0.8, "reduced_motion": false}
var settings: Dictionary = DEFAULT_SETTINGS.duplicate()
var settings_path := "user://settings_v1.cfg"
var settings_saved := true
var page := "home"
var modal_open := false
var run: Dictionary = {}
var run_sequence := 0

func _ready() -> void:
	load_settings()

func has_save() -> bool:
	# S08 will supply a validated save, not merely a settings file.
	return false

func can_enter_level(level: int) -> bool:
	return level == 1

func start_new_run() -> bool:
	if modal_open:
		return false
	run_sequence += 1
	run = {"run_id": run_sequence, "level_id": 1, "pet_count": 0}
	session_changed.emit()
	return navigate("ranch")

func navigate(destination: String) -> bool:
	if modal_open or destination not in ["home", "map", "ranch", "town"]:
		return false
	if destination in ["ranch", "town"] and run.is_empty():
		return false
	page = destination
	page_changed.emit(page)
	return true

func pet_sheep() -> bool:
	if modal_open or page != "ranch" or run.is_empty():
		return false
	run.pet_count += 1
	session_changed.emit()
	return true

func update_setting(key: String, value: Variant) -> bool:
	if key not in DEFAULT_SETTINGS:
		return false
	if key == "reduced_motion":
		if not value is bool:
			return false
	else:
		if not (value is float or value is int) or not is_finite(float(value)):
			return false
		value = clampf(float(value), 0.0, 1.0)
	settings[key] = value
	var config := ConfigFile.new()
	config.set_value("settings", "schema_version", 1)
	for item in settings:
		config.set_value("settings", item, settings[item])
	settings_saved = config.save(settings_path) == OK
	settings_changed.emit()
	return true

func load_settings() -> void:
	settings = DEFAULT_SETTINGS.duplicate()
	var config := ConfigFile.new()
	var result := config.load(settings_path)
	settings_saved = result in [OK, ERR_FILE_NOT_FOUND]
	if result == OK:
		if config.get_value("settings", "schema_version", 0) != 1:
			settings_saved = false
			return
		for key in DEFAULT_SETTINGS:
			var value: Variant = config.get_value("settings", key, DEFAULT_SETTINGS[key])
			if key == "reduced_motion" and value is bool:
				settings[key] = value
			elif key != "reduced_motion" and (value is float or value is int) and is_finite(float(value)):
				settings[key] = clampf(float(value), 0.0, 1.0)
			else:
				settings_saved = false
