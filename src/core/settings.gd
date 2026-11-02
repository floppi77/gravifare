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
	load_settings()
	apply()

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

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(path)

func set_value(key: String, v) -> void:
	values[key] = v
	apply()
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
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)

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
