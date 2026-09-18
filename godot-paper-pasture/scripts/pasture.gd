extends Node2D
## Exact Figma layers remain editable in the three .tscn scene files.
## Grid coordinates use the source's 98 x 50 isometric diamonds.
const ORIGIN := Vector2(820, 279)
const STEP := Vector2(49, 25)
const DIRS := [Vector2i(1,0), Vector2i(0,1), Vector2i(-1,0), Vector2i(0,-1)]
const SHEEP := [Vector2i(2,3), Vector2i(3,4), Vector2i(5,3), Vector2i(7,3)]
const GRASS := [Vector2i(1,2), Vector2i(2,2), Vector2i(3,2), Vector2i(1,3), Vector2i(5,2), Vector2i(6,2), Vector2i(7,3), Vector2i(6,4)]
const BLOCKED := [Vector2i(3,1), Vector2i(4,1), Vector2i(4,2), Vector2i(0,0), Vector2i(1,0), Vector2i(2,0), Vector2i(7,0), Vector2i(8,0), Vector2i(9,0), Vector2i(0,5), Vector2i(0,6), Vector2i(4,6), Vector2i(6,6), Vector2i(7,6)]
var selected: Dictionary = {}
var committed: Dictionary = {}
var history: Array[Dictionary] = []
var state := 0
var erase := false
var dragging := false
var last_cell := Vector2i(-100,-100)
var coins := 40
var paid := 0
var changed := false
var paused := false
var sound_on := false
var clock_time := 0.0
var layers: Array[Node2D] = []
var previews: Array[Node2D] = []
var fence_layers: Array[Node2D] = []
var fence_plus: Node2D
var fence_minus: Node2D
var tile_texture: Texture2D
var notice: Label
var ui: CanvasLayer
var controls: Array[Control] = []
var overlay: Control
var layer_config: Array

func _ready() -> void:
	layers = [$Planning, $Day, $Night]
	layer_config = JSON.parse_string(FileAccess.get_file_as_string("res://source/runtime-layers.json"))
	tile_texture = $Planning/Art_56_649.texture
	fence_plus = _fence_template(735, 741, Vector2(771,354))
	fence_minus = _fence_template(742, 748, Vector2(771,354))
	for scene in layers:
		var preview := Node2D.new()
		preview.name = "SelectedCells"
		scene.add_child(preview)
		preview.z_index = 1
		previews.append(preview)
		var fences := Node2D.new()
		fences.name = "LiveFences"
		scene.add_child(fences)
		fence_layers.append(fences)
	# Native Godot UI, kept separate from the editable exported artwork.
	ui = CanvasLayer.new()
	add_child(ui)
	notice = _label("", Vector2(410,775), 19)
	notice.size = Vector2(780,45)
	notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	ui.add_child(notice)
	_reset_selection()
	_rebuild_buttons()
	_update_stats()
	if "--verify" in OS.get_cmdline_user_args():
		call_deferred("_verify")

func _fence_template(first: int, last: int, origin: Vector2) -> Node2D:
	var segment := Node2D.new()
	for id in range(first,last+1):
		var art := $Planning.get_node("Art_56_%d" % id).duplicate() as Sprite2D
		art.position -= origin
		segment.add_child(art)
	return segment

func iso(cell: Vector2i) -> Vector2:
	return ORIGIN + Vector2((cell.x-cell.y)*STEP.x,(cell.x+cell.y)*STEP.y)

func cell_at(point: Vector2) -> Vector2i:
	var p := point-ORIGIN
	return Vector2i(floori((p.x/STEP.x+p.y/STEP.y)/2),floori((p.y/STEP.y-p.x/STEP.x)/2))

func water(cell: Vector2i) -> bool:
	return cell.x in [8,9] and cell.y in [2,3,4]

func valid(cell: Vector2i) -> bool:
	return cell.x>=0 and cell.x<10 and cell.y>=0 and cell.y<7 and not water(cell) and cell not in BLOCKED

