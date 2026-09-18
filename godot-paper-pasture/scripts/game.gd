extends Node2D
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/session.gd")
const Saves=preload("res://scripts/save_store.gd")
const Quiz=preload("res://scripts/quiz.gd")
const World=preload("res://scripts/world.gd")
const Sounds=preload("res://scripts/audio.gd")
const INK=Color("304a42")
const MUTED=Color("748477")
const PAPER=Color("fffdf3")
const GREEN=Color("466c55")
var levels: Array
var save_store=Saves.new()
var session=Session.new()
var quiz=Quiz.new()
var world: Node2D
var sounds: Node
var canvas: CanvasLayer
var screen: Control
var status: Control
var modal: Control
var toast_label: Label
var toast_time := 0.0
var page := "home"
var planning := false
var paused := false
var practice := false
var night_elapsed := 0.0
var night_report: Dictionary={}
var quantities := {"grass":1,"water":1}
var quiz_progress: Label
var quiz_bar: ProgressBar
var quiz_player_bar: ProgressBar
var quiz_panel: Control
var answer_buttons: Array[Button]=[]
var answer_cooldown := 0.0
var ui_epoch := 0
var qa_mode := false

func _ready() -> void:
	levels=JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json")).levels
	qa_mode="--qa" in OS.get_cmdline_user_args()
	if qa_mode: save_store.path="user://qa-progress.json"
	save_store.load_save()
	world=World.new(); add_child(world)
	world.stroke_started.connect(func(): session.snapshot())
	world.paint_cell.connect(_paint)
	world.sheep_touched.connect(_pet)
	sounds=Sounds.new(); add_child(sounds)
	canvas=CanvasLayer.new(); add_child(canvas)
	screen=Control.new(); screen.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); screen.mouse_filter=Control.MOUSE_FILTER_IGNORE; canvas.add_child(screen)
	toast_label=_label("",Rect2(400,788,800,50),20); toast_label.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER; canvas.add_child(toast_label)
	_apply_settings()
	_home()
	if "--qa-capture" in OS.get_cmdline_user_args(): call_deferred("_qa_capture")

func _draw() -> void:
	var n: float=world.night_amount if world and page in ["night","result"] else 0
	draw_rect(Rect2(0,0,1600,1000),Color("e9efdf").lerp(Color("1c3143"),n))
	draw_colored_polygon(PackedVector2Array([Vector2(0,480),Vector2(240,363),Vector2(640,449),Vector2(1260,260),Vector2(1600,353),Vector2(1600,1000),Vector2(0,1000)]),Color("dee7cd").lerp(Color("203c4b"),n))
	draw_colored_polygon(PackedVector2Array([Vector2(0,703),Vector2(290,569),Vector2(741,720),Vector2(1600,551),Vector2(1600,1000),Vector2(0,1000)]),Color("d4dfc2").lerp(Color("254352"),n))
	draw_circle(Vector2(1350,172),51,Color("f7e9b6"))
	if n>0.5:
		draw_circle(Vector2(1372,156),47,Color("1c3143"))
		for i in 24: draw_circle(Vector2(350+(i*127)%960,100+(i*43)%160),1.8,Color(0.98,0.96,0.8,0.7))

func _style(color: Color,corner: int=18) -> StyleBoxFlat:
	var s:=StyleBoxFlat.new(); s.bg_color=color; s.set_corner_radius_all(corner)
	s.shadow_color=Color(0.20,0.29,0.19,0.055); s.shadow_size=4; s.shadow_offset=Vector2(0,4)
	return s

func _panel(rect: Rect2,parent: Node=screen,color: Color=PAPER) -> Panel:
	var p:=Panel.new(); p.position=rect.position; p.size=rect.size; p.add_theme_stylebox_override("panel",_style(color)); p.mouse_filter=Control.MOUSE_FILTER_STOP; parent.add_child(p); return p

func _label(text: String,rect: Rect2,size: int=20,color: Color=INK,bold: bool=false) -> Label:
	var l:=Label.new(); l.position=rect.position; l.size=rect.size; l.text=text
	l.add_theme_font_override("font",load("res://assets/fonts/bold.ttc" if bold else "res://assets/fonts/regular.ttc"))
	l.add_theme_font_size_override("font_size",size); l.add_theme_color_override("font_color",color)
	l.mouse_filter=Control.MOUSE_FILTER_IGNORE
	return l

func _text(text: String,rect: Rect2,size: int=20,color: Color=INK,bold: bool=false,parent: Node=screen) -> Label:
	var l:=_label(text,rect,size,color,bold); parent.add_child(l); return l

