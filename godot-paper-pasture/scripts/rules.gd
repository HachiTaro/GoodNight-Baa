extends RefCounted
## Deterministic rules shared by preview, billing, supply allocation and night.
const DIRS := [Vector2i(1,0),Vector2i(0,1),Vector2i(-1,0),Vector2i(0,-1)]

static func cell(level: Dictionary, p: Vector2i) -> String:
	if p.y<0 or p.y>=level.grid.size() or p.x<0 or p.x>=level.grid[0].length(): return "outside"
	return level.grid[p.y].substr(p.x,1)

static func valid(level: Dictionary, p: Vector2i) -> bool:
	return cell(level,p) in [".","g","S","s"]

static func sheep(level: Dictionary) -> Array[Vector2i]:
	var out: Array[Vector2i]=[]
	for y in level.grid.size():
		for x in level.grid[y].length():
			if cell(level,Vector2i(x,y)) in ["S","s"]: out.append(Vector2i(x,y))
	return out

static func from_pairs(pairs: Array) -> Dictionary:
	var out: Dictionary={}
	for p in pairs: out[Vector2i(int(p[0])-1,int(p[1])-1)]=true
	return out

static func to_pairs(cells: Dictionary) -> Array:
	var out: Array=[]
	for p: Vector2i in ordered(cells): out.append([p.x+1,p.y+1])
	return out

static func ordered(cells: Dictionary) -> Array:
	var keys := cells.keys()
	keys.sort_custom(func(a: Vector2i,b: Vector2i): return a.y<b.y or (a.y==b.y and a.x<b.x))
	return keys

static func edge_key(a: Vector2i,b: Vector2i) -> String:
	if a.x>b.x or (a.x==b.x and a.y>b.y): return "%d,%d:%d,%d"%[b.x,b.y,a.x,a.y]
	return "%d,%d:%d,%d"%[a.x,a.y,b.x,b.y]

static func boundary(level: Dictionary,cells: Dictionary) -> Array:
	var edges: Array=[]
	for p: Vector2i in ordered(cells):
		for d: Vector2i in DIRS:
			if not cells.has(p+d): edges.append({"cell":p,"dir":d,"water":cell(level,p+d)=="W","key":edge_key(p,p+d)})
	return edges

static func components(cells: Dictionary) -> Array:
	var remaining := cells.duplicate()
	var result: Array=[]
	for start: Vector2i in ordered(cells):
		if not remaining.has(start): continue
		var group: Dictionary={start:true}
		var queue: Array[Vector2i]=[start]
		remaining.erase(start)
		var at := 0
		while at<queue.size():
			var current := queue[at]
			at+=1
			for d: Vector2i in DIRS:
				var next := current+d
				if remaining.has(next):
					remaining.erase(next)
					group[next]=true
					queue.append(next)
		result.append(group)
	return result

static func analyze(level: Dictionary,cells: Dictionary,stock: Dictionary={"grass":0,"water":0}) -> Dictionary:
	var edges := boundary(level,cells)
	var shore := 0
	for e in edges:
		if e.water: shore+=1
	var groups: Array=[]
	var grass_left: int=int(stock.get("grass",0))
	var water_left: int=int(stock.get("water",0))
	var sheep_cells := sheep(level)
	var uncovered: Array=[]
	for s in sheep_cells:
		if not cells.has(s): uncovered.append(s)
	var area_missing := 0
	var grass_missing := 0
	var water_missing := 0
	for group: Dictionary in components(cells):
		var n := 0
		var natural := 0
		var bank := 0
		for p: Vector2i in group:
			if p in sheep_cells: n+=1
			if cell(level,p) in ["g","S"]: natural+=1
		for e in boundary(level,group):
			if e.water: bank+=1
		var grass_need: int=maxi(0,n*2-natural)
		var water_need: int=0 if bank>0 else n
		var assigned_g: int=mini(grass_left,grass_need)
		var assigned_w: int=mini(water_left,water_need)
		grass_left-=assigned_g
		water_left-=assigned_w
		var missing_a: int=maxi(0,n*2-group.size())
		groups.append({"name":String.chr(65+groups.size()),"cells":group,"sheep":n,"area":group.size(),"natural":natural,"shore":bank,"grass":assigned_g,"water":assigned_w,"missing_area":missing_a,"missing_grass":grass_need-assigned_g,"missing_water":water_need-assigned_w})
		area_missing+=missing_a
		grass_missing+=grass_need-assigned_g
		water_missing+=water_need-assigned_w
	return {"area":cells.size(),"perimeter":edges.size(),"shore":shore,"fences":edges.size()-shore,"edges":edges,"groups":groups,"uncovered":uncovered,"missing_area":area_missing,"missing_grass":grass_missing,"missing_water":water_missing,"used_grass":int(stock.get("grass",0))-grass_left,"used_water":int(stock.get("water",0))-water_left}