func _reset_selection() -> void:
	selected.clear()
	for x in [1,2,3,5,6,7]:
		for y in [2,3,4]: selected[Vector2i(x,y)] = true
	selected[Vector2i(4,4)] = true
	committed = selected.duplicate()

func metrics(cells: Dictionary) -> Dictionary:
	var perimeter := 0
	var shore := 0
	var grass := 0
	for cell: Vector2i in cells:
		if cell in GRASS: grass+=1
		for d: Vector2i in DIRS:
			if not cells.has(cell+d):
				perimeter+=1
				if water(cell+d): shore+=1
	return {"area":cells.size(),"perimeter":perimeter,"shore":shore,"fences":perimeter-shore,"grass":grass}

func _label(text: String, pos: Vector2, font_size: int) -> Label:
	var result := Label.new()
	result.text = text
	result.position = pos
	result.add_theme_font_override("font",preload("res://assets/fonts/regular.ttc"))
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",Color("304a42"))
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result

func _button(rect: Rect2, hint: String, action: Callable) -> void:
	var button := Button.new()
	button.position = rect.position
	button.size = rect.size
	button.tooltip_text = hint
	button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	button.add_theme_stylebox_override("normal",StyleBoxEmpty.new())
	var hover := StyleBoxFlat.new()
	hover.bg_color = Color(0.5,0.65,0.4,0.15)
	hover.set_corner_radius_all(16)
	button.add_theme_stylebox_override("hover",hover)
	button.add_theme_stylebox_override("pressed",hover)
	button.pressed.connect(action)
	ui.add_child(button)
	controls.append(button)

func _rebuild_buttons() -> void:
	for control in controls:
		control.queue_free()
	controls.clear()
	_button(Rect2(40,36,50,50),"返回规划 / Esc",_back)
	_button(Rect2(1360,36,67,50),"查看当前账单",_bill)
	_button(Rect2(1443,36,50,50),"暂停 / 继续",_pause)
	_button(Rect2(1505,36,55,50),"声音设置",func(): _message("本场景尚未配置背景音乐。"))
	if state==0:
		_button(Rect2(58,410,62,65),"涂选草地 · 鼠标左键",func(): erase=false; _message("选择模式：按住鼠标拖动涂选草地。"))
		_button(Rect2(58,481,62,74),"擦除草地 · 鼠标右键也可擦除",func(): erase=true; _message("擦除模式：拖动移除选中的草地。"))
		_button(Rect2(1092,900,202,51),"支付围栏费用，进入白天观察",_confirm)
		_button(Rect2(1320,900,80,51),"撤销本次修改",_cancel)
	elif state==1:
		_button(Rect2(49,865,203,66),"重新规划草地",func(): _set_state(0))
		_button(Rect2(49,795,203,54),"查看补给",_supplies)
		_button(Rect2(1300,866,253,66),"让夜晚到来",func(): _set_state(2))
	else:
		_button(Rect2(1415,900,145,55),"结束夜晚，返回白天",func(): _set_state(1))

func _message(text: String) -> void:
	notice.text = text
	notice.add_theme_color_override("font_color",Color("f5efdc") if state==2 else Color("304a42"))

func _set_state(next: int) -> void:
	state = next
	dragging = false
	for i in layers.size(): layers[i].visible = i==state
	_message("")
	_rebuild_buttons()
	_update_stats()

func _pause() -> void:
	paused = not paused
	_message("已暂停，再点暂停按钮继续。" if paused else "")

