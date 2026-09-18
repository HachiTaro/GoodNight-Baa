extends Control
const UI = preload("res://scripts/presentation/ui_factory.gd")
var app: Control
var panel: MarginContainer

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	var shade := ColorRect.new()
	shade.color = Color(0.08, 0.14, 0.1, 0.65)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	gui_input.connect(func(_event: InputEvent): accept_event())
	hide()

func open(kind: String) -> void:
	if is_instance_valid(panel):
		remove_child(panel)
		panel.queue_free()
	panel = MarginContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		panel.add_theme_constant_override("margin_" + side, 32)
	add_child(panel)
	var background := PanelContainer.new()
	panel.add_child(background)
	var layout := VBoxContainer.new()
	background.add_child(layout)
	var close := UI.button(layout, "Close", "common.close" if kind == "settings" else "common.cancel", app.close_modal)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	layout.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	if kind == "settings":
		var settings := preload("res://scenes/ui/Settings.tscn").instantiate()
		settings.app = app
		column.add_child(settings)
	else:
		UI.label(column, "confirm.title", {}, 30)
		UI.label(column, "confirm.restart")
		UI.button(column, "ConfirmRestart", "confirm.accept", func():
			app.close_modal()
			app.session.start_new_run())
	show()
	close.grab_focus()

