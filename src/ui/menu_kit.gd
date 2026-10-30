class_name MenuKit
extends RefCounted
## Gemeinsame Menü-Bausteine (Theme, Buttons, Slider) – ein einheitlicher Stil für alle Menüs.

static func make_theme() -> Theme:
	var th := Theme.new()
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#1b1f3a")
	normal.border_color = Color("#3a4580")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(5)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.bg_color = Color("#2f3a78")
	focus.border_color = Color("#ffe14a")
	var pressed := focus.duplicate() as StyleBoxFlat
	pressed.bg_color = Color("#4a56a8")
	th.set_stylebox("normal", "Button", normal)
	th.set_stylebox("hover", "Button", focus)
	th.set_stylebox("focus", "Button", focus)
	th.set_stylebox("pressed", "Button", pressed)
	th.set_stylebox("disabled", "Button", normal)
	th.set_color("font_color", "Button", Color("#c9cfee"))
	th.set_color("font_focus_color", "Button", Color.WHITE)
	th.set_color("font_hover_color", "Button", Color.WHITE)
	th.set_color("font_disabled_color", "Button", Color("#5a628f"))
	th.set_font_size("font_size", "Button", 10)
	th.set_font_size("font_size", "Label", 10)
	th.set_color("font_color", "Label", Color("#c9cfee"))
	return th

static func button(text: String, cb: Callable) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(160, 20)
	b.focus_mode = Control.FOCUS_ALL
	b.pressed.connect(func():
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
	return b

static func slider_row(label: String, value: float, on_change: Callable) -> HBoxContainer:
	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	var l := Label.new()
	l.text = label
	l.custom_minimum_size = Vector2(70, 0)
	var s := HSlider.new()
	s.min_value = 0.0
	s.max_value = 1.0
	s.step = 0.05
	s.value = value
	s.custom_minimum_size = Vector2(90, 16)
	s.focus_mode = Control.FOCUS_ALL
	s.value_changed.connect(func(v): on_change.call(v))
	row.add_child(l)
	row.add_child(s)
	return row

## Flaggenknopf für die Sprachwahl (kein Text). Gewählte Sprache: goldener Rahmen; Fokus: weißer Rahmen.
static func flag_button(tex: Texture2D, selected: bool, tip: String, cb: Callable) -> Button:
	var b := Button.new()
	b.icon = tex
	b.expand_icon = true
	b.add_theme_constant_override("icon_max_width", 40)
	b.custom_minimum_size = Vector2(52, 36)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	var normal := StyleBoxFlat.new()
	normal.bg_color = Color("#10142b")
	normal.border_color = Color("#ffe14a") if selected else Color("#3a4580")
	normal.set_border_width_all(2)
	normal.set_content_margin_all(4)
	var focus := normal.duplicate() as StyleBoxFlat
	focus.border_color = Color.WHITE
	focus.set_border_width_all(3)
	for st in ["normal", "disabled"]:
		b.add_theme_stylebox_override(st, normal)
	for st in ["hover", "focus", "pressed"]:
		b.add_theme_stylebox_override(st, focus)
	b.add_theme_color_override("icon_normal_color", Color(1, 1, 1, 1.0 if selected else 0.62))
	for c in ["icon_hover_color", "icon_focus_color", "icon_pressed_color"]:
		b.add_theme_color_override(c, Color.WHITE)
	b.pressed.connect(func():
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
	return b

static func title(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#ffe14a"))
	return l

## Optionsliste; wird von Haupt- und Pausenmenü benutzt. `back` kehrt zur vorherigen Seite zurück.
static func options_panel(back: Callable, rebuild: Callable = Callable()) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 4)
	v.add_child(title(v.tr("MENU_OPTIONS")))
	v.add_child(slider_row(v.tr("OPT_MUSIC"), Settings.values.music, func(x): Settings.set_value("music", x)))
	v.add_child(slider_row(v.tr("OPT_SFX"), Settings.values.sfx, func(x): Settings.set_value("sfx", x)))
	v.add_child(slider_row(v.tr("OPT_VOICE"), Settings.values.voice, func(x): Settings.set_value("voice", x)))
	v.add_child(slider_row(v.tr("OPT_DEADZONE"), Settings.values.deadzone, func(x): Settings.set_value("deadzone", clampf(x, 0.05, 0.9))))
	var gear := button("", func(): pass)
	var refresh := func():
		gear.text = v.tr("OPT_GEAR") + ": " + v.tr("OPT_GEAR_TOGGLE" if Settings.values.gear_toggle else "OPT_GEAR_HOLD")
	refresh.call()
	gear.pressed.connect(func():
		Settings.set_value("gear_toggle", not Settings.values.gear_toggle)
		refresh.call())
	v.add_child(gear)
	var lang := button("", func(): pass)
	var lrefresh := func():
		var code: String = TranslationServer.get_locale().substr(0, 2)
		lang.text = v.tr("OPT_LANG") + ": " + ("Deutsch" if code == "de" else "English")
	lrefresh.call()
	lang.pressed.connect(func():
		var cur: String = TranslationServer.get_locale().substr(0, 2)
		Settings.set_value("language", "en" if cur == "de" else "de")
		lrefresh.call()
		if rebuild.is_valid():
			rebuild.call())      # Menü neu aufbauen, damit alle Texte die neue Sprache zeigen
	v.add_child(lang)
	var fs := button("", func(): pass)
	var frefresh := func():
		fs.text = v.tr("OPT_FULLSCREEN") + ": " + v.tr("ON" if Settings.values.fullscreen else "OFF")
	frefresh.call()
	fs.pressed.connect(func():
		Settings.set_value("fullscreen", not Settings.values.fullscreen)
		frefresh.call())
	v.add_child(fs)
	var rm := button("", func(): pass)
	var rrefresh := func():
		rm.text = v.tr("OPT_REDUCE") + ": " + v.tr("ON" if Settings.values.reduce_motion else "OFF")
	rrefresh.call()
	rm.pressed.connect(func():
		Settings.set_value("reduce_motion", not Settings.values.reduce_motion)
		rrefresh.call())
	v.add_child(rm)
	var sub := button("", func(): pass)
	var srefresh := func():
		sub.text = v.tr("OPT_SUBTITLES") + ": " + v.tr("ON" if Settings.values.subtitles else "OFF")
	srefresh.call()
	sub.pressed.connect(func():
		Settings.set_value("subtitles", not Settings.values.subtitles)
		srefresh.call())
	v.add_child(sub)
	v.add_child(button(v.tr("MENU_BACK"), back))
	return v