func _button(text: String,rect: Rect2,action: Callable,primary: bool=false,parent: Node=screen,disabled: bool=false) -> Button:
	var b:=Button.new(); b.position=rect.position; b.size=rect.size; b.text=text; b.disabled=disabled
	b.add_theme_font_override("font",preload("res://assets/fonts/regular.ttc")); b.add_theme_font_size_override("font_size",20)
	b.add_theme_color_override("font_color",PAPER if primary else INK)
	b.add_theme_color_override("font_hover_color",PAPER if primary else INK)
	b.add_theme_color_override("font_pressed_color",PAPER if primary else INK)
	b.add_theme_color_override("font_disabled_color",Color("a1aa9a"))
	b.add_theme_stylebox_override("normal",_style(GREEN if primary else PAPER,15))
	b.add_theme_stylebox_override("hover",_style(Color("597d62") if primary else Color("edf3e2"),15))
	b.add_theme_stylebox_override("pressed",_style(Color("355442") if primary else Color("dbe6cb"),15))
	b.add_theme_stylebox_override("disabled",_style(Color("dce3d1"),15))
	b.mouse_default_cursor_shape=Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): sounds.tone(520,0.07,0.05); action.call())
	parent.add_child(b); return b

func _clear(node: Node) -> void:
	for c in node.get_children(): node.remove_child(c); c.queue_free()

func _clear_page(next: String) -> void:
	ui_epoch+=1; _close_modal(); _clear(screen); status=null; page=next; toast_label.text=""
	world.visible=next in ["home","farm","night","result"]
	world.input_enabled=next=="farm"
	world.actors.modulate=Color.WHITE
	quiz_progress=null; quiz_bar=null; quiz_player_bar=null; quiz_panel=null
	queue_redraw()

func _toast(message: String) -> void:
	toast_label.text=message; toast_time=3.8
	toast_label.add_theme_color_override("font_color",PAPER if page in ["night","result"] else INK)

func _apply_settings() -> void:
	var settings: Dictionary=save_store.data.settings
	sounds.volume=float(settings.get("volume",0.6)); sounds.music=bool(settings.get("music",true))
	world.reduced_motion=bool(settings.get("reduced_motion",false))

func _persist() -> void:
	if session.level and not practice: save_store.data.session=session.serialize()
	if not save_store.save(): _toast("暂时没能保存进度，请检查磁盘空间。")

func _home() -> void:
	_clear_page("home")
	var preview=Session.new(); preview.setup(levels[4]); preview.built=Rules.from_pairs(levels[4].reference.cells); preview.draft=preview.built.duplicate()
	world.configure(preview,false); world.input_enabled=false
	_text("晚安，羊羊",Rect2(74,194,700,90),64,INK,true)
	_text("围一片草地，留住今晚的好梦。",Rect2(80,299,640,40),24,MUTED)
	_text("用面积、周长和一点点巧思，\n照顾属于你的小牧场。",Rect2(80,352,520,100),23,INK)
	var has_save: bool=not save_store.data.session.is_empty() or not save_store.data.scores.is_empty()
	_button("继续游戏" if has_save else "开始游戏",Rect2(80,500,280,64),_continue if has_save else func(): _load_level(0),true)
	_button("关卡地图",Rect2(80,582,280,58),_level_map)
	_button("设置",Rect2(80,656,130,52),_settings)
	_button("口算练习",Rect2(226,656,134,52),func(): _pk_intro(true))
	if has_save: _button("重新开始",Rect2(80,738,280,48),func(): _confirm_dialog("重新开始？","会清除本机的关卡成绩和当前进度。", "重新开始",func(): save_store.clear_progress(); save_store.save(); _load_level(0)))
	_text("八个夜晚 · 一个慢慢长大的牧场",Rect2(80,920,650,34),18,MUTED)

func _continue() -> void:
	var data: Dictionary=save_store.data.session
	if data.is_empty() or bool(data.get("finalized",false)): _level_map(); return
	var id:=clampi(int(data.get("level_id",1)),1,levels.size())
	session=Session.new(); session.setup(levels[id-1])
	if not session.restore(data): _load_level(id-1); _toast("存档中的方案无法恢复，已重新开始本关。"); return
	planning=false; practice=false; _farm()

