extends SceneTree
var app: Control
var checks := 0
var failed := 0
var path := "user://s01_test_%s.cfg" % Time.get_ticks_usec()

func _initialize() -> void:
	call_deferred("_run")

func check(ok: bool, description: String) -> void:
	checks += 1
	if ok:
		print("PASS ", description)
	else:
		failed += 1
		push_error("FAIL " + description)

func button(id: String) -> Button:
	return app.current_page.find_child(id, true, false) as Button

func press(id: String) -> void:
	var control := button(id)
	check(control != null and not control.disabled, "available button " + id)
	if control != null and not control.disabled:
		control.pressed.emit()
	await process_frame
	await process_frame

func _run() -> void:
	var probe = load("res://scenes/app/S00Probe.tscn").instantiate()
	root.add_child(probe)
	check(probe.count == 0, "S00 initial zero")
	for i in 3:
		probe.test_button.pressed.emit()
	check(probe.counter.text == "点击次数：3", "S00 three signals still work")
	probe.free()
	root.size = Vector2i(1280, 720)
	app = load("res://scenes/app/Boot.tscn").instantiate()
	app.settings_path_override = path
	root.add_child(app)
	await process_frame
	check(app.session.page == "home", "Boot routes home")
	check(button("Continue").disabled, "no save disables continue")
	check(not app.session.navigate("town"), "town rejects missing run")
	await press("Start")
	check(app.session.page == "ranch", "first start enters ranch")
	check(button("Night").disabled and button("Plan").disabled, "unfinished gameplay disabled")
	await press("Pet")
	var snapshot: Dictionary = app.session.run.duplicate(true)
	await press("Town")
	check(button("Shop").disabled, "unfinished shop disabled")
	await press("Ranch")
	check(app.session.run == snapshot, "ranch town roundtrip preserves session")
	await press("Settings")
	check(app.session.modal_open and app.modal.visible, "settings opens modal")
	check(not app.session.navigate("town") and not app.session.pet_sheep(), "modal rejects application commands")
	check(button("Pet").focus_mode == Control.FOCUS_NONE, "background keyboard focus disabled")
	# Inject real GUI pointer events where the underlying Pet button was located.
	var point := button("Pet").get_global_rect().get_center()
	for down in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = down
		Input.parse_input_event(event)
		await process_frame
	check(app.session.run == snapshot, "modal pointer does not reach underlying interaction")
	var slider := app.modal.find_child("MusicSlider", true, false) as HSlider
	slider.value = 23
	var reduced := app.modal.find_child("ReducedMotion", true, false) as CheckButton
	reduced.button_pressed = true
	check(is_equal_approx(app.session.settings.music, 0.23), "music slider updates state")
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("Music")), linear_to_db(0.23)), "music bus applies setting")
	app.session.update_setting("master", 0.0)
	check(AudioServer.is_bus_mute(0), "master zero mutes audio")
	app.session.update_setting("sfx", 0.41)
	check(is_equal_approx(AudioServer.get_bus_volume_db(AudioServer.get_bus_index("SFX")), linear_to_db(0.41)), "sfx independent bus")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	Input.parse_input_event(escape)
	await process_frame
	check(not app.session.modal_open, "Escape closes modal")
	check(root.gui_get_focus_owner() == button("Settings"), "modal restores focus")
	await press("Pet")
	check(app.current_page.world.visual.position.y == 0, "reduced motion keeps visual stationary")
	await press("Map")
	for level in range(2, 9):
		check(button("Level%d" % level).disabled and not app.session.can_enter_level(level), "locked level %d" % level)
	await press("Home")
	check(button("Continue").disabled, "in-memory session is not a saved game")
	await press("Start")
	check(app.session.modal_open, "existing run requires confirmation")
	var old_id: int = app.session.run.run_id
	app.modal.find_child("Close", true, false).pressed.emit()
	check(app.session.run.run_id == old_id, "cancel restart preserves run")
	await press("Start")
	app.modal.find_child("ConfirmRestart", true, false).pressed.emit()
	await process_frame
	check(app.session.run.run_id != old_id and app.session.run.pet_count == 0, "confirmed restart replaces run")
	check(app.session.settings.reduced_motion, "restart preserves settings")
	for i in 20:
		app.session.navigate("town")
		await process_frame
		app.session.navigate("ranch")
		await process_frame
	check(app.page_host.get_child_count() == 1, "20 roundtrips retain one page")
	check(app.session.session_changed.get_connections().size() == 1, "20 roundtrips no stale subscriptions")
	app.session.settings_path = "user://nonexistent_s01_folder/settings.cfg"
	app.session.update_setting("music", 0.2)
	check(not app.session.settings_saved, "write failure reported")
	app.free()
	await process_frame
	app = load("res://scenes/app/Boot.tscn").instantiate()
	app.settings_path_override = path
	root.add_child(app)
	await process_frame
	check(is_equal_approx(app.session.settings.music, 0.23) and app.session.settings.reduced_motion, "new application restores settings")
	check(app.session.run.is_empty() and button("Continue").disabled, "relaunch does not fake gameplay save")
	for size in [Vector2i(960, 540), Vector2i(1280, 720)]:
		root.size = size
		await process_frame
		await process_frame
		check(button("Start").get_global_rect().end.x <= root.get_visible_rect().size.x, "home fits width %s" % size)
	app.free()
	DirAccess.remove_absolute(path)
	print("S01 RESULT checks=%d failed=%d" % [checks, failed])
	quit(0 if failed == 0 else 1)
