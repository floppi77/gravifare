extends Node
## Autoload "Sfx": Audiobusse (Master/Music/SFX/Voice) mit getrennten Lautstärken, Einmal-Effekte
## und die Schub-Schleifen. Fehlende Dateien werden übersprungen (Spiel läuft stumm weiter).

const NAMES := ["land", "gear", "crash", "hit", "warn", "coin", "board", "exit", "transit", "ui_move", "ui_ok", "pump_hit", "pump_boom", "price_tick", "near_miss", "perfect", "scream_f", "scream_m", "splat", "flatline", "shatter", "plasma_warn", "meteor_warn", "exit_tick", "exit_tick_fast"]
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

## Beim Beenden die Dauerschleifen (Schub) anhalten, damit ihre Wiedergabe-Objekte mit freigegeben werden.
func _exit_tree() -> void:
	for p in [thrust_player, side_player]:
		if p != null:
			p.stop()

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

## Effekte mit leichter Tonhöhen-/Lautstärke-Variation (gegen den „Maschinengewehr“-Effekt bei häufigen Geräuschen).
const VARY := {"land": 0.05, "hit": 0.07, "coin": 0.04, "board": 0.05, "price_tick": 0.04, "pump_hit": 0.06, "gear": 0.04, "near_miss": 0.03}
## Wichtige Effekte werden nie verdrängt, wenn alle Kanäle belegt sind.
const KEEP := ["crash", "pump_boom", "shatter", "splat", "exit", "flatline", "scream_f", "scream_m", "perfect"]
var _steal := 0

func play(name: String, volume_db := 0.0, pitch := 1.0) -> void:
	var s: AudioStream = streams.get(name)
	if s == null:
		return
	var slot: AudioStreamPlayer = null
	for p in pool:
		if not p.playing:
			slot = p
			break
	if slot == null:
		for i in pool.size():                        # alle belegt: einen unwichtigen Kanal reihum verdrängen statt den Ton still zu verwerfen
			var cand: AudioStreamPlayer = pool[(_steal + i) % pool.size()]
			if not bool(cand.get_meta("keep", false)):
				slot = cand
				_steal = (_steal + i + 1) % pool.size()
				break
		if slot == null:
			return
	var v: float = VARY.get(name, 0.0)
	slot.stream = s
	slot.pitch_scale = pitch * (1.0 + randf_range(-v, v) if v > 0.0 else 1.0)
	slot.volume_db = volume_db + (randf_range(-v, v) * 20.0 if v > 0.0 else 0.0)
	slot.set_meta("keep", KEEP.has(name))
	slot.play()

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
var narration_until := 0       # ms-Zeitpunkt, bis zu dem eine Erzählerstimme (Tutorial, Einspieler) läuft: Fahrgast-Zurufe schweigen

func play_voice(voice: String, line: String) -> bool:
	if voice != "d0" and voice != "i0" and Time.get_ticks_msec() < narration_until:
		return false
	var lang := TranslationServer.get_locale().substr(0, 2)
	var path := "res://assets/audio/voice/%s/%s_%s.ogg" % [lang, voice, line]
	if not ResourceLoader.exists(path):
		return false
	var stream: AudioStream = load(path)
	voice_player.stream = stream
	voice_player.play()
	Music.duck_timed(-6.0, stream.get_length() + 0.25)     # Musik leiser, solange gesprochen wird
	return true

## Raumklang des Sektors: leise Schleife unter dem Spiel; wechselt mit weicher Blende.
var amb_player: AudioStreamPlayer
var _amb := 0

func play_ambient(sector: int) -> void:
	if sector == _amb:
		return
	_amb = sector
	var s: AudioStream = _load("res://assets/audio/sfx/amb_s%d.wav" % sector)
	if s == null:
		return
	if amb_player == null:
		amb_player = AudioStreamPlayer.new()
		amb_player.bus = "SFX"
		add_child(amb_player)
	if s is AudioStreamWAV:
		s = s.duplicate()
		s.loop_mode = AudioStreamWAV.LOOP_FORWARD
		s.loop_begin = 0
		s.loop_end = int(s.data.size() / 2)
	amb_player.stream = s
	amb_player.volume_db = -50.0
	amb_player.play()
	create_tween().tween_property(amb_player, "volume_db", AMB_DB, 2.0)

func stop_ambient() -> void:
	_amb = 0
	if amb_player != null and amb_player.playing:
		var tw := create_tween()
		tw.tween_property(amb_player, "volume_db", -50.0, 0.6)
		tw.tween_callback(amb_player.stop)

const AMB_DB := -17.0

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

var _lines := {}

## Untertiteltext einer Sondersprechzeile (Tankwart t0, Zentrale d0, Passagier-Extras) aus data/voice_lines.json.
func line_text(group: String, key: String) -> String:
	if _lines.is_empty():
		var f := FileAccess.open("res://data/voice_lines.json", FileAccess.READ)
		var d = JSON.parse_string(f.get_as_text()) if f != null else null
		_lines = d if typeof(d) == TYPE_DICTIONARY else {"_": 1}
	var lang := TranslationServer.get_locale().substr(0, 2)
	return String(_lines.get(group, {}).get(lang, {}).get(key, ""))
