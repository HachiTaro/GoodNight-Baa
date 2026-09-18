extends Node
## Small original synthesized sounds; no remote audio or external dependency.
var enabled := true
var music := true
var volume := 0.6
var note_clock := 0.0
var note_index := 0
var night := false
var melody := [261.63,329.63,392.0,329.63,293.66,349.23,440.0,349.23]

func tone(frequency: float,duration: float=0.16,gain: float=0.16) -> void:
	if not enabled or volume<=0: return
	var rate:=22050
	var data:=PackedByteArray(); data.resize(int(rate*duration)*2)
	for i in int(rate*duration):
		var t:=float(i)/rate
		var envelope:=minf(1,t/0.012)*pow(1-t/duration,2)
		var sample:=int(sin(TAU*frequency*t)*envelope*gain*volume*32767)
		data.encode_s16(i*2,sample)
	var stream:=AudioStreamWAV.new(); stream.format=AudioStreamWAV.FORMAT_16_BITS; stream.mix_rate=rate; stream.data=data
	var player:=AudioStreamPlayer.new(); player.stream=stream; add_child(player); player.finished.connect(player.queue_free); player.play()

func bleat() -> void:
	tone(370,0.25,0.23)

func _process(delta: float) -> void:
	if not music: return
	note_clock+=delta
	if note_clock>1.8:
		note_clock=0; tone(melody[note_index%melody.size()]*(0.5 if night else 1.0),1.1,0.04); note_index+=1
