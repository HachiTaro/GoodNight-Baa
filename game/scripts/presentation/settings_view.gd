extends VBoxContainer
const UI = preload("res://scripts/presentation/ui_factory.gd")
var app: Control
var status_label: Label

func _ready() -> void:
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_settings(self)

func _settings(column: VBoxContainer) -> void:
	UI.label(column, "settings.title", {}, 30)
	for key in ["master", "music", "sfx"]:
		var value_label := UI.label(column, "settings." + key, {"value": roundi(app.session.settings[key] * 100)})
		var slider := HSlider.new()
		slider.name = key.capitalize() + "Slider"
		slider.min_value = 0
		slider.max_value = 100
		slider.step = 1
		slider.value = app.session.settings[key] * 100
		slider.custom_minimum_size.y = 44
		slider.value_changed.connect(func(value: float):
			app.session.update_setting(key, value / 100.0)
			value_label.text = UI.Text.format("settings." + key, {"value": roundi(value)})
			_refresh_status())
		column.add_child(slider)
	var reduced := CheckButton.new()
	reduced.name = "ReducedMotion"
	reduced.text = UI.Text.format("settings.reduced_motion")
	reduced.button_pressed = app.session.settings.reduced_motion
	reduced.custom_minimum_size.y = 48
	reduced.toggled.connect(func(value: bool):
		app.session.update_setting("reduced_motion", value)
		_refresh_status())
	column.add_child(reduced)
	UI.label(column, "settings.preview_hint", {}, 16)
	var row := HFlowContainer.new()
	column.add_child(row)
	UI.button(row, "PreviewMusic", "settings.preview_music", func(): app.audio.preview("music"))
	UI.button(row, "PreviewSfx", "settings.preview_sfx", func(): app.audio.preview("sfx"))
	status_label = UI.label(column, "settings.saved")
	_refresh_status()
	UI.button(column, "SettingsHome", "common.home", func():
		app.close_modal()
		app.session.navigate("home"))

func _refresh_status() -> void:
	status_label.text = UI.Text.format("settings.saved" if app.session.settings_saved else "settings.failed")
