class_name OptionsPanel
extends VBoxContainer
## Optionen als Kategorien (Audio, Steuerung, Anzeige, Spiel) mit Seiten im selben Container. Die Belegungsseite
## erlaubt freies Umbelegen: Knopf wählen, dann gewünschte Taste/Gamepad-Eingabe drücken (Esc/Start = Abbruch).

var back: Callable
var rebuild: Callable
var page := "root"
var listen := {}
var listen_since := 0
var note := ""
var note_label: Label

func _init(back_cb: Callable = Callable(), rebuild_cb: Callable = Callable()) -> void:
	back = back_cb
	rebuild = rebuild_cb

## Eine Ebene zurück (B/Esc): Unterseite → Übersicht → vorheriger Bildschirm.
func go_back() -> void:
	match page:
		"root":
			if back.is_valid():
				back.call()
		"bindings":
			note = ""
			show_controls()
		_:
			show_root()

func _ready() -> void:
	alignment = BoxContainer.ALIGNMENT_CENTER
	add_theme_constant_override("separation", 4)
	show_root()

func _clear() -> void:
	for c in get_children():
		remove_child(c)
		c.queue_free()

func _focus() -> void:
	await get_tree().process_frame
	for c in find_children("*", "Button", true, false):
		c.grab_focus()
		return

func _toggle(label_key: String, setting: String, on_change := Callable()) -> Button:
	var b := MenuKit.button("", func(): pass)
	var refresh := func(): b.text = tr(label_key) + ": " + tr("ON" if Settings.values[setting] else "OFF")
	refresh.call()
	b.pressed.connect(func():
		Settings.set_value(setting, not Settings.values[setting])
		refresh.call()
		if on_change.is_valid():
			on_change.call())
	return b

func show_root() -> void:
	page = "root"
	_clear()
	add_child(MenuKit.title(tr("MENU_OPTIONS")))
	add_child(MenuKit.button(tr("OPT_CAT_AUDIO"), show_audio))
	add_child(MenuKit.button(tr("OPT_CAT_CONTROLS"), show_controls))
	add_child(MenuKit.button(tr("OPT_CAT_DISPLAY"), show_display))
	add_child(MenuKit.button(tr("OPT_CAT_GAME"), show_game))
	add_child(MenuKit.button(tr("MENU_BACK"), func(): if back.is_valid(): back.call()))
	_focus()

func show_audio() -> void:
	page = "audio"
	_clear()
	add_child(MenuKit.title(tr("OPT_CAT_AUDIO")))
	add_child(MenuKit.slider_row(tr("OPT_MASTER"), Settings.values.master, func(x): Settings.set_value("master", x)))
	add_child(MenuKit.slider_row(tr("OPT_MUSIC"), Settings.values.music, func(x): Settings.set_value("music", x)))
	add_child(MenuKit.slider_row(tr("OPT_SFX"), Settings.values.sfx, func(x): Settings.set_value("sfx", x)))
	add_child(MenuKit.slider_row(tr("OPT_VOICE"), Settings.values.voice, func(x): Settings.set_value("voice", x)))
	add_child(_toggle("OPT_SUBTITLES", "subtitles"))
	add_child(MenuKit.button(tr("MENU_BACK"), show_root))
	_focus()

func show_controls() -> void:
	page = "controls"
	_clear()
	add_child(MenuKit.title(tr("OPT_CAT_CONTROLS")))
	add_child(MenuKit.button(tr("OPT_BINDINGS"), show_bindings))
	add_child(MenuKit.slider_row(tr("OPT_DEADZONE"), Settings.values.deadzone, func(x): Settings.set_value("deadzone", clampf(x, 0.05, 0.9))))
	add_child(MenuKit.slider_row(tr("OPT_VIBRATION"), Settings.values.vibration, func(x):
		Settings.set_value("vibration", x)
		Haptics.pulse(0.4, 0.6, 0.15)))
	var gear := MenuKit.button("", func(): pass)
	var gr := func(): gear.text = tr("OPT_GEAR") + ": " + tr("OPT_GEAR_TOGGLE" if Settings.values.gear_toggle else "OPT_GEAR_HOLD")
	gr.call()
	gear.pressed.connect(func():
		Settings.set_value("gear_toggle", not Settings.values.gear_toggle)
		gr.call())
	add_child(gear)
	add_child(MenuKit.button(tr("MENU_BACK"), show_root))
	_focus()

func show_display() -> void:
	page = "display"
	_clear()
	add_child(MenuKit.title(tr("OPT_CAT_DISPLAY")))
	add_child(_toggle("OPT_FULLSCREEN", "fullscreen"))
	add_child(_toggle("OPT_VSYNC", "vsync"))
	var fps := MenuKit.button("", func(): pass)
	var fr := func():
		var v: int = Settings.values.fps_cap
		fps.text = tr("OPT_FPS_CAP") + ": " + (tr("OPT_FPS_UNLIMITED") if v <= 0 else str(v))
	fr.call()
	fps.pressed.connect(func():
		var steps := [0, 30, 60, 120, 144, 240]
		var i := steps.find(int(Settings.values.fps_cap))
		Settings.set_value("fps_cap", steps[(i + 1) % steps.size()])
		fr.call())
	add_child(fps)
	add_child(_toggle("OPT_SHOW_FPS", "show_fps"))
	add_child(_toggle("OPT_REDUCE", "reduce_motion"))
	add_child(MenuKit.button(tr("MENU_BACK"), show_root))
	_focus()

