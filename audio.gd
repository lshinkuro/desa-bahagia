extends Node
# Musik latar & efek suara. Aset: Kenney (CC0) + OpenGameArt (CC0).

const SFX = {
	"click": "click_002.ogg", "hover": "select_001.ogg", "pickup": "drop_002.ogg",
	"pluck": "pluck_001.ogg", "coins": "handleCoins.ogg", "error": "error_004.ogg",
	"door": "doorOpen_1.ogg", "milk": "metalPot1.ogg", "eat": "chop.ogg",
	"cloth": "cloth1.ogg", "mission": "jingles_PIZZI04.ogg", "win": "jingles_STEEL00.ogg",
	"daily": "confirmation_002.ogg", "moo": "moo.wav", "open": "open_002.ogg",
}
var cache := {}
var footsteps: Array = []
var music: AudioStreamPlayer


func _ready() -> void:
	for bus in ["Music", "SFX"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	set_volume("Music", 0.6)
	set_volume("SFX", 0.8)
	for k in SFX:
		cache[k] = load("res://assets/audio/" + SFX[k])
	for i in 5:
		footsteps.append(load("res://assets/audio/footstep_grass_00%d.ogg" % i))
	music = AudioStreamPlayer.new()
	var stream: AudioStream = load("res://assets/audio/music_hot_spring_town.ogg")
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	music.stream = stream
	music.bus = "Music"
	music.volume_db = -6
	add_child(music)
	music.play()


func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))
	AudioServer.set_bus_mute(i, linear <= 0.01)


func _player(stream: AudioStream, at, volume_db: float, pitch: float) -> void:
	var p: Node
	if at is Vector3:
		var p3 := AudioStreamPlayer3D.new()
		p3.position = at
		p3.unit_size = 8
		p3.max_distance = 45
		p = p3
	else:
		p = AudioStreamPlayer.new()
	p.stream = stream
	p.bus = "SFX"
	p.volume_db = volume_db
	p.pitch_scale = pitch
	add_child(p)
	p.finished.connect(p.queue_free)
	p.play()


func sfx(name: String, at = null, volume_db := 0.0) -> void:
	if cache.has(name):
		_player(cache[name], at, volume_db, randf_range(0.95, 1.05))


func footstep() -> void:
	_player(footsteps[randi() % footsteps.size()], null, -10.0, randf_range(0.9, 1.1))


func moo(at: Vector3) -> void:
	_player(cache["moo"], at, 2.0, randf_range(0.85, 1.1))