func _level_map() -> void:
	_clear_page("map")
	_text("八个夜晚",Rect2(110,92,650,70),44,INK,true)
	_text("慢慢来，每一片草地都有不同的办法。",Rect2(112,169,900,36),23,MUTED)
	_button("返回首页",Rect2(1350,92,150,52),_home)
	for i in levels.size():
		var level: Dictionary=levels[i]; var x:=110+(i%4)*350; var y:=260+(i/4)*288
		var p:=_panel(Rect2(x,y,325,245))
		var unlocked: bool=i<int(save_store.data.unlocked)
		var score: Dictionary=save_store.data.scores.get(str(i+1),{})
		_text("0%d"%(i+1),Rect2(25,18,100,48),35,GREEN,true,p)
		_text(level.title,Rect2(25,82,290,40),23,INK,true,p)
		var star_text: String="★".repeat(int(score.get("stars",0)))+"☆".repeat(3-int(score.get("stars",0)))
		_text(star_text if unlocked else "完成前一关后解锁",Rect2(25,134,285,30),20,Color("ad8f4c") if unlocked else MUTED,false,p)
		_button("进入牧场" if unlocked else "尚未解锁",Rect2(24,180,277,48),func(): _load_level(i),unlocked,p,not unlocked)

func _load_level(index: int) -> void:
	session=Session.new(); session.setup(levels[index]); planning=false; practice=false
	_persist(); _farm()

func _topbar() -> void:
	_button("‹",Rect2(40,35,52,52),func(): _persist(); _level_map())
	_text("晚安，羊羊",Rect2(112,29,420,34),24,INK,true)
	_text("第 %d 关 · %s"%[int(session.level.id),session.level.title],Rect2(113,66,650,25),16,MUTED)
	_button("金币 %d  ·  账单"%session.balance(),Rect2(960,35,204,52),_bill)
	_button("草 %d   水 %d  +"%[session.stock().grass,session.stock().water],Rect2(1180,35,224,52),_shop)
	_button("Ⅱ",Rect2(1420,35,56,52),_settings)
	_button("♪",Rect2(1492,35,56,52),func(): save_store.data.settings.music=not sounds.music; _apply_settings(); save_store.save(); _toast("音乐已开启" if sounds.music else "音乐已关闭"))

func _farm() -> void:
	_clear_page("farm"); world.configure(session,planning); _topbar()
	var task:=_panel(Rect2(40,130,315,121))
	_text("今晚，照顾好 %d 只小羊"%Rules.sheep(session.level).size(),Rect2(22,16,295,32),21,INK,true,task)
	var hint:=_text(session.level.hint,Rect2(22,55,272,54),16,MUTED,false,task); hint.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	if planning:
		_button("选择",Rect2(40,708,98,50),func(): world.erase_mode=false; _toast("选择模式：按住鼠标涂选草地。"),not world.erase_mode)
		_button("擦除",Rect2(150,708,98,50),func(): world.erase_mode=true; _toast("擦除模式：拖动移除草地。"),world.erase_mode)
		_button("撤销",Rect2(40,772,98,48),_undo)
		_button("重做",Rect2(150,772,98,48),_redo)
		_text("右键擦除 · Ctrl+Z 撤销",Rect2(40,833,290,30),15,MUTED)
	else:
		_button("开始规划" if session.built.is_empty() else "调整围栏",Rect2(40,785,256,58),func(): planning=true; _farm(),true)
		_button("去小镇补给 ↗",Rect2(40,861,256,58),_town)
		_button("让夜晚到来",Rect2(1300,868,250,65),_night_prompt,true)
		_text("不满意？随时可以再调整。",Rect2(1302,946,280,28),16,MUTED)
	status=Control.new(); status.mouse_filter=Control.MOUSE_FILTER_IGNORE; screen.add_child(status)
	_refresh_stats()