static func wolf_route(level: Dictionary,cells: Dictionary) -> Dictionary:
	var walls: Dictionary={}
	for e in boundary(level,cells):
		if not e.water: walls[e.key]=true
	var targets := sheep(level)
	var best: Dictionary={"target":-1,"path":[],"patrol":[]}
	var best_distance := 999999
	var width: int=level.grid[0].length()
	var height: int=level.grid.size()
	for entry in level.wolf_entries:
		var start := Vector2i(int(entry[0])-1,int(entry[1])-1)
		var queue: Array[Vector2i]=[start]
		var parent: Dictionary={start:start}
		var distance: Dictionary={start:0}
		var at := 0
		while at<queue.size():
			var p := queue[at]
			at+=1
			for d: Vector2i in DIRS:
				var next := p+d
				if next.x < -2 or next.y < -2 or next.x>width+1 or next.y>height+1: continue
				if parent.has(next) or cell(level,next) in ["W","#","H"] or walls.has(edge_key(p,next)): continue
				parent[next]=p
				distance[next]=distance[p]+1
				queue.append(next)
		for i in targets.size():
			var target := targets[i]
			if distance.has(target) and (int(distance[target])<best_distance or (int(distance[target])==best_distance and i<int(best.target))):
				best_distance=distance[target]
				var path: Array[Vector2i]=[target]
				while path[-1]!=start: path.append(parent[path[-1]])
				path.reverse()
				best={"target":i,"path":path,"patrol":[]}
		if best.target==-1 and best.patrol.is_empty():
			# Find a reachable point closest to a sheep, then walk back out.
			var nearest := start
			var near_distance := 999999
			for p: Vector2i in queue:
				for s in targets:
					var md: int=absi(p.x-s.x)+absi(p.y-s.y)
					if md<near_distance: near_distance=md; nearest=p
			var path: Array[Vector2i]=[nearest]
			while path[-1]!=start: path.append(parent[path[-1]])
			path.reverse()
			best.patrol=path
	return best

static func resolve(level: Dictionary,cells: Dictionary,stock: Dictionary,coins: int) -> Dictionary:
	var report := analyze(level,cells,stock)
	var wolf := wolf_route(level,cells)
	var reasons: Array[String]=[]
	if wolf.target>=0: reasons.append("第 %d 只小羊还没有安全的围栏保护。"%(int(wolf.target)+1))
	if not report.uncovered.is_empty(): reasons.append("还有 %d 只小羊没圈进牧场。"%report.uncovered.size())
	for group in report.groups:
		if group.missing_area>0: reasons.append("牧场 %s 还差 %d 格生活空间。"%[group.name,group.missing_area])
		if group.missing_grass>0: reasons.append("牧场 %s 还差 %d 份草料。"%[group.name,group.missing_grass])
		if group.missing_water>0: reasons.append("牧场 %s 还差 %d 份饮水。"%[group.name,group.missing_water])
	if coins<0: reasons.append("本次方案超过预算。")
	report["success"]=reasons.is_empty()
	report["reasons"]=reasons
	report["wolf"]=wolf
	return report
