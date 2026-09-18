extends SceneTree

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var boot = load("res://scenes/app/S00Probe.tscn").instantiate()
	root.add_child(boot)
	await process_frame
	if boot.count != 0 or boot.test_button.text != "开始测试":
		_fail("Initial count or Chinese button text mismatch")
		return
	for i in range(3):
		boot.test_button.pressed.emit()
	if boot.count != 3 or boot.counter.text != "点击次数：3":
		_fail("Three pressed signals must display count 3")
		return
	boot.free()
	var fresh = load("res://scenes/app/S00Probe.tscn").instantiate()
	root.add_child(fresh)
	await process_frame
	if fresh.count != 0:
		_fail("Fresh scene must reset count")
		return
	print("S00 PASS: initial Chinese text, three button signals, fresh scene reset (3 checks)")
	fresh.free()
	quit(0)

func _fail(message: String) -> void:
	push_error("S00 FAIL: " + message)
	quit(1)

