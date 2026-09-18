extends SubViewportContainer
var town := false
var visual: Node3D
var motion: Tween

func _ready() -> void:
	stretch = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	custom_minimum_size.y = 180
	size_flags_vertical = Control.SIZE_EXPAND_FILL
	var viewport := SubViewport.new()
	viewport.size = Vector2i(600, 260)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	add_child(viewport)
	var world := Node3D.new()
	viewport.add_child(world)
	var camera := Camera3D.new()
	camera.projection = Camera3D.PROJECTION_ORTHOGONAL
	camera.size = 7
	world.add_child(camera)
	camera.position = Vector3(5, 5, 6)
	camera.look_at(Vector3.ZERO)
	var light := DirectionalLight3D.new()
	light.rotation_degrees = Vector3(-55, -30, 0)
	world.add_child(light)
	var environment := WorldEnvironment.new()
	environment.environment = Environment.new()
	environment.environment.background_mode = Environment.BG_COLOR
	environment.environment.background_color = Color("dce5cc")
	environment.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.environment.ambient_light_color = Color.WHITE
	environment.environment.ambient_light_energy = 0.6
	world.add_child(environment)
	_mesh(world, Vector3(5, 0.2, 3), Vector3(0, -0.2, 0), Color("a3b681"))
	visual = Node3D.new()
	visual.name = "VisualRoot"
	world.add_child(visual)
	if town:
		_mesh(visual, Vector3(1.8, 1.4, 1.2), Vector3(0, 0.6, 0), Color("c9b594"))
		_mesh(visual, Vector3(2.1, 0.25, 1.5), Vector3(0, 1.4, 0), Color("577154"))
		_mesh(visual, Vector3(0.5, 0.8, 0.1), Vector3(0, 0.3, 0.65), Color("6e694b"))
	else:
		for x in [-0.8, 0.8]:
			_mesh(visual, Vector3(0.65, 0.5, 0.9), Vector3(x, 0.4, 0), Color("fff8df"))
			_mesh(visual, Vector3(0.4, 0.4, 0.4), Vector3(x, 0.6, 0.5), Color("a1997d"))

func feedback(reduced: bool) -> void:
	if motion:
		motion.kill()
	visual.position.y = 0
	if not reduced:
		motion = create_tween()
		motion.tween_property(visual, "position:y", 0.18, 0.12)
		motion.tween_property(visual, "position:y", 0.0, 0.18)

func _mesh(parent: Node3D, dimensions: Vector3, location: Vector3, color: Color) -> void:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = dimensions
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	mesh.material = material
	instance.mesh = mesh
	instance.position = location
	parent.add_child(instance)
