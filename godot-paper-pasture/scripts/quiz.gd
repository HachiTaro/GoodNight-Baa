extends RefCounted
var rng:=RandomNumberGenerator.new()
var difficulty := 6
var limit := 30.0
var elapsed := 0.0
var correct := 0
var mistakes := 0
var question: Dictionary={}
var active := false
var won := false

func start(level_id: int,seconds: float,seed_value: int=0) -> void:
	difficulty=level_id; limit=seconds; elapsed=0; correct=0; mistakes=0; won=false; active=true
	if seed_value==0: rng.randomize()
	else: rng.seed=seed_value
	next_question()

func next_question() -> void:
	var a: int=rng.randi_range(1,18) if difficulty<=6 else rng.randi_range(12,79)
	var b: int=rng.randi_range(0,20-a) if difficulty<=6 else rng.randi_range(10,69)
	var addition:=rng.randf()>0.5
	if not addition and a<b: var swap:=a; a=b; b=swap
	var answer: int=a+b if addition else a-b
	var expression: String="%d %s %d"%[a,"+" if addition else "−",b]
	if difficulty>=8:
		var c:=rng.randi_range(1,mini(15,maxi(1,answer)))
		if answer>=c: expression+=" − %d"%c; answer-=c
	var options: Array[int]=[answer]
	while options.size()<4:
		var wrong:=maxi(0,answer+rng.randi_range(-12,12))
		if wrong not in options: options.append(wrong)
	for i in range(3,0,-1):
		var j:=rng.randi_range(0,i); var temporary:=options[i]; options[i]=options[j]; options[j]=temporary
	question={"text":expression,"answer":answer,"options":options}

func tick(delta: float) -> void:
	if not active: return
	elapsed+=delta
	if elapsed>=limit: active=false; won=false

func answer(value: int) -> bool:
	if not active or elapsed>=limit: return false
	if value!=int(question.answer): mistakes+=1; return false
	correct+=1
	if correct>=5: active=false; won=true
	else: next_question()
	return true

func abandon() -> void:
	active=false; won=false
