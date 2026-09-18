extends RefCounted
const Rules=preload("res://scripts/rules.gd")
var level: Dictionary
var draft: Dictionary={}
var built: Dictionary={}
var batches: Array=[]
var ledger: Array=[]
var fence_paid := 0
var supplies_paid := 0
var discount := false
var finalized := false
var result: Dictionary={}
var undo_stack: Array[Dictionary]=[]
var redo_stack: Array[Dictionary]=[]

func setup(data: Dictionary) -> void:
	level=data.duplicate(true)

func balance() -> int: return int(level.budget)-fence_paid-supplies_paid

func stock() -> Dictionary:
	var out := {"grass":0,"water":0}
	for b in batches: out[b.item]+=int(b.remaining)
	return out

func dirty() -> bool: return Rules.to_pairs(draft)!=Rules.to_pairs(built)

func snapshot() -> void:
	undo_stack.append(draft.duplicate())
	if undo_stack.size()>100: undo_stack.pop_front()
	redo_stack.clear()

func paint(p: Vector2i,remove: bool) -> bool:
	if finalized or not Rules.valid(level,p): return false
	if remove: draft.erase(p)
	else: draft[p]=true
	return true

func undo() -> void:
	if undo_stack.is_empty() or finalized: return
	redo_stack.append(draft.duplicate())
	draft=undo_stack.pop_back()

func redo() -> void:
	if redo_stack.is_empty() or finalized: return
	undo_stack.append(draft.duplicate())
	draft=redo_stack.pop_back()

func cancel() -> void:
	if finalized: return
	snapshot()
	draft=built.duplicate()

func build_cost() -> int: return Rules.analyze(level,draft).fences-fence_paid

func commit() -> bool:
	if finalized: return false
	var cost := build_cost()
	if cost>balance(): return false
	fence_paid+=cost
	built=draft.duplicate()
	ledger.append({"type":"fence","cost":cost})
	return true

func price(item: String) -> int:
	return (1 if discount else 2) if item=="grass" else (2 if discount else 4)

func purchase(item: String,quantity: int) -> bool:
	if finalized or item not in ["grass","water"] or quantity<1 or quantity>99: return false
	var unit := price(item)
	var cost := quantity*unit
	if cost>balance(): return false
	var units := quantity*(4 if item=="water" else 1)
	batches.append({"item":item,"quantity":quantity,"remaining":units,"units":units,"cost":cost,"unit_price":unit})
	supplies_paid+=cost
	ledger.append({"type":"purchase","item":item,"quantity":quantity,"cost":cost})
	return true

func refund(item: String) -> int:
	if finalized: return 0
	var amount := 0
	for i in range(batches.size()-1,-1,-1):
		var b: Dictionary=batches[i]
		if b.item==item and int(b.remaining)==int(b.units):
			amount+=int(b.cost)
			batches.remove_at(i)
	supplies_paid-=amount
	if amount>0: ledger.append({"type":"refund","item":item,"cost":-amount})
	return amount

func resolve() -> Dictionary:
	return Rules.resolve(level,built,stock(),balance())

func settle() -> Dictionary:
	if finalized: return result
	result=resolve()
	if result.success:
		for item in ["grass","water"]:
			var need: int=result["used_"+item]
			for b in batches:
				if b.item==item:
					var consumed: int=mini(need,int(b.remaining))
					b.remaining-=consumed
					need-=consumed
		finalized=true
		var spend := fence_paid+supplies_paid
		result["stars"]=3 if spend<=int(level.stars[0]) else (2 if spend<=int(level.stars[1]) else 1)
	else: result["stars"]=0
	return result

func serialize() -> Dictionary:
	return {"level_id":int(level.id),"draft":Rules.to_pairs(draft),"built":Rules.to_pairs(built),"batches":batches.duplicate(true),"ledger":ledger.duplicate(true),"fence_paid":fence_paid,"supplies_paid":supplies_paid,"discount":discount,"finalized":finalized}

func restore(data: Dictionary) -> bool:
	var restored_draft := Rules.from_pairs(data.get("draft",[]))
	var restored_built := Rules.from_pairs(data.get("built",[]))
	for cells in [restored_draft,restored_built]:
		for p: Vector2i in cells:
			if not Rules.valid(level,p): return false
	draft=restored_draft
	built=restored_built
	batches=data.get("batches",[]).duplicate(true)
	ledger=data.get("ledger",[]).duplicate(true)
	fence_paid=int(data.get("fence_paid",0))
	supplies_paid=int(data.get("supplies_paid",0))
	discount=bool(data.get("discount",false))
	finalized=bool(data.get("finalized",false))
	if fence_paid!=int(Rules.analyze(level,built).fences) or balance()<0: return false
	return true
