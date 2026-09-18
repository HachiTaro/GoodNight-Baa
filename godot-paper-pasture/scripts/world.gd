extends Node2D
const Rules=preload("res://scripts/rules.gd")
signal stroke_started
signal paint_cell(cell: Vector2i,erase: bool)
signal sheep_touched(index: int,point: Vector2)
var game: RefCounted
var planning := false
var input_enabled := true
var reduced_motion := false
var erase_mode := false
var night_amount := 0.0
var origin := Vector2.ZERO
var zoom := 1.0
var hover := Vector2i(-99,-99)
var dragging := false
var drag_erase := false
var last_point := Vector2.ZERO
var clock := 0.0
var bank: Node2D
var actors: Node2D
var sheep_nodes: Array[Sprite2D]=[]
var sheep_origins: Array[Vector2]=[]
var wolf: Sprite2D
var night_path: Array=[]
var night_duration := 10.0
var night_elapsed := 0.0
var show_wolf := false
var failed_sheep := -1
var plus: Node2D
var minus: Node2D
var focus_cells: Dictionary={}

func _ready() -> void:
	bank=preload("res://scenes/planning.tscn").instantiate()
	plus=_template(735,741,Vector2(771,354))
	minus=_template(742,748,Vector2(771,354))
	actors=Node2D.new(); actors.name="ActorsAndFences"; add_child(actors)

func _template(first: int,last: int,zero: Vector2) -> Node2D:
	var n:=Node2D.new()
	for id in range(first,last+1):
		var s:=bank.get_node("Art_56_%d"%id).duplicate() as Sprite2D
		s.position-=zero; n.add_child(s)
	return n

func configure(session: RefCounted,editing: bool) -> void:
	game=session; planning=editing
	var w: int=game.level.grid[0].length(); var h: int=game.level.grid.size()
	zoom=minf(1.55,960.0/((w+h)*49))
	origin=Vector2(940-(w-h)*49*zoom/2,510-(w+h)*25*zoom/2)
	night_amount=0; show_wolf=false; focus_cells={}
	refresh()

func iso(p: Vector2) -> Vector2:
	return origin+Vector2((p.x-p.y)*49,(p.x+p.y)*25)*zoom

func at(point: Vector2) -> Vector2i:
	var d: Vector2=(point-origin)/zoom
	return Vector2i(floori((d.x/49+d.y/25)/2),floori((d.y/25-d.x/49)/2))

func diamond(p: Vector2i) -> PackedVector2Array:
	return PackedVector2Array([iso(Vector2(p)),iso(Vector2(p)+Vector2(1,0)),iso(Vector2(p)+Vector2(1,1)),iso(Vector2(p)+Vector2(0,1))])

func _art(id: int,point: Vector2,scale_factor: float=1.0) -> Sprite2D:
	var s:=bank.get_node("Art_56_%d"%id).duplicate() as Sprite2D
	var sz: Vector2=s.texture.get_size()*s.scale
	s.position=point-Vector2(sz.x/2,sz.y)*zoom*scale_factor
	s.scale*=zoom*scale_factor
	s.z_index=int(point.y)
	actors.add_child(s)
	return s

