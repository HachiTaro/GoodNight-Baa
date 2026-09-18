extends Control
const UI = preload("res://scripts/presentation/ui_factory.gd")
const World = preload("res://scripts/presentation/placeholder_world.gd")
@export var page_id := "home"
var app: Control
var body: VBoxContainer
var world: SubViewportContainer
var pet_label: Label

func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	add_child(margin)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	margin.add_child(scroll)
	body = VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.add_child(body)
	UI.label(body, "app.stage", {}, 16)
	var header := HBoxContainer.new()
	body.add_child(header)
	var heading := UI.label(header, page_id + ".title", {}, 32)
	heading.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var settings := UI.button(header, "Settings", "settings.open", func(): app.open_modal())
	settings.size_flags_horizontal = Control.SIZE_SHRINK_END
	if page_id == "map":
		UI.button(header, "Home", "common.home", func(): app.session.navigate("home"))
	UI.label(body, page_id + ".intro")
	match page_id:
		"home": _home()
		"map": _map()
		"ranch": _ranch()
		"town": _town()
	var first := find_child("Start", true, false) if page_id == "home" else settings
	if first:
		first.grab_focus()

func _home() -> void:
	UI.button(body, "Start", "home.start", app.request_new_run)
	UI.button(body, "Continue", "home.continue", Callable(), not app.session.has_save())
	UI.label(body, "home.no_save")
	if not app.session.run.is_empty():
		UI.button(body, "Resume", "home.resume", func(): app.session.navigate("ranch"))
	UI.button(body, "Map", "common.map", func(): app.session.navigate("map"))
	UI.label(body, "home.scope")

func _map() -> void:
	for level in range(1, 9):
		var card := PanelContainer.new()
		body.add_child(card)
		var column := VBoxContainer.new()
		card.add_child(column)
		UI.label(column, "map.level", {"number": level, "title": UI.Text.format("level.%02d" % level)}, 22)
		UI.label(column, "map.no_stars")
		if level > 2:
			UI.label(column, "map.candidate", {}, 16)
		if not app.session.can_enter_level(level):
			UI.label(column, "map.locked", {"previous": level - 1}, 16)
		var entry := UI.button(column, "Level%d" % level, "map.enter", app.request_new_run, not app.session.can_enter_level(level))
		if level == 1 and not app.session.run.is_empty():
			entry.text = UI.Text.format("map.restart")
	if not app.session.run.is_empty():
		UI.button(body, "Resume", "home.resume", func(): app.session.navigate("ranch"))

func _ranch() -> void:
	UI.label(body, "ranch.request")
	world = World.new()
	body.add_child(world)
	pet_label = UI.label(body, "ranch.pets", {"count": app.session.run.pet_count})
	pet_label.name = "PetCount"
	UI.button(body, "Pet", "ranch.pet", _pet)
	var row := HFlowContainer.new()
	body.add_child(row)
	UI.button(row, "Town", "ranch.town", func(): app.session.navigate("town"))
	UI.button(row, "Plan", "ranch.plan_disabled", Callable(), true)
	UI.button(row, "Night", "ranch.night_disabled", Callable(), true)
	UI.button(row, "Map", "common.map", func(): app.session.navigate("map"))
	UI.button(row, "Home", "common.home", func(): app.session.navigate("home"))
	UI.label(body, "ranch.pending", {}, 16)
	app.session.session_changed.connect(_refresh_pets)

func _pet() -> void:
	if app.session.pet_sheep():
		world.feedback(app.session.settings.reduced_motion)
		app.audio.preview("sfx")

func _refresh_pets() -> void:
	pet_label.text = UI.Text.format("ranch.pets", {"count": app.session.run.pet_count})

func _town() -> void:
	world = World.new()
	world.town = true
	body.add_child(world)
	UI.button(body, "Shop", "town.shop_disabled", Callable(), true)
	UI.label(body, "town.pending")
	UI.button(body, "Ranch", "town.ranch", func(): app.session.navigate("ranch"))
	UI.button(body, "Home", "common.home", func(): app.session.navigate("home"))
