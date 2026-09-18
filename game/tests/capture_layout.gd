extends SceneTree

func _initialize() -> void:
	call_deferred("capture")

func capture() -> void:
	var app = load("res://scenes/app/Boot.tscn").instantiate()
	app.settings_path_override = "user://s01_layout_probe.cfg"
	root.add_child(app)
	app.session.start_new_run()
	for i in 12:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/s01-ranch-960.png")
	app.open_modal()
	for i in 6:
		await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://docs/s01-settings-960.png")
	print("S01 native capture window=", root.size, " logical=", root.get_visible_rect().size)
	app.free()
	quit()