func refresh() -> void:
	if not game or not actors: return
	for n in actors.get_children(): actors.remove_child(n); n.queue_free()
	sheep_nodes.clear(); sheep_origins.clear(); wolf=null
	var level: Dictionary=game.level
	var cells: Dictionary=game.draft if planning else game.built
	for y in level.grid.size():
		for x in level.grid[y].length():
			var p:=Vector2i(x,y)
			var kind:=Rules.cell(level,p)
			var center:=iso(Vector2(p)+Vector2(0.5,0.5))
			if kind in ["g","S"]: _art(687,center+Vector2(14,6)*zoom,0.7)
			if kind=="#": _art(791,center+Vector2(0,13)*zoom,0.78)
			if kind=="H": _art(1048,center+Vector2(0,12)*zoom,0.8)
	for p: Vector2i in Rules.sheep(level):
		var sheep:=_art(905,iso(Vector2(p)+Vector2(0.5,0.5))+Vector2(0,14)*zoom,0.76)
		sheep_nodes.append(sheep); sheep_origins.append(sheep.position)
	for edge in Rules.boundary(level,cells):
		if edge.water: continue
		var point:=iso(Vector2(edge.cell)); var positive:=true
		if edge.dir==Vector2i(1,0): point+=Vector2(49,25)*zoom; positive=false
		elif edge.dir==Vector2i(0,1): point+=Vector2(-49,25)*zoom
		elif edge.dir==Vector2i(-1,0): positive=false
		var segment: Node2D=(plus if positive else minus).duplicate()
		segment.position=point; segment.scale=Vector2.ONE*zoom
		segment.z_index=int(point.y+25*zoom)
		if planning: segment.modulate.a=0.72
		actors.add_child(segment)
	# Trees are decorations outside the playable grid, never hidden obstacles.
	var w: int=level.grid[0].length(); var h: int=level.grid.size()
	for tree in [Vector2(0,-0.65),Vector2(2,-0.65),Vector2(w-1,-0.65),Vector2(-0.6,h-1),Vector2(w+0.4,h-1)]:
		_art(809,iso(tree),0.66)
	queue_redraw()

func _draw() -> void:
	if not game: return
	var level: Dictionary=game.level
	var w: int=level.grid[0].length(); var h: int=level.grid.size()
	var ground: Color=Color("afc681").lerp(Color("4f7060"),night_amount)
	var corners:=PackedVector2Array([iso(Vector2.ZERO),iso(Vector2(w,0)),iso(Vector2(w,h)),iso(Vector2(0,h))])
	var depth:=Vector2(0,27*zoom)
	draw_set_transform(Vector2(950,650),0,Vector2(1,0.28))
	draw_circle(Vector2.ZERO,440,Color(0.25,0.36,0.23,0.10))
	draw_set_transform(Vector2.ZERO)
	draw_colored_polygon(PackedVector2Array([corners[1],corners[2],corners[2]+depth,corners[1]+depth]),Color("93966b").lerp(Color("324e50"),night_amount))
	draw_colored_polygon(PackedVector2Array([corners[2],corners[3],corners[3]+depth,corners[2]+depth]),Color("aaa878").lerp(Color("3e5d59"),night_amount))
	var cells: Dictionary=game.draft if planning else game.built
	for y in h:
		for x in w:
			var p:=Vector2i(x,y); var points:=diamond(p); var kind:=Rules.cell(level,p)
			var fill:=ground.lightened(0.045 if (x+y)%2 else 0.0)
			if kind=="W": fill=Color("80bfb4").lerp(Color("47747e"),night_amount)
			elif cells.has(p): fill=Color("bed896").lerp(Color("688268"),night_amount)
			draw_colored_polygon(points,fill)
			var border:=Color(0.94,0.97,0.86,0.50 if planning else 0.18)
			draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),border,1,true)
			if kind=="W":
				var c:=iso(Vector2(p)+Vector2(0.5,0.5))
				draw_line(c-Vector2(14,0)*zoom,c+Vector2(14,0)*zoom,Color(0.8,0.94,0.92,0.55),2,true)
			if focus_cells.has(p): draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color("d9ad59"),3,true)
			if p==hover and planning and input_enabled:
				draw_polyline(PackedVector2Array([points[0],points[1],points[2],points[3],points[0]]),Color("fffbea") if Rules.valid(level,p) else Color("c57263"),3,true)
	# Visible supplementary baskets/troughs do not occupy logical cells.
	var report:=Rules.analyze(level,cells,game.stock())
	for g in report.groups:
		if g.cells.is_empty(): continue
		var center:=iso(Vector2(Rules.ordered(g.cells)[0])+Vector2(0.5,0.5))
		if g.grass>0:
			draw_style_box(_box(Color("bda573")),Rect2(center+Vector2(-24,12),Vector2(21,12)))
		if g.water>0:
			draw_style_box(_box(Color("639b9d")),Rect2(center+Vector2(2,12),Vector2(23,12)))