func _back() -> void:
	if overlay: overlay.queue_free(); overlay=null; return
	if paused: _pause(); return
	_set_state(0)

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE: _back()
		if event.keycode==KEY_Z and event.ctrl_pressed and state==0 and not paused and not overlay: _undo()
	if overlay or paused: return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
			if not event.pressed:
				dragging=false
				return
			var point: Vector2 = get_global_mouse_position()
			if state==0 and valid(cell_at(point)):
				history.append(selected.duplicate())
				dragging=true
				last_cell=Vector2i(-100,-100)
				_paint(cell_at(point),erase or event.button_index==MOUSE_BUTTON_RIGHT)
			elif state!=0:
				for sheep in SHEEP:
					if point.distance_to(iso(sheep)+Vector2(0,15))<65:
						_message("小羊睡得很香，晚安。" if state==2 else "咩～小羊很喜欢这个家！")
	if event is InputEventMouseMotion and dragging and state==0:
		_paint(cell_at(get_global_mouse_position()),erase or Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT))

func _paint(cell: Vector2i, remove: bool) -> void:
	if not valid(cell) or cell==last_cell: return
	last_cell=cell
	if remove: selected.erase(cell)
	else: selected[cell]=true
	changed=true
	_refresh_world()
	_update_stats()
	_message("")

func _undo() -> void:
	if history.is_empty(): return
	selected=history.pop_back()
	changed=true
	_refresh_world()
	_update_stats()

func _cancel() -> void:
	selected=committed.duplicate()
	history.clear()
	changed=true
	_refresh_world()
	_update_stats()
	_message("已恢复上次的围栏规划。")

func _confirm() -> void:
	var m := metrics(selected)
	for sheep in SHEEP:
		if not selected.has(sheep): _message("还有小羊没被圈进来，再检查一下草地吧。 "); return
	if m.area<8 or m.grass<8 or m.shore<1:
		_message("需要至少 8 格空间、8 份牧草，并接到水岸。")
		return
	var cost: int = maxi(0,m.fences-paid)
	if cost>coins: _message("金币不够啦，试试更省围栏的形状。 "); return
	coins-=cost
	paid=maxi(paid,m.fences)
	committed=selected.duplicate()
	history.clear()
	_set_state(1)

func _text(scene: int, id: int, value: String) -> void:
	var node := layers[scene].get_node_or_null("Text_56_%d"%id)
	if node: node.text=value

func _update_stats() -> void:
	var m := metrics(selected)
	var cost: int = maxi(0,m.fences-paid)
	_text(0,1106,str(coins))
	_text(1,1619,str(coins))
	_text(2,2115,str(coins))
	_text(0,1131,"%d / 8 格"%m.area)
	_text(0,1133,"%d / 8 份"%m.grass)
	_text(0,1135,"水岸充足" if m.shore>0 else "还没接到水岸")
	_text(0,1137,"围栏 %d 段 · 余 %d 金币"%[m.fences,coins-cost])
	_text(0,1138,"本次建造 %d 金币"%cost)
	_text(0,1142,"周长 %d − 临水 %d = 围栏 %d"%[m.perimeter,m.shore,m.fences])
	# Imported day frame includes a native button added after the original design.
	if not $Day.has_node("SupplyCaption"):
		var label := _label("去小镇补给 ↗",Vector2(78,811),18)
		label.name="SupplyCaption"
		$Day.add_child(label)

func _clear(node: Node) -> void:
	for child in node.get_children():
		node.remove_child(child)
		child.queue_free()

func _refresh_world() -> void:
	# Reuse the source fence posts/rails and grass tile; do not approximate icons.
	for i in layers.size():
		var scene := layers[i]
		for node_name: String in layer_config[i].fences:
			scene.get_node(node_name).visible=false
		for node_name: String in layer_config[i].selected:
			scene.get_node(node_name).visible=false
		for actor: Array in layer_config[i].actors:
			scene.get_node(actor[0]).z_index=int(actor[1])
		_clear(previews[i])
		_clear(fence_layers[i])
		for cell: Vector2i in selected:
			if i==0:
				var tile := Sprite2D.new()
				tile.texture=tile_texture
				tile.centered=false
				tile.position=iso(cell)-Vector2(49,0)
				previews[i].add_child(tile)
			for d: Vector2i in DIRS:
				if selected.has(cell+d) or water(cell+d): continue
				var start := iso(cell)
				var plus := true
				if d==Vector2i(1,0): start+=Vector2(49,25); plus=false
				elif d==Vector2i(0,1): start+=Vector2(-49,25)
				elif d==Vector2i(-1,0): plus=false
				var segment: Node2D = (fence_plus if plus else fence_minus).duplicate()
				segment.position=start
				segment.z_index=int(start.y+25)
				if i==2: segment.modulate=Color(0.76,0.81,0.73)
				fence_layers[i].add_child(segment)

