extends Node
## Autoload "Settings": persistente Optionen in user://settings.cfg. Defekte/fehlende Datei -> Standardwerte.

const PATH := "user://settings.cfg"
var values := {
	"music": 0.8, "sfx": 0.9, "voice": 1.0,
	"language": "",
	"gear_toggle": true, "deadzone": 0.2,
	"fullscreen": false, "vsync": true, "reduce_motion": false, "subtitles": true,
}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	load_settings()
	apply()

func load_settings() -> void:
	var cf := ConfigFile.new()
	if cf.load(PATH) != OK:
		return
	for k in values:
		var v = cf.get_value("settings", k, values[k])
		if typeof(v) == typeof(values[k]):
			values[k] = v
	for k in ["music", "sfx", "voice", "deadzone"]:
		values[k] = clampf(values[k], 0.0, 1.0)

func save_settings() -> void:
	var cf := ConfigFile.new()
	for k in values:
		cf.set_value("settings", k, values[k])
	cf.save(PATH)

func set_value(key: String, v) -> void:
	values[key] = v
	apply()
	save_settings()

func apply() -> void:
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
	if not DisplayServer.get_name() == "headless":
		DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN if values.fullscreen else DisplayServer.WINDOW_MODE_WINDOWED)
		DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_ENABLED if values.vsync else DisplayServer.VSYNC_DISABLED)