func _refresh_stats() -> void:
	if not status or page!="farm": return
	_clear(status)
	var report:=Rules.analyze(session.level,session.draft if planning else session.built,session.stock())
	var card_y:=276
	for g in report.groups:
		if g.sheep==0: continue
		if card_y>665: break
		var panel:=_panel(Rect2(40,card_y,315,120),status)
		_text("牧场 %s  ·  %d 只羊"%[g.name,g.sheep],Rect2(18,12,290,29),19,INK,true,panel)
		_text("面积 %d / %d   牧草 %d + %d / %d"%[g.area,g.sheep*2,g.natural,g.grass,g.sheep*2],Rect2(18,48,290,25),16,MUTED,false,panel)
		var line: String="临水充足" if g.shore>0 else "已分配饮水 %d / %d"%[g.water,g.sheep]
		if g.missing_area>0 or g.missing_grass>0 or g.missing_water>0: line+=" · 待补足"
		_text(line,Rect2(18,80,290,25),16,Color("a76b52") if "待补足" in line else GREEN,false,panel)
		var locator:=Button.new(); locator.flat=true; locator.position=Vector2(40,card_y); locator.size=Vector2(315,120); locator.tooltip_text="定位牧场 "+g.name
		locator.pressed.connect(func(): world.focus_cells=g.cells; world.queue_redraw()); status.add_child(locator)
		card_y+=133
	if report.groups.is_empty():
		_text("每只羊需要\n2 格空间 · 2 份草 · 1 份水\n\n点点小羊，和它打个招呼。",Rect2(60,294,300,135),19,MUTED,false,status)
	if planning:
		var bar:=_panel(Rect2(380,883,1170,84),status)
		var metrics: Array=[["生活面积","%d 格"%report.area],["数学周长","%d 边"%report.perimeter],["免建水岸","%d 边"%report.shore],["需建围栏","%d 段"%report.fences],["改建差价","%+d 金币"%session.build_cost()]]
		for i in metrics.size():
			_text(metrics[i][0],Rect2(24+i*154,12,150,22),15,MUTED,false,bar)
			_text(metrics[i][1],Rect2(24+i*154,41,155,29),23,INK,true,bar)
		_button("确认建造",Rect2(794,16,178,54),_build_prompt,true,bar,session.build_cost()>session.balance())
		_button("取消",Rect2(991,16,155,54),func(): session.cancel(); planning=false; _persist(); _farm(),false,bar)
		_text("周长 %d − 临水 %d = 围栏 %d   ·   选地只预览，确认后才记账"%[report.perimeter,report.shore,report.fences],Rect2(590,837,920,29),16,MUTED,false,status)
	else:
		var ready: bool=report.uncovered.is_empty() and report.missing_area==0 and report.missing_grass==0 and report.missing_water==0
		var p:=_panel(Rect2(435,895,800,55),status)
		_text("草、水、空间都够了，可以安心入夜。" if ready else "先规划，再看看每个牧场还缺什么。",Rect2(24,13,750,31),20,GREEN,false,p)

func _paint(cell: Vector2i,remove: bool) -> void:
	if page!="farm" or not planning or modal: return
	var existed: bool=session.draft.has(cell)
	if existed==not remove: return
	if session.paint(cell,remove): world.refresh(); _refresh_stats()

func _undo() -> void:
	session.undo(); world.refresh(); _refresh_stats()

func _redo() -> void:
	session.redo(); world.refresh(); _refresh_stats()

func _pet(index: int,point: Vector2) -> void:
	sounds.bleat(); _toast("第 %d 只小羊：我需要 2 格空间、2 份草和 1 份水。"%(index+1))
	var heart:=_label("♥",Rect2(point-Vector2(16,70),Vector2(50,50)),36,Color("c77878")); canvas.add_child(heart)
	var t:=create_tween(); t.set_parallel(); t.tween_property(heart,"position:y",heart.position.y-50,0.9); t.tween_property(heart,"modulate:a",0.0,0.9); t.chain().tween_callback(heart.queue_free)

func _dialog(title: String,width: float=690,height: float=470) -> Panel:
	_close_modal(); world.input_enabled=false
	modal=Control.new(); modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); canvas.add_child(modal)
	var shade:=ColorRect.new(); shade.color=Color(0.08,0.17,0.13,0.42); shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT); modal.add_child(shade)
	var p:=_panel(Rect2((1600-width)/2,(1000-height)/2,width,height),modal)
	_text(title,Rect2(32,25,width-90,48),29,INK,true,p)
	_button("×",Rect2(width-73,20,48,48),_close_modal,false,p)
	return p

func _close_modal() -> void:
	if modal: modal.queue_free(); modal=null
	if world: world.input_enabled=page=="farm" and not paused

func _confirm_dialog(title: String,body: String,action_name: String,action: Callable) -> void:
	var p:=_dialog(title)
	var l:=_text(body,Rect2(34,107,622,230),22,INK,false,p); l.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_button("返回修改",Rect2(32,378,280,56),_close_modal,false,p)
	_button(action_name,Rect2(334,378,324,56),func(): _close_modal(); action.call(),true,p)

func _build_prompt() -> void:
	var m:=Rules.analyze(session.level,session.draft,session.stock())
	var difference: int=session.build_cost()
	var details: String="面积 %d 格，周长 %d 边，临水 %d 边。\n共需 %d 段围栏。\n\n%s %d 金币，确认后余额 %d。"%[m.area,m.perimeter,m.shore,m.fences,"本次支付" if difference>=0 else "本次退还",absi(difference),session.balance()-difference]
	_confirm_dialog("把这里围成家？",details,"确认建造",func():
		if session.commit(): planning=false; _persist(); _farm(); _toast("围栏建好啦！再看看草和水够不够。"); sounds.tone(660,0.3)
		else: _toast("金币不足，试试更紧凑的形状。"))

