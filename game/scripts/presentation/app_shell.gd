extends Control
const Session = preload("res://scripts/application/session_controller.gd")
const Audio = preload("res://scripts/presentation/audio_service.gd")
const UI = preload("res://scripts/presentation/ui_factory.gd")
const Modal = preload("res://scenes/ui/ModalHost.tscn")
const PAGES = {
	"home": preload("res://scenes/app/Home.tscn"),
	"map": preload("res://scenes/app/LevelMap.tscn"),
	"ranch": preload("res://scenes/world/Ranch.tscn"),
	"town": preload("res://scenes/world/Town.tscn")
}
var session: Node
var audio: Node
var page_host: Control
var current_page: Control
var modal: Control
var settings_path_override := ""
var previous_focus: Control

func _ready() -> void:
	theme = UI.create_theme()
	session = Session.new()
	session.name = "SessionController"
	if not settings_path_override.is_empty():
		session.settings_path = settings_path_override
	add_child(session)
	audio = Audio.new()
	audio.name = "AudioService"
	add_child(audio)
	audio.apply_settings(session.settings)
	session.settings_changed.connect(_apply_settings)
	page_host = Control.new()
	page_host.name = "PageHost"
	page_host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(page_host)
	modal = Modal.instantiate()
	modal.app = self
	add_child(modal)
	session.page_changed.connect(_show_page)
	_show_page("home")

func _show_page(page: String) -> void:
	if is_instance_valid(current_page):
		page_host.remove_child(current_page)
		current_page.queue_free()
	current_page = PAGES[page].instantiate()
	current_page.app = self
	page_host.add_child(current_page)
	print("S01 PAGE=", page)

func request_new_run() -> void:
	if session.modal_open:
		return
	if session.run.is_empty():
		session.start_new_run()
	else:
		open_modal("restart")

func open_modal(kind: String = "settings") -> void:
	if session.modal_open:
		return
	previous_focus = get_viewport().gui_get_focus_owner()
	session.modal_open = true
	for control in current_page.find_children("*", "Control", true, false):
		control.set_meta("previous_focus_mode", control.focus_mode)
		control.focus_mode = Control.FOCUS_NONE
	modal.open(kind)

func close_modal() -> void:
	modal.hide()
	session.modal_open = false
	audio.stop_previews()
	for control in current_page.find_children("*", "Control", true, false):
		if control.has_meta("previous_focus_mode"):
			control.focus_mode = control.get_meta("previous_focus_mode")
	if is_instance_valid(previous_focus) and previous_focus.is_visible_in_tree():
		previous_focus.grab_focus()

func _apply_settings() -> void:
	audio.apply_settings(session.settings)
	if current_page != null and current_page.world != null:
		if session.settings.reduced_motion:
			current_page.world.feedback(true)

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		if session.modal_open:
			close_modal()
		else:
			open_modal()
		get_viewport().set_input_as_handled()