func show_game() -> void:
	page = "game"
	_clear()
	add_child(MenuKit.title(tr("OPT_CAT_GAME")))
	var lang := MenuKit.button("", func(): pass)
	var lr := func():
		var code: String = TranslationServer.get_locale().substr(0, 2)
		lang.text = tr("OPT_LANG") + ": " + ("Deutsch" if code == "de" else "English")
	lr.call()
	lang.pressed.connect(func():
		var cur: String = TranslationServer.get_locale().substr(0, 2)
		Settings.set_value("language", "en" if cur == "de" else "de")
		if rebuild.is_valid():
			rebuild.call()
		else:
			show_game())
	add_child(lang)
	add_child(_toggle("OPT_HINTS", "hints"))
	add_child(_toggle("OPT_ASSIST", "landing_assist"))
	add_child(_toggle("OPT_GHOST", "ghost"))
	add_child(MenuKit.button(tr("MENU_BACK"), show_root))
	_focus()

# ------------------------------------------------------------------ Belegung
func show_bindings() -> void:
	page = "bindings"
	_clear()
	listen = {}
	add_child(MenuKit.title(tr("OPT_BINDINGS")))
	var head := HBoxContainer.new()
	head.alignment = BoxContainer.ALIGNMENT_CENTER
	head.add_theme_constant_override("separation", 3)
	var spacer := Label.new()
	spacer.custom_minimum_size = Vector2(86, 0)
	head.add_child(spacer)
	for h in ["BIND_KB1", "BIND_KB2", "BIND_PAD1", "BIND_PAD2"]:
		var l := Label.new()
		l.text = tr(h)
		l.custom_minimum_size = Vector2(62, 0)
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.add_theme_font_size_override("font_size", 8)
		l.add_theme_color_override("font_color", Color("#a9b8ff"))
		head.add_child(l)
	add_child(head)
	for action in Controls.REMAPPABLE:
		var row := HBoxContainer.new()
		row.alignment = BoxContainer.ALIGNMENT_CENTER
		row.add_theme_constant_override("separation", 3)
		var l := Label.new()
		l.text = tr("ACT_" + action.to_upper())
		l.custom_minimum_size = Vector2(86, 0)
		row.add_child(l)
		for cell in [["kb", 0], ["kb", 1], ["pad", 0], ["pad", 1]]:
			var kind: String = cell[0]
			var slot: int = cell[1]
			var b := Button.new()
			b.custom_minimum_size = Vector2(62, 16)
			b.focus_mode = Control.FOCUS_ALL
			b.add_theme_font_size_override("font_size", 8)
			b.text = Controls.slot_label(action, kind, slot)
			b.pressed.connect(func():
				listen = {"action": action, "kind": kind, "slot": slot, "btn": b}
				listen_since = Time.get_ticks_msec()
				b.text = "…"
				_set_note(tr("BIND_PRESS") % (tr("BIND_KB1") if kind == "kb" else tr("BIND_PAD1")).left(8)))
			row.add_child(b)
		add_child(row)
	note_label = Label.new()
	note_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	note_label.add_theme_font_size_override("font_size", 8)
	note_label.add_theme_color_override("font_color", Color("#ffe14a"))
	note_label.text = note
	note_label.custom_minimum_size = Vector2(0, 12)
	add_child(note_label)
	add_child(MenuKit.button(tr("BIND_RESET"), func():
		Controls.reset_defaults()
		note = tr("BIND_RESET_DONE")
		show_bindings()))
	add_child(MenuKit.button(tr("MENU_BACK"), func():
		note = ""
		show_controls()))
	_focus()

func _set_note(t: String) -> void:
	note = t
	if note_label != null and is_instance_valid(note_label):
		note_label.text = t

func _input(event: InputEvent) -> void:
	if listen.is_empty():
		return
	if Time.get_ticks_msec() - listen_since < 250:     # den auslösenden Tastendruck nicht mitzählen
		return
	var action: String = listen.action
	var kind: String = listen.kind
	var ev: InputEvent = null
	if event is InputEventKey and event.pressed and not event.echo:
		get_viewport().set_input_as_handled()
		if event.physical_keycode == KEY_ESCAPE:
			_cancel_listen()
			return
		if kind == "kb":
			ev = InputEventKey.new()
			ev.physical_keycode = event.physical_keycode
	elif event is InputEventJoypadButton and event.pressed:
		get_viewport().set_input_as_handled()
		if event.button_index == JOY_BUTTON_START:
			_cancel_listen()
			return
		if kind == "pad":
			ev = InputEventJoypadButton.new()
			ev.button_index = event.button_index
	elif event is InputEventJoypadMotion and absf(event.axis_value) >= 0.7 and kind == "pad" and action.begins_with("thrust_") and event.axis < 4:
		get_viewport().set_input_as_handled()
		ev = InputEventJoypadMotion.new()
		ev.axis = event.axis
		ev.axis_value = signf(event.axis_value)
	if ev == null:
		return
	var swapped := Controls.set_slot(action, kind, int(listen.slot), ev)
	Sfx.play("ui_ok")
	note = tr("BIND_SWAPPED") % tr("ACT_" + swapped.to_upper()) if swapped != "" else tr("BIND_SAVED")
	listen = {}
	show_bindings()

func _cancel_listen() -> void:
	listen = {}
	note = ""
	show_bindings()
