extends Control

const TextCatalog = preload("res://scripts/presentation/text_catalog.gd")
const CHINESE_FONT = preload("res://assets/fonts/NotoSansCJKsc-Regular.otf")
var count: int = 0
var counter: Label
var test_button: Button

func _ready() -> void:
	var ui_theme := Theme.new()
	ui_theme.default_font = CHINESE_FONT
	ui_theme.default_font_size = 22
	ui_theme.set_color("font_color", "Label", Color("344c40"))
	theme = ui_theme
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", _box(Color("fffcf1"), Color("c4cdb2"), 36))
	center.add_child(card)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 18)
	card.add_child(column)
	_label(column, "s00.stage", 18)
	_label(column, "s00.title", 48)
	_label(column, "s00.subtitle", 24)
	counter = _label(column, "s00.count", 30, {"count": count})
	counter.name = "Counter"
	test_button = Button.new()
	test_button.name = "StartTest"
	test_button.text = TextCatalog.format("s00.start")
	test_button.custom_minimum_size = Vector2(280, 64)
	test_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	test_button.add_theme_color_override("font_color", Color("ffffff"))
	test_button.add_theme_color_override("font_hover_color", Color("ffffff"))
	test_button.add_theme_color_override("font_pressed_color", Color("ffffff"))
	test_button.add_theme_stylebox_override("normal", _box(Color("476b50"), Color("476b50"), 12))
	test_button.add_theme_stylebox_override("hover", _box(Color("557d5c"), Color("557d5c"), 12))
	test_button.add_theme_stylebox_override("pressed", _box(Color("344c40"), Color("344c40"), 12))
	var focus := _box(Color(0, 0, 0, 0), Color("bb8c43"), 0)
	focus.set_border_width_all(3)
	test_button.add_theme_stylebox_override("focus", focus)
	test_button.pressed.connect(_on_test_pressed)
	column.add_child(test_button)
	_label(column, "s00.hint", 20)
	_label(column, "s00.footer", 18)
	test_button.grab_focus()
	print("S00 READY count=0")

func _on_test_pressed() -> void:
	count += 1
	counter.text = TextCatalog.format("s00.count", {"count": count})
	print("S00 COUNT=", count)

func _label(parent: Node, key: String, size: int, params: Dictionary = {}) -> Label:
	var label := Label.new()
	label.text = TextCatalog.format(key, params)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", size)
	parent.add_child(label)
	return label

func _box(fill: Color, border: Color, padding: float) -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = fill
	box.border_color = border
	box.set_border_width_all(1)
	box.set_corner_radius_all(16)
	box.content_margin_left = padding
	box.content_margin_right = padding
	box.content_margin_top = padding
	box.content_margin_bottom = padding
	return box