func _box(color: Color) -> StyleBoxFlat:
	var box:=StyleBoxFlat.new(); box.bg_color=color; box.set_corner_radius_all(3); return box

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and not event.pressed: dragging=false

func _unhandled_input(event: InputEvent) -> void:
	if not visible or not game or not input_enabled: return
	if event is InputEventMouseMotion:
		hover=at(event.position); queue_redraw()
		if dragging and planning:
			var point: Vector2=event.position
			var steps:=maxi(1,ceili(last_point.distance_to(point)/12.0))
			for i in range(1,steps+1): paint_cell.emit(at(last_point.lerp(point,float(i)/steps)),drag_erase)
			last_point=point
	if event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		var point: Vector2=event.position
		if planning and Rules.valid(game.level,at(point)):
			dragging=true; drag_erase=erase_mode or event.button_index==MOUSE_BUTTON_RIGHT
			last_point=point; stroke_started.emit(); paint_cell.emit(at(point),drag_erase)
		else:
			for i in sheep_nodes.size():
				if point.distance_to(iso(Vector2(Rules.sheep(game.level)[i])+Vector2(0.5,0.5)))<45*zoom:
					sheep_touched.emit(i,point)
					if not reduced_motion:
						var tween:=create_tween(); tween.tween_property(sheep_nodes[i],"rotation",-0.12,0.1); tween.tween_property(sheep_nodes[i],"rotation",0.0,0.2)
					return

func start_night(report: Dictionary) -> void:
	input_enabled=false; planning=false; show_wolf=true; night_elapsed=0
	failed_sheep=int(report.wolf.target)
	night_path=report.wolf.path.duplicate() if failed_sheep>=0 else report.wolf.patrol.duplicate()
	if failed_sheep<0:
		var reverse:=night_path.duplicate(); reverse.reverse(); night_path.append_array(reverse)
	wolf=Sprite2D.new()
	var atlas:=AtlasTexture.new(); atlas.atlas=load("res://assets/characters/wolf-sheet.png"); atlas.region=Rect2(565,430,410,270)
	wolf.texture=atlas; wolf.scale=Vector2.ONE*0.22*zoom
	var shader:=Shader.new()
	shader.code="shader_type canvas_item; void fragment(){ vec4 c=texture(TEXTURE,UV); float white=smoothstep(0.91,0.96,min(c.r,min(c.g,c.b))); COLOR=vec4(c.rgb,c.a*(1.0-white)); }"
	var material:=ShaderMaterial.new(); material.shader=shader; wolf.material=material
	actors.add_child(wolf)
	if not night_path.is_empty(): wolf.position=iso(Vector2(night_path[0])+Vector2(0.5,0.5))-Vector2(0,20)*zoom

func _process(delta: float) -> void:
	if not visible or not game: return
	clock+=delta
	if show_wolf:
		night_elapsed+=delta
		night_amount=minf(1,night_elapsed/2.3)
		actors.modulate=Color.WHITE.lerp(Color("b2bfc2"),night_amount*0.5)
		if wolf and not night_path.is_empty():
			var progress:=clampf((night_elapsed-1)/7.5,0,1)*(night_path.size()-1)
			var a:=int(progress); var b:=mini(a+1,night_path.size()-1)
			wolf.position=iso(Vector2(night_path[a]).lerp(Vector2(night_path[b]),progress-a)+Vector2(0.5,0.5))-Vector2(0,22)*zoom
			wolf.z_index=int(wolf.position.y+22*zoom)
			wolf.flip_h=night_path[b].x<night_path[a].x
			if not reduced_motion: wolf.position.y+=sin(clock*7)*1.6
		queue_redraw()
	elif not reduced_motion:
		for i in sheep_nodes.size(): sheep_nodes[i].position=sheep_origins[i]+Vector2(sin(clock*0.7+i)*1.2,sin(clock*1.3+i)*1.3)

func _exit_tree() -> void:
	if bank: bank.free()
	if plus: plus.free()
	if minus: minus.free()