func _bill() -> void:
	var m := metrics(selected)
	_dialog("牧场账单", "生活面积  %d 格\n数学周长  %d 段\n临水边界  %d 段（计周长，免围栏）\n需要围栏  %d 段\n本次支付  %d 金币\n剩余金币  %d" % [m.area,m.perimeter,m.shore,m.fences,maxi(0,m.fences-paid),coins])

func _supplies() -> void:
	_dialog("牧场补给", "当前草地提供 8 份牧草，水岸提供饮水。\n这份场景暂不包含小镇商店。\n\n可以返回牧场继续选地，或让夜晚到来。")

func _dialog(title: String, body: String) -> void:
	if overlay: return
	overlay=Control.new()
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.add_child(overlay)
	var shade := ColorRect.new()
	shade.color=Color(0.07,0.14,0.12,0.45)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var panel := Panel.new()
	panel.position=Vector2(485,260)
	panel.size=Vector2(630,455)
	var style := StyleBoxFlat.new()
	style.bg_color=Color("fffbea")
	style.set_corner_radius_all(25)
	panel.add_theme_stylebox_override("panel",style)
	overlay.add_child(panel)
	panel.add_child(_label(title,Vector2(38,26),28))
	panel.add_child(_label(body,Vector2(38,92),21))
	var close := Button.new()
	close.position=Vector2(430,372)
	close.size=Vector2(155,48)
	close.text="回到牧场"
	close.add_theme_font_override("font",preload("res://assets/fonts/regular.ttc"))
	close.add_theme_font_size_override("font_size",19)
	close.pressed.connect(func(): overlay.queue_free(); overlay=null)
	panel.add_child(close)

func _process(delta: float) -> void:
	if paused: return
	clock_time+=delta
	# Gentle breathing keeps each sheep independent and the original placement intact.
	var ids := [[905,918,931,944],[1419,1432,1445,1458],[1918,1931,1944,1957]]
	for id: int in ids[state]:
		var sheep := layers[state].get_node_or_null("Art_56_%d"%id) as Sprite2D
		if sheep:
			sheep.modulate.a=0.97+sin(clock_time*1.5+id)*0.03

func _exit_tree() -> void:
	if fence_plus: fence_plus.free()
	if fence_minus: fence_minus.free()

func _verify() -> void:
	var m := metrics(selected)
	assert(m.area==19 and m.perimeter==24 and m.shore==3 and m.fences==21,"Source plan metrics")
	assert(m.grass==8,"Grass coverage")
	assert(cell_at(iso(Vector2i(3,4))+Vector2(0,24))==Vector2i(3,4),"Isometric picking")
	assert(not valid(Vector2i(8,3)),"Water cannot be selected")
	assert(not valid(Vector2i(4,2)),"Rock collision")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/planning.png")
	history.append(selected.duplicate())
	_paint(Vector2i(4,4),true)
	assert(metrics(selected).perimeter==24 and selected.size()==18,"Erase and perimeter")
	_undo()
	assert(selected.size()==19,"Undo")
	_confirm()
	assert(state==1 and coins==19,"Confirm and payment")
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/day.png")
	_set_state(0)
	_confirm()
	assert(coins==19,"Unchanged plan must not charge twice")
	_set_state(2)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/night.png")
	_set_state(0)
	selected.erase(SHEEP[0])
	_confirm()
	assert(state==0,"Cannot abandon a sheep")
	print("VERIFIED: source metrics, water/rock collision, picking, erase, undo, payment, duplicate charge, sheep validation, three rendered states.")
	get_tree().quit()