func _bill() -> void:
	var p:=_dialog("牧场账单",760,590)
	var m:=Rules.analyze(session.level,session.built,session.stock())
	_text("初始预算           %d 金币\n当前围栏实付       %d 金币\n补给采购净支出     %d 金币\n剩余金币           %d 金币\n\n周长 %d − 水岸 %d = 围栏 %d\n草库存 %d 份 · 水库存 %d 份\n折扣：%s"%[int(session.level.budget),session.fence_paid,session.supplies_paid,session.balance(),m.perimeter,m.shore,m.fences,session.stock().grass,session.stock().water,"草水五折" if session.discount else "原价"],Rect2(36,105,690,335),23,INK,false,p)
	_button("查看采购记录",Rect2(36,505,315,52),_transactions,false,p)
	_button("回到牧场",Rect2(376,505,348,52),_close_modal,true,p)

func _transactions() -> void:
	var p:=_dialog("采购与改建记录",760,630)
	var scroll:=ScrollContainer.new(); scroll.position=Vector2(34,95); scroll.size=Vector2(690,432); p.add_child(scroll)
	var box:=VBoxContainer.new(); box.size_flags_horizontal=Control.SIZE_EXPAND_FILL; scroll.add_child(box)
	for entry in session.ledger:
		var text: String="围栏改建" if entry.type=="fence" else ("购买" if entry.type=="purchase" else "退货")+("草料" if entry.get("item","")=="grass" else "饮水")
		var row:=_label(text+"    %+d 金币"%int(entry.cost),Rect2(0,0,670,42),20); row.custom_minimum_size=Vector2(670,42); box.add_child(row)
	if session.ledger.is_empty(): box.add_child(_label("还没有支出记录。",Rect2(0,0,600,45),21))
	_button("返回账单",Rect2(36,552,688,52),_bill,true,p)

func _town() -> void:
	_persist(); _clear_page("town"); _topbar()
	_text("草叶小镇",Rect2(80,159,650,68),46,INK,true)
	_text("欢迎来补给。多余的东西，白天可以按买入价退回。",Rect2(82,244,1100,42),22,MUTED)
	var house:=world.bank.get_node("Art_56_1048").duplicate() as Sprite2D; house.position=Vector2(575,325); house.scale*=4.5; screen.add_child(house)
	var shop_sign:=_panel(Rect2(522,726,525,92)); _text("草叶补给店",Rect2(70,20,410,55),36,INK,true,shop_sign)
	_button("进入商店",Rect2(591,840,390,66),_shop,true)
	_button("← 返回牧场",Rect2(60,866,260,62),_farm)
	for pos in [Vector2(420,420),Vector2(1120,490)]:
		var tree:=world.bank.get_node("Art_56_809").duplicate() as Sprite2D; tree.position=pos; tree.scale*=1.8; screen.add_child(tree)

func _portrait(person: String,rect: Rect2,parent: Node) -> void:
	var atlas:=AtlasTexture.new(); atlas.atlas=load("res://assets/characters/%s-sheet.png"%person)
	atlas.region=Rect2(90,600,325,310) if person=="merchant" else Rect2(0,0,300,550)
	var image:=TextureRect.new(); image.expand_mode=TextureRect.EXPAND_IGNORE_SIZE; image.texture=atlas; image.position=rect.position; image.size=rect.size; image.stretch_mode=TextureRect.STRETCH_KEEP_ASPECT_CENTERED; image.mouse_filter=Control.MOUSE_FILTER_IGNORE; parent.add_child(image)

