extends Node
## Autoload "Music": Themen (menu, t00..t19; ein Thema je 5 Level, C64-SID-Klang) aus drei synchronen Schichten (A Basis, B Bewegung, C Spannung) über
## AudioStreamSynchronized, nahtlos geloopt. Schichten blenden weich ein/aus; Ducking für Sequenzen, Pause, Sprache.
## Fehlen Dateien, bleibt es still (Spiel läuft weiter).

var player: AudioStreamPlayer
var fade_out: AudioStreamPlayer
const FADE_S := 1.6
var current := ""
var target_db: Array = [0.0, -80.0, -80.0]
var cur_db: Array = [-80.0, -80.0, -80.0]
var duck_base := 0.0              # Ducking durch Sequenz/Pause
var duck_voice := 0.0             # kurzes Ducking während Sprachzeilen
var _voice_t := 0.0
var _fade_tw: Tween

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	player = AudioStreamPlayer.new()
	player.bus = "Music"
	add_child(player)
	fade_out = AudioStreamPlayer.new()
	fade_out.bus = "Music"
	add_child(fade_out)

## Thema für eine Levelnummer (1..99): wechselt alle 5 Level (t00 = Level 1–5 … t19 = Level 96–99).
static func theme_for_level(level_no: int) -> String:
	return "t%02d" % clampi((level_no - 1) / 5, 0, 19)

func play_theme(theme: String) -> void:
	if theme == current and player.playing:
		return
	var st := AudioStreamSynchronized.new()
	st.stream_count = 3
	for i in 3:
		var path := "res://assets/audio/music/%s_%s.ogg" % [theme, "ABC"[i]]
		if not ResourceLoader.exists(path):
			return
		var s: AudioStream = load(path)
		if "loop" in s:
			s.loop = true
		st.set_sync_stream(i, s)
	current = theme
	cur_db = [-40.0, -80.0, -80.0]
	target_db = [0.0, -80.0, -80.0]
	if player.playing:                    # altes Thema läuft auf dem zweiten Spieler kurz aus (weicher Übergang)
		if _fade_tw != null:
			_fade_tw.kill()               # sonst stoppt eine laufende Blende den Spieler, der jetzt wieder gebraucht wird
		var old := player
		player = fade_out
		fade_out = old
		_fade_tw = create_tween()
		_fade_tw.tween_property(old, "volume_db", -50.0, FADE_S)
		_fade_tw.tween_callback(old.stop)
		_fade_tw.tween_property(old, "volume_db", 0.0, 0.0)
	player.stream = st
	player.volume_db = 0.0
	player.play()

## B = Bewegung (Arpeggio/Lead), C = Spannung (Drums, Riser).
func set_layers(b: bool, c: bool) -> void:
	target_db[1] = -2.0 if b else -80.0
	target_db[2] = -3.0 if c else -80.0

func duck(db: float) -> void:
	duck_base = db

func duck_timed(db: float, seconds: float) -> void:
	duck_voice = db
	_voice_t = maxf(_voice_t, seconds)

func stop() -> void:
	target_db = [-80.0, -80.0, -80.0]
	current = ""

## Spielposition und Länge des laufenden Themas in Sekunden (Musikplayer).
func track_position() -> float:
	return player.get_playback_position() if player.playing else 0.0

func track_length() -> float:
	return player.stream.get_length() if player.stream != null else 0.0

func _process(delta: float) -> void:
	_voice_t = maxf(0.0, _voice_t - delta)
	var vd := duck_voice if _voice_t > 0.0 else 0.0
	var st := player.stream as AudioStreamSynchronized
	if st == null:
		return
	var d := minf(duck_base, vd)
	for i in 3:
		cur_db[i] = move_toward(cur_db[i], maxf(target_db[i] + d, -80.0), 45.0 * delta)
		st.set_sync_stream_volume(i, cur_db[i])
