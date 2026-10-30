extends Node
## Autoload "Sfx": Audiobusse (Master/Music/SFX/Voice) mit getrennten Lautstärken, Einmal-Effekte
## und die Schub-Schleifen. Fehlende Dateien werden übersprungen (Spiel läuft stumm weiter).

const NAMES := ["land", "gear", "crash", "hit", "warn", "coin", "board", "exit", "transit", "ui_move", "ui_ok", "pump_hit", "pump_boom", "price_tick"]
var streams := {}
var thrust_player: AudioStreamPlayer
var side_player: AudioStreamPlayer
var pool: Array[AudioStreamPlayer] = []
var voice_player: AudioStreamPlayer
var long_player: AudioStreamPlayer

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for b in ["Music", "SFX", "Voice"]:
		if AudioServer.get_bus_index(b) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, b)
			AudioServer.set_bus_send(i, "Master")
	for n in NAMES:
		var s := _load("res://assets/audio/sfx/%s.wav" % n)
		if s != null:
			streams[n] = s
	thrust_player = _loop_player("thrust")
	side_player = _loop_player("side")
	long_player = AudioStreamPlayer.new()
	long_player.bus = "SFX"
	add_child(long_player)
	voice_player = AudioStreamPlayer.new()
	voice_player.bus = "Voice"
	add_child(voice_player)
	for i in 8:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		pool.append(p)

func _load(path: String) -> AudioStream:
	if not ResourceLoader.exists(path):
		return null
	return load(path)

func _loop_player(name: String) -> AudioStreamPlayer:
	var p := AudioStreamPlayer.new()
	p.bus = "SFX"
	p.volume_db = -80.0
	var s := _load("res://assets/audio/sfx/%s.wav" % name)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.data.size() / 2)
		p.stream = s
	add_child(p)
	if p.stream != null:
		p.play()
	return p

func play(name: String, volume_db := 0.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	for p in pool:
		if not p.playing:
			p.stream = s
			p.volume_db = volume_db
			p.play()
			return

## main/side 0..1; wird jeden Tick vom Spiel gesetzt (0 = still).
func set_thrust(main: float, side: float) -> void:
	thrust_player.volume_db = -80.0 if main <= 0.01 else linear_to_db(0.25 + 0.75 * main) - 6.0
	thrust_player.pitch_scale = 0.8 + 0.4 * main
	side_player.volume_db = -80.0 if side <= 0.01 else linear_to_db(0.3 + 0.7 * side) - 10.0

func set_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i >= 0:
		AudioServer.set_bus_volume_db(i, linear_to_db(clampf(linear, 0.0001, 1.0)))
		AudioServer.set_bus_mute(i, linear <= 0.001)

## Fahrgast-Sprachzeile abspielen (Datei: voice/<sprache>/<stimme>_<zeile>.ogg). Fehlt sie, bleibt es beim
## Untertitel – das Spiel funktioniert vollständig ohne Sprachdateien.
func play_voice(voice: String, line: String) -> bool:
	var lang := TranslationServer.get_locale().substr(0, 2)
	var path := "res://assets/audio/voice/%s/%s_%s.ogg" % [lang, voice, line]
	if not ResourceLoader.exists(path):
		return false
	voice_player.stream = load(path)
	voice_player.play()
	return true

## Langer Einzelklang (Levelwechsel-Flug); stop_long() bricht ihn z. B. beim Überspringen ab.
func play_long(name: String, volume_db := 0.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	long_player.stream = s
	long_player.volume_db = volume_db
	long_player.play()

func stop_long(fade := 0.35) -> void:
	if long_player.playing:
		var tw := create_tween()
		tw.tween_property(long_player, "volume_db", -60.0, fade)
		tw.tween_callback(long_player.stop)
