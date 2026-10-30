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
	b.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
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
	b.custom_minimum_size = Vector2(54, 38)
	b.tooltip_text = tip
	b.focus_mode = Control.FOCUS_ALL
	# Flagge als zentriertes Kind (Button-Icons sitzen nicht mittig im Rahmen)
	var flag := TextureRect.new()
	flag.texture = tex
	flag.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	flag.stretch_mode = TextureRect.STRETCH_SCALE
	flag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flag.set_anchors_preset(Control.PRESET_CENTER)
	flag.offset_left = -20.0
	flag.offset_right = 20.0
	flag.offset_top = -13.33
	flag.offset_bottom = 13.33
	flag.modulate = Color(1, 1, 1, 1.0 if selected else 0.62)
	b.add_child(flag)
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
	b.focus_entered.connect(func(): flag.modulate = Color.WHITE)
	b.focus_exited.connect(func(): flag.modulate = Color(1, 1, 1, 1.0 if selected else 0.62))
	b.pressed.connect(func():
		Sfx.play("ui_ok")
		cb.call())
	b.focus_entered.connect(func(): Sfx.play("ui_move", -6.0))
	return b

## Sprachwahl: zwei Flaggen ohne Text (Haupt- und Pausenmenü). `on_select(code)` wird mit "de"/"en" aufgerufen.
static func flag_row(on_select: Callable) -> HBoxContainer:
	var flags := HBoxContainer.new()
	flags.alignment = BoxContainer.ALIGNMENT_CENTER
	flags.add_theme_constant_override("separation", 10)
	var cur := TranslationServer.get_locale().substr(0, 2)
	for entry in [["de", "res://assets/art/flag_de.png", "Deutsch"], ["en", "res://assets/art/flag_en.png", "English"]]:
		var code: String = entry[0]
		var fb := flag_button(load(entry[1]), cur == code, entry[2], func():
			Settings.set_value("language", code)
			on_select.call(code))
		fb.set_meta("lang", code)
		flags.add_child(fb)
	return flags

static func title(text: String, size := 16) -> Label:
	var l := Label.new()
	l.text = text
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color("#ffe14a"))
	if size >= 20:
		l.add_theme_font_override("font", Fonts.title)          # große Überschriften in der Pixel-Schrift
	return l

## Optionen (Kategorien-Seiten); wird von Haupt- und Pausenmenü benutzt. `back` kehrt zur vorherigen Seite zurück.
static func options_panel(back: Callable, rebuild: Callable = Callable()) -> VBoxContainer:
	return OptionsPanel.new(back, rebuild)