func _shop() -> void:
	if page in ["night","result"]: return
	var p:=_dialog("草叶补给店",1000,680)
	_portrait("merchant",Rect2(35,92,170,163),p)
	_text("商人阿禾",Rect2(230,108,600,34),25,INK,true,p)
	_text("草料和饮水都准备好了。\n需要多少，就带多少回家吧。",Rect2(230,154,690,90),22,MUTED,false,p)
	_text("余额 %d 金币   ·   %s"%[session.balance(),"草水五折已生效" if session.discount else "当前原价"],Rect2(35,267,930,40),23,GREEN,true,p)
	for i in 2:
		var item: String="grass" if i==0 else "water"
		var x:=35+i*480; var quantity: int=quantities[item]
		var card:=_panel(Rect2(x,325,450,207),p,Color("edf2e2"))
		_text("牧草 · 每份 %d 金币"%session.price(item) if i==0 else "饮水 · 每桶 %d 金币 / 4 份"%session.price(item),Rect2(18,16,420,35),22,INK,true,card)
		_button("−",Rect2(18,68,52,48),func(): quantities[item]=maxi(1,int(quantities[item])-1); _shop(),false,card)
		_text(str(quantity),Rect2(88,74,56,40),25,INK,true,card)
		_button("+",Rect2(153,68,52,48),func(): quantities[item]=mini(99,int(quantities[item])+1); _shop(),false,card)
		_text("合计 %d 金币"%(quantity*session.price(item)),Rect2(226,76,208,40),21,GREEN,false,card)
		_button("确认购买",Rect2(18,137,203,51),func():
			if session.purchase(item,quantity): _persist(); _shop(); _toast("补给已装好，回牧场会自动分配。"); sounds.tone(660,0.18)
		,true,card,quantity*session.price(item)>session.balance())
		_button("退回未用库存",Rect2(236,137,195,51),func(): _refund_prompt(item),false,card,session.stock()[item]==0)
	var pk_enabled: bool=int(session.level.pk_seconds)>0
	_button("商人的口算挑战" if pk_enabled else "第 6 关开启口算挑战",Rect2(35,576,450,58),func(): _pk_intro(false),false,p,not pk_enabled or session.discount)
	_button("带着补给回牧场",Rect2(515,576,450,58),func(): _close_modal(); _farm(),true,p)

func _refund_prompt(item: String) -> void:
	_confirm_dialog("退回未使用的补给？","将按各次购买时的实际价格退款。\n退货后会重新分配牧场补给，可能出现缺口。","确认退货",func(): var returned: int=session.refund(item); _persist(); _shop(); _toast("已退还 %d 金币。"%returned))

func _pk_intro(is_practice: bool) -> void:
	practice=is_practice
	var seconds: int=30 if practice else int(session.level.pk_seconds)
	var p:=_dialog("阿禾的口算挑战",780,515)
	_portrait("merchant",Rect2(35,104,150,143),p)
	_text("比一比谁先答对 5 道题！",Rect2(212,110,530,50),27,INK,true,p)
	var reward: String="这是自由练习，不影响关卡。" if practice else "你赢了，本关草料和水都给你五折。"
	_text("四个选项，选出正确答案。\n答错不加进度，可以继续尝试。\n阿禾大约需要 %d 秒。\n%s"%[seconds,reward],Rect2(212,184,530,170),21,MUTED,false,p)
	_button("下次再来",Rect2(34,410,300,60),_close_modal,false,p)
	_button("开始挑战",Rect2(360,410,385,60),_start_quiz,true,p)

func _start_quiz() -> void:
	_clear_page("quiz")
	quiz.start(6 if practice else int(session.level.id),30.0 if practice else float(session.level.pk_seconds))
	var panel:=_panel(Rect2(410,80,780,845))
	_text("阿禾",Rect2(40,35,220,38),25,INK,true,panel)
	_text("你",Rect2(642,35,100,38),25,INK,true,panel)
	_text("口算挑战",Rect2(288,29,350,50),30,GREEN,true,panel)
	quiz_progress=_text("",Rect2(40,130,700,38),20,MUTED,false,panel)
	quiz_bar=ProgressBar.new(); quiz_bar.position=Vector2(40,88); quiz_bar.size=Vector2(290,20); quiz_bar.max_value=5; quiz_bar.show_percentage=false; panel.add_child(quiz_bar)
	quiz_player_bar=ProgressBar.new(); quiz_player_bar.position=Vector2(450,88); quiz_player_bar.size=Vector2(290,20); quiz_player_bar.max_value=5; quiz_player_bar.show_percentage=false; panel.add_child(quiz_player_bar)
	quiz_panel=Control.new(); quiz_panel.position=Vector2(40,198); panel.add_child(quiz_panel)
	_question_ui()
	_button("退出挑战",Rect2(38,760,704,54),func(): _confirm_dialog("退出这次挑战？","退出不会获得折扣。下次还可以再来。","退出挑战",func(): quiz.abandon(); _quiz_return()),false,panel)

func _question_ui() -> void:
	_clear(quiz_panel); answer_buttons.clear()
	var question:=_text(quiz.question.text+" = ?",Rect2(0,0,700,140),58,INK,true,quiz_panel); question.horizontal_alignment=HORIZONTAL_ALIGNMENT_CENTER
	_text("选择正确答案",Rect2(240,148,350,40),22,MUTED,false,quiz_panel)
	for i in 4:
		var value: int=quiz.question.options[i]
		var button:=_button(str(value),Rect2((i%2)*365,220+(i/2)*135,335,110),func(): _answer(value),false,quiz_panel)
		button.add_theme_font_size_override("font_size",36); answer_buttons.append(button)

