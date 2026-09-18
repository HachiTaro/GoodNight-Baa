extends RefCounted
const Text = preload("res://scripts/presentation/text_catalog.gd")
const FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")

static func box(color: Color, padding: float = 16.0) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = color
	style.set_corner_radius_all(12)
	style.content_margin_left = padding
	style.content_margin_right = padding
	style.content_margin_top = padding
	style.content_margin_bottom = padding
	return style

static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font = FONT
	result.default_font_size = 20
	result.set_color("font_color", "Label", Color("304c3c"))
	result.set_stylebox("panel", "PanelContainer", box(Color("fffcf1")))
	for state in ["normal", "hover", "pressed", "disabled"]:
		var colors := {"normal": "476b50", "hover": "5e825d", "pressed": "304c3c", "disabled": "d1d5c8"}
		result.set_stylebox(state, "Button", box(Color(colors[state]), 12))
		result.set_color("font_" + state + "_color", "Button", Color("ffffff") if state != "disabled" else Color("56614f"))
	result.set_color("font_color", "Button", Color.WHITE)
	var focus := box(Color.TRANSPARENT, 0)
	focus.border_color = Color("bd883b")
	focus.set_border_width_all(3)
	result.set_stylebox("focus", "Button", focus)
	result.set_constant("separation", "VBoxContainer", 12)
	result.set_constant("separation", "HBoxContainer", 12)
	return result

static func label(parent: Node, key: String, params: Dictionary = {}, font_size: int = 20) -> Label:
	var result := Label.new()
	result.text = Text.format(key, params)
	result.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	result.add_theme_font_size_override("font_size", font_size)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(result)
	return result

static func button(parent: Node, id: String, key: String, action: Callable, disabled: bool = false) -> Button:
	var result := Button.new()
	result.name = id
	result.text = Text.format(key)
	result.custom_minimum_size.y = 48
	result.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	result.disabled = disabled
	if action.is_valid():
		result.pressed.connect(action)
	parent.add_child(result)
	return result
