extends SceneTree
const Rules=preload("res://scripts/rules.gd")
const Session=preload("res://scripts/session.gd")
const Saves=preload("res://scripts/save_store.gd")
var checks := 0
var failed := 0

func check(condition: bool,what: String) -> void:
	checks+=1
	if not condition: failed+=1; printerr("FAIL: "+what)

func _initialize() -> void:
	var data: Dictionary=JSON.parse_string(FileAccess.get_file_as_string("res://data/levels.json"))
	var levels: Array=data.levels
	var bills: Array=[]
	for level: Dictionary in levels:
		var session=Session.new()
		session.setup(level)
		session.draft=Rules.from_pairs(level.reference.cells)
		for p: Vector2i in session.draft: check(Rules.valid(level,p),"Reference valid L%d"%int(level.id))
		check(session.commit(),"Reference commit L%d"%int(level.id))
		if int(level.reference.grass)>0: check(session.purchase("grass",int(level.reference.grass)),"Buy grass L%d"%int(level.id))
		if int(level.reference.water_buckets)>0: check(session.purchase("water",int(level.reference.water_buckets)),"Buy water L%d"%int(level.id))
		var result: Dictionary=session.resolve()
		check(result.success,"Full-price solution L%d: %s"%[int(level.id),str(result.reasons)])
		bills.append({"level":int(level.id),"area":result.area,"perimeter":result.perimeter,"shore":result.shore,"fences":result.fences,"supplies":session.supplies_paid,"total":session.fence_paid+session.supplies_paid})
		var before: Dictionary=session.stock()
		session.settle()
		var after: Dictionary=session.stock()
		session.settle()
		check(session.stock()==after,"Idempotent successful settlement")
		check(after.grass==before.grass-result.used_grass and after.water==before.water-result.used_water,"Consume only allocated supplies")
		check(not session.purchase("grass",1) and not session.commit(),"Final result locks transactions")
	for index in [4,6]:
		for alternative in levels[index].alternatives:
			for discount in [false,true]:
				var s=Session.new(); s.setup(levels[index]); s.discount=discount
				s.draft=Rules.from_pairs(alternative.cells); s.commit()
				if alternative.grass>0: s.purchase("grass",int(alternative.grass))
				if alternative.water_buckets>0: s.purchase("water",int(alternative.water_buckets))
				check(s.resolve().success,"Bridge alternative valid")
				check(s.fence_paid+s.supplies_paid==int(alternative.discount_cost if discount else alternative.normal_cost),"Economic reversal uses actual edges")
	var flat := {"grid":[".....",".....",".....",".....","....."],"wolf_entries":[[0,2]]}
	var square := Rules.from_pairs([[2,2],[3,2],[2,3],[3,3]])
	check(Rules.analyze(flat,square).perimeter==8,"2x2 perimeter")
	check(Rules.components(Rules.from_pairs([[1,1],[2,2]])).size()==2,"Diagonal not connected")
	var hole := Rules.from_pairs([[2,2],[3,2],[4,2],[2,3],[4,3],[2,4],[3,4],[4,4]])
	check(Rules.analyze(flat,hole).perimeter==16,"Hole perimeter")
	var second := Rules.analyze(levels[1],Rules.from_pairs(levels[1].reference.cells))
	check(second.area==8 and second.perimeter==12 and second.shore==1 and second.fences==11,"Level 2 exact specification")
	var s=Session.new(); s.setup(levels[0]); s.draft=square
	check(s.commit(),"Build transaction")
	var balance: int=s.balance(); check(s.commit() and s.balance()==balance,"Duplicate confirm no double charge")
	s.draft={}; check(s.commit() and s.balance()==16,"Demolition refunds exact fence cost")
	s.purchase("grass",2); s.discount=true; s.purchase("grass",2)
	check(s.refund("grass")==6 and s.balance()==16,"Batch-aware refunds cannot arbitrage discount")
	check(not s.purchase("water",99) and s.balance()==16,"Insufficient funds atomic")
	s.draft=Rules.from_pairs(levels[0].reference.cells); s.commit()
	var pre_stock: Dictionary=s.stock(); var pre_coins: int=s.balance()
	check(not s.settle().success and s.stock()==pre_stock and s.balance()==pre_coins,"Failure preserves pre-night state")
	var open_route := Rules.wolf_route(levels[0],{})
	check(open_route.target>=0,"Wolf can reach uncovered sheep")
	check(Rules.wolf_route(levels[0],s.built).target==-1,"Wolf blocked by complete fence")
	check(Rules.wolf_route(levels[1],Rules.from_pairs(levels[1].reference.cells)).target==-1,"Water bank protects without fence")
	var broken: Dictionary=s.built.duplicate(); broken.erase(Rules.sheep(levels[0])[0])
	check(Rules.wolf_route(levels[0],broken).target==0,"Missing sheep gets concrete risk id")
	var split := Rules.analyze(levels[4],Rules.from_pairs(levels[4].alternatives[0].cells))
	check(split.missing_grass==4 and split.missing_water==2,"Disconnected natural resources cannot be shared")
	var shared := Rules.analyze(levels[4],Rules.from_pairs(levels[4].reference.cells))
	check(shared.missing_grass==0 and shared.missing_water==0,"Connected resources shared")
	s.purchase("water",1)
	var restored=Session.new(); restored.setup(levels[0])
	check(restored.restore(s.serialize()) and restored.balance()==s.balance() and restored.stock()==s.stock(),"Session serialization exact")
	var saves=Saves.new(); saves.path="user://test-progress.json"; saves.data.session=s.serialize()
	saves.record(1,3,12,false); check(saves.save(),"Atomic save")
	var loaded=Saves.new(); loaded.path=saves.path
	check(loaded.load_save() and loaded.data.unlocked==2 and loaded.data.scores['1'].regular==12,"Save roundtrip and unlock")
	saves.record(1,2,10,true); saves.save()
	check(saves.data.scores['1'].regular==12 and saves.data.scores['1'].discount==10,"Best costs segregate discount")
	var f:=FileAccess.open("res://verification/level-bills.json",FileAccess.WRITE); f.store_string(JSON.stringify(bills,"  ")); f.close()
	print("RULE CHECKS: %d passed / %d total"%[checks-failed,checks])
	print(JSON.stringify(bills))
	quit(1 if failed else 0)
