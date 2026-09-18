extends Node
## Generated tones are disposable S01 previews, not final music or sheep audio.
var music := AudioStreamPlayer.new()
var sfx := AudioStreamPlayer.new()

func _ready() -> void:
	for bus_name in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus_name) < 0:
			AudioServer.add_bus()
			AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
			AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	music.bus = "Music"
	sfx.bus = "SFX"
	add_child(music)
	add_child(sfx)
	music.stream = _tone(330, 0.8)
	sfx.stream = _tone(660, 0.18)

func apply_settings(settings: Dictionary) -> void:
	for item in [["Master", "master"], ["Music", "music"], ["SFX", "sfx"]]:
		var index := AudioServer.get_bus_index(item[0])
		var volume: float = settings[item[1]]
		AudioServer.set_bus_mute(index, volume <= 0.0)
		AudioServer.set_bus_volume_db(index, linear_to_db(maxf(volume, 0.0001)))

func preview(channel: String) -> void:
	if channel == "music":
		music.play()
	else:
		sfx.play()

func stop_previews() -> void:
	music.stop()
	sfx.stop()

func _tone(frequency: float, seconds: float) -> AudioStreamWAV:
	var data := PackedByteArray()
	var samples := int(22050 * seconds)
	data.resize(samples * 2)
	for i in samples:
		var envelope := sin(PI * float(i) / samples)
		data.encode_s16(i * 2, int(sin(TAU * frequency * i / 22050.0) * envelope * 5000))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = 22050
	stream.data = data
	return stream
