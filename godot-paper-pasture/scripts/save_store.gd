extends RefCounted
const PATH := "user://progress-v1.json"
var path := PATH
var data: Dictionary={"version":1,"unlocked":1,"scores":{},"session":{},"settings":{"volume":0.6,"music":true,"reduced_motion":false}}

func load_save() -> bool:
	for candidate in [path,path+".bak"]:
		if not FileAccess.file_exists(candidate): continue
		var parsed: Variant=JSON.parse_string(FileAccess.get_file_as_string(candidate))
		if parsed is Dictionary and int(parsed.get("version",0))==1 and parsed.get("scores") is Dictionary and parsed.get("session") is Dictionary:
			data.merge(parsed,true)
			data.unlocked=clampi(int(data.unlocked),1,8)
			return true
	return false

func save() -> bool:
	var file := FileAccess.open(path+".tmp",FileAccess.WRITE)
	if not file: return false
	file.store_string(JSON.stringify(data))
	file.flush()
	file.close()
	if FileAccess.file_exists(path):
		if FileAccess.file_exists(path+".bak"): DirAccess.remove_absolute(path+".bak")
		if DirAccess.rename_absolute(path,path+".bak")!=OK: return false
	return DirAccess.rename_absolute(path+".tmp",path)==OK

func record(level_id: int,stars: int,spend: int,discount: bool) -> void:
	var key := str(level_id)
	var previous: Dictionary=data.scores.get(key,{"stars":0})
	previous.stars=maxi(int(previous.stars),stars)
	var category := "discount" if discount else "regular"
	previous[category]=mini(int(previous.get(category,999999)),spend)
	data.scores[key]=previous
	data.unlocked=maxi(int(data.unlocked),mini(8,level_id+1))

func clear_progress() -> void:
	data.unlocked=1
	data.scores={}
	data.session={}
