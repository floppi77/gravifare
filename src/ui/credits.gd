extends Control
## Credits-Abspann: scrollender Text über dem animierten Menühintergrund. A/Enter beschleunigt, B/Esc beendet.

var lines: Array = []
var scroll_y := 380.0
var lang := "de"

func _ready() -> void:
	Music.play_theme("menu")
	Music.set_layers(true, false)
	Music.duck(0.0)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	lang = TranslationServer.get_locale().substr(0, 2)
	var f := FileAccess.open("res://data/credits.json", FileAccess.READ)
	var d = JSON.parse_string(f.get_as_text()) if f != null else null
	if typeof(d) == TYPE_DICTIONARY:
		lines = d.get("lines", [])
	var backdrop := Control.new()
	backdrop.set_script(load("res://src/ui/menu_backdrop.gd"))
	add_child(backdrop)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.03, 0.1, 0.55)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)
	var view := Control.new()
	view.set_script(load("res://src/ui/credits_view.gd"))
	view.lines = lines
	view.lang = lang
	view.owner_scene = self
	view.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(view)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()   # vor dem Szenenwechsel, danach hat der Knoten keinen Viewport mehr
		Flow.to_menu()