func _answer(value: int) -> void:
	if answer_cooldown>0 or not quiz.active: return
	var right: bool=quiz.answer(value)
	answer_cooldown=0.22 if right else 0.4
	if right:
		sounds.tone(740,0.17); _toast("答对了！")
		if quiz.active: _question_ui()
	else:
		sounds.tone(220,0.13); _toast("再算一遍，你可以的。")
		for b in answer_buttons:
			if b.text==str(value): b.disabled=true
	if not quiz.active: _quiz_finish()

func _quiz_finish() -> void:
	if quiz.won and not practice:
		session.discount=true
		var best: Dictionary=save_store.data.get("pk",{})
		var key:=str(int(session.level.id)); best[key]=minf(float(best.get(key,999)),quiz.elapsed); save_store.data["pk"]=best
		_persist()
	elif not practice: _persist()
	var p:=_dialog("你赢啦！" if quiz.won else "这次阿禾快了一点",780,470)
	var body: String="答对 %d 题 · 用时 %.1f 秒\n\n"%[quiz.correct,minf(quiz.elapsed,quiz.limit)]
	body+=("本关草料、水五折已经生效！" if not practice else "练习完成，进步一点点也很棒。") if quiz.won else "再来一次也可以。原价购买同样能通关。"
	_text(body,Rect2(35,115,710,180),25,INK,false,p)
	_button("再来一次",Rect2(35,365,310,62),_start_quiz,false,p)
	_button("返回" if practice else "返回商店",Rect2(368,365,376,62),_quiz_return,true,p)

func _quiz_return() -> void:
	if practice: practice=false; _home()
	else: _town(); _shop()

func _night_prompt() -> void:
	if session.dirty():
		var p:=_dialog("还有没提交的规划",820,450)
		_text("先处理草稿，再让夜晚到来。\n确认建造会按差价扣款或退款。",Rect2(35,112,750,130),23,INK,false,p)
		_button("建造并检查",Rect2(35,332,240,62),func():
			if session.commit(): _persist(); planning=false; _close_modal(); _night_prompt()
			else: _toast("金币不足，请返回修改。"),true,p)
		_button("丢弃草稿",Rect2(290,332,235,62),func(): session.cancel(); _persist(); _close_modal(); _night_prompt(),false,p)
		_button("继续修改",Rect2(540,332,245,62),func(): planning=true; _farm(),false,p)
		return
	night_report=session.resolve()
	var body: String="所有小羊都已圈好，空间和草水也够了。\n准备看看夜晚的牧场吧。" if night_report.success else "\n".join(night_report.reasons)+"\n\n可以回去调整，也可以先看看会发生什么。"
	_confirm_dialog("让夜晚到来？",body,"开始守夜",_start_night)

func _start_night() -> void:
	_persist(); _clear_page("night"); planning=false
	world.configure(session,false); night_report=session.resolve(); world.start_night(night_report)
	night_elapsed=0; sounds.night=true
	_text("嘘，夜晚来了。",Rect2(55,120,650,60),33,PAPER)
	_text("小狼正在牧场外走一走。",Rect2(57,190,650,35),21,Color("b5c6cc"))
	_button("跳过演出",Rect2(1325,915,215,52),_finish_night)
	_button("Ⅱ 暂停",Rect2(1390,35,150,50),_settings)

func _finish_night() -> void:
	if page!="night": return
	var result: Dictionary=session.settle(); night_report=result
	if result.success:
		save_store.record(int(session.level.id),int(result.stars),session.fence_paid+session.supplies_paid,session.discount)
	_persist(); _result()

