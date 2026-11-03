extends Node
## Autoload "Settings": persistente Optionen in user://settings.cfg. Defekte/fehlende Datei -> Standardwerte.

var path := "user://settings.cfg"
var values := {
	"master": 1.0, "music": 0.8, "sfx": 0.9, "voice": 1.0,
	"language": "",
	"gear_toggle": true, "deadzone": 0.2,
	"fullscreen": false, "vsync": true, "reduce_motion": false, "subtitles": true, "vibration": 1.0, "fps_cap": 0, "show_fps": false, "hints": true, "landing_assist": true, "ghost": true, "debug": false,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	var first_start := not FileAccess.file_exists(path)
	load_settings()
	apply()
	apply_display()
	if not values.fullscreen:
		fit_window(first_start)

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(path) != OK:
		return
	for k in values:
		var v = cf.get_value("settings", k, values[k])
		if typeof(v) == typeof(values[k]):
			values[k] = v
	for k in ["master", "music", "sfx", "voice", "deadzone", "vibration"]:
		values[k] = clampf(values[k], 0.0, 1.0)

## Atomar wie der Spielstand: erst in eine .tmp-Datei, dann umbenennen (ein Absturz beim Schreiben lässt die alte Datei stehen).
func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	var tmp := path + ".tmp"
	if cf.save(tmp) != OK:
		push_warning("Einstellungen nicht schreibbar")
		return
	DirAccess.rename_absolute(tmp, path)

func set_value(key: String, v) -> void:
	values[key] = v
	apply()
	if key in DISPLAY_KEYS:
		apply_display()
	save_settings()

func apply() -> void:
	Sfx.set_volume("Master", values.master)
	Sfx.set_volume("Music", values.music)
	Sfx.set_volume("SFX", values.sfx)
	Sfx.set_volume("Voice", values.voice)
	var lang: String = values.language
	if lang == "":
		lang = "de" if OS.get_locale_language() == "de" else "en"
	Loc.set_language(lang)
	Controls.gear_toggle = values.gear_toggle
	Controls.deadzone = values.deadzone
	for a in ["thrust_left", "thrust_right", "thrust_up", "thrust_down"]:
		InputMap.action_set_deadzone(a, values.deadzone)
	Engine.max_fps = int(values.fps_cap)
	_update_fps_overlay()

const DISPLAY_KEYS := ["fullscreen", "vsync"]
const Stage := preload("res://src/core/stage.gd")

## Vollbild und VSync nur setzen, wenn sie sich vom aktuellen Zustand unterscheiden: Andere Optionen (z. B. Lautstärke)
## lassen das Fenster in Ruhe, und ein maximiertes Fenster bleibt maximiert.
func apply_display() -> void:
	if DisplayServer.get_name() == "headless":
		return
	var mode := DisplayServer.window_get_mode()
	var is_fs := mode == DisplayServer.WINDOW_MODE_FULLSCREEN or mode == DisplayServer.WINDOW_MODE_EXCLUSIVE_FULLSCREEN
	if values.fullscreen and not is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)
	elif not values.fullscreen and is_fs:
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_WINDOWED)
		fit_window()
	var vs := DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED
	if DisplayServer.window_get_vsync_mode() != vs:
		DisplayServer.window_set_vsync_mode(vs)

## Fenstermodus: Das Fenster (Standard 1920×1080) muss samt Rahmen auf den Bildschirm passen. Sonst wird es auf das
## größte ganzzahlige Vielfache von 640×360 verkleinert, das passt (z. B. 1280×720 auf einem 1080p-Bildschirm mit Taskleiste),
## und zentriert. Passt nicht einmal 1280×720 (z. B. 1366×768), wäre das Bild im Fenster nur einfach groß: Dann startet das
## Spiel beim allerersten Start (`allow_fullscreen`) im Vollbild, das die Option auch speichert. Nie größer als die Vorgabe;
## Fenstergröße/Vollbild per Kommandozeile (Tests, Trailer-Aufnahme) bleiben unberührt.
func fit_window(allow_fullscreen := false) -> void:
	if DisplayServer.get_name() == "headless" or _size_from_cmdline():
		return
	if DisplayServer.window_get_mode() != DisplayServer.WINDOW_MODE_WINDOWED:
		return
	var screen := DisplayServer.window_get_current_screen()
	var usable := DisplayServer.screen_get_usable_rect(screen)
	var want := Stage.window_size_for(usable.size, DisplayServer.window_get_size())
	if want == DisplayServer.window_get_size():
		return
	if allow_fullscreen and Stage.wants_fullscreen(want, DisplayServer.screen_get_size(screen)):
		set_value("fullscreen", true)
		return
	DisplayServer.window_set_size(want)
	DisplayServer.window_set_position(usable.position + (usable.size - want) / 2)

func _size_from_cmdline() -> bool:
	for a in OS.get_cmdline_args():
		if a in ["--resolution", "-f", "--fullscreen", "-m", "--maximized", "--position", "--write-movie"] or a.begins_with("--resolution=") or a.begins_with("--position="):
			return true
	return false

var _fps_label: Label

## Kleine FPS-Anzeige oben rechts (Option „FPS anzeigen“).
func _update_fps_overlay() -> void:
	if values.show_fps and _fps_label == null:
		var layer := CanvasLayer.new()
		layer.layer = 100
		_fps_label = Label.new()
		_fps_label.position = Vector2(560, 2)
		_fps_label.add_theme_font_size_override("font_size", 8)
		_fps_label.add_theme_color_override("font_color", Color("#5dff9a"))
		layer.add_child(_fps_label)
		add_child(layer)
	if _fps_label != null:
		_fps_label.get_parent().visible = values.show_fps

func _process(_d: float) -> void:
	if _fps_label != null and values.show_fps:
		_fps_label.text = "%d FPS" % Engine.get_frames_per_second()