func _result() -> void:
	_clear_page("result"); world.night_amount=1; world.input_enabled=false; world.show_wolf=false; sounds.night=false
	var p:=_panel(Rect2(395,130,810,740))
	_text("晚安，小羊们。" if night_report.success else "再照顾它们一下吧",Rect2(38,35,740,55),34,INK,true,p)
	_text("★".repeat(int(night_report.stars))+"☆".repeat(3-int(night_report.stars)),Rect2(38,105,740,65),45,Color("c3a052"),true,p)
	var body: String="每只小羊都安全、吃饱、喝足，安心睡下了。" if night_report.success else "\n".join(night_report.reasons)
	var report_label:=_text(body,Rect2(38,188,728,124),21,INK,false,p); report_label.autowrap_mode=TextServer.AUTOWRAP_WORD_SMART
	_text("面积 %d 格    周长 %d 边    免建水岸 %d 边\n围栏 %d 金币  +  补给 %d 金币\n总支出 %d 金币    节余 %d 金币\n%s"%[night_report.area,night_report.perimeter,night_report.shore,session.fence_paid,session.supplies_paid,session.fence_paid+session.supplies_paid,session.balance(),"本次使用草水五折" if session.discount else "本次使用原价补给"],Rect2(38,336,735,175),22,MUTED,false,p)
	if night_report.success:
		_button("下一关" if int(session.level.id)<8 else "八个夜晚，全部完成！",Rect2(38,546,734,61),func(): _load_level(int(session.level.id)) if int(session.level.id)<8 else _level_map(),true,p)
	else:
		_button("回到入夜前，继续修改",Rect2(38,546,734,61),func(): planning=false; _farm(),true,p)
	_button("再试一次",Rect2(38,631,351,58),func(): _load_level(int(session.level.id)-1),false,p)
	_button("返回关卡地图",Rect2(414,631,358,58),_level_map,false,p)

func _settings() -> void:
	paused=true; world.set_process(false)
	var p:=_dialog("休息一下",690,560)
	_text("音量",Rect2(35,112,590,36),23,INK,false,p)
	var slider:=HSlider.new(); slider.position=Vector2(36,165); slider.size=Vector2(615,44); slider.min_value=0; slider.max_value=1; slider.step=0.05; slider.value=sounds.volume; p.add_child(slider)
	slider.value_changed.connect(func(value: float): save_store.data.settings.volume=value; _apply_settings())
	_button("音乐：开" if sounds.music else "音乐：关",Rect2(35,243,615,54),func(): save_store.data.settings.music=not sounds.music; _apply_settings(); _settings(),false,p)
	_button("减弱动效：开" if world.reduced_motion else "减弱动效：关",Rect2(35,315,615,54),func(): save_store.data.settings.reduced_motion=not world.reduced_motion; _apply_settings(); _settings(),false,p)
	_button("返回首页",Rect2(35,450,280,62),func(): _resume(); _persist(); _home(),false,p)
	_button("继续游戏",Rect2(337,450,315,62),_resume,true,p)
	# The close icon must resume as well as close the card.
	for child in p.get_children():
		if child is Button and child.text=="×":
			for connection in child.pressed.get_connections(): child.pressed.disconnect(connection.callable)
			child.pressed.connect(_resume)

func _resume() -> void:
	paused=false; world.set_process(true); save_store.save(); _close_modal()

func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode==KEY_ESCAPE:
			if paused: _resume()
			elif modal: _close_modal()
			else: _settings()
		if page=="farm" and planning and not modal and not paused:
			if event.ctrl_pressed and event.keycode==KEY_Z: _undo()
			if event.ctrl_pressed and event.keycode==KEY_Y: _redo()

func _notification(what: int) -> void:
	if what==NOTIFICATION_WM_CLOSE_REQUEST and session.level: _persist()

func _process(delta: float) -> void:
	if toast_time>0: toast_time-=delta
	elif toast_label: toast_label.text=""
	if paused: return
	answer_cooldown=maxf(0,answer_cooldown-delta)
	if page=="quiz" and quiz.active and not modal:
		quiz.tick(delta)
		if quiz_bar: quiz_bar.value=minf(5,quiz.elapsed/quiz.limit*5)
		if quiz_player_bar: quiz_player_bar.value=quiz.correct
		if quiz_progress: quiz_progress.text="阿禾 %d / 5                          你 %d / 5     剩余 %.0f 秒"%[mini(5,int(quiz.elapsed/quiz.limit*5)),quiz.correct,maxf(0,quiz.limit-quiz.elapsed)]
		if not quiz.active: _quiz_finish()
	if page=="night":
		night_elapsed+=delta; queue_redraw()
		if night_elapsed>=10: _finish_night()

func _qa_capture() -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/home.png")
	_load_level(0); planning=true; _farm()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/level1.png")
	session.draft=Rules.from_pairs(session.level.reference.cells); session.commit(); planning=false; _farm()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/level1-built.png")
	_town(); _shop()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/shop.png")
	practice=true; _start_quiz()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/quiz.png")
	quiz.abandon(); practice=false; _load_level(6); session.draft=Rules.from_pairs(session.level.reference.cells); session.commit(); _farm()
	_start_night()
	for i in 100: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://verification/night-game.png")
	_finish_night()
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png("res://verification/result.png")
	print("UI CAPTURE COMPLETE")
	get_tree().quit()
